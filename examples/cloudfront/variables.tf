variable "workload_region" {
  description = "Region of the surrounding workload stack. The certificate remains pinned to us-east-1 for CloudFront."
  type        = string
  default     = "us-east-2"
}

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
