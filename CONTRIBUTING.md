# Contributing to ARAS OS

## Change discipline

Every material change should have:
- a clear scope and owner
- an issue, work order or canonical ARAS reference
- acceptance criteria
- evidence of testing
- rollback or recovery notes when the change has side effects

## Branch naming

Suggested patterns:
- `feat/<scope>`
- `fix/<scope>`
- `docs/<scope>`
- `security/<scope>`
- `ops/<scope>`

## Pull requests

Pull requests should explain:
- what changed
- why it changed
- risk and affected systems
- test/evidence
- rollback plan
- required approvals/gates

## Separation of duties

Engineering does not self-approve production release. QA remains independent. Security/privacy review is required when the change triggers those risks.

## Canonical records

GitHub records technical implementation history. Corporate governance, decisions, acceptance and handoff evidence remain canonical in Google Drive unless an approved ARAS OS standard explicitly changes that boundary.
