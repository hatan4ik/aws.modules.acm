# Validation through another DNS provider

A public certificate for names whose DNS is not hosted in Route 53. The module
requests the certificate and exposes `domain_validation_options`, the CNAME
records ACM wants to see; creating them is the caller's job at the DNS provider
in question. Because nothing in this configuration can make those records,
`wait_for_validation` is set to `false` explicitly. The module refuses the
default of waiting when it has no zones to write to, so a pending certificate
never blocks an apply by accident.

After the first apply the certificate is `PENDING_VALIDATION`. Create the
records from the output, for example with the DNS provider's own Terraform
provider, and then let the same root wait for issuance so downstream listeners
attach to an issued certificate:

```hcl
resource "cloudflare_dns_record" "validation" {
  for_each = { for option in module.certificate.domain_validation_options : option.domain_name => option }

  zone_id = var.cloudflare_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  content = each.value.resource_record_value
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = module.certificate.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.validation : record.name]
}
```

## Run

```sh
terraform init
terraform plan \
  -var domain_name=app.example.net \
  -var 'subject_alternative_names=["www.example.net"]'
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
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Fully qualified domain name to issue the certificate for. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the certificate is created in. | `string` | `"us-east-1"` | no |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Further names on the certificate. | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the requested certificate. It stays PENDING\_VALIDATION until the records below exist. |
| <a name="output_domain_validation_options"></a> [domain\_validation\_options](#output\_domain\_validation\_options) | The CNAME records to create at the external DNS provider, one per domain: name, type, and value. |
<!-- END_TF_DOCS -->
