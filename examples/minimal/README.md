# Minimal certificate

The smallest working call of `aws.modules.acm`: one public certificate for one
domain, validated through the Route 53 zone that serves it. Everything else
keeps the module's defaults: DNS validation, an RSA 2048 key, certificate
transparency logging on, a 60 second TTL on the validation record, and an apply
that waits up to 45 minutes for ACM to issue the certificate. Start here to see
exactly what a certificate needs before adding subject alternative names,
further zones, or another mode.

The module writes one CNAME record into the zone, keyed by the domain, and
`certificate_arn` is only produced once ACM reports the certificate `ISSUED`,
so a listener that references it can never be created against a pending
certificate.

## Run

```sh
terraform init
terraform plan \
  -var domain_name=app.example.com \
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
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Fully qualified domain name to issue the certificate for, such as app.example.com. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the certificate is created in. Use the region of the load balancer or API that will serve it. | `string` | `"us-east-1"` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | ID of that hosted zone, such as Z0123456789ABCDEFGHIJ. | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Name of the Route 53 hosted zone that serves domain\_name, without a trailing dot, such as example.com. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the issued certificate, produced after ACM has validated it; attach this to listeners. |
| <a name="output_status"></a> [status](#output\_status) | Certificate status as reported by ACM. |
| <a name="output_validation_record_fqdns"></a> [validation\_record\_fqdns](#output\_validation\_record\_fqdns) | FQDNs of the DNS validation records the module created. |
<!-- END_TF_DOCS -->
