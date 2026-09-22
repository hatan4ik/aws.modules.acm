resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = tolist(var.subject_alternative_names)
  validation_method         = var.validation_method
  key_algorithm             = var.key_algorithm

  options {
    certificate_transparency_logging_preference = var.certificate_transparency_logging_preference
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

locals {
  validation_records = var.route53_zone_id == null ? {} : {
    for option in aws_acm_certificate.this.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      type   = option.resource_record_type
      record = option.resource_record_value
    }
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.validation_records

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count = var.wait_for_validation && var.route53_zone_id != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = values(aws_route53_record.validation)[*].fqdn
}
