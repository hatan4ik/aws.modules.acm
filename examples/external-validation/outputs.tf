output "certificate_arn" {
  description = "ARN of the requested certificate. It stays PENDING_VALIDATION until the records below exist."
  value       = module.certificate.arn
}

output "domain_validation_options" {
  description = "The CNAME records to create at the external DNS provider, one per domain: name, type, and value."
  value       = module.certificate.domain_validation_options
}
