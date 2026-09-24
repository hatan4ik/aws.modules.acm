# ---------------------------------------------------------------------------
# Subject
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Fully qualified domain name the certificate is issued for: lowercase, at least two labels, optionally starting with a wildcard label (*.example.com). Required for public and private certificates; must be unset for an import, which carries its own subject."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null ? true : (length(var.domain_name) <= 253 && can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.domain_name)))
    error_message = "domain_name must be a lowercase fully qualified domain name of at most 253 characters with at least two labels, optionally starting with *., and no trailing dot."
  }
}

variable "subject_alternative_names" {
  description = "Additional fully qualified domain names on the certificate, in the same format as domain_name. Do not repeat domain_name; ACM adds it. Public certificates accept 10 by default (an adjustable service quota)."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for name in var.subject_alternative_names : length(name) <= 253 && can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", name))])
    error_message = "Every subject alternative name must be a lowercase fully qualified domain name of at most 253 characters with at least two labels, optionally starting with *., and no trailing dot."
  }
}

variable "key_algorithm" {
  description = "Key algorithm of a requested public or private certificate: RSA_2048 (the ACM default, with the widest consumer support), RSA_3072, RSA_4096, EC_prime256v1, EC_secp384r1, or EC_secp521r1. Not used for imports."
  type        = string
  default     = "RSA_2048"
  nullable    = false

  validation {
    condition     = contains(["RSA_2048", "RSA_3072", "RSA_4096", "EC_prime256v1", "EC_secp384r1", "EC_secp521r1"], var.key_algorithm)
    error_message = "key_algorithm must be one of RSA_2048, RSA_3072, RSA_4096, EC_prime256v1, EC_secp384r1, or EC_secp521r1."
  }
}

variable "name" {
  description = "Value of the Name tag. Defaults to domain_name. Set it for an import, which has no domain_name; without it an import gets no Name tag."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Public certificate validation
# ---------------------------------------------------------------------------

variable "validation_method" {
  description = "How ACM proves control of a public certificate's domains: DNS (records in route53_zones, or created elsewhere from output domain_validation_options) or EMAIL (ACM mails the registrant and the standard aliases; steer recipients with validation_option). Ignored for private and imported certificates."
  type        = string
  default     = "DNS"
  nullable    = false

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "validation_method must be DNS or EMAIL."
  }
}

variable "route53_zones" {
  description = "Route 53 hosted zones the DNS validation records may be written to, keyed by zone name without a trailing dot. Each validated domain uses the zone whose name is its longest suffix, so an apex zone and a delegated subdomain zone can both be listed. Empty means the records are created elsewhere from output domain_validation_options, which also requires wait_for_validation = false."
  type = map(object({
    zone_id = string
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for name, zone in var.route53_zones : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)*[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", name)) && can(regex("^Z[0-9A-Z]{1,31}$", zone.zone_id))])
    error_message = "route53_zones keys must be lowercase zone names without a wildcard label or trailing dot, and every zone_id must be a hosted zone ID such as Z0123456789ABCDEFGHIJ without the /hostedzone/ prefix."
  }
}

variable "validation_record_ttl" {
  description = "TTL in seconds of the Route 53 validation records."
  type        = number
  default     = 60
  nullable    = false

  validation {
    condition     = var.validation_record_ttl >= 0 && var.validation_record_ttl <= 2147483647 && floor(var.validation_record_ttl) == var.validation_record_ttl
    error_message = "validation_record_ttl must be a whole number of seconds between 0 and 2147483647."
  }
}

variable "wait_for_validation" {
  description = "Block the apply until ACM reports the public certificate ISSUED, so a consumer that references validated_arn never attaches a pending certificate. Needs route53_zones (DNS) or EMAIL validation; set it to false when the DNS records are created elsewhere. Ignored for private and imported certificates."
  type        = bool
  default     = true
  nullable    = false
}

variable "validation_timeout" {
  description = "How long the apply waits for issuance when wait_for_validation is true, as a duration such as 45m or 1h30m."
  type        = string
  default     = "45m"
  nullable    = false

  validation {
    condition     = can(regex("^([0-9]+(h|m|s))+$", var.validation_timeout))
    error_message = "validation_timeout must be a duration made of hours, minutes, and seconds, such as 45m or 1h30m."
  }
}

variable "validation_option" {
  description = "For EMAIL validation only: where ACM sends the validation email, keyed by a certificate domain (domain_name or a subject alternative name) and valued with that domain or one of its parent domains. Domains not listed are mailed at their own name."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for domain, validation_domain in var.validation_option : can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", domain)) && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", validation_domain))])
    error_message = "validation_option keys must be lowercase fully qualified domain names (optionally starting with *.) and values lowercase fully qualified domain names, none with a trailing dot."
  }
}

