# CloudFront only accepts certificates from us-east-1, whatever region the
# rest of the stack lives in. The provider deliberately stays in the workload
# Region; the module's resource-level region pin places both ACM operations in
# us-east-1. Route 53 is global, so the validation records work from either.
provider "aws" {
  region = var.workload_region
}

module "certificate" {
  source = "../../"

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  region                    = "us-east-1"

  route53_zones = {
    (var.zone_name) = { zone_id = var.zone_id }
  }
}
