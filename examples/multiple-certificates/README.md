# Multiple certificates

Issues a set of certificates from one root by using `for_each` on the module
block. `aws.modules.acm` provisions exactly one certificate per call on
purpose: a certificate is the unit that gets its own validation records, its
own wait, and its own replacement when a name changes, and a plan error names
the one certificate that caused it. Fleets are therefore expressed in the
caller, as a map of certificate specifications, not as a list inside the module.

Every entry supplies its primary domain, optional further names, and
optionally a key algorithm; all of them share the map of zones they may
validate through, and the module picks the zone per name. Adding a certificate
is adding a map entry; removing one destroys exactly that certificate.

## Run

Declare the fleet in a `terraform.tfvars`:

```hcl
route53_zones = {
  "example.com"          = { zone_id = "Z0123456789APEXZONE00" }
  "internal.example.com" = { zone_id = "Z0123456789INTERNAL00" }
}

certificates = {
  web = {
    domain_name               = "example.com"
    subject_alternative_names = ["www.example.com"]
  }
  api = {
    domain_name   = "api.internal.example.com"
    key_algorithm = "EC_prime256v1"
  }
}
```

```sh
terraform init && terraform plan
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
| <a name="input_certificates"></a> [certificates](#input\_certificates) | Certificates to issue, keyed by workload. Each entry names its primary domain, optional further names, and an optional key algorithm. | <pre>map(object({<br/>    domain_name               = string<br/>    subject_alternative_names = optional(set(string), [])<br/>    key_algorithm             = optional(string, "RSA_2048")<br/>  }))</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the certificates are created in. | `string` | `"us-east-1"` | no |
| <a name="input_route53_zones"></a> [route53\_zones](#input\_route53\_zones) | Every hosted zone the certificates may validate through, keyed by zone name. Each name on each certificate must be served by one of them. | <pre>map(object({<br/>    zone_id = string<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every certificate; a Workload tag with the map key is added to each. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arns"></a> [certificate\_arns](#output\_certificate\_arns) | ARN of each issued certificate keyed by workload, produced after validation. |
| <a name="output_validation_record_zone_ids"></a> [validation\_record\_zone\_ids](#output\_validation\_record\_zone\_ids) | Hosted zone selected for each validated domain, keyed by workload and then by domain. |
<!-- END_TF_DOCS -->
