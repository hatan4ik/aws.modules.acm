# DNS validation records, one per validated domain in the zone selected by
# longest suffix, and the wait for issuance.

resource "aws_route53_record" "validation" {
  for_each = local.validation_record_zone_ids

  zone_id = each.value
  name    = local.validation_options[each.key].resource_record_name
  type    = local.validation_options[each.key].resource_record_type
  records = [local.validation_options[each.key].resource_record_value]
  ttl     = var.validation_record_ttl

  # ACM emits the same CNAME for a re-requested certificate of the same domain
  # and for a wildcard and its apex; overwriting is safe and avoids a conflict
  # with a record left by a previous certificate.
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = local.wait ? 1 : 0

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = local.manage_records ? [for record in aws_route53_record.validation : record.fqdn] : null

  timeouts {
    create = var.validation_timeout
  }
}
