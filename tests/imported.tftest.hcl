mock_provider "aws" {}

variables {
  name = "imported-web"

  imported = {
    certificate_body  = "-----BEGIN CERTIFICATE-----\nMIIBbody\n-----END CERTIFICATE-----\n"
    private_key       = "-----BEGIN PRIVATE KEY-----\nMIIEkey\n-----END PRIVATE KEY-----\n"
    certificate_chain = "-----BEGIN CERTIFICATE-----\nMIIBchain\n-----END CERTIFICATE-----\n"
  }
}

run "imports_the_supplied_certificate" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.certificate_body == "-----BEGIN CERTIFICATE-----\nMIIBbody\n-----END CERTIFICATE-----\n" && aws_acm_certificate.this.private_key == "-----BEGIN PRIVATE KEY-----\nMIIEkey\n-----END PRIVATE KEY-----\n" && aws_acm_certificate.this.certificate_chain == "-----BEGIN CERTIFICATE-----\nMIIBchain\n-----END CERTIFICATE-----\n"
    error_message = "The PEM body, private key, and chain must reach the certificate unchanged."
  }

  assert {
    condition     = aws_acm_certificate.this.certificate_authority_arn == null && length(aws_acm_certificate.this.options) == 0 && length(aws_acm_certificate.this.validation_option) == 0
    error_message = "An import carries no CA, transparency, export, or validation settings."
  }

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 0
    error_message = "Imports need no validation records and no wait."
  }

  assert {
    condition     = output.mode == "imported" && aws_acm_certificate.this.tags["Name"] == "imported-web"
    error_message = "The imported mode and the Name tag from name must be exposed."
  }
}

run "imports_without_a_chain" {
  command = plan

  variables {
    imported = {
      certificate_body = "-----BEGIN CERTIFICATE-----\nMIIBbody\n-----END CERTIFICATE-----\n"
      private_key      = "-----BEGIN RSA PRIVATE KEY-----\nMIIEkey\n-----END RSA PRIVATE KEY-----\n"
    }
  }

  assert {
    condition     = aws_acm_certificate.this.certificate_chain == null
    error_message = "A missing chain must render as null."
  }
}

run "adds_no_name_tag_without_name" {
  command = plan

  variables {
    name = null
    tags = { Owner = "platform" }
  }

  assert {
    condition     = !contains(keys(aws_acm_certificate.this.tags), "Name") && aws_acm_certificate.this.tags["Owner"] == "platform"
    error_message = "An import without name has no domain to derive a Name tag from, so none may be added."
  }
}
