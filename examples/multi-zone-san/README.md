# Apex, wildcard, and a delegated subdomain

One certificate for `example.com`, `*.example.com`, and `api.internal.example.com`
when `internal.example.com` is delegated to its own Route 53 hosted zone. This
is the case v0.1.x could not express: it knew one zone ID, so a name served by
another zone could not be validated.

The module receives both zones in `route53_zones`, keyed by name, and picks the
zone for each validated name by longest suffix. `api.internal.example.com`
matches both `example.com` and `internal.example.com`; the longer one wins, so
its record goes into the delegated zone, where the name actually resolves. The
apex and the wildcard match only the apex zone. ACM issues one and the same
CNAME for an apex and its wildcard, so the module creates one record for the
pair rather than two resources fighting over one record set.
`validation_record_zone_ids` shows the selection at plan time, before any
certificate exists.

## Run

```sh
terraform init
terraform plan \
  -var 'apex_zone={name="example.com",zone_id="Z0123456789APEXZONE00"}' \
  -var 'subdomain_zone={name="internal.example.com",zone_id="Z0123456789INTERNAL00"}'
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_certificate"></a> [certificate](#module\_certificate) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apex_zone"></a> [apex\_zone](#input\_apex\_zone) | The apex hosted zone: its name (example.com) and ID. The certificate is issued for this name and for *.<name>. | <pre>object({<br/>    name    = string<br/>    zone_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the certificate is created in. | `string` | `"us-east-1"` | no |
| <a name="input_subdomain_zone"></a> [subdomain\_zone](#input\_subdomain\_zone) | A hosted zone delegated below the apex (internal.example.com) and its ID. The certificate also covers api.<name>, validated in this zone. | <pre>object({<br/>    name    = string<br/>    zone_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the certificate. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the issued certificate, produced after validation. |
| <a name="output_validation_record_fqdns"></a> [validation\_record\_fqdns](#output\_validation\_record\_fqdns) | FQDNs of the DNS validation records the module created. |
| <a name="output_validation_record_zone_ids"></a> [validation\_record\_zone\_ids](#output\_validation\_record\_zone\_ids) | Hosted zone the module selected for each validated domain. |
<!-- END_TF_DOCS -->
