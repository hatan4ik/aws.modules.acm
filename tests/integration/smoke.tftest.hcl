# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Nothing is hard-coded and no fixture is needed: the suite
# requests a public certificate for names under a zone nobody hosts, leaves
# the wait off so the apply returns with the certificate PENDING_VALIDATION,
# asserts what the real API reports, and deletes the certificate at the end
# of the file. ACM does not charge for public certificates and deletes a
# pending one immediately, so nothing lingers and nothing costs anything.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "smoke" {
  variables {
    # Names under the IANA-reserved example domain: ACM accepts the request
    # and the validation records can never be created, which is the point.
    domain_name               = "smoke.acm-integration.example.com"
    subject_alternative_names = ["*.smoke.acm-integration.example.com"]

    # No hosted zone serves these names, so the records are left to the
    # caller (there is none) and the apply must not wait for issuance.
    wait_for_validation = false

    tags = {
      IntegrationTest = "aws.modules.acm"
      Disposable      = "true"
    }
  }

  assert {
    condition     = output.mode == "public" && output.type == "AMAZON_ISSUED" && output.status == "PENDING_VALIDATION"
    error_message = "The request must produce a pending Amazon-issued public certificate."
  }

  assert {
    condition     = startswith(output.arn, "arn:") && output.id == output.arn && output.validated_arn == output.arn
    error_message = "Without a wait, validated_arn and id must be the certificate ARN itself."
  }

  assert {
    condition     = output.domain_name == "smoke.acm-integration.example.com" && contains(output.subject_alternative_names, "*.smoke.acm-integration.example.com")
    error_message = "The certificate must carry the requested primary name and subject alternative name."
  }

  assert {
    condition     = length(output.domain_validation_options) == 2 && toset([for option in output.domain_validation_options : option.domain_name]) == toset(["smoke.acm-integration.example.com", "*.smoke.acm-integration.example.com"])
    error_message = "ACM must report one validation option per requested name."
  }

  assert {
    condition     = alltrue([for option in output.domain_validation_options : option.resource_record_type == "CNAME" && endswith(trimsuffix(option.resource_record_name, "."), ".smoke.acm-integration.example.com") && length(option.resource_record_value) > 0])
    error_message = "Every validation option must be a CNAME under the requested name with a target value, ready for another DNS provider."
  }

  assert {
    condition     = length(output.validation_record_fqdns) == 0 && length(output.validation_record_ids) == 0 && length(output.validation_record_zone_ids) == 0 && length(output.validation_emails) == 0
    error_message = "Without zones the module manages no records, and DNS validation sends no mail."
  }

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 0
    error_message = "No record and no wait resource may exist for an externally validated certificate."
  }

  assert {
    condition     = aws_acm_certificate.this.key_algorithm == "RSA_2048" && aws_acm_certificate.this.options[0].certificate_transparency_logging_preference == "ENABLED" && aws_acm_certificate.this.tags["Name"] == "smoke.acm-integration.example.com"
    error_message = "The real API must accept the defaults: RSA 2048, transparency logging on, a Name tag from domain_name."
  }
}
