mock_provider "aws" {}

variables {
  domain_name               = "example.com"
  subject_alternative_names = ["www.example.com"]
  validation_method         = "EMAIL"
  validation_option         = { "www.example.com" = "example.com" }
}

run "validates_by_email_without_dns_records" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.validation_method == "EMAIL" && length(aws_route53_record.validation) == 0
    error_message = "Email validation must create no DNS records."
  }

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 1 && aws_acm_certificate_validation.this[0].validation_record_fqdns == null
    error_message = "The module must still wait for issuance, without record FQDNs."
  }

  assert {
    condition     = length(aws_acm_certificate.this.validation_option) == 1 && tolist(aws_acm_certificate.this.validation_option)[0].domain_name == "www.example.com" && tolist(aws_acm_certificate.this.validation_option)[0].validation_domain == "example.com"
    error_message = "validation_option entries must render as validation_option blocks."
  }

  assert {
    condition     = output.mode == "public" && length(output.validation_record_fqdns) == 0
    error_message = "Email validation is a public certificate with no managed records."
  }
}

run "ignores_zones_for_email_validation" {
  command = plan

  variables {
    route53_zones = { "example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" } }
  }

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 1
    error_message = "Zones are irrelevant to email validation and must not produce records."
  }
}

run "skips_the_wait_when_disabled" {
  command = plan

  variables {
    wait_for_validation = false
  }

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 0
    error_message = "No wait resource may exist when wait_for_validation is false."
  }
}
