output "certificate_arns" {
  description = "ARN of each issued certificate keyed by workload, produced after validation."
  value       = { for key, certificate in module.certificate : key => certificate.validated_arn }
}

output "validation_record_zone_ids" {
  description = "Hosted zone selected for each validated domain, keyed by workload and then by domain."
  value       = { for key, certificate in module.certificate : key => certificate.validation_record_zone_ids }
}
