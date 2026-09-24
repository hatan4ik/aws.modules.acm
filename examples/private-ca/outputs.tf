output "certificate_arn" {
  description = "ARN of the certificate issued by the Private CA."
  value       = module.certificate.validated_arn
}

output "mode" {
  description = "Mode the module resolved, private here."
  value       = module.certificate.mode
}
