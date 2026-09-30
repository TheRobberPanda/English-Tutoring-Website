-- A failed book_slot call rolls back its own transaction, so the database can
-- never record that it failed. The client sees the error, so it reports it here.

create table if not exists public.booking_failures (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.profiles(id) on delete cascade,
  slot_id     uuid,
  slot_start  timestamptz,
  message     text not null,
  created_at  timestamptz not null default now()
);

create index if not exists booking_failures_created_idx
  on public.booking_failures (created_at desc);

alter table public.booking_failures enable row level security;

-- Only the admin reads; nobody writes directly (inserts go through the RPC).
drop policy if exists booking_failures_admin_select on public.booking_failures;
create policy booking_failures_admin_select on public.booking_failures
  for select to authenticated using (public.is_admin());

drop policy if exists booking_failures_admin_delete on public.booking_failures;
create policy booking_failures_admin_delete on public.booking_failures
  for delete to authenticated using (public.is_admin());

revoke all on public.booking_failures from anon, authenticated;
grant select, delete on public.booking_failures to authenticated;

create or replace function public.log_booking_failure(_slot_id uuid, _message text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  v_start timestamptz;
begin
  if caller_id is null then return; end if;

  -- Cheap flood guard: a student cannot fill the table.
  if (select count(*) from public.booking_failures
      where student_id = caller_id and created_at > now() - interval '1 hour') >= 20 then
    return;
  end if;

  select start_time into v_start from public.schedule_slots where id = _slot_id;

  insert into public.booking_failures (student_id, slot_id, slot_start, message)
  values (caller_id, _slot_id, v_start, left(coalesce(_message, ''), 300));
end;
$function$;

revoke execute on function public.log_booking_failure(uuid, text) from public, anon;
grant execute on function public.log_booking_failure(uuid, text) to authenticated;
