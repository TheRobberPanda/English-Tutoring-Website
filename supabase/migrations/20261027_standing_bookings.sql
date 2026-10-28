-- Standing (weekly) bookings: a student keeps the same hour every week.
--
-- A standing booking points at one weekly_template row. An hourly cron walks
-- that hour's real schedule_slots and, per occurrence:
--   28 days ahead   hold it: reserved_for = student, so nobody else can take it
--    7 days ahead   book it and charge its credit_cost, like book_slot would
--   24 hours ahead  still unpaid (no credits) -> release it to everyone and
--                   record a skip, so the hold is not put straight back
-- Nothing within 12 hours is ever booked automatically: that is the
-- cancellation cut-off, and an auto-booked lesson must stay cancellable.
--
-- Exceptions never touch the standing booking itself:
--   standing_booking_skips  one week the student (or Paulo) dropped. Written
--                           by the unbook trigger below when a lesson is
--                           cancelled, so the cron does not rebook it.
-- Template changes cascade: closing the hour in Semana tipo ends the
-- standing booking (its open holds are deleted with the hour's open slots;
-- booked lessons stay, as everywhere else).

create table if not exists public.standing_bookings (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  template_id uuid not null references public.weekly_template(id) on delete cascade,
  created_by_admin boolean not null default false,
  created_at timestamptz not null default now(),
  unique (template_id)                      -- one student per weekly hour
);
create index if not exists standing_bookings_student_idx on public.standing_bookings (student_id);

create table if not exists public.standing_booking_skips (
  standing_booking_id uuid not null references public.standing_bookings(id) on delete cascade,
  occurs_on date not null,                  -- Europe/Warsaw date
  reason text not null check (reason in ('cancelled', 'skipped', 'no_credits')),
  created_at timestamptz not null default now(),
  primary key (standing_booking_id, occurs_on)
);

