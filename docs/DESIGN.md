# Design: aws.modules.acm v1

Status: accepted 2026-09-23. Supersedes the v0.1.x "one zone, DNS only" design.

## Purpose

`aws.modules.acm` provisions **one** AWS Certificate Manager certificate per
module call, in exactly one of three modes chosen by the inputs:

- **public**: a certificate requested from ACM for `domain_name` and its
  `subject_alternative_names`, validated by DNS or by email;
- **private**: a certificate issued by an AWS Private CA named in
  `certificate_authority_arn`, which needs no validation;
- **imported**: an existing certificate whose PEM body, private key, and
  optional chain are supplied in `imported`.

For DNS-validated public certificates the module also manages the validation
records across any number of Route 53 hosted zones, choosing the zone for each
domain by longest suffix, and by default blocks the apply until ACM has issued
the certificate so that downstream listeners and distributions never reference
a certificate that is still `PENDING_VALIDATION`.

The module deliberately does **not** create hosted zones, the private CA, or
the consumers of the certificate (load balancer listeners, CloudFront
distributions, API Gateway domain names, VPN endpoints). Those have separate
lifecycles and owners. The module consumes zone IDs and the CA ARN and exposes
the certificate ARN.

## Why the v0.1.x design was replaced

| v0.1.x behaviour | Problem | v1 decision |
|---|---|---|
| Validation records went to one `route53_zone_id`. | A SAN in a delegated subdomain zone, or in a second domain, could not be validated by the module at all. | `route53_zones` is a map of zone name to zone ID. Each validated domain selects the zone whose name is its longest suffix; a precondition names any domain that matches no zone. |
| `validation_method` accepted only `DNS`. | Email validation, the only option for domains whose DNS is not under the caller's control, was impossible. | `DNS` or `EMAIL`. Email validation renders `validation_option` blocks and still waits for issuance when `wait_for_validation` is true. |
| No private CA issuance, no import, no exportable certificates. | Three of the four ways a certificate reaches ACM were out of scope; callers wrote raw resources beside the module. | `certificate_authority_arn`, `imported`, and `options.export`. Exactly one mode is active; preconditions reject mixed inputs with an actionable message. |
| Records were keyed by the computed `domain_validation_options` set. | The keys are known at plan only because the AWS provider pre-populates that set from the inputs during its plan customisation. Anything else (a mock provider under `terraform test`, an unknown `validation_method`) turns into `Invalid for_each argument`, and the record map could not be asserted offline. | Records are keyed by the declared domain list, which is known by construction, and the validation option is looked up per domain. Record keys, zone selection, and counts are known at plan time and covered by tests. |
| Wildcard and apex names produced two records with identical name and value. | Two resources managed one Route 53 record; the second delete failed or raced. | A wildcard whose apex is also on the certificate is skipped at plan time: ACM emits one CNAME for both. `allow_overwrite` remains on for re-requests. |
| `wait_for_validation` was silently ignored when no zone was given. | An apply "succeeded" with a pending certificate and the listener that consumed it failed later, out of context. | Waiting requires zones (DNS) or email validation. A caller who validates externally sets `wait_for_validation = false` explicitly and reads `domain_validation_options` from the outputs. |
| Fixed 60-second TTL; no validation timeout. | Nothing to tune when a registrar caches aggressively or when issuance takes long. | `validation_record_ttl` (default 60) and `validation_timeout` (default `45m`). |
| `certificate_transparency_logging_preference` was a top-level input. | The ACM API groups it with `export` under certificate options; a flat input did not scale. | `options = { certificate_transparency_logging_preference, export }`. Transparency logging stays `ENABLED` by default and a `check` warns when it is disabled. |
| No tests, no examples. | Regressions and interface drift were invisible until an apply. | Mock-provider tests for every mode, validation, and selection rule; six examples exercised by CI. |

## Principles and how the module applies them

- **Single responsibility.** The module owns one certificate and the DNS
  records that prove control of its domains, nothing else. Concerns are split
  by file: `certificate.tf` (the certificate and its mode preconditions),
  `validation.tf` (records and the wait), `locals.tf` (mode selection, domain
  list, zone selection), `checks.tf` (advisory warnings).
- **Open/closed.** New behaviour arrives as data: another zone in
  `route53_zones`, another SAN, an `options` field, a `validation_option`
  entry. No mode requires editing the module.
- **Liskov substitution.** The `arn` and `validated_arn` outputs mean the same
  thing in every mode: `validated_arn` is the ARN a consumer may safely attach
  to, whether it came from the wait resource, a private CA, or an import.
- **Interface segregation.** Each mode reads only its own inputs. A public
  certificate needs `domain_name`; a private certificate adds
  `certificate_authority_arn`; an import needs only `imported`. Everything
  else defaults to a safe value or `null`.
- **Dependency inversion.** The module depends on identifiers (zone IDs, a CA
  ARN), never on how they were produced, and performs no data-source reads.
  The region is the provider's region, which is how CloudFront certificates
  are placed in `us-east-1` through a provider alias.
