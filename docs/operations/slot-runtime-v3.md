# Slot Runtime v3 — Reliability Runbook

## Why this exists

The original worker path could lease a queue row without atomically creating a `workflow_runs.run_id`. Later completion paths could therefore fail even though the queue item had already been leased.

The scheduled-task layer also has platform behavior that can pause tasks when they are inactive or require further action. ARAS OS therefore treats scheduled tasks as bounded executors, not the durable state machine.

## Runtime v3 rules

1. Every scheduled run writes a heartbeat with `record_slot_heartbeat_v1`.
2. Claims use `claim_next_job_v3`, which atomically:
   - selects one eligible row with `FOR UPDATE SKIP LOCKED`
   - enforces approval state
   - writes the lease
   - creates the corresponding `workflow_runs.run_id`
3. Long work renews the lease with `heartbeat_job_v1`.
4. Completion uses `finish_job_v3`; DONE requires evidence.
5. Expired leases are recovered by `recover_stale_jobs_v2`.
6. Supabase Cron runs stale-lease recovery every five minutes.
7. Slot 1 and Slot 5 act as independent scheduled-task self-heal sentinels.
8. Unattended runs never wait for a new human approval; approval-gated work remains unclaimed or is parked safely.
9. Vercel writes remain outside unattended execution.

## Capacity model

The account supports five active scheduled tasks. The five ARAS slots are therefore the complete active worker pool. They are staggered across the hour to reduce connector bursts and lock contention, and each may process a small bounded batch.

## Failure model

- Connection/tool failure before external effect: retry only after idempotency/readback.
- Failure after lease but before finish: pg_cron requeues or dead-letters based on attempt budget.
- Disabled scheduled task: peer sentinel re-enables it unless HUMAN-CEO explicitly paused it.
- Queue empty: still write heartbeat and exit successfully.
- Human approval needed: do not pause the scheduled task waiting for the user.

## Evidence

A runtime smoke test must show:
- claim returns a run_id
- finish closes that exact run
- job lease is cleared
- evidence is persisted
- stale-recovery cron is active
