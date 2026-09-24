# Integration suites

The suites in this directory apply the module for real in **your** AWS account
and destroy everything afterwards. They complement the contract tests in
`tests/`, which run with `mock_provider`, need no credentials, and use
placeholder zone IDs and the AWS documentation account `123456789012` on
purpose: they prove the module's interface, zone selection, and rendering, not
that AWS accepts it. These suites prove the latter.

Nothing here is tied to an account, region, zone, or landing zone. Credentials
and the region come from the environment, and the certificate under test is
requested for names under the IANA-reserved `example.com`, which no caller
hosts, so the request is accepted, never validates, and is deleted at the end.
ACM does not charge for public certificates and deletes a pending one
immediately, so nothing lingers. No fixture module is needed; a suite that ever
needs one keeps it in `setup/`, which the policy scans exclude (`.checkov.yml`,
`trivy.yaml`).

| Suite | What it proves | Needs | Typical time |
| --- | --- | --- | --- |
| `smoke.tftest.hcl` | A DNS-validated request with no zones and `wait_for_validation = false` is accepted by the API and returns `PENDING_VALIDATION`; `domain_validation_options` exposes one CNAME per requested name for another DNS provider to create; no record, no wait, and no mail are produced; the defaults (RSA 2048, transparency logging, the `Name` tag) survive the real API. | credentials, region | about a minute |

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
```

The credentials need the permissions in
[`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json)
(replace `<ACCOUNT_ID>`): `acm:RequestCertificate`, which takes no resource
constraint, and the describe, tag, and delete actions on certificates of the
account. Nothing else is touched.

`terraform test` runs `tests/` only by default, so these suites never run in
the credential-free quality pipeline.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only
and assumes a role through GitHub OIDC. It reads everything account-specific
from the protected `integration` environment of the repository, so the code
stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<OWNER>/<REPO>` set to this repository; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region the certificate is requested in. |

Dispatch with `gh workflow run integration.yml -f suite=smoke`. Protect the
environment with required reviewers so a run cannot be started from a pull
request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox
region; the role ARN is added once the role exists in the sandbox account,
created through the platform's delivery IAM module with the trust policy above
and the subject `repo:hatan4ik/aws.modules.acm:environment:integration`.
