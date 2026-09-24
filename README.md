# aws.modules.acm

Provisions one AWS Certificate Manager certificate per module call, in exactly one of three modes chosen by the inputs: a **public** certificate requested from ACM and validated by DNS or email, a **private** certificate issued by an AWS Private CA, or an existing certificate **imported** from PEM material. For DNS validation the module writes the validation records into any number of Route 53 hosted zones, choosing the zone for each name by longest suffix, and by default blocks the apply until ACM reports the certificate `ISSUED`, so a listener or distribution that references `validated_arn` never attaches a pending certificate. It is secure by default and explicit by declaration, creates nothing beyond the certificate and its validation records, and performs no data-source reads. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

What you get from `domain_name` and one zone, without setting anything else:

- Validation records in the right zone. `route53_zones` maps zone names to zone IDs; each validated name selects the zone whose name is its longest suffix, so an apex zone and a delegated subdomain zone work side by side, and a name that matches no zone fails the plan with a message that names it.
- Record keys known at plan time. Validation records are keyed by the domains you declare (`aws_route53_record.validation["app.example.com"]`), not by the certificate's computed `domain_validation_options`. The plan shows which record lands in which zone before the certificate exists, adding a subject alternative name adds exactly one record, and the module's own tests assert on the record map with a mock provider, which the computed-key pattern used by most ACM modules cannot do.
- One record for a wildcard and its apex. ACM emits the same CNAME for `example.com` and `*.example.com`; the module creates one record instead of two resources managing one record set.
- An apply that waits for issuance. `aws_acm_certificate_validation.this[0]` blocks for up to `validation_timeout` (45 minutes) and produces `validated_arn`, so downstream resources depend on issuance. Validating elsewhere is an explicit choice (`wait_for_validation = false`) with the records exposed in `domain_validation_options`.
- Safe certificate defaults. Certificate transparency logging `ENABLED` (an advisory check warns when it is turned off), not exportable, `RSA_2048`, every ACM key algorithm accepted by name.
- Exactly one mode. `certificate_authority_arn` selects private issuance, `imported` selects import, anything else is a public request. Mixed or incomplete input fails at plan time with the fix in the message.
- Key material stays out of plans and outputs. `imported` is a sensitive input and no output returns it.
- Plan-time validation of every input: domain name syntax, zone names and IDs, key algorithm, validation method, TTL, timeout and renewal durations, PEM markers, and the cross-input rules of each mode.
- Only a `Name` tag is added (from `name` or `domain_name`); caller tags are never overridden.

## Quick start

```hcl
module "certificate" {
  source = "git::https://github.com/hatan4ik/aws.modules.acm.git?ref=<commit-sha>" # v1.0.0

  domain_name               = "app.example.com"
  subject_alternative_names = ["*.app.example.com"]

  route53_zones = {
    "example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" }
  }

  tags = { Environment = "prod", Owner = "platform" }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = var.load_balancer_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = module.certificate.validated_arn

  default_action {
    type             = "forward"
    target_group_arn = var.target_group_arn
  }
}
```

This requests a DNS-validated `RSA_2048` certificate for `app.example.com` and `*.app.example.com` with transparency logging enabled, writes one CNAME record (`aws_route53_record.validation["app.example.com"]`; the wildcard shares it) into the zone with a 60-second TTL, waits up to 45 minutes for ACM to issue the certificate, and hands the listener an ARN that exists only once the certificate is `ISSUED`.

## Architecture

```text
root (one certificate)
├── certificate.tf   aws_acm_certificate.this: public request, private CA issuance, or import; create_before_destroy; mode preconditions
├── validation.tf    aws_route53_record.validation["<domain>"] in the longest-suffix zone; aws_acm_certificate_validation.this[0] when waiting
├── locals.tf        Mode resolution, domain list, zone selection, wildcard and apex de-duplication
├── checks.tf        certificate_transparency_disabled (advisory)
└── outputs.tf       Identity, status, validation data, validated_arn, mode
```

The mode follows from the inputs, and every other input is read only by its mode:

