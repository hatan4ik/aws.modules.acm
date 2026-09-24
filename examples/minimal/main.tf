provider "aws" {
  region = var.region
}

module "certificate" {
  source = "../../"

  domain_name = var.domain_name

  # The zone that serves domain_name. The module writes the DNS validation
  # record there and waits until ACM has issued the certificate.
  route53_zones = {
    (var.zone_name) = { zone_id = var.zone_id }
  }
}
