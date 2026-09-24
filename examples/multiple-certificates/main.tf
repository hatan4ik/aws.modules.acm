provider "aws" {
  region = var.region
}

# One module call is one certificate. A fleet is a for_each over the module
# block, so every certificate keeps its own plan, its own validation errors,
# and its own lifecycle while sharing the zones it may validate through.
module "certificate" {
  source   = "../../"
  for_each = var.certificates

  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  key_algorithm             = each.value.key_algorithm
  route53_zones             = var.route53_zones

  tags = merge(var.tags, { Workload = each.key })
}
