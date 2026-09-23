# ARAS OS Technical Architecture

## Control boundaries

### Google Drive
Institutional source of truth for governance, office records, decisions, handoffs and evidence.

### Supabase
Primary technical queue/state backend for workflows, ledgers, runtime control and security shadow telemetry.

### GitHub
Technical source of truth for code, configuration, diffs, pull requests, issues and software history.

### Slack
Signal, command and notification transport. Slack messages are not canonical institutional truth.

### Vercel
Deployment/build/runtime inspection and approved deployment operations. Vercel access does not itself grant production deployment authority.

## Execution model

ARAS OS uses bounded work release:
command/work order -> queue -> execution -> evidence -> review/QA -> approval -> release-next.

A completed implementation is not automatically accepted or releasable.

## Security posture

Security Kernel remains staged and must not be treated as a complete enforcement boundary while direct connector bypass paths remain.

Least privilege, scoped identities, exact-effect approval, provenance and context isolation remain target controls.
