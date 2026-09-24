# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.1.x | Security fixes only, until 2026-12-31. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see. Redact certificate material and zone IDs.

## What counts

- A module default that weakens security: certificate transparency logging off, an exportable certificate, a key algorithm accepted without validation, a validation record written to a zone the caller did not list.
- Key material exposure: an imported private key, certificate body, or chain appearing in plan output, in an output, or in a log line the module produces.
- A validation bypass: an input the module claims to reject at plan time but that reaches the provider.
- A wait bypass: `validated_arn` resolving to a certificate ACM has not reported `ISSUED` while `wait_for_validation` is true.
- A mode bypass: an input from one mode taking effect in another (for example an export option on a private certificate) instead of being rejected.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a certificate you chose to make exportable) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release of every supported line with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: certificate transparency logging on with an advisory check when it is disabled, no export unless declared, `RSA_2048` with every algorithm validated by name, a sensitive `imported` input that never reaches an output, validation records confined to the listed zones and the validated names, an apply that waits for issuance unless the caller opts out explicitly, exactly one mode per certificate with the other modes' inputs rejected, no data sources, and no IAM resources. Every claim is enforced by a validation, a precondition, or a `check` block with a `terraform test` case behind it. The full description is in the [Security model](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
