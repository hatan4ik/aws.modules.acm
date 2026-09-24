# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

## [1.0.0] - 2026-09-24

Breaking release. One module call still provisions one certificate, now in one of three modes. [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) maps every 0.1.x input and output to its replacement and gives the one state operation a wildcard-plus-apex certificate needs; resource addresses are unchanged.

### Added

- Private certificates issued by AWS Private CA through `certificate_authority_arn`, with `early_renewal_duration` for Terraform-driven renewal.
- Imported certificates through the sensitive `imported` object (`certificate_body`, `private_key`, optional `certificate_chain`).
- `EMAIL` validation, `validation_option` to direct the mail to a parent domain, and the `validation_emails` output.
- Multi-zone DNS validation: `route53_zones` maps zone names to zone IDs and each validated domain selects the zone whose name is its longest suffix. A precondition names any domain that matches no zone.
- Validation records keyed by the declared domains, so `for_each` keys and zone selection are known at plan time and covered by mock-provider tests; `validation_record_zone_ids` exposes the selection.
- `validation_record_ttl` (default 60) and `validation_timeout` (default `45m`) on the wait for issuance.
- `options.export` for exportable public certificates.
- `name` to set the `Name` tag independently of `domain_name`.
- Outputs `id`, `subject_alternative_names`, `key_algorithm`, `status`, `type`, `not_before`, `not_after`, `renewal_eligibility`, `domain_validation_options`, `validation_emails`, `validation_record_ids`, `validation_record_zone_ids`, `validated_arn`, and `mode`.
- Advisory `check` block `certificate_transparency_disabled`.
- Plan-time validation of every input (domain name syntax, subject alternative names, zone names and IDs, key algorithm, validation method, TTL, timeout and renewal durations, PEM markers) and preconditions for the cross-input rules of each mode.
- Mock-provider contract tests in `tests/` for the defaults, every validation and precondition, zone selection, wildcard handling, email validation, private CA issuance, import, and external validation.
- Examples `minimal`, `multi-zone-san`, `cloudfront`, `private-ca`, `external-validation`, and `multiple-certificates`.
- Credential-driven integration suite `smoke` in `tests/integration/`, a `make integration-smoke` target, a dispatch-only `integration` workflow that assumes a role through GitHub OIDC from the protected `integration` environment, and the IAM trust and permissions documents the role needs.
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, the `Makefile` quality gate, pre-commit, tflint, and terraform-docs configuration, Dependabot, issue and pull request templates, and the `module-release` workflow.

### Changed

- **Breaking:** `route53_zone_id` is replaced by the `route53_zones` map.
- **Breaking:** `certificate_transparency_logging_preference` moves to `options.certificate_transparency_logging_preference`.
- **Breaking:** `wait_for_validation = true` with DNS validation and no zones is rejected at plan time instead of being ignored; validating elsewhere requires `wait_for_validation = false`.
- **Breaking:** outputs `certificate_arn` and `certificate_domain_name` are renamed `arn` and `domain_name`; `validation_record_fqdns` is sorted.
- **Breaking:** `subject_alternative_names` must not repeat `domain_name`.
- `validation_method` accepts `EMAIL`; `key_algorithm` is validated against the ACM algorithm names; `domain_name` is validated as a fully qualified domain name.
- A wildcard whose apex is also on the certificate no longer gets a record of its own; ACM issues one CNAME for both.
- The module adds a `Name` tag (from `name` or `domain_name`) unless the caller sets one; caller tags are never overridden.
- The AWS provider constraint is `>= 6.35.0, < 7.0.0` (was `>= 6.0, < 7.0`).
- CI runs the shared `terraform-quality` workflow over the root and every example, with a docs drift check.

### Removed

- **Breaking:** the top-level inputs `route53_zone_id` and `certificate_transparency_logging_preference` (see Changed).
- The `validation_method` validation that accepted only `DNS`.

### Fixed

- A wildcard and its apex created two Route 53 record resources for one record set, which raced on delete.
- `wait_for_validation` was silently ignored without a zone, so an apply succeeded with a pending certificate and the consumer failed later, out of context.
- Record `for_each` keys came from the computed `domain_validation_options` set, which could not be planned offline and turned every mock-provider test into `Invalid for_each argument`.
- An unknown `key_algorithm` or a malformed `domain_name` failed at apply time; both are rejected at plan time.

## [0.1.2] - 2026-09-22

### Changed

- The committed provider lock file carries checksums for the platforms CI and contributors use.
- The quality workflow validates modules that declare provider configuration aliases.

## [0.1.1] - 2026-09-22

### Added

- Generated module reference (inputs and outputs tables) in the README.

## [0.1.0] - 2026-09-22

### Added

- Versioned ACM certificate module: a public certificate with DNS validation records in one Route 53 zone and an optional wait for issuance.

[Unreleased]: https://github.com/hatan4ik/aws.modules.acm/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.acm/compare/v0.1.2...v1.0.0
[0.1.2]: https://github.com/hatan4ik/aws.modules.acm/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/hatan4ik/aws.modules.acm/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.acm/releases/tag/v0.1.0
