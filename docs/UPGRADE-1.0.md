# Upgrading from 0.1.x to 1.0.0

## What changed and why

Version 0.1.x requested a public certificate, wrote its DNS validation records into one `route53_zone_id`, and waited for issuance when that zone was given. Version 1.0.0 keeps that shape as its default mode and adds the rest of what ACM does: validation records across any number of zones selected by longest suffix, email validation, issuance from a private CA, import of PEM material, exportable certificates, a validation timeout and record TTL, and an explicit decision when validation happens elsewhere. It validates every input at plan time and ships with tests and examples. The reasons, and the table of 0.1.x behaviours that were replaced, are in [DESIGN.md](DESIGN.md). This guide moves an existing 0.1.x consumer onto 1.0.0 without replacing the certificate or its validation records.

## Input mapping

Root inputs of 0.1.2:

| 0.1.x input | 1.0.0 equivalent |
| --- | --- |
| `domain_name` | `domain_name`, unchanged. Now validated: lowercase, at least two labels, an optional leading `*.`, no trailing dot. |
| `subject_alternative_names` | `subject_alternative_names`, unchanged. It must no longer repeat `domain_name`; ACM adds the primary name itself. |
| `validation_method` | `validation_method`, unchanged. `EMAIL` is now accepted as well as `DNS`. |
| `route53_zone_id` | `route53_zones = { "<zone name>" = { zone_id = "<zone id>" } }`. The key is the hosted zone's name without a trailing dot; add further zones for names they serve. `null` becomes `{}`. |
| `wait_for_validation` | `wait_for_validation`, unchanged name and default. With DNS validation and `route53_zones = {}` it must now be set to `false` explicitly; 0.1.x silently ignored it. |
| `key_algorithm` | `key_algorithm`, unchanged. Now validated against the ACM algorithm names. |
| `certificate_transparency_logging_preference` | `options = { certificate_transparency_logging_preference = "<value>" }`. The default is still `ENABLED`; `DISABLED` now also raises the advisory `certificate_transparency_disabled` check. |
| `tags` | `tags`, unchanged shape. The module now adds a `Name` tag equal to `domain_name` (or `name`) unless you set `Name` yourself. |

Outputs of 0.1.2:

| 0.1.x output | 1.0.0 equivalent |
| --- | --- |
| `certificate_arn` | `arn`. For consumers that must not attach before issuance use `validated_arn`, which is produced by the wait when `wait_for_validation` is true. |
| `certificate_domain_name` | `domain_name`. |
| `validation_record_fqdns` | `validation_record_fqdns`, now sorted. |

New in 1.0.0, all optional: the inputs `name`, `validation_record_ttl`, `validation_timeout`, `validation_option`, `options.export`, `certificate_authority_arn`, `imported`, and `early_renewal_duration`; the outputs `id`, `subject_alternative_names`, `key_algorithm`, `status`, `type`, `not_before`, `not_after`, `renewal_eligibility`, `domain_validation_options`, `validation_emails`, `validation_record_ids`, `validation_record_zone_ids`, `validated_arn`, and `mode`.

A 0.1.x call and its 1.0.0 rewrite, for a consumer whose block is `module "certificate"`:

```hcl
# 0.1.2
module "certificate" {
  source = "git::https://github.com/hatan4ik/aws.modules.acm.git?ref=v0.1.2"

  domain_name                                 = "example.com"
  subject_alternative_names                   = ["*.example.com", "www.example.com"]
  route53_zone_id                             = "Z0123456789ABCDEFGHIJ"
  certificate_transparency_logging_preference = "ENABLED"
  tags                                        = var.tags
}

# 1.0.0
module "certificate" {
  source = "git::https://github.com/hatan4ik/aws.modules.acm.git?ref=<commit-sha>" # v1.0.0

  domain_name               = "example.com"
  subject_alternative_names = ["*.example.com", "www.example.com"]

  route53_zones = {
    "example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" }
  }

  # Optional: ENABLED is the default.
  options = { certificate_transparency_logging_preference = "ENABLED" }

  tags = var.tags
}
```

`module.certificate.certificate_arn` becomes `module.certificate.arn` (or `validated_arn` for a listener or distribution), and `certificate_domain_name` becomes `domain_name`.

## Preserving existing resources

A certificate has no name; it is identified by its ARN, and 1.0.0 sends ACM the same request for the same inputs, so the certificate is not replaced and the validation records are updated in place at most. What changes, all in place and all expected:

- The `Name` tag is added to the certificate unless your `tags` already carry one.
- `validation_record_fqdns` changes order if you compared it with a fixed list.

Nothing else changes for a DNS-validated certificate whose names all live in one zone.

## State addresses

The resource addresses are the same in both versions, and 0.1.x keyed the validation records by domain name as well, so no `moved` blocks are needed. For a consumer block named `module.certificate`:

| 0.1.2 address | 1.0.0 address |
| --- | --- |
| `module.certificate.aws_acm_certificate.this` | `module.certificate.aws_acm_certificate.this` (unchanged) |
| `module.certificate.aws_route53_record.validation["<domain>"]` | `module.certificate.aws_route53_record.validation["<domain>"]` (unchanged) |
| `module.certificate.aws_acm_certificate_validation.this[0]` | `module.certificate.aws_acm_certificate_validation.this[0]` (unchanged) |

One exception. When the certificate carries both a wildcard and its apex (`example.com` and `*.example.com`), 0.1.x created two record resources for the one CNAME ACM issues, `validation["example.com"]` and `validation["*.example.com"]`. 1.0.0 creates only the apex record. The plan will show the wildcard instance being destroyed, and destroying it would delete the live record that the apex instance also manages: the next apply would recreate it, but ACM's automatic renewal needs the record present at all times. Forget the duplicate instead of destroying it, before you plan:

```sh
terraform state rm 'module.certificate.aws_route53_record.validation["*.example.com"]'
```

A `removed` block cannot express this, because it addresses whole resources rather than one instance.

## Procedure

1. Pin the 1.0.0 release: copy the commit SHA of tag `v1.0.0` into `?ref=<commit-sha>` and put the tag in a trailing comment.
2. Rewrite the module block with the tables above: `route53_zone_id` into `route53_zones`, `certificate_transparency_logging_preference` into `options`. If you validated elsewhere with `route53_zone_id = null`, set `wait_for_validation = false`.
3. Update references to the renamed outputs (`certificate_arn`, `certificate_domain_name`).
4. If the certificate has both a wildcard and its apex, run the `terraform state rm` above.
5. Run `terraform init -upgrade` to fetch the new module source, then `terraform plan`.
6. Verify the plan. There must be no replacement of `aws_acm_certificate.this` and no change to `aws_route53_record.validation` beyond the forgotten wildcard instance. Expect the `Name` tag update in place. If the certificate shows `must be replaced`, compare `domain_name`, `subject_alternative_names`, `key_algorithm`, and `validation_method` with the running certificate before applying: a replacement is safe (`create_before_destroy` requests and validates the new certificate before the old one is deleted) but not necessary for an unchanged request.
7. Apply.
