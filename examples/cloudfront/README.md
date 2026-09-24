# Certificate for CloudFront

A public certificate for a CloudFront distribution. CloudFront reads
certificates from `us-east-1` only, regardless of where the origin, the
Route 53 zone, or the rest of the stack lives, so the example declares an
aliased `us-east-1` provider and hands it to the module with `providers`. The
module creates everything with the provider it is given; Route 53 is a global
service, so the validation records are unaffected by the region choice.

`certificate_arn` is produced after ACM has issued the certificate. Reference it
from `viewer_certificate.acm_certificate_arn` on the distribution and the
distribution waits for issuance automatically.

## Run

```sh
terraform init
terraform plan \
  -var domain_name=www.example.com \
  -var 'subject_alternative_names=["example.com"]' \
  -var zone_name=example.com \
  -var zone_id=Z0123456789ABCDEFGHIJ
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
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name the distribution serves, such as www.example.com. | `string` | n/a | yes |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Further names the distribution serves, such as example.com or *.example.com. All must be served by the zone below. | `set(string)` | `[]` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | ID of that hosted zone. | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Name of the Route 53 hosted zone that serves every name above, without a trailing dot. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the issued us-east-1 certificate; pass it to aws\_cloudfront\_distribution.viewer\_certificate.acm\_certificate\_arn. |
<!-- END_TF_DOCS -->
