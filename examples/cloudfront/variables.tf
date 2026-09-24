variable "domain_name" {
  description = "Domain name the distribution serves, such as www.example.com."
  type        = string
}

variable "subject_alternative_names" {
  description = "Further names the distribution serves, such as example.com or *.example.com. All must be served by the zone below."
  type        = set(string)
  default     = []
}

variable "zone_name" {
  description = "Name of the Route 53 hosted zone that serves every name above, without a trailing dot."
  type        = string
}

variable "zone_id" {
  description = "ID of that hosted zone."
  type        = string
}
