# ARAS OS

ARAS OS is the private technical repository for the ARAS organizational operating system.

## Source-of-truth boundaries

- **Google Drive:** canonical institutional records, governance documents, handoffs, decisions, evidence.
- **Supabase:** primary technical queue/state, workflow state, ledgers and runtime control data.
- **GitHub:** source code, technical configuration, change history, pull requests, issues and CI/CD artifacts.
- **Slack:** command/signal/notification layer; not canonical.
- **Vercel:** deployment/build/runtime observation and approved deployment actions.

## Governance

This repository does **not** supersede ARAS OS governance in Drive. Repository changes must respect existing approval, QA, security and release gates.

Production deployment, production-domain or environment mutation, destructive changes, secrets changes, and cost-bearing infrastructure actions remain approval-gated.

## Security

Never commit:
- passwords, API keys, access tokens, OAuth secrets or private keys
- production `.env` files
- personal or regulated data
- private Drive/Supabase dumps
- credentials embedded in examples, screenshots or logs

See [SECURITY.md](SECURITY.md).

## Working model

1. Create a scoped branch.
2. Make the smallest necessary change.
3. Open a pull request.
4. Review evidence, QA and security impact.
5. Merge only after the applicable gate is satisfied.

## Current status

Foundation repository initialized. Application/runtime code will be added only through explicit ARAS OS work orders and controlled handoff.
