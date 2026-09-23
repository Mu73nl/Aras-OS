# Security Policy

## Core rule

ARAS OS secrets, credentials and sensitive institutional or personal data must never be committed to GitHub.

## Reportable security issues

Report suspected credential exposure, unauthorized access, dependency compromise, production-impacting defects, data leakage, or bypass of ARAS OS approval controls through the canonical ARAS OS security/incident path.

Do not publish sensitive incident details in public channels.

## Repository controls

- Use scoped branches and pull requests for material changes.
- Keep production/deploy authority separate from ordinary code-write access.
- Do not treat repository access as authorization to deploy.
- Do not store production secrets in source files.
- Redact credentials from logs, screenshots, issue bodies and PR descriptions.
- Security findings should include evidence and a reproducible scope where possible.

## Production gate

Production deployment, production domain/environment changes, destructive actions and cost-bearing infrastructure changes require the applicable HUMAN-CEO approval gate and independent QA/security evidence when triggered.
