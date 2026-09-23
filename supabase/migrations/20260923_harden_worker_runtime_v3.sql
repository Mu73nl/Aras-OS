-- ARAS OS worker runtime v3
-- Applied live on 2026-09-23 after HUMAN-CEO authorization.
-- Additive migration: keeps v2 functions for rollback compatibility.

create extension if not exists pg_cron;

create index if not exists workflow_jobs_claim_v3_idx
on aras_os.workflow_jobs (status, approval_state, not_before, next_check, due_at, lease_until, created_at)
where status in ('READY','WAITING');

create or replace function aras_os.claim_next_job_v3(
  p_worker text,
  p_lease_seconds integer default 1200
)
returns table(
  queue_id text,
  run_id text,
  workflow_id text,
  task_type text,
  target_role text,
  action text,
  acceptance_criteria text,
  evidence_target text,
  canonical_sources jsonb,
  attempts integer,
  max_attempts integer,
  lease_until timestamptz
)
language plpgsql
set search_path = ''
as $$
declare
  v_job aras_os.workflow_jobs%rowtype;
  v_run_id text;
begin
  if p_worker is null or btrim(p_worker) = '' then
    raise exception 'worker required';
  end if;
  if p_lease_seconds < 120 or p_lease_seconds > 3600 then
    raise exception 'invalid lease seconds';
  end if;

  if exists (
    select 1 from aras_os.control_state
    where key = 'system_mode'
      and coalesce(value,'PAUSED') <> 'ACTIVE'
  ) then
    return;
  end if;

  select j.*
  into v_job
  from aras_os.workflow_jobs j
  where j.status in ('READY','WAITING')
    and j.attempts < j.max_attempts
    and coalesce(j.approval_state,'NOT_REQUIRED') in ('NOT_REQUIRED','APPROVED')
    and coalesce(j.not_before, now()) <= now()
    and (j.due_at is null or j.due_at <= now())
    and (j.next_check is null or j.next_check <= now())
    and (j.lease_until is null or j.lease_until < now())
    and (
      j.concurrency_key is null
      or not exists (
        select 1 from aras_os.workflow_jobs x
        where x.id <> j.id
          and x.concurrency_key = j.concurrency_key
          and x.status in ('LEASED','IN_PROGRESS')
          and x.lease_until is not null
          and x.lease_until >= now()
      )
    )
  order by
    case j.priority when 'CRITICAL' then 1 when 'HIGH' then 2 when 'NORMAL' then 3 else 4 end,
    case when j.due_at is not null and j.due_at < now() then 0 else 1 end,
    j.due_at nulls last,
    j.next_check nulls first,
    j.created_at
  for update skip locked
  limit 1;

  if not found then
    return;
  end if;

  update aras_os.workflow_jobs j
  set status = 'LEASED',
      lease_owner = p_worker,
      lease_until = now() + make_interval(secs => p_lease_seconds),
      attempts = j.attempts + 1,
      updated_at = now()
  where j.id = v_job.id
  returning j.* into v_job;

  v_run_id :=
    'RUN-' || p_worker || '-' ||
    to_char(clock_timestamp() at time zone 'UTC','YYYYMMDDHH24MISSMS') || '-' ||
    substr(extensions.gen_random_uuid()::text,1,8);

  insert into aras_os.workflow_runs(
    run_id, slot_id, queue_id, started_at, executor_role,
    attempt, trigger, lease_released, automation_task_ref, notes
  )
  values(
    v_run_id, p_worker, v_job.queue_id, now(), v_job.target_role,
    v_job.attempts, 'SCHEDULED_TASK', false, p_worker,
    'claim_next_job_v3 atomic lease + run creation'
  );

  return query
  select
    v_job.queue_id, v_run_id, v_job.workflow_id, v_job.task_type,
    v_job.target_role, v_job.action, v_job.acceptance_criteria,
    v_job.evidence_target, v_job.canonical_sources, v_job.attempts,
    v_job.max_attempts, v_job.lease_until;
end;
$$;

create or replace function aras_os.finish_job_v3(
  p_queue_id text,
  p_worker text,
  p_run_id text,
  p_outcome text,
  p_status text,
  p_evidence jsonb default '{}'::jsonb,
  p_error text default null,
  p_next_check timestamptz default null
)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_job aras_os.workflow_jobs%rowtype;
  v_effective_next timestamptz;
  v_updated integer;
begin
  if p_queue_id is null or p_worker is null or p_run_id is null then
    raise exception 'queue_id, worker and run_id required';
  end if;

  if p_status not in (
    'DONE','WAITING','WAITING_REVIEW','APPROVAL_REQUIRED',
    'BLOCKED','DEAD_LETTER','REJECTED','CANCELLED','RELEASE_NEXT'
  ) then
    raise exception 'invalid terminal/release status: %', p_status;
  end if;

  if p_status = 'DONE' and (p_evidence is null or p_evidence = '{}'::jsonb) then
    raise exception 'DONE requires evidence';
  end if;

  select * into v_job
  from aras_os.workflow_jobs
  where queue_id = p_queue_id
  for update;

  if not found then return false; end if;

  if exists (
    select 1 from aras_os.workflow_runs
    where run_id = p_run_id
      and queue_id = p_queue_id
      and slot_id = p_worker
      and finished_at is not null
  ) then
    return v_job.status = p_status;
  end if;

  if v_job.lease_owner is distinct from p_worker
     or v_job.status not in ('LEASED','IN_PROGRESS') then
    return false;
  end if;

  v_effective_next :=
    case
      when p_status = 'WAITING' then coalesce(p_next_check, now() + interval '15 minutes')
      when p_status in ('BLOCKED','APPROVAL_REQUIRED','WAITING_REVIEW') then p_next_check
      else null
    end;

  update aras_os.workflow_runs
  set finished_at = now(),
      outcome = p_outcome,
      evidence = coalesce(p_evidence,'{}'::jsonb),
      error = p_error,
      retry_at = v_effective_next,
      lease_released = true
  where run_id = p_run_id
    and queue_id = p_queue_id
    and slot_id = p_worker
    and finished_at is null;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then return false; end if;

  update aras_os.workflow_jobs
  set status = p_status,
      lease_owner = null,
      lease_until = null,
      next_check = v_effective_next,
      updated_at = now()
  where id = v_job.id;

  return true;
