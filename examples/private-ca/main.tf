provider "aws" {
  region = var.region
}

# Setting certificate_authority_arn selects the private mode: the certificate
# is issued by the Private CA immediately, with no DNS or email validation,
# no transparency logging, and no Route 53 records. Internal services usually
# terminate TLS with an elliptic-curve key.
module "certificate" {
  source = "../../"

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  certificate_authority_arn = var.certificate_authority_arn
  key_algorithm             = "EC_prime256v1"

  tags = var.tags
}
