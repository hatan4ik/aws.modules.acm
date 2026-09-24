output "certificate_arn" {
  description = "ARN of the issued us-east-1 certificate; pass it to aws_cloudfront_distribution.viewer_certificate.acm_certificate_arn."
  value       = module.certificate.validated_arn
}
