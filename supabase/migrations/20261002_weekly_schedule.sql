-- Recurring weekly schedule.
--
-- weekly_template holds the open hours of a normal week (Europe/Warsaw wall
-- time). _materialize_weekly_schedule() turns it into real schedule_slots
-- HORIZON days ahead; a daily cron keeps that window rolling, so the schedule
-- repeats forever without anyone generating slots by hand.
--
-- Two kinds of exceptions, neither of which touches the template:
--   schedule_skips    one occurrence Paulo deleted. Recorded by
--                     admin_cancel_slot, so the generator never recreates it.
--   schedule_closures a date range (vacation). Open slots inside it are
--                     removed and the generator leaves the range empty.
--                     Deleting the closure brings the slots back.
-- Booked lessons are never removed by template or closure changes; only an
-- explicit admin_cancel_slot (with its refund choice) does that.

create table if not exists public.weekly_template (
  id uuid primary key default gen_random_uuid(),
  weekday smallint not null check (weekday between 1 and 7),   -- ISO: 1 = Monday
  start_local time not null,                                   -- Europe/Warsaw
  duration_min int not null default 50 check (duration_min between 15 and 240),
  created_at timestamptz not null default now(),
  unique (weekday, start_local)
);

create table if not exists public.schedule_skips (
  template_id uuid not null references public.weekly_template(id) on delete cascade,
  occurs_on date not null,                                     -- Europe/Warsaw date
  created_at timestamptz not null default now(),
  primary key (template_id, occurs_on)
);

