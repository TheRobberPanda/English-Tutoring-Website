-- Credit ledger: every change to profiles.credits, and every booking/unbooking,
-- is recorded so "how many credits should this student have?" can be answered
-- from the database. Written by triggers, so no RPC has to remember to log.

create table public.credit_ledger (
  id bigint generated always as identity primary key,
  student_id uuid not null references public.profiles(id) on delete cascade,
  delta numeric not null,
  balance_after numeric not null,
  source text,            -- top-level statement that caused it, e.g. "book_slot"
  actor uuid,             -- auth.uid() at the time (null for cron/service)
  created_at timestamptz not null default now()
);
create index credit_ledger_student_idx on public.credit_ledger (student_id, created_at desc);

create table public.booking_log (
  id bigint generated always as identity primary key,
  slot_id uuid not null,
  student_id uuid not null,
  action text not null check (action in ('booked', 'unbooked')),
  start_time timestamptz not null,
  credit_cost numeric,
  actor uuid,
  created_at timestamptz not null default now()
);
create index booking_log_student_idx on public.booking_log (student_id, created_at desc);

alter table public.credit_ledger enable row level security;
alter table public.booking_log enable row level security;

create policy credit_ledger_read on public.credit_ledger for select to authenticated
  using (student_id = (select auth.uid()) or public.is_admin());
create policy booking_log_read on public.booking_log for select to authenticated
  using (student_id = (select auth.uid()) or public.is_admin());

revoke all on public.credit_ledger, public.booking_log from anon, authenticated;
grant select on public.credit_ledger, public.booking_log to authenticated;

create or replace function public._log_credit_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_src text;
begin
  if new.credits is distinct from old.credits then
    -- PostgREST RPCs arrive as "... public.<fn>(..."; keep just the name.
    select coalesce(substring(a.query from 'public\.\"?([a-z_]+)\"?\s*\('), left(a.query, 120))
      into v_src from pg_catalog.pg_stat_activity a where a.pid = pg_catalog.pg_backend_pid();
    insert into public.credit_ledger (student_id, delta, balance_after, source, actor)
    values (new.id, new.credits - old.credits, new.credits, v_src, auth.uid());
  end if;
  return new;
end $$;

create trigger trg_log_credit_change after update of credits on public.profiles
  for each row execute function public._log_credit_change();

-- Insert-time credits (signup gift) count as an entry too.
create or replace function public._log_credit_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.credits, 0) <> 0 then
    insert into public.credit_ledger (student_id, delta, balance_after, source, actor)
    values (new.id, new.credits, new.credits, 'signup', null);
  end if;
  return new;
end $$;

create trigger trg_log_credit_insert after insert on public.profiles
  for each row execute function public._log_credit_insert();

create or replace function public._log_booking_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    if old.student_id is not null then
      insert into public.booking_log (slot_id, student_id, action, start_time, credit_cost, actor)
      values (old.id, old.student_id, 'unbooked', old.start_time, old.credit_cost, auth.uid());
    end if;
    return old;
  end if;
  if old.student_id is not null and old.student_id is distinct from new.student_id then
    insert into public.booking_log (slot_id, student_id, action, start_time, credit_cost, actor)
    values (old.id, old.student_id, 'unbooked', old.start_time, old.credit_cost, auth.uid());
  end if;
  if new.student_id is not null and old.student_id is distinct from new.student_id then
    insert into public.booking_log (slot_id, student_id, action, start_time, credit_cost, actor)
    values (new.id, new.student_id, 'booked', new.start_time, new.credit_cost, auth.uid());
  end if;
  return new;
end $$;

create trigger trg_log_booking_change after update of student_id or delete on public.schedule_slots
  for each row execute function public._log_booking_change();

revoke all on function public._log_credit_change(), public._log_credit_insert(), public._log_booking_change()
  from public, anon, authenticated;
