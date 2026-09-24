mock_provider "aws" {}

variables {
  domain_name   = "example.com"
  route53_zones = { "example.com" = { zone_id = "Z0123456789ABCDEFGHIJ" } }
  tags          = { Environment = "test", Owner = "platform" }
}

run "requests_a_public_dns_validated_certificate_with_secure_defaults" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.domain_name == "example.com" && aws_acm_certificate.this.validation_method == "DNS" && aws_acm_certificate.this.key_algorithm == "RSA_2048"
    error_message = "A certificate with only domain_name set must be a DNS-validated RSA_2048 public request."
  }

  assert {
    condition     = length(aws_acm_certificate.this.options) == 1 && aws_acm_certificate.this.options[0].certificate_transparency_logging_preference == "ENABLED"
    error_message = "Certificate transparency logging must be enabled by default."
  }

  assert {
    condition     = aws_acm_certificate.this.certificate_authority_arn == null && aws_acm_certificate.this.certificate_body == null && aws_acm_certificate.this.private_key == null && aws_acm_certificate.this.certificate_chain == null
    error_message = "A public request must carry no private CA or import material."
  }

  assert {
    condition     = length(aws_acm_certificate.this.subject_alternative_names) == 0 && length(aws_acm_certificate.this.validation_option) == 0 && aws_acm_certificate.this.early_renewal_duration == null
    error_message = "Optional subject and validation settings must not render unless declared."
  }

  assert {
    condition     = aws_acm_certificate.this.tags["Name"] == "example.com" && aws_acm_certificate.this.tags["Owner"] == "platform" && aws_acm_certificate.this.tags["Environment"] == "test"
    error_message = "Caller tags must be preserved and a Name tag derived from domain_name."
  }

  assert {
    condition     = output.mode == "public"
    error_message = "The resolved mode must be exposed as public."
  }
}

run "creates_one_validation_record_per_domain_in_the_selected_zone" {
  command = plan

  assert {
    condition     = length(aws_route53_record.validation) == 1 && contains(keys(aws_route53_record.validation), "example.com")
    error_message = "Exactly one validation record keyed by the domain must be planned."
  }

  assert {
    condition     = aws_route53_record.validation["example.com"].zone_id == "Z0123456789ABCDEFGHIJ" && aws_route53_record.validation["example.com"].ttl == 60 && aws_route53_record.validation["example.com"].allow_overwrite == true
    error_message = "The record must live in the selected zone with a 60 second TTL and allow_overwrite."
  }

  assert {
    condition     = length(output.validation_record_zone_ids) == 1 && output.validation_record_zone_ids["example.com"] == "Z0123456789ABCDEFGHIJ" && length(output.validation_record_ids) == 1
    error_message = "Record zone IDs and record IDs must be exposed keyed by domain."
  }
}

run "waits_for_issuance_with_the_default_timeout" {
  command = plan

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 1 && aws_acm_certificate_validation.this[0].timeouts.create == "45m"
    error_message = "The module must wait for issuance with a 45 minute timeout by default."
  }
}

run "keeps_a_caller_supplied_name_tag" {
  command = plan

  variables {
    tags = { Name = "custom", Owner = "platform" }
  }

  assert {
    condition     = aws_acm_certificate.this.tags["Name"] == "custom" && aws_acm_certificate.this.tags["Owner"] == "platform"
    error_message = "A caller Name tag must never be overridden."
  }
}

run "uses_name_for_the_name_tag" {
  command = plan

  variables {
    name = "web"
  }

  assert {
    condition     = aws_acm_certificate.this.tags["Name"] == "web"
    error_message = "name must set the Name tag."
  }
}

run "warns_when_certificate_transparency_logging_is_disabled" {
  command = plan

  variables {
    options = { certificate_transparency_logging_preference = "DISABLED" }
  }

  assert {
    condition     = aws_acm_certificate.this.options[0].certificate_transparency_logging_preference == "DISABLED"
    error_message = "The declared transparency preference must be rendered."
  }

  expect_failures = [check.certificate_transparency_disabled]
}

run "renders_export_when_declared" {
  command = plan

  variables {
    options = { export = "ENABLED" }
  }

  assert {
    condition     = aws_acm_certificate.this.options[0].export == "ENABLED" && aws_acm_certificate.this.options[0].certificate_transparency_logging_preference == "ENABLED"
    error_message = "export must pass through and transparency logging must stay enabled."
  }
}
