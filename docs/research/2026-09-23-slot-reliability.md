# Reliability Research Notes — 2026-09-23

This note records the external design references used for the Slot Runtime v3 hardening.

## ChatGPT scheduled tasks

OpenAI documents plan-specific active task limits; Plus supports five active tasks. It also documents that tasks may be paused if they are inactive or require further action, and that connected-app permissions continue to apply. ARAS OS therefore uses exactly five slots, avoids unattended approval waits, and records a heartbeat even when no queue item exists.

## PostgreSQL queue concurrency

PostgreSQL documents `FOR UPDATE ... SKIP LOCKED` as appropriate for queue-like tables with multiple consumers. Runtime v3 keeps row locking and makes lease + run creation atomic in one database function.

## Supabase durability

Supabase Cron is backed by pg_cron and records job executions. Supabase recommends bounded cron concurrency and short jobs. ARAS OS uses one small five-minute stale-lease recovery job.

Supabase Queues/pgmq provides durable queue semantics and remains a possible later migration path, but Runtime v3 deliberately hardens the existing canonical queue first to avoid a disruptive big-bang rewrite.

## Design consequence

The scheduled-task layer is a wake/execution layer. Supabase is the durable technical state machine. GitHub stores migration/version history. Drive remains canonical institutional evidence.
