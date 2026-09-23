mock_provider "aws" {}

variables {
  domain_name               = "app.corp.example.com"
  subject_alternative_names = ["*.app.corp.example.com"]
  certificate_authority_arn = "arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/11111111-2222-3333-4444-555555555555"
  tags                      = { Owner = "platform" }
}

run "issues_from_the_private_ca_without_validation" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.certificate_authority_arn == "arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/11111111-2222-3333-4444-555555555555" && aws_acm_certificate.this.domain_name == "app.corp.example.com"
    error_message = "The certificate must be requested from the declared private CA for the declared domain."
  }

  assert {
    condition     = length(aws_acm_certificate.this.options) == 0 && length(aws_acm_certificate.this.validation_option) == 0 && aws_acm_certificate.this.certificate_body == null
    error_message = "Private certificates carry no transparency, export, or validation options."
  }

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 0
    error_message = "Private certificates need no validation records and no wait."
  }

  assert {
    condition     = output.mode == "private" && aws_acm_certificate.this.tags["Name"] == "app.corp.example.com" && aws_acm_certificate.this.key_algorithm == "RSA_2048"
    error_message = "The private mode, Name tag, and default key algorithm must be exposed."
  }
}

run "ignores_zones_and_wait_for_private_certificates" {
  command = plan

  variables {
    route53_zones       = { "corp.example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" } }
    wait_for_validation = true
  }

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 0
    error_message = "Zones and the wait flag have no effect on private certificates."
  }
}

run "accepts_an_elliptic_curve_key_and_early_renewal" {
  command = plan

  variables {
    key_algorithm          = "EC_prime256v1"
    early_renewal_duration = "P60D"
  }

  assert {
    condition     = aws_acm_certificate.this.key_algorithm == "EC_prime256v1" && aws_acm_certificate.this.early_renewal_duration == "P60D"
    error_message = "key_algorithm and early_renewal_duration must pass through for private certificates."
  }
}
