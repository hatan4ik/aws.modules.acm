output "arn" {
  description = "ARN of the certificate. A consumer that must not attach before issuance should reference validated_arn instead."
  value       = aws_acm_certificate.this.arn
}

output "id" {
  description = "ID of the certificate (the same value as the ARN)."
  value       = aws_acm_certificate.this.id
}

output "domain_name" {
  description = "Primary domain name on the certificate."
  value       = aws_acm_certificate.this.domain_name
}

output "subject_alternative_names" {
  description = "Subject alternative names on the certificate."
  value       = aws_acm_certificate.this.subject_alternative_names
}

output "key_algorithm" {
  description = "Key algorithm of the certificate."
  value       = aws_acm_certificate.this.key_algorithm
}

output "status" {
  description = "Certificate status as reported by ACM, for example PENDING_VALIDATION or ISSUED."
  value       = aws_acm_certificate.this.status
}

output "type" {
  description = "Certificate source as reported by ACM: AMAZON_ISSUED, PRIVATE, or IMPORTED."
  value       = aws_acm_certificate.this.type
}

output "not_before" {
  description = "Start of the certificate's validity period."
  value       = aws_acm_certificate.this.not_before
}

output "not_after" {
  description = "Expiration of the certificate."
  value       = aws_acm_certificate.this.not_after
}

output "renewal_eligibility" {
  description = "Whether ACM can renew the certificate: ELIGIBLE or INELIGIBLE."
  value       = aws_acm_certificate.this.renewal_eligibility
}

output "domain_validation_options" {
  description = "DNS records that prove control of each domain, one object per domain with domain_name, resource_record_name, resource_record_type, and resource_record_value. Create them elsewhere when route53_zones is empty."
  value = [
    for option in aws_acm_certificate.this.domain_validation_options : {
      domain_name           = option.domain_name
      resource_record_name  = option.resource_record_name
      resource_record_type  = option.resource_record_type
      resource_record_value = option.resource_record_value
    }
  ]
}

output "validation_emails" {
  description = "Addresses ACM sent validation email to, for EMAIL validation."
  value       = aws_acm_certificate.this.validation_emails
}

output "validation_record_fqdns" {
  description = "Sorted FQDNs of the Route 53 validation records the module manages."
  value       = sort([for record in aws_route53_record.validation : record.fqdn])
}

output "validation_record_ids" {
  description = "IDs of the Route 53 validation records keyed by validated domain."
  value       = { for domain, record in aws_route53_record.validation : domain => record.id }
}

output "validation_record_zone_ids" {
  description = "Hosted zone selected for each managed validation record, keyed by validated domain. Known at plan time."
  value       = local.validation_record_zone_ids
}

output "validated_arn" {
  description = "ARN to attach to listeners and distributions. When the module waits for validation it is produced by the wait, so consumers depend on issuance; otherwise it is the certificate ARN."
  value       = local.wait ? aws_acm_certificate_validation.this[0].certificate_arn : aws_acm_certificate.this.arn
}

output "mode" {
  description = "Resolved certificate mode: public, private, or imported."
  value       = local.mode
}
