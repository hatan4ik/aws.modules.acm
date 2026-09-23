# Advisory checks: they warn on every plan and apply but never block. Each
# describes a configuration that is valid yet usually unintended.

check "certificate_transparency_disabled" {
  assert {
    condition     = local.mode != "public" || local.certificate_transparency_logging_preference == "ENABLED"
    error_message = "Certificate transparency logging is disabled. Browsers may not trust a public certificate that is absent from the CT logs; keep options.certificate_transparency_logging_preference = ENABLED unless the domain must deliberately stay out of them."
  }
}
