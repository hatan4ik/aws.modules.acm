mock_provider "aws" {}

variables {
  domain_name   = "example.com"
  route53_zones = { "example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" } }
}

# ---------------------------------------------------------------------------
# Variable validations
# ---------------------------------------------------------------------------

run "rejects_uppercase_domain_name" {
  command = plan
  variables {
    domain_name = "Example.com"
  }
  expect_failures = [var.domain_name]
}

run "rejects_domain_name_with_trailing_dot" {
  command = plan
  variables {
    domain_name = "example.com."
  }
  expect_failures = [var.domain_name]
}

run "rejects_single_label_domain_name" {
  command = plan
  variables {
    domain_name = "localhost"
  }
  expect_failures = [var.domain_name]
}

run "rejects_malformed_subject_alternative_name" {
  command = plan
  variables {
    subject_alternative_names = ["www.example.com", "*.*.example.com"]
  }
  expect_failures = [var.subject_alternative_names]
}

run "rejects_unknown_validation_method" {
  command = plan
  variables {
    validation_method = "HTTP"
  }
  expect_failures = [var.validation_method]
}

run "rejects_unknown_key_algorithm" {
  command = plan
  variables {
    key_algorithm = "RSA_1024"
  }
  expect_failures = [var.key_algorithm]
}

run "rejects_unknown_transparency_logging_preference" {
  command = plan
  variables {
    options = { certificate_transparency_logging_preference = "OFF" }
  }
  expect_failures = [var.options]
}

run "rejects_unknown_export_value" {
  command = plan
  variables {
    options = { export = "true" }
  }
  expect_failures = [var.options]
}

run "rejects_zone_name_with_trailing_dot" {
  command = plan
  variables {
    route53_zones = { "example.com." = { zone_id = "Z0123456789ABCDEFGHIJ" } }
  }
  expect_failures = [var.route53_zones]
}

run "rejects_wildcard_zone_name" {
  command = plan
  variables {
    route53_zones = { "*.example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" } }
  }
  expect_failures = [var.route53_zones]
}

run "rejects_malformed_zone_id" {
  command = plan
  variables {
    route53_zones = { "example.com" = { zone_id = "/hostedzone/Z0123456789ABCDEFGHIJ" } }
  }
  expect_failures = [var.route53_zones]
}

run "rejects_negative_record_ttl" {
  command = plan
  variables {
    validation_record_ttl = -1
  }
  expect_failures = [var.validation_record_ttl]
}

run "rejects_malformed_validation_timeout" {
  command = plan
  variables {
    validation_timeout = "45 minutes"
  }
  expect_failures = [var.validation_timeout]
}

run "rejects_malformed_early_renewal_duration" {
  command = plan
  variables {
    early_renewal_duration = "60 days"
  }
  expect_failures = [var.early_renewal_duration]
}

run "rejects_malformed_certificate_authority_arn" {
  command = plan
  variables {
    certificate_authority_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  }
  expect_failures = [var.certificate_authority_arn]
}

run "rejects_import_without_pem_markers" {
  command = plan
  variables {
    domain_name   = null
    route53_zones = {}
    imported = {
      certificate_body = "MIIBbody"
      private_key      = "MIIEkey"
    }
  }
  expect_failures = [var.imported]
}

run "rejects_validation_option_with_malformed_domain" {
  command = plan
  variables {
    validation_method = "EMAIL"
    route53_zones     = {}
    validation_option = { "example.com" = "example.com." }
  }
  expect_failures = [var.validation_option]
}

# ---------------------------------------------------------------------------
# Certificate preconditions
# ---------------------------------------------------------------------------

run "rejects_missing_domain_name" {
  command = plan
  variables {
    domain_name = null
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_import_with_domain_name" {
  command = plan
  variables {
    imported = {
      certificate_body = "-----BEGIN CERTIFICATE-----\nMIIBbody\n-----END CERTIFICATE-----\n"
      private_key      = "-----BEGIN PRIVATE KEY-----\nMIIEkey\n-----END PRIVATE KEY-----\n"
    }
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_import_with_certificate_authority" {
  command = plan
  variables {
    domain_name               = null
    route53_zones             = {}
    certificate_authority_arn = "arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/11111111-2222-3333-4444-555555555555"
    imported = {
      certificate_body = "-----BEGIN CERTIFICATE-----\nMIIBbody\n-----END CERTIFICATE-----\n"
      private_key      = "-----BEGIN PRIVATE KEY-----\nMIIEkey\n-----END PRIVATE KEY-----\n"
    }
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_subject_alternative_name_equal_to_domain_name" {
  command = plan
  variables {
    subject_alternative_names = ["example.com", "www.example.com"]
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_options_for_private_certificate" {
  command = plan
  variables {
    certificate_authority_arn = "arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/11111111-2222-3333-4444-555555555555"
    options                   = { certificate_transparency_logging_preference = "ENABLED" }
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_early_renewal_for_public_certificate" {
  command = plan
  variables {
    early_renewal_duration = "P60D"
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_validation_option_with_dns_validation" {
  command = plan
  variables {
    validation_option = { "example.com" = "example.com" }
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_validation_option_for_undeclared_domain" {
  command = plan
  variables {
    validation_method = "EMAIL"
    route53_zones     = {}
    validation_option = { "shop.example.com" = "example.com" }
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_validation_domain_that_is_not_a_parent" {
  command = plan
  variables {
    validation_method         = "EMAIL"
    route53_zones             = {}
    subject_alternative_names = ["www.example.com"]
    validation_option         = { "www.example.com" = "example.net" }
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_domain_without_a_matching_zone" {
  command = plan
  variables {
    subject_alternative_names = ["www.example.net"]
  }
  expect_failures = [aws_acm_certificate.this]
}

run "rejects_waiting_without_zones_for_dns_validation" {
  command = plan
  variables {
    route53_zones = {}
  }
  expect_failures = [aws_acm_certificate.this]
}
