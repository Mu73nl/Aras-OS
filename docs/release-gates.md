# ARAS OS Release Gates

## Principle

Merge, deployment and release are different states. A merged change is not automatically production-ready.

## Standard path

1. Product/requirement scope exists when applicable.
2. Engineering produces implementation and test evidence.
3. QA independently verifies acceptance/regression evidence.
4. Security/Privacy reviews changes that trigger security, privacy, access, secret, data or external-effect risk.
5. SRE reviews availability/recovery/observability impact when applicable.
6. HUMAN-CEO approves production deployment when the production gate is triggered.

## High-impact examples

- production deployment
- production domain or environment-variable change
- credential/permission changes
- destructive data/configuration mutation
- irreversible external side effects
- cost-bearing infrastructure changes

## Evidence rule

No high-impact action is considered complete without post-action readback/evidence.