-- One row per thing worth telling the student about; the unique key is what
-- stops an hourly cron from sending the same Telegram message every hour.
create table if not exists public.standing_booking_notices (
  id bigint generated always as identity primary key,
  standing_booking_id uuid not null references public.standing_bookings(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  slot_id uuid,
  start_time timestamptz not null,
  kind text not null check (kind in ('needs_credit', 'released')),
  created_at timestamptz not null default now(),
  unique (standing_booking_id, start_time, kind)
);

alter table public.standing_bookings enable row level security;
alter table public.standing_booking_skips enable row level security;
alter table public.standing_booking_notices enable row level security;

create policy standing_bookings_read on public.standing_bookings
  for select to authenticated using (student_id = (select auth.uid()) or public.is_admin());
create policy standing_booking_skips_read on public.standing_booking_skips
  for select to authenticated using (
    public.is_admin() or exists (select 1 from public.standing_bookings b
                                 where b.id = standing_booking_id and b.student_id = (select auth.uid())));
create policy standing_booking_notices_admin_read on public.standing_booking_notices
  for select to authenticated using (public.is_admin());

-- Read-only from the client; every write goes through the RPCs below.
revoke all on public.standing_bookings, public.standing_booking_skips, public.standing_booking_notices
  from anon, authenticated;
grant select on public.standing_bookings, public.standing_booking_skips, public.standing_booking_notices
  to authenticated;

-- ---------------------------------------------------------------------------
-- The worker. Not callable by clients: cron runs it, and the RPCs call it.
create or replace function public._process_standing_bookings(p_student uuid default null)
returns jsonb
language plpgsql set search_path = ''
as $function$
declare
  c_cutoff     constant interval := interval '12 hours';  -- = the cancellation rule
  c_release    constant interval := interval '24 hours';
  c_book_ahead constant interval := interval '7 days';
  c_hold_ahead constant interval := interval '28 days';
  r record;
  v_credits numeric;
  v_cost numeric;
  v_booked int := 0;
  v_held int := 0;
  v_released int := 0;
  v_short int := 0;
begin
  for r in
    select s.id as slot_id, s.start_time, s.credit_cost, s.reserved_for,
           b.id as sb_id, b.student_id,
           (s.start_time at time zone 'Europe/Warsaw')::date as day
    from public.standing_bookings b
    join public.schedule_slots s on s.template_id = b.template_id
    where (p_student is null or b.student_id = p_student)
      and s.start_time > now() + c_cutoff
      and s.start_time <= now() + c_hold_ahead
      and not s.is_booked
      and not coalesce(s.is_blocked, false)
      and (s.reserved_for is null or s.reserved_for = b.student_id)
      and not exists (select 1 from public.standing_booking_skips k
                      where k.standing_booking_id = b.id
                        and k.occurs_on = (s.start_time at time zone 'Europe/Warsaw')::date)
    order by s.start_time
    for update of s skip locked
  loop
    v_cost := coalesce(r.credit_cost, 1);

    if r.start_time <= now() + c_book_ahead then
      select credits into v_credits from public.profiles where id = r.student_id for update;

      if coalesce(v_credits, 0) >= v_cost then
        perform set_config('app.trusted_credit_update', 'true', true);
        update public.profiles set credits = credits - v_cost where id = r.student_id;
        update public.schedule_slots
           set is_booked = true, student_id = r.student_id, reserved_for = null
         where id = r.slot_id;
        v_booked := v_booked + 1;

      elsif r.start_time <= now() + c_release then
        -- Out of time and out of credits: give this one week back.
        update public.schedule_slots set reserved_for = null
         where id = r.slot_id and reserved_for = r.student_id;
        insert into public.standing_booking_skips (standing_booking_id, occurs_on, reason)
        values (r.sb_id, r.day, 'no_credits') on conflict do nothing;
        insert into public.standing_booking_notices (standing_booking_id, student_id, slot_id, start_time, kind)
        values (r.sb_id, r.student_id, r.slot_id, r.start_time, 'released') on conflict do nothing;
        v_released := v_released + 1;

      else
        if r.reserved_for is null then
          update public.schedule_slots set reserved_for = r.student_id where id = r.slot_id;
          v_held := v_held + 1;
        end if;
        insert into public.standing_booking_notices (standing_booking_id, student_id, slot_id, start_time, kind)
        values (r.sb_id, r.student_id, r.slot_id, r.start_time, 'needs_credit') on conflict do nothing;
        v_short := v_short + 1;
      end if;

    elsif r.reserved_for is null then
      update public.schedule_slots set reserved_for = r.student_id where id = r.slot_id;
      v_held := v_held + 1;
    end if;
  end loop;

  return jsonb_build_object('booked', v_booked, 'held', v_held, 'released', v_released, 'short', v_short);
end;
$function$;
revoke all on function public._process_standing_bookings(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- A cancelled lesson that came from a standing booking must stay cancelled:
-- remember the week as skipped, and drop any leftover hold so the slot is
-- open to everyone. Covers cancel_booking, admin_cancel_slot and anything
-- else that frees a booking, without any of them having to know about this.
create or replace function public._standing_on_unbook()
returns trigger
language plpgsql security definer set search_path = ''
as $function$
declare
  v_sb uuid;
begin
  select id into v_sb from public.standing_bookings
   where student_id = old.student_id and template_id = old.template_id;
  if v_sb is not null then
    insert into public.standing_booking_skips (standing_booking_id, occurs_on, reason)
    values (v_sb, (old.start_time at time zone 'Europe/Warsaw')::date, 'cancelled')
    on conflict do nothing;
    if new.reserved_for = old.student_id then
      new.reserved_for := null;
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function public._standing_on_unbook() from public, anon, authenticated;

drop trigger if exists standing_on_unbook_trigger on public.schedule_slots;
create trigger standing_on_unbook_trigger
  before update of student_id on public.schedule_slots
  for each row
  when (old.student_id is not null and new.student_id is null and old.template_id is not null)
  execute function public._standing_on_unbook();

-- ---------------------------------------------------------------------------
-- Errors are short codes (not sentences) so cuenta.html can show them in the
-- student's language.
create or replace function public.create_standing_booking(p_template_id uuid, p_student_id uuid default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_admin boolean := public.is_admin();
  v_student uuid;
  v_id uuid;
  v_free int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_student_id is not null and p_student_id <> v_uid and not v_admin then
    raise exception 'not_allowed';
  end if;
  v_student := coalesce(p_student_id, v_uid);

  if not exists (select 1 from public.weekly_template where id = p_template_id) then
    raise exception 'template_not_found';
  end if;
  if exists (select 1 from public.standing_bookings where template_id = p_template_id) then
    raise exception 'slot_taken';
  end if;
  if (select count(*) from public.standing_bookings where student_id = v_student) >= 3 then
    raise exception 'too_many';
  end if;
  -- Paulo may set one up before the first payment; a student needs a credit.
  if not v_admin and coalesce((select credits from public.profiles where id = v_student), 0) < 1 then
    raise exception 'no_credits';
  end if;

  select count(*) into v_free
  from public.schedule_slots s
  where s.template_id = p_template_id
    and s.start_time > now() + interval '12 hours'
    and s.start_time <= now() + interval '28 days'
    and not s.is_booked and not coalesce(s.is_blocked, false)
    and (s.reserved_for is null or s.reserved_for = v_student);
  if v_free = 0 then
    raise exception 'no_free_weeks';
  end if;

  insert into public.standing_bookings (student_id, template_id, created_by_admin)
  values (v_student, p_template_id, v_student <> v_uid)
  returning id into v_id;

  return public._process_standing_bookings(v_student) || jsonb_build_object('id', v_id);
end;
$function$;
revoke all on function public.create_standing_booking(uuid, uuid) from public, anon;
grant execute on function public.create_standing_booking(uuid, uuid) to authenticated;

-- Ends a standing booking. Open holds go back to everyone; lessons already
-- booked stay booked (they are cancelled one by one, under the 12h rule).
create or replace function public.cancel_standing_booking(p_id uuid)
returns int
language plpgsql security definer set search_path = ''
as $function$
declare
  v_sb public.standing_bookings%rowtype;
  v_released int;
begin
  select * into v_sb from public.standing_bookings where id = p_id;
  if not found then
    raise exception 'not_found';
  end if;
  if v_sb.student_id is distinct from auth.uid() and not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  update public.schedule_slots
     set reserved_for = null
   where template_id = v_sb.template_id and reserved_for = v_sb.student_id
     and not is_booked and start_time > now();
  get diagnostics v_released = row_count;

  delete from public.standing_bookings where id = p_id;
  return v_released;
end;
$function$;
revoke all on function public.cancel_standing_booking(uuid) from public, anon;
grant execute on function public.cancel_standing_booking(uuid) to authenticated;

-- Drop one week that is held but not booked yet. A booked week is cancelled
-- with cancel_booking instead, which keeps the 12h rule and the refund.
create or replace function public.skip_standing_occurrence(p_slot_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  v_slot public.schedule_slots%rowtype;
  v_sb public.standing_bookings%rowtype;
begin
  select * into v_slot from public.schedule_slots where id = p_slot_id;
  if not found then
    raise exception 'not_found';
  end if;
  select * into v_sb from public.standing_bookings where template_id = v_slot.template_id;
  if not found or (v_sb.student_id is distinct from auth.uid() and not public.is_admin()) then
    raise exception 'not_allowed';
  end if;
  if v_slot.is_booked then
    raise exception 'already_booked';
  end if;

  insert into public.standing_booking_skips (standing_booking_id, occurs_on, reason)
  values (v_sb.id, (v_slot.start_time at time zone 'Europe/Warsaw')::date, 'skipped')
  on conflict do nothing;
  update public.schedule_slots set reserved_for = null
   where id = p_slot_id and reserved_for = v_sb.student_id;
end;
$function$;
revoke all on function public.skip_standing_occurrence(uuid) from public, anon;
grant execute on function public.skip_standing_occurrence(uuid) to authenticated;

-- Undo a skipped week (any reason), then let the worker hold or book it.
create or replace function public.restore_standing_occurrence(p_id uuid, p_day date)
returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  v_student uuid;
begin
  select student_id into v_student from public.standing_bookings where id = p_id;
  if v_student is null or (v_student is distinct from auth.uid() and not public.is_admin()) then
    raise exception 'not_allowed';
  end if;
  delete from public.standing_booking_skips where standing_booking_id = p_id and occurs_on = p_day;
  return public._process_standing_bookings(v_student);
end;
$function$;
revoke all on function public.restore_standing_occurrence(uuid, date) from public, anon;
grant execute on function public.restore_standing_occurrence(uuid, date) to authenticated;

-- The caller's standing bookings with the next 4 weeks of each. Status:
--   booked   booked for this student (credit already spent)
--   held     reserved for them, booked automatically 7 days before
--   pending  open, not held yet (inside 12h, or the hourly run is pending)
--   skipped  dropped for this week; skip_reason says why
--   taken    someone else has it, or Paulo has a calendar conflict
create or replace function public.my_standing_bookings()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', b.id,
      'template_id', t.id,
      'weekday', t.weekday,
      'start_local', to_char(t.start_local, 'HH24:MI'),
      'duration_min', t.duration_min,
      'created_at', b.created_at,
      'occurrences', (
        select coalesce(jsonb_agg(o.j order by o.st), '[]'::jsonb) from (
          select s.start_time as st, jsonb_build_object(
            'slot_id', s.id,
            'start_time', s.start_time,
            'end_time', s.end_time,
            'day', (s.start_time at time zone 'Europe/Warsaw')::date,
            'credit_cost', s.credit_cost,
            'status', case
              when s.is_booked and s.student_id = b.student_id then 'booked'
              when k.occurs_on is not null then 'skipped'
              when s.is_booked or coalesce(s.is_blocked, false)
                   or (s.reserved_for is not null and s.reserved_for <> b.student_id) then 'taken'
              when s.reserved_for = b.student_id then 'held'
              else 'pending' end,
            'skip_reason', k.reason) as j
          from public.schedule_slots s
          left join public.standing_booking_skips k
            on k.standing_booking_id = b.id
           and k.occurs_on = (s.start_time at time zone 'Europe/Warsaw')::date
          where s.template_id = b.template_id
            and s.end_time > now()
            and s.start_time <= now() + interval '28 days'
        ) o)
    ) order by t.weekday, t.start_local), '[]'::jsonb)
    from public.standing_bookings b
    join public.weekly_template t on t.id = b.template_id
    where b.student_id = auth.uid()
  );