| Mode | Selected by | Validation | Rejected in this mode |
| --- | --- | --- | --- |
| `public` | Neither `certificate_authority_arn` nor `imported` is set | `validation_method` `DNS` (records in `route53_zones`, or created elsewhere from `domain_validation_options`) or `EMAIL` (`validation_option` steers the mail) | `early_renewal_duration` |
| `private` | `certificate_authority_arn` | None; the CA issues the certificate on request | `options`, `validation_option`. `route53_zones` and `wait_for_validation` have no effect. |
| `imported` | `imported` | None | `domain_name`, `subject_alternative_names`, `certificate_authority_arn`, `options`, `early_renewal_duration` |

For a DNS-validated public certificate the domain list is `domain_name` plus the sorted `subject_alternative_names`. For each domain the module strips a leading `*.` and selects the `route53_zones` key that equals it or is its longest `.`-separated suffix: with zones `example.com` and `internal.example.com`, `api.internal.example.com` selects the delegated zone, `www.example.com` and `*.example.com` select the apex zone, and `www.example.net` fails the plan. A wildcard whose apex is also on the certificate is dropped from the record list. The remaining domains are the `for_each` keys of `aws_route53_record.validation`; each record's name, type, and value are looked up from the certificate's `domain_validation_options` entry for that domain, so the keys and zones are known at plan time while the values are computed, which is the standard ACM shape. `validation_record_zone_ids` shows the selection in the plan.

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal`](examples/minimal) | One domain, one zone, every default: DNS validation, RSA 2048, wait for issuance. |
| [`examples/multi-zone-san`](examples/multi-zone-san) | Apex, wildcard, and a subject alternative name in a delegated subdomain zone: longest-suffix selection and wildcard de-duplication. |
| [`examples/cloudfront`](examples/cloudfront) | A `us-east-1` provider alias passed with `providers`, the only region CloudFront accepts certificates from. |
| [`examples/private-ca`](examples/private-ca) | Issuance from an AWS Private CA with an elliptic-curve key; no validation, no records. |
| [`examples/external-validation`](examples/external-validation) | DNS hosted outside Route 53: `wait_for_validation = false` and the records exposed for another provider to create. |
| [`examples/multiple-certificates`](examples/multiple-certificates) | `for_each` over a map of certificates sharing a zone map: one module call per certificate. |

## Security model

Certificate

- Certificate transparency logging is `ENABLED` unless `options.certificate_transparency_logging_preference = "DISABLED"`, and the `certificate_transparency_disabled` check warns on every plan while it is. Browsers may refuse a public certificate that is absent from the CT logs; disable it only for a name that must deliberately stay out of them.
- Certificates are not exportable unless `options.export = "ENABLED"`. An exportable certificate lets `acm:ExportCertificate` retrieve the private key, so the flag is an explicit declaration, applies to public certificates only, and is rejected in the other modes.
- `RSA_2048` is the default because every AWS integration accepts it; `RSA_3072`, `RSA_4096`, `EC_prime256v1`, `EC_secp384r1`, and `EC_secp521r1` are validated by name so a typo fails at plan time rather than at apply time.

Key material

- `imported` is declared `sensitive`. The certificate body, private key, and chain never appear in plan output, and no output returns them. Supply the key from a secret store or a file outside version control, never as a literal.
- Terraform state holds what the AWS provider stores for the resource, including an imported private key. Protect the state backend as you would the key.

DNS

- Records are written only to the zones listed in `route53_zones`, and only for the validated names. A domain that matches no listed zone is rejected, so the module can never write into an unexpected zone.
- `allow_overwrite = true` lets a re-requested certificate, or a wildcard and its apex, reuse the one CNAME ACM issues for a name. ACM validation record names are derived from the domain and the account, so nothing else legitimately owns them.
- The principal that applies the module needs `acm:RequestCertificate`, `acm:DescribeCertificate`, `acm:DeleteCertificate`, `acm:AddTagsToCertificate`, `acm:RemoveTagsFromCertificate`, and `acm:ListTagsForCertificate`, plus `acm:ImportCertificate` for imports, permission to issue from the CA (`acm-pca:IssueCertificate`, `acm-pca:GetCertificate`) for private certificates, and `route53:ChangeResourceRecordSets`, `route53:GetChange`, and `route53:ListResourceRecordSets` on the listed zones. The module grants nothing and creates no IAM resources.

Not created here

- Hosted zones, the private CA, and the consumers of the certificate: load balancer listeners, CloudFront distributions, API Gateway domain names, VPN endpoints. They have separate lifecycles and owners. The module consumes zone IDs and the CA ARN and exposes the certificate ARN.

## Lifecycle notes

- `create_before_destroy` is always on. Changing `domain_name`, `subject_alternative_names`, `key_algorithm`, `validation_method`, `certificate_authority_arn`, or the import material replaces the certificate; the replacement is requested and validated before the old one is deleted, and every consumer that references `validated_arn` moves to the new ARN in the same apply. ACM refuses to delete a certificate that is still in use, so a consumer outside Terraform must be repointed first.
- Validation records are keyed by domain. Adding a subject alternative name adds exactly `aws_route53_record.validation["<name>"]`; removing it removes exactly that record. The new certificate's CNAME values are written over the old ones (`allow_overwrite`) in the same apply.
- `wait_for_validation` (default `true`) creates `aws_acm_certificate_validation.this[0]`, which blocks for up to `validation_timeout` (default `45m`). It needs something to wait for: records the module manages (`route53_zones` non-empty) or `EMAIL` validation. With DNS validation and no zones the plan fails until you set `wait_for_validation = false`, which is the external-validation pattern: the apply finishes with the certificate `PENDING_VALIDATION`, `domain_validation_options` lists the records to create, and `validated_arn` equals `arn`. Toggling the flag later adds or removes only the wait resource.
- ACM renews public certificates itself as long as the validation records stay in place (DNS) or the mail is answered (EMAIL), so keep the records under management for the life of the certificate. Private certificates are renewed by Terraform when `early_renewal_duration` is set and the certificate has been exported at least once, the ACM prerequisite for renewing a private certificate; `renewal_eligibility` reports whether a certificate qualifies. Imported certificates are never renewed: re-import by changing `imported`, which replaces the certificate.
- `EMAIL` validation sends mail to the registrant contacts and the standard aliases (`admin@`, `administrator@`, `hostmaster@`, `postmaster@`, `webmaster@`) of each domain, or of the parent domain named in `validation_option`. `validation_emails` lists the addresses ACM used. The wait blocks until someone follows the link, so choose `validation_timeout` accordingly.
- One `check` block warns without blocking: `certificate_transparency_disabled`.
- The certificate is created in the region of the provider you pass. CloudFront reads certificates from `us-east-1` only; hand the module an aliased provider through `providers = { aws = aws.us_east_1 }` (see [`examples/cloudfront`](examples/cloudfront)). Route 53 is global, so the validation records work from any region.

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/`, run by `make test` and by CI) use `mock_provider`: no credentials, nothing created, placeholder zone IDs and the AWS documentation account `123456789012`. Under a mock provider the certificate's `domain_validation_options` are unknown, so the tests assert on what the module knows by construction: record keys, zone selection, TTL, counts, the presence of the wait resource and its timeout, tags, mode, and every validation and precondition through `expect_failures`.
- **Integration suites** (`tests/integration/`, run by `make integration-smoke` or the dispatch-only `integration` workflow) apply the module for real in **your** account with **your** credentials and region from the environment. `smoke` requests a DNS-validated certificate for names under a zone nobody hosts, with `wait_for_validation = false`, asserts what the real API reports (mode, type, status, the validation records ACM expects), and deletes the certificate. No fixtures, no charge, nothing left behind. See [tests/integration/README.md](tests/integration/README.md) for permissions and the GitHub environment contract.

