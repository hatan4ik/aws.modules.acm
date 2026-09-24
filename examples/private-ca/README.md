# Certificate from a Private CA

A certificate issued by an AWS Private CA for an internal name. Setting
`certificate_authority_arn` selects the private mode: the CA issues the
certificate as part of the request, so there is nothing to validate, no
Route 53 record to write, no wait, and no certificate transparency or export
option, which only exist for public certificates. The module rejects `options`
in this mode rather than silently ignoring them.

The example asks for an `EC_prime256v1` key, the usual choice for service to
service TLS. Private certificates are the one kind Terraform can renew early:
set `early_renewal_duration` (for example `P30D`) once the certificate has been
exported at least once, which is what ACM requires before it renews a private
certificate on your behalf.

## Run

```sh
terraform init
terraform plan \
  -var domain_name=app.corp.example.com \
  -var certificate_authority_arn=arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/11111111-2222-3333-4444-555555555555
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
| <a name="input_certificate_authority_arn"></a> [certificate\_authority\_arn](#input\_certificate\_authority\_arn) | ARN of the AWS Private CA that issues the certificate, in the same region and account or shared through AWS RAM. | `string` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Internal name the certificate is issued for, such as app.corp.example.com. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region of the Private CA and the certificate. | `string` | `"us-east-1"` | no |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Further internal names on the certificate. | `set(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the certificate. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the certificate issued by the Private CA. |
| <a name="output_mode"></a> [mode](#output\_mode) | Mode the module resolved, private here. |
<!-- END_TF_DOCS -->
