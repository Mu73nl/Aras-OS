# ARAS OS Repository Governance

## Repository role

This repository is a technical implementation workspace. It does not replace the ARAS OS institutional governance layer.

## Authority

- HUMAN-CEO retains final authority for high-impact decisions.
- Engineering owns technical implementation.
- QA independently verifies release readiness.
- Security/Privacy owns security and privacy review within its mandate.
- SRE owns reliability/incident/recovery evidence within its mandate.

## Required distinction

- `DONE` is not `ACTIVE`.
- delivery is not acceptance.
- merge is not production release.
- repository access is not deployment authority.

## Change classes

### Routine technical change
May proceed through normal branch/PR workflow.

### High-impact change
Includes production deployment, production domain/environment mutation, destructive data/configuration changes, permission/security changes, and cost-bearing infrastructure changes. These require explicit approval according to ARAS OS governance.

## Evidence

Material changes should preserve commit/PR evidence in GitHub and acceptance/governance evidence in the canonical Drive records.
