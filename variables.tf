variable "domain_name" {
  description = "Fully qualified domain name for the certificate."
  type        = string

  validation {
    condition     = length(trimspace(var.domain_name)) > 0
    error_message = "domain_name must not be empty."
  }
}

variable "subject_alternative_names" {
  description = "Additional fully qualified domain names on the certificate."
  type        = set(string)
  default     = []
}

variable "validation_method" {
  description = "ACM certificate validation method. DNS is the supported automation path."
  type        = string
  default     = "DNS"

  validation {
    condition     = var.validation_method == "DNS"
    error_message = "Only DNS validation is supported by this module."
  }
}

variable "route53_zone_id" {
  description = "Optional Route 53 hosted-zone ID used to create DNS validation records."
  type        = string
  default     = null
  nullable    = true
}

variable "wait_for_validation" {
  description = "Whether Terraform waits for ACM to validate the certificate."
  type        = bool
  default     = true
}

variable "key_algorithm" {
  description = "ACM key algorithm."
  type        = string
  default     = "RSA_2048"
}

variable "certificate_transparency_logging_preference" {
  description = "Certificate transparency logging preference."
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.certificate_transparency_logging_preference)
    error_message = "certificate_transparency_logging_preference must be ENABLED or DISABLED."
  }
}

variable "tags" {
  description = "Tags applied to the certificate."
  type        = map(string)
  default     = {}
}
