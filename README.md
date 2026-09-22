# aws.modules.acm

Versioned Terraform module for ACM certificates with DNS validation through an
explicit Route 53 zone. Use an `us-east-1` provider alias when the certificate
is for CloudFront; use the workload Region for regional services.

The module never creates a hosted zone. Supply `route53_zone_id` only when the
caller owns the DNS validation records.