end;
$function$;
revoke all on function public.my_standing_bookings() from public, anon;
grant execute on function public.my_standing_bookings() to authenticated;

-- Weekly hours a student could make their own: in the template, nobody's
-- standing booking yet, and free in at least one of the next 4 weeks.
-- next_start is a real timestamp so the page can show it in the student's
-- own time zone.
create or replace function public.standing_booking_options()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'template_id', t.id,
      'weekday', t.weekday,
      'start_local', to_char(t.start_local, 'HH24:MI'),
      'duration_min', t.duration_min,
      'next_start', f.next_start,
      'free_weeks', f.free,
      'weeks', f.total
    ) order by t.weekday, t.start_local), '[]'::jsonb)
    from public.weekly_template t
    cross join lateral (
      select count(*) filter (where ok) as free,
             count(*) as total,
             min(s.start_time) filter (where ok) as next_start
      from (
        select s.start_time,
               (not s.is_booked and not coalesce(s.is_blocked, false)
                and (s.reserved_for is null or s.reserved_for = v_uid)) as ok
        from public.schedule_slots s
        where s.template_id = t.id
          and s.start_time > now() + interval '12 hours'
          and s.start_time <= now() + interval '28 days'
      ) s
    ) f
    where not exists (select 1 from public.standing_bookings b where b.template_id = t.id)
      and f.free > 0
  );
