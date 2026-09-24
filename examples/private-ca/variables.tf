variable "region" {
  description = "AWS region of the Private CA and the certificate."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Internal name the certificate is issued for, such as app.corp.example.com."
  type        = string
}

variable "subject_alternative_names" {
  description = "Further internal names on the certificate."
  type        = set(string)
  default     = []
}

variable "certificate_authority_arn" {
  description = "ARN of the AWS Private CA that issues the certificate, in the same region and account or shared through AWS RAM."
  type        = string
}

variable "tags" {
  description = "Tags applied to the certificate."
  type        = map(string)
  default     = {}
}
