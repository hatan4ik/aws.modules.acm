variable "region" {
  description = "AWS region the certificate is created in. Use the region of the load balancer or API that will serve it."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Fully qualified domain name to issue the certificate for, such as app.example.com."
  type        = string
}

variable "zone_name" {
  description = "Name of the Route 53 hosted zone that serves domain_name, without a trailing dot, such as example.com."
  type        = string
}

variable "zone_id" {
  description = "ID of that hosted zone, such as Z0123456789ABCDEFGHIJ."
  type        = string
}
