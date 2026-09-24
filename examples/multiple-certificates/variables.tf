variable "region" {
  description = "AWS region the certificates are created in."
  type        = string
  default     = "us-east-1"
}

variable "route53_zones" {
  description = "Every hosted zone the certificates may validate through, keyed by zone name. Each name on each certificate must be served by one of them."
  type = map(object({
    zone_id = string
  }))
}

variable "certificates" {
  description = "Certificates to issue, keyed by workload. Each entry names its primary domain, optional further names, and an optional key algorithm."
  type = map(object({
    domain_name               = string
    subject_alternative_names = optional(set(string), [])
    key_algorithm             = optional(string, "RSA_2048")
  }))
}

variable "tags" {
  description = "Tags applied to every certificate; a Workload tag with the map key is added to each."
  type        = map(string)
  default     = {}
}