variable "options" {
  description = "Public certificate options. certificate_transparency_logging_preference is ENABLED unless set to DISABLED, which keeps the domain out of public CT logs and triggers a warning. export = ENABLED makes the certificate and its private key exportable through ACM; unset or DISABLED does not. Must stay empty for private and imported certificates."
  type = object({
    certificate_transparency_logging_preference = optional(string)
    export                                      = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = (var.options.certificate_transparency_logging_preference == null ? true : contains(["ENABLED", "DISABLED"], var.options.certificate_transparency_logging_preference)) && (var.options.export == null ? true : contains(["ENABLED", "DISABLED"], var.options.export))
    error_message = "options.certificate_transparency_logging_preference and options.export must be ENABLED or DISABLED."
  }
}

# ---------------------------------------------------------------------------
# Private certificate
# ---------------------------------------------------------------------------

variable "certificate_authority_arn" {
  description = "ARN of the AWS Private CA that issues the certificate. Setting it selects the private mode: no validation, no transparency logging, no export option. The CA must be in the certificate's region and account, or shared with it through AWS RAM."
  type        = string
  default     = null

  validation {
    condition     = var.certificate_authority_arn == null ? true : can(regex("^arn:[a-z-]+:acm-pca:[a-z0-9-]+:[0-9]{12}:certificate-authority/[0-9a-f-]{36}$", var.certificate_authority_arn))
    error_message = "certificate_authority_arn must be a Private CA ARN (arn:<partition>:acm-pca:<region>:<account>:certificate-authority/<uuid>)."
  }
}

# ---------------------------------------------------------------------------
# Imported certificate
# ---------------------------------------------------------------------------

variable "imported" {
  description = "PEM material of an existing certificate to import: certificate_body, private_key, and the optional certificate_chain. Setting it selects the import mode; domain_name and subject_alternative_names must then be unset. The whole object is sensitive so the key never appears in plan output."
  type = object({
    certificate_body  = string
    private_key       = string
    certificate_chain = optional(string)
  })
  default   = null
  sensitive = true

  validation {
    condition = var.imported == null ? true : (
      can(regex("^-----BEGIN CERTIFICATE-----", trimspace(var.imported.certificate_body))) &&
      can(regex("^-----BEGIN [A-Z ]*PRIVATE KEY-----", trimspace(var.imported.private_key))) &&
      (var.imported.certificate_chain == null ? true : can(regex("^-----BEGIN CERTIFICATE-----", trimspace(var.imported.certificate_chain))))
    )
    error_message = "imported.certificate_body and imported.certificate_chain must be PEM certificates starting with -----BEGIN CERTIFICATE-----, and imported.private_key a PEM private key starting with -----BEGIN ... PRIVATE KEY-----."
  }
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

variable "early_renewal_duration" {
  description = "Private certificates only: how long before expiry Terraform renews the certificate on the next apply, as a subset of an RFC 3339 duration (P90D) or a number of hours (2160h). Has no effect below 60 days. Null leaves renewal to ACM. ACM renews public certificates itself and never renews imports."
  type        = string
  default     = null

  validation {
    condition     = var.early_renewal_duration == null ? true : (can(regex("^(P([0-9]+Y)?([0-9]+M)?([0-9]+D)?|[0-9]+h)$", var.early_renewal_duration)) && var.early_renewal_duration != "P")
    error_message = "early_renewal_duration must be an RFC 3339 duration of years, months, and days such as P90D, or a number of hours such as 2160h."
  }
}

variable "tags" {
  description = "Tags applied to the certificate. The module adds a Name tag (from name or domain_name) only when you do not set one, and never overrides caller tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
