variable "region" {
  description = "AWS region the certificate is created in."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Fully qualified domain name to issue the certificate for."
  type        = string
}

variable "subject_alternative_names" {
  description = "Further names on the certificate."
  type        = set(string)
  default     = []
}