- **Clean, deterministic code.** Domain lists are sets, record keys are the
  domains themselves, outputs are sorted, and every cross-input rule is a
  precondition with a message that names the offending value.

## Architecture

```text
root (one certificate)
├── variables.tf      Inputs grouped by concern: subject, validation, private CA, import, lifecycle, tags.
├── locals.tf         Mode selection, domain list, longest-suffix zone selection, wildcard/apex de-duplication.
├── certificate.tf    aws_acm_certificate.this: three modes, create_before_destroy, mode preconditions.
├── validation.tf     aws_route53_record.validation["<domain>"], aws_acm_certificate_validation.this[0].
├── checks.tf         Advisory check: certificate_transparency_disabled.
└── outputs.tf        Identity, status, validation data, validated_arn, mode.
```

Data flow for a DNS-validated public certificate: the domain list is
`domain_name` plus the sorted SANs. For each domain the module strips a
leading `*.` and picks the `route53_zones` key that equals it or is the longest
`.`-separated suffix of it. Wildcards whose apex is also listed are dropped
because ACM issues one CNAME for both. The remaining domains become the
`for_each` keys of `aws_route53_record.validation`; each record's name, type,
and value are looked up from the certificate's `domain_validation_options`
entry for that domain, and its zone is the selected zone ID. The validation
resource references every record's FQDN and waits, with
`timeouts.create = validation_timeout`, until ACM reports `ISSUED`.

### Root interface (summary)

Mode selection: `imported` set means import; otherwise
`certificate_authority_arn` set means private; otherwise public.
`domain_name` is required for public and private certificates and must be
absent for imports.

- Subject: `domain_name`, `subject_alternative_names`, `key_algorithm`,
  `name` (the `Name` tag; defaults to `domain_name`).
- Public validation: `validation_method`, `route53_zones`,
  `validation_record_ttl`, `wait_for_validation`, `validation_timeout`,
  `validation_option`, `options`.
- Private CA: `certificate_authority_arn`.
- Import: `imported` (sensitive object).
- Lifecycle: `early_renewal_duration`.
- `tags`.

Outputs expose the certificate identity (`arn`, `id`, `domain_name`,
`subject_alternative_names`, `key_algorithm`), its state (`status`, `type`,
`not_before`, `not_after`, `renewal_eligibility`), the validation data a
caller needs to validate elsewhere (`domain_validation_options`,
`validation_emails`), the records the module created
(`validation_record_fqdns`, `validation_record_ids`,
`validation_record_zone_ids`), the ARN safe to consume (`validated_arn`), and
the resolved `mode`.

### Lifecycle rules

- `create_before_destroy` is always on. Changing the subject, key algorithm,
  validation method, or CA replaces the certificate; the replacement is
  requested and validated before the previous one is deleted, and consumers
  that reference `validated_arn` roll to it in the same apply.
- Validation records are keyed by domain, so adding a SAN adds exactly one
  record and removing it removes exactly one.
- `wait_for_validation` only has meaning for public certificates. Private and
  imported certificates are issued synchronously and the wait is ignored.
- Validation records use `allow_overwrite = true` because ACM emits the same
  CNAME for a re-requested certificate of the same domain and for a wildcard
  and its apex.

## Security defaults

- Certificate transparency logging `ENABLED`; the
  `certificate_transparency_disabled` check warns when it is turned off.
- Certificates are not exportable unless `options.export = "ENABLED"`.
- `RSA_2048` by default, the ACM default with the widest consumer support;
  every ACM algorithm is accepted and validated by name.
- The import object is `sensitive`, so the private key never appears in plan
  output, and no output exposes key material.
- The module adds only a `Name` tag and never overrides a caller tag.
- No data sources, no wildcard IAM, no resources outside the certificate and
  its validation records.

## Testing strategy

- Contract tests use `mock_provider` with `command = plan`; no credentials.
- Under a mock provider `domain_validation_options` is unknown, so tests
  assert on what is known by construction: record keys, zone IDs, TTL,
  counts, the presence of the validation resource and its timeout, tags, and
  outputs derived from inputs.
- `tests/` cover: secure defaults, every variable validation and every
  precondition via `expect_failures`, longest-suffix zone selection, wildcard
  handling, email validation, private CA issuance, import, external
  validation, and the advisory check.
- Every example is initialised, validated, linted, and scanned in CI;
  examples are the documentation's executable form.

## Compatibility

- Terraform `>= 1.7.0, < 2.0.0` (the consuming platform pins 1.7.5).
- AWS provider `>= 6.35.0, < 7.0.0`.
- The certificate is created in the provider's region. CloudFront requires
  `us-east-1`; pass a provider alias (see `examples/cloudfront`).

## Migration

`docs/UPGRADE-1.0.md` maps every v0.1.x input to its v1 equivalent and shows
that the resource addresses are unchanged, so a consumer adopts v1 without
`moved` blocks or certificate replacement.