create table if not exists public.schedule_closures (
  id uuid primary key default gen_random_uuid(),
  starts_on date not null,
  ends_on date not null,
  note text,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

alter table public.schedule_slots
  add column if not exists template_id uuid references public.weekly_template(id) on delete set null;
-- Also makes concurrent generator runs harmless: the second insert conflicts.
create unique index if not exists schedule_slots_template_occ_idx
  on public.schedule_slots (template_id, start_time) where template_id is not null;

alter table public.weekly_template enable row level security;
alter table public.schedule_skips enable row level security;
alter table public.schedule_closures enable row level security;
-- Read-only for the admin; every write goes through the RPCs below.
create policy weekly_template_admin_read on public.weekly_template
  for select to authenticated using (public.is_admin());
create policy schedule_skips_admin_read on public.schedule_skips
  for select to authenticated using (public.is_admin());
create policy schedule_closures_admin_read on public.schedule_closures
  for select to authenticated using (public.is_admin());
revoke all on public.weekly_template, public.schedule_skips, public.schedule_closures from anon, authenticated;
grant select on public.weekly_template, public.schedule_skips, public.schedule_closures to authenticated;

-- ---------------------------------------------------------------------------
-- Generator. Not callable by clients: cron runs it, and the admin RPCs call it.
create or replace function public._materialize_weekly_schedule()
returns int
language plpgsql set search_path = ''
as $function$
declare
  v_today date := (now() at time zone 'Europe/Warsaw')::date;
  v_horizon int := 84;  -- 12 weeks
  v_created int;
begin
  with occ as (
    select t.id as template_id,
           d::date as day,
           (d::date + t.start_local) at time zone 'Europe/Warsaw' as st,
           ((d::date + t.start_local) at time zone 'Europe/Warsaw')
             + make_interval(mins => t.duration_min) as en
    from public.weekly_template t
    join generate_series(v_today::timestamp, (v_today + v_horizon)::timestamp, interval '1 day') d
      on extract(isodow from d) = t.weekday
  )
  insert into public.schedule_slots (start_time, end_time, template_id)
  select o.st, o.en, o.template_id
  from occ o
  where o.st > now()
    and not exists (select 1 from public.schedule_closures c
                    where o.day between c.starts_on and c.ends_on)
    and not exists (select 1 from public.schedule_skips s
                    where s.template_id = o.template_id and s.occurs_on = o.day)
    -- Never stack on anything already there (manual slots, a reserved class).
    and not exists (select 1 from public.schedule_slots x
                    where x.start_time < o.en and x.end_time > o.st)
  on conflict do nothing;

  get diagnostics v_created = row_count;
  return v_created;
end;
$function$;
revoke all on function public._materialize_weekly_schedule() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Replace the whole template with p_cells: [{"weekday":1,"start":"09:00"}, ...]
create or replace function public.admin_save_weekly_template(p_cells jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  v_removed int := 0;
  v_booked_kept int := 0;
  v_created int;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  if jsonb_typeof(p_cells) <> 'array' then
    raise exception 'p_cells debe ser una lista.';
  end if;

  create temp table pg_temp._wanted on commit drop as
    select distinct (c->>'weekday')::smallint as weekday, (c->>'start')::time as start_local
    from jsonb_array_elements(p_cells) c;
  if exists (select 1 from pg_temp._wanted where weekday not between 1 and 7 or start_local is null) then
    raise exception 'Día u hora no válidos.';
  end if;

  -- Hours being closed: drop their future open slots. Booked ones stay (they
  -- lose template_id via ON DELETE SET NULL and become ordinary slots).
  select count(*) into v_booked_kept
  from public.schedule_slots s
  join public.weekly_template t on t.id = s.template_id
  where s.start_time > now() and s.is_booked
    and not exists (select 1 from pg_temp._wanted w where w.weekday = t.weekday and w.start_local = t.start_local);

  delete from public.schedule_slots s
  using public.weekly_template t
  where t.id = s.template_id
    and s.start_time > now() and not s.is_booked
    and not exists (select 1 from pg_temp._wanted w where w.weekday = t.weekday and w.start_local = t.start_local);
  get diagnostics v_removed = row_count;

  delete from public.weekly_template t
  where not exists (select 1 from pg_temp._wanted w where w.weekday = t.weekday and w.start_local = t.start_local);

  insert into public.weekly_template (weekday, start_local)
  select weekday, start_local from pg_temp._wanted
  on conflict (weekday, start_local) do nothing;

  v_created := public._materialize_weekly_schedule();

  return jsonb_build_object('created', v_created, 'removed', v_removed, 'booked_kept', v_booked_kept);
end;
$function$;
revoke all on function public.admin_save_weekly_template(jsonb) from public, anon;
grant execute on function public.admin_save_weekly_template(jsonb) to authenticated;

-- Undo a single deleted occurrence.
create or replace function public.admin_restore_occurrence(p_template_id uuid, p_day date)
returns int
language plpgsql security definer set search_path = ''
as $function$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  delete from public.schedule_skips where template_id = p_template_id and occurs_on = p_day;
  return public._materialize_weekly_schedule();
end;
$function$;
revoke all on function public.admin_restore_occurrence(uuid, date) from public, anon;
grant execute on function public.admin_restore_occurrence(uuid, date) to authenticated;

-- Vacation / day off. Removes every open slot in the range (manual ones too —
-- Paulo is away) and returns the booked lessons that still fall inside it, so
-- he can decide on each one with the refund choice in the calendar.
create or replace function public.admin_add_closure(p_from date, p_to date, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  v_removed int;
  v_booked jsonb;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'Fechas no válidas.';
  end if;

  insert into public.schedule_closures (starts_on, ends_on, note)
  values (p_from, p_to, nullif(trim(p_note), ''));

  delete from public.schedule_slots
  where not is_booked and start_time > now()
    and (start_time at time zone 'Europe/Warsaw')::date between p_from and p_to;
  get diagnostics v_removed = row_count;

  select coalesce(jsonb_agg(jsonb_build_object(
           'start_time', s.start_time,
           'student', coalesce(p.full_name, p.email, 'Alumno/a')) order by s.start_time), '[]'::jsonb)
    into v_booked
  from public.schedule_slots s
  left join public.profiles p on p.id = s.student_id
  where s.is_booked and s.start_time > now()
    and (s.start_time at time zone 'Europe/Warsaw')::date between p_from and p_to;

  return jsonb_build_object('removed', v_removed, 'booked', v_booked);
end;
$function$;
revoke all on function public.admin_add_closure(date, date, text) from public, anon;
grant execute on function public.admin_add_closure(date, date, text) to authenticated;

create or replace function public.admin_delete_closure(p_id uuid)
returns int
language plpgsql security definer set search_path = ''
as $function$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  delete from public.schedule_closures where id = p_id;
  return public._materialize_weekly_schedule();
end;
$function$;
revoke all on function public.admin_delete_closure(uuid) from public, anon;
grant execute on function public.admin_delete_closure(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Deleting a generated occurrence must stick: remember it as a skip.
create or replace function public.admin_cancel_slot(_slot_id uuid, _refund boolean default true)
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  v_student_id uuid;
  v_is_booked boolean;
  v_cost numeric;
  v_template_id uuid;
  v_start timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;

  select student_id, is_booked, credit_cost, template_id, start_time
    into v_student_id, v_is_booked, v_cost, v_template_id, v_start
  from public.schedule_slots where id = _slot_id;

  if v_is_booked then
    if _refund and v_student_id is not null then
      perform set_config('app.trusted_credit_update', 'true', true);
      update public.profiles
      set credits = credits + coalesce(v_cost, 1)
      where id = v_student_id;
    end if;

    update public.schedule_slots
    set is_booked = false, student_id = null
    where id = _slot_id;
  end if;

  if v_template_id is not null then
    insert into public.schedule_skips (template_id, occurs_on)
    values (v_template_id, (v_start at time zone 'Europe/Warsaw')::date)
    on conflict do nothing;
  end if;

  delete from public.schedule_slots where id = _slot_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Seed the template from the hours already published, so switching over
-- changes nothing a student can see. A weekday+time counts as part of the
-- normal week if it is published on at least 4 future dates as a plain
-- 50-minute, 1-credit, unreserved slot.
insert into public.weekly_template (weekday, start_local)
select extract(isodow from l)::smallint, l::time
from (
  select start_time at time zone 'Europe/Warsaw' as l
  from public.schedule_slots
  where start_time > now() and reserved_for is null and credit_cost = 1
    and end_time - start_time = interval '50 minutes'
) x
group by 1, 2
having count(distinct l::date) >= 4
on conflict do nothing;

update public.schedule_slots s
set template_id = t.id
from public.weekly_template t
where s.start_time > now() and s.template_id is null
  and s.reserved_for is null and s.credit_cost = 1
  and s.end_time - s.start_time = make_interval(mins => t.duration_min)
  and extract(isodow from s.start_time at time zone 'Europe/Warsaw') = t.weekday
  and (s.start_time at time zone 'Europe/Warsaw')::time = t.start_local;

-- Occurrences already missing inside the published range were deleted on
-- purpose; record them as skips so the generator does not bring them back.
insert into public.schedule_skips (template_id, occurs_on)
select t.id, d::date
from public.weekly_template t
cross join generate_series(
  (now() at time zone 'Europe/Warsaw')::date::timestamp,
  (select max(start_time at time zone 'Europe/Warsaw')::date::timestamp from public.schedule_slots where template_id is not null),
  interval '1 day') d
where extract(isodow from d) = t.weekday
  and ((d::date + t.start_local) at time zone 'Europe/Warsaw') > now()
  and not exists (select 1 from public.schedule_slots s
                  where s.template_id = t.id
                    and (s.start_time at time zone 'Europe/Warsaw')::date = d::date)
on conflict do nothing;

-- Keep the window rolling. Pure SQL, no secret involved.
select cron.schedule('weekly-schedule-job', '30 3 * * *', $$select public._materialize_weekly_schedule()$$);
