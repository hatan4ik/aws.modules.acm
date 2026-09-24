variable "region" {
  description = "AWS region the certificate is created in."
  type        = string
  default     = "us-east-1"
}

variable "apex_zone" {
  description = "The apex hosted zone: its name (example.com) and ID. The certificate is issued for this name and for *.<name>."
  type = object({
    name    = string
    zone_id = string
  })
}

variable "subdomain_zone" {
  description = "A hosted zone delegated below the apex (internal.example.com) and its ID. The certificate also covers api.<name>, validated in this zone."
  type = object({
    name    = string
    zone_id = string
  })
}

variable "tags" {
  description = "Tags applied to the certificate."
  type        = map(string)
  default     = {}
}
