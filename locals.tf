locals {
  # The import object is sensitive. Its presence must not be: the mode drives
  # count and for_each, which reject sensitive values, and is itself an
  # output. nonsensitive() strips the mark from this boolean only.
  imported = nonsensitive(var.imported != null)
  mode     = local.imported ? "imported" : (var.certificate_authority_arn != null ? "private" : "public")

  name = var.name != null ? var.name : var.domain_name
  # The caller's Name tag wins; the module only fills the gap.
  tags = merge(local.name == null ? {} : { Name = local.name }, var.tags)

  certificate_transparency_logging_preference = local.mode == "public" ? coalesce(var.options.certificate_transparency_logging_preference, "ENABLED") : null

  # Every domain on a requested certificate, in a stable order. Empty for an
  # import, and while domain_name is missing (which a precondition reports).
  domains = var.domain_name == null ? [] : distinct(concat([var.domain_name], sort(tolist(var.subject_alternative_names))))

  dns_validated  = local.mode == "public" && var.validation_method == "DNS"
  manage_records = local.dns_validated && length(var.route53_zones) > 0
  wait           = local.mode == "public" && var.wait_for_validation && (local.manage_records || var.validation_method == "EMAIL")

  # Zone selection. A wildcard label is stripped, then a zone matches when its
  # name equals the domain or the domain ends in ".<zone name>", so a partial
  # label never matches. Of several matches the longest name wins.
  domain_zone_candidates = {
    for domain in local.domains : domain => [
      for zone_name in keys(var.route53_zones) : zone_name
      if trimprefix(domain, "*.") == zone_name || endswith(trimprefix(domain, "*."), ".${zone_name}")
    ]
  }
  domain_zone_names = {
    for domain, candidates in local.domain_zone_candidates : domain => one([
      for zone_name in candidates : zone_name
      if length(zone_name) == max(concat([0], [for candidate in candidates : length(candidate)])...)
    ])
  }
  unmatched_domains = local.manage_records ? [for domain, zone_name in local.domain_zone_names : domain if zone_name == null] : []

  # ACM issues one CNAME for a wildcard and its apex, so a wildcard whose
  # apex is also on the certificate needs no record of its own.
  record_domains = local.manage_records ? [
    for domain in local.domains : domain
    if !(startswith(domain, "*.") && contains(local.domains, trimprefix(domain, "*.")))
  ] : []

  # for_each keys of the validation records. Known at plan time because they
  # come from the inputs, not from the computed domain_validation_options.
  validation_record_zone_ids = {
    for domain in local.record_domains : domain => var.route53_zones[local.domain_zone_names[domain]].zone_id
    if local.domain_zone_names[domain] != null
  }

  # Record name, type, and value per domain, looked up from the certificate.
  # The values are unknown until the provider plans the certificate; the keys
  # never are.
  validation_options = {
    for domain in local.record_domains : domain => one([
      for option in aws_acm_certificate.this.domain_validation_options : option if option.domain_name == domain
    ])
  }
}
