mock_provider "aws" {}

variables {
  domain_name               = "example.com"
  subject_alternative_names = ["*.example.com", "api.internal.example.com", "www.example.com"]

  route53_zones = {
    "example.com"          = { zone_id = "Z0123456789APEXZONE00" }
    "internal.example.com" = { zone_id = "Z0123456789INTERNAL00" }
  }
}

run "selects_the_zone_with_the_longest_matching_suffix" {
  command = plan

  assert {
    condition     = length(aws_route53_record.validation) == 3
    error_message = "One record per domain must be planned, with the wildcard folded into its apex."
  }

  assert {
    condition     = aws_route53_record.validation["api.internal.example.com"].zone_id == "Z0123456789INTERNAL00"
    error_message = "A domain in a delegated subdomain zone must select that zone, not the apex zone."
  }

  assert {
    condition     = aws_route53_record.validation["example.com"].zone_id == "Z0123456789APEXZONE00" && aws_route53_record.validation["www.example.com"].zone_id == "Z0123456789APEXZONE00"
    error_message = "The apex and its direct children must select the apex zone."
  }

  assert {
    condition     = tomap(output.validation_record_zone_ids) == tomap({ "example.com" = "Z0123456789APEXZONE00", "www.example.com" = "Z0123456789APEXZONE00", "api.internal.example.com" = "Z0123456789INTERNAL00" })
    error_message = "The zone selection must be exposed per domain."
  }
}

run "skips_the_wildcard_record_when_its_apex_is_on_the_certificate" {
  command = plan

  assert {
    condition     = !contains(keys(aws_route53_record.validation), "*.example.com")
    error_message = "ACM issues one CNAME for a wildcard and its apex, so no separate wildcard record may be planned."
  }

  assert {
    condition     = length(aws_acm_certificate.this.subject_alternative_names) == 3 && contains(aws_acm_certificate.this.subject_alternative_names, "*.example.com")
    error_message = "The wildcard must still be on the certificate."
  }
}

run "creates_a_wildcard_record_when_the_apex_is_absent" {
  command = plan

  variables {
    domain_name               = "*.example.com"
    subject_alternative_names = []
  }

  assert {
    condition     = length(aws_route53_record.validation) == 1 && aws_route53_record.validation["*.example.com"].zone_id == "Z0123456789APEXZONE00"
    error_message = "A wildcard without its apex needs its own record in the zone matching the bare name."
  }
}

run "does_not_match_a_zone_on_a_partial_label" {
  command = plan

  variables {
    domain_name               = "notexample.com"
    subject_alternative_names = []
  }

  expect_failures = [aws_acm_certificate.this]
}

run "validates_externally_when_no_zones_are_given" {
  command = plan

  variables {
    route53_zones       = {}
    wait_for_validation = false
  }

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 0
    error_message = "Without zones the module must create neither records nor a wait."
  }

  assert {
    condition     = length(output.validation_record_fqdns) == 0 && length(output.validation_record_ids) == 0 && length(output.validation_record_zone_ids) == 0
    error_message = "Record outputs must be empty when no records are managed."
  }
}

run "skips_the_wait_when_disabled" {
  command = plan

  variables {
    wait_for_validation = false
  }

  assert {
    condition     = length(aws_route53_record.validation) == 3 && length(aws_acm_certificate_validation.this) == 0
    error_message = "Records must still be created when the wait is disabled."
  }
}

run "passes_ttl_and_timeout_through" {
  command = plan

  variables {
    validation_record_ttl = 300
    validation_timeout    = "1h30m"
  }

  assert {
    condition     = aws_route53_record.validation["example.com"].ttl == 300 && aws_acm_certificate_validation.this[0].timeouts.create == "1h30m"
    error_message = "TTL and timeout must pass through unchanged."
  }
}
