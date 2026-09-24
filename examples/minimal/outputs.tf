output "certificate_arn" {
  description = "ARN of the issued certificate, produced after ACM has validated it; attach this to listeners."
  value       = module.certificate.validated_arn
}

output "validation_record_fqdns" {
  description = "FQDNs of the DNS validation records the module created."
  value       = module.certificate.validation_record_fqdns
}

output "status" {
  description = "Certificate status as reported by ACM."
  value       = module.certificate.status
}