## Design principles

- Single responsibility. The module owns one certificate and the records that prove control of its names, nothing else. Concerns are split by file: `certificate.tf` (the certificate and its mode preconditions), `validation.tf` (records and the wait), `locals.tf` (mode, domain list, zone selection), `checks.tf` (advisory warnings).
- Open/closed. New behaviour arrives as data: another zone in `route53_zones`, another subject alternative name, an `options` field, a `validation_option` entry. No mode needs the module edited.
- Liskov substitution. `validated_arn` means the same thing in every mode: the ARN a consumer may attach to. It comes from the wait resource when the module waits and from the certificate otherwise, so a consumer written against a public certificate works unchanged against a private or imported one.
- Interface segregation. Each mode reads only its own inputs. A public certificate needs `domain_name` and a zone; a private certificate adds `certificate_authority_arn`; an import needs only `imported`. Everything else defaults to a safe value or `null`, and inputs that do not apply to a mode are rejected rather than ignored.
- Dependency inversion. The module depends on identifiers (zone IDs, a CA ARN), never on how they were produced, and performs no data-source reads. The region is the provider's region.

The full rationale, including why the v0.1.x design was replaced, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- Public certificates with DNS or EMAIL validation, exportable public certificates, private certificates from AWS Private CA, and imported certificates. Validation records go to Route 53 hosted zones the provider's credentials can write to; for any other DNS provider, or zones in another account, create the records yourself from `domain_validation_options` and wait with your own `aws_acm_certificate_validation` (see [`examples/external-validation`](examples/external-validation)).
- Nothing in the v1 interface is scheduled to change. Additions arrive as optional inputs and outputs.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "certificate" {
  source = "git::https://github.com/hatan4ik/aws.modules.acm.git?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag points at the revision it checked out, and a maintenance release for an older line (for example a 0.1.x fix after 1.0.0 landed on `main`) is cut from that line's commit.

Upgrading from 0.1.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) for the input and output mapping and the one state operation a wildcard-plus-apex certificate needs. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_authority_arn"></a> [certificate\_authority\_arn](#input\_certificate\_authority\_arn) | ARN of the AWS Private CA that issues the certificate. Setting it selects the private mode: no validation, no transparency logging, no export option. The CA must be in the certificate's region and account, or shared with it through AWS RAM. | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Fully qualified domain name the certificate is issued for: lowercase, at least two labels, optionally starting with a wildcard label (*.example.com). Required for public and private certificates; must be unset for an import, which carries its own subject. | `string` | `null` | no |
| <a name="input_early_renewal_duration"></a> [early\_renewal\_duration](#input\_early\_renewal\_duration) | Private certificates only: how long before expiry Terraform renews the certificate on the next apply, as a subset of an RFC 3339 duration (P90D) or a number of hours (2160h). Has no effect below 60 days. Null leaves renewal to ACM. ACM renews public certificates itself and never renews imports. | `string` | `null` | no |
| <a name="input_imported"></a> [imported](#input\_imported) | PEM material of an existing certificate to import: certificate\_body, private\_key, and the optional certificate\_chain. Setting it selects the import mode; domain\_name and subject\_alternative\_names must then be unset. The whole object is sensitive so the key never appears in plan output. | <pre>object({<br/>    certificate_body  = string<br/>    private_key       = string<br/>    certificate_chain = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_key_algorithm"></a> [key\_algorithm](#input\_key\_algorithm) | Key algorithm of a requested public or private certificate: RSA\_2048 (the ACM default, with the widest consumer support), RSA\_3072, RSA\_4096, EC\_prime256v1, EC\_secp384r1, or EC\_secp521r1. Not used for imports. | `string` | `"RSA_2048"` | no |
| <a name="input_name"></a> [name](#input\_name) | Value of the Name tag. Defaults to domain\_name. Set it for an import, which has no domain\_name; without it an import gets no Name tag. | `string` | `null` | no |
| <a name="input_options"></a> [options](#input\_options) | Public certificate options. certificate\_transparency\_logging\_preference is ENABLED unless set to DISABLED, which keeps the domain out of public CT logs and triggers a warning. export = ENABLED makes the certificate and its private key exportable through ACM; unset or DISABLED does not. Must stay empty for private and imported certificates. | <pre>object({<br/>    certificate_transparency_logging_preference = optional(string)<br/>    export                                      = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_route53_zones"></a> [route53\_zones](#input\_route53\_zones) | Route 53 hosted zones the DNS validation records may be written to, keyed by zone name without a trailing dot. Each validated domain uses the zone whose name is its longest suffix, so an apex zone and a delegated subdomain zone can both be listed. Empty means the records are created elsewhere from output domain\_validation\_options, which also requires wait\_for\_validation = false. | <pre>map(object({<br/>    zone_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Additional fully qualified domain names on the certificate, in the same format as domain\_name. Do not repeat domain\_name; ACM adds it. Public certificates accept 10 by default (an adjustable service quota). | `set(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the certificate. The module adds a Name tag (from name or domain\_name) only when you do not set one, and never overrides caller tags. | `map(string)` | `{}` | no |
| <a name="input_validation_method"></a> [validation\_method](#input\_validation\_method) | How ACM proves control of a public certificate's domains: DNS (records in route53\_zones, or created elsewhere from output domain\_validation\_options) or EMAIL (ACM mails the registrant and the standard aliases; steer recipients with validation\_option). Ignored for private and imported certificates. | `string` | `"DNS"` | no |
| <a name="input_validation_option"></a> [validation\_option](#input\_validation\_option) | For EMAIL validation only: where ACM sends the validation email, keyed by a certificate domain (domain\_name or a subject alternative name) and valued with that domain or one of its parent domains. Domains not listed are mailed at their own name. | `map(string)` | `{}` | no |
| <a name="input_validation_record_ttl"></a> [validation\_record\_ttl](#input\_validation\_record\_ttl) | TTL in seconds of the Route 53 validation records. | `number` | `60` | no |
| <a name="input_validation_timeout"></a> [validation\_timeout](#input\_validation\_timeout) | How long the apply waits for issuance when wait\_for\_validation is true, as a duration such as 45m or 1h30m. | `string` | `"45m"` | no |
| <a name="input_wait_for_validation"></a> [wait\_for\_validation](#input\_wait\_for\_validation) | Block the apply until ACM reports the public certificate ISSUED, so a consumer that references validated\_arn never attaches a pending certificate. Needs route53\_zones (DNS) or EMAIL validation; set it to false when the DNS records are created elsewhere. Ignored for private and imported certificates. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the certificate. A consumer that must not attach before issuance should reference validated\_arn instead. |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | Primary domain name on the certificate. |
| <a name="output_domain_validation_options"></a> [domain\_validation\_options](#output\_domain\_validation\_options) | DNS records that prove control of each domain, one object per domain with domain\_name, resource\_record\_name, resource\_record\_type, and resource\_record\_value. Create them elsewhere when route53\_zones is empty. |
| <a name="output_id"></a> [id](#output\_id) | ID of the certificate (the same value as the ARN). |
| <a name="output_key_algorithm"></a> [key\_algorithm](#output\_key\_algorithm) | Key algorithm of the certificate. |
| <a name="output_mode"></a> [mode](#output\_mode) | Resolved certificate mode: public, private, or imported. |
| <a name="output_not_after"></a> [not\_after](#output\_not\_after) | Expiration of the certificate. |
| <a name="output_not_before"></a> [not\_before](#output\_not\_before) | Start of the certificate's validity period. |
| <a name="output_renewal_eligibility"></a> [renewal\_eligibility](#output\_renewal\_eligibility) | Whether ACM can renew the certificate: ELIGIBLE or INELIGIBLE. |
| <a name="output_status"></a> [status](#output\_status) | Certificate status as reported by ACM, for example PENDING\_VALIDATION or ISSUED. |
| <a name="output_subject_alternative_names"></a> [subject\_alternative\_names](#output\_subject\_alternative\_names) | Subject alternative names on the certificate. |
| <a name="output_type"></a> [type](#output\_type) | Certificate source as reported by ACM: AMAZON\_ISSUED, PRIVATE, or IMPORTED. |
| <a name="output_validated_arn"></a> [validated\_arn](#output\_validated\_arn) | ARN to attach to listeners and distributions. When the module waits for validation it is produced by the wait, so consumers depend on issuance; otherwise it is the certificate ARN. |
| <a name="output_validation_emails"></a> [validation\_emails](#output\_validation\_emails) | Addresses ACM sent validation email to, for EMAIL validation. |
| <a name="output_validation_record_fqdns"></a> [validation\_record\_fqdns](#output\_validation\_record\_fqdns) | Sorted FQDNs of the Route 53 validation records the module manages. |
| <a name="output_validation_record_ids"></a> [validation\_record\_ids](#output\_validation\_record\_ids) | IDs of the Route 53 validation records keyed by validated domain. |
| <a name="output_validation_record_zone_ids"></a> [validation\_record\_zone\_ids](#output\_validation\_record\_zone\_ids) | Hosted zone selected for each managed validation record, keyed by validated domain. Known at plan time. |
<!-- END_TF_DOCS -->