end;
$$;

create or replace function aras_os.record_slot_heartbeat_v1(
  p_slot text,
  p_automation_task_ref text default null,
  p_notes text default null
)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_run_id text;
begin
  if p_slot is null or btrim(p_slot) = '' then
    raise exception 'slot required';
  end if;

  v_run_id :=
    'HB-' || p_slot || '-' ||
    to_char(clock_timestamp() at time zone 'UTC','YYYYMMDDHH24MISSMS') || '-' ||
    substr(extensions.gen_random_uuid()::text,1,8);

  insert into aras_os.workflow_runs(
    run_id, slot_id, queue_id, started_at, finished_at, outcome,
    executor_role, attempt, trigger, reads, writes, evidence,
    lease_released, automation_task_ref, notes
  )
  values(
    v_run_id, p_slot, null, now(), now(), 'HEARTBEAT_OK',
    'ARAS_OS_WORKER', 0, 'SCHEDULED_TASK', '[]'::jsonb, '[]'::jsonb,
    jsonb_build_object('heartbeat',true,'recorded_at',now()),
    true, coalesce(p_automation_task_ref,p_slot), p_notes
  );

  return v_run_id;
end;
$$;

create or replace function aras_os.slot_health_v1()
returns table(
  slot_id text,
  last_seen timestamptz,
  minutes_since_seen numeric,
  health text
)
language sql
stable
set search_path = ''
as $$
with slots(slot_id) as (
  values ('SLOT-1'),('SLOT-2'),('SLOT-3'),('SLOT-4'),('SLOT-5')
),
last_seen as (
  select s.slot_id, max(r.created_at) as last_seen
  from slots s
  left join aras_os.workflow_runs r on r.slot_id = s.slot_id
  group by s.slot_id
)
select
  l.slot_id,
  l.last_seen,
  case when l.last_seen is null then null
       else round(extract(epoch from (now()-l.last_seen))/60.0,1) end,
  case
    when l.last_seen is null then 'NEVER_SEEN'
    when l.last_seen >= now() - interval '80 minutes' then 'HEALTHY'
    when l.last_seen >= now() - interval '130 minutes' then 'LATE'
    else 'STALE'
  end
from last_seen l
order by l.slot_id;
$$;

create or replace function aras_os.recover_stale_jobs_v2()
returns table(
  queue_id text,
  new_status text,
  attempts integer,
  max_attempts integer,
  run_id text
)
language plpgsql
set search_path = ''
as $$
declare
  r record;
  v_new_status text;
  v_next timestamptz;
  v_run_id text;
begin
  for r in
    select j.id, j.queue_id, j.lease_owner, j.attempts, j.max_attempts
    from aras_os.workflow_jobs j
    where j.status in ('LEASED','IN_PROGRESS')
      and j.lease_until is not null
      and j.lease_until < now()
    for update skip locked
  loop
    v_new_status := case when r.attempts >= r.max_attempts then 'DEAD_LETTER' else 'WAITING' end;
    v_next := case when v_new_status = 'WAITING'
                   then now() + make_interval(mins => least(30, greatest(5, r.attempts * 5)))
                   else null end;

    select wr.run_id into v_run_id
    from aras_os.workflow_runs wr
    where wr.queue_id = r.queue_id
      and wr.slot_id = r.lease_owner
      and wr.finished_at is null
    order by wr.started_at desc
    limit 1;

    if v_run_id is not null then
      update aras_os.workflow_runs
      set finished_at = now(),
          outcome = case when v_new_status='DEAD_LETTER'
                         then 'LEASE_EXPIRED_DEAD_LETTER'
                         else 'LEASE_EXPIRED_REQUEUED' end,
          error = 'Lease expired before clean finish; recovered by recover_stale_jobs_v2',
          retry_at = v_next,
          lease_released = true
      where run_id = v_run_id;
    end if;

    update aras_os.workflow_jobs
    set status = v_new_status,
        lease_owner = null,
        lease_until = null,
        next_check = v_next,
        updated_at = now()
    where id = r.id;

    queue_id := r.queue_id;
    new_status := v_new_status;
    attempts := r.attempts;
    max_attempts := r.max_attempts;
    run_id := v_run_id;
    return next;
  end loop;
end;
$$;

do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname='aras-os-stale-lease-recovery';
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;

  perform cron.schedule(
    'aras-os-stale-lease-recovery',
    '*/5 * * * *',
    'select * from aras_os.recover_stale_jobs_v2();'
  );
end;
$$;
