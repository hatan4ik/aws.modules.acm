# One certificate in exactly one mode. The mode follows from which inputs are
# set (locals.tf); the preconditions reject mixed or incomplete input with a
# message that names the fix.

resource "aws_acm_certificate" "this" {
  # Requested certificates, public or private.
  domain_name               = local.mode == "imported" ? null : var.domain_name
  subject_alternative_names = local.mode == "imported" ? null : sort(tolist(var.subject_alternative_names))
  key_algorithm             = local.mode == "imported" ? null : var.key_algorithm

  # Public certificates.
  validation_method = local.mode == "public" ? var.validation_method : null

  dynamic "options" {
    for_each = local.mode == "public" ? [true] : []

    content {
      certificate_transparency_logging_preference = local.certificate_transparency_logging_preference
      export                                      = var.options.export
    }
  }

  dynamic "validation_option" {
    for_each = var.validation_option

    content {
      domain_name       = validation_option.key
      validation_domain = validation_option.value
    }
  }

  # Private certificates. ACM renews public certificates itself and never
  # renews imports, so early renewal only exists here.
  certificate_authority_arn = var.certificate_authority_arn
  early_renewal_duration    = local.mode == "private" ? var.early_renewal_duration : null

  # Imported certificates.
  certificate_body  = local.mode == "imported" ? var.imported.certificate_body : null
  private_key       = local.mode == "imported" ? var.imported.private_key : null
  certificate_chain = local.mode == "imported" ? var.imported.certificate_chain : null

  tags = local.tags

  lifecycle {
    # A replacement is requested and validated before the previous certificate
    # is deleted, so consumers roll to the new ARN without an outage.
    create_before_destroy = true

    precondition {
      condition     = local.imported || var.domain_name != null
      error_message = "domain_name is required for a public or private certificate. Set it, or set imported to import an existing certificate."
    }

    precondition {
      condition     = !local.imported || (var.domain_name == null && length(var.subject_alternative_names) == 0 && var.certificate_authority_arn == null)
      error_message = "An imported certificate carries its own subject and issuer: leave domain_name, subject_alternative_names, and certificate_authority_arn unset when imported is set."
    }

    precondition {
      condition     = var.domain_name == null ? true : !contains(var.subject_alternative_names, var.domain_name)
      error_message = "subject_alternative_names must not repeat domain_name; ACM adds the primary domain to the certificate itself."
    }

    precondition {
      condition     = local.mode == "public" || (var.options.certificate_transparency_logging_preference == null && var.options.export == null)
      error_message = "options (certificate transparency logging, export) apply to public certificates only. Leave options empty for private and imported certificates."
    }

    precondition {
      condition     = var.early_renewal_duration == null || local.mode == "private"
      error_message = "early_renewal_duration applies to private certificates only: ACM renews public certificates itself and never renews imported ones."
    }

    precondition {
      condition     = length(var.validation_option) == 0 || (local.mode == "public" && var.validation_method == "EMAIL")
      error_message = "validation_option applies to EMAIL-validated public certificates only."
    }

    precondition {
      condition     = alltrue([for domain, validation_domain in var.validation_option : contains(local.domains, domain) && (trimprefix(domain, "*.") == validation_domain || endswith(trimprefix(domain, "*."), ".${validation_domain}"))])
      error_message = "Every validation_option key must be domain_name or a subject alternative name, and its value must be that domain without its wildcard label or one of its parent domains."
    }

    precondition {
      condition     = length(local.unmatched_domains) == 0
      error_message = "No route53_zones entry is a suffix of: ${join(", ", local.unmatched_domains)}. Add the hosted zone that serves each domain, or validate elsewhere with route53_zones = {} and wait_for_validation = false."
    }

    precondition {
      condition     = !(local.dns_validated && var.wait_for_validation && length(var.route53_zones) == 0)
      error_message = "wait_for_validation needs DNS validation records the module can create. Add route53_zones, or set wait_for_validation = false and create the records elsewhere from output domain_validation_options."
    }
  }
}
