provider "aws" {
  region = var.region
}

# DNS for these names lives outside Route 53. The module requests the
# certificate and exposes the records ACM expects; nothing here can create
# them, so the wait is switched off explicitly and the apply finishes with the
# certificate pending.
module "certificate" {
  source = "../../"

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names

  wait_for_validation = false
}
