provider "aws" {
  region = var.region
}

# One certificate covering the apex, every host directly under it, and an API
# host in a delegated subdomain zone. The module selects, for each name, the
# zone whose name is its longest suffix: api.<subdomain zone> lands in the
# subdomain zone, the apex and the wildcard in the apex zone.
module "certificate" {
  source = "../../"

  domain_name = var.apex_zone.name

  subject_alternative_names = [
    "*.${var.apex_zone.name}",
    "api.${var.subdomain_zone.name}",
  ]

  route53_zones = {
    (var.apex_zone.name)      = { zone_id = var.apex_zone.zone_id }
    (var.subdomain_zone.name) = { zone_id = var.subdomain_zone.zone_id }
  }

  tags = var.tags
}
