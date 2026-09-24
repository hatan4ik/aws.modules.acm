# CloudFront only accepts certificates from us-east-1, whatever region the
# rest of the stack lives in. The module creates the certificate with the
# provider it is given, so an aliased us-east-1 provider is all it takes.
# Route 53 is global; the validation records work from any region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "certificate" {
  source = "../../"

  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names

  route53_zones = {
    (var.zone_name) = { zone_id = var.zone_id }
  }
}
