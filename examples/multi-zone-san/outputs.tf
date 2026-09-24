output "certificate_arn" {
  description = "ARN of the issued certificate, produced after validation."
  value       = module.certificate.validated_arn
}

output "validation_record_zone_ids" {
  description = "Hosted zone the module selected for each validated domain."
  value       = module.certificate.validation_record_zone_ids
}

output "validation_record_fqdns" {
  description = "FQDNs of the DNS validation records the module created."
  value       = module.certificate.validation_record_fqdns
}