end;
$function$;
revoke all on function public.standing_booking_options() from public, anon;
grant execute on function public.standing_booking_options() to authenticated;

-- ---------------------------------------------------------------------------
-- Telegram: each new notice goes to standing-booking-notify. Same webhook
-- pattern and Vault secrets as time-request-notify.
create or replace function public.trg_standing_notice_notify()
returns trigger
language plpgsql security definer set search_path = ''
as $function$
declare
  v_apikey text;
  v_secret text;
begin
  select decrypted_secret into v_apikey
  from vault.decrypted_secrets where name = 'service_secret_key';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'webhook_shared_secret';

  perform net.http_post(
    url := 'https://xmpajzrbgnmlttmlwopf.supabase.co/functions/v1/standing-booking-notify',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_apikey,
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object('record', to_jsonb(new))
  );
  return new;
end;
$function$;
revoke execute on function public.trg_standing_notice_notify() from public, anon, authenticated;

drop trigger if exists standing_notice_notify_trigger on public.standing_booking_notices;
create trigger standing_notice_notify_trigger
  after insert on public.standing_booking_notices
  for each row execute function public.trg_standing_notice_notify();

-- Hourly, a few minutes after the hour. Pure SQL, no secret involved.
select cron.schedule('standing-bookings-job', '7 * * * *', $$select public._process_standing_bookings()$$);
