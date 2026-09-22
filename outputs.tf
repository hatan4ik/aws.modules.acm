output "certificate_arn" {
  description = "ARN of the ACM certificate."
  value       = aws_acm_certificate.this.arn
}

output "certificate_domain_name" {
  description = "Primary domain name on the certificate."
  value       = aws_acm_certificate.this.domain_name
}

output "validation_record_fqdns" {
  description = "Route 53 DNS validation record FQDNs managed by this module."
  value       = values(aws_route53_record.validation)[*].fqdn
}
