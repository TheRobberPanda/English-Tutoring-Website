-- Only release (and only tell the student about) a week that was actually
-- held for them.
--
-- Found in a rolled-back test of 20261027_standing_bookings.sql: a standing
-- booking Paulo creates for a student with no credits, whose nearest
-- occurrence is already inside the 24 h window, was "released" on the spot
-- and queued a "your weekly lesson was released" Telegram message — for a
-- week the student never had. A week that was never held is now simply left
-- alone inside that window: no skip, no notice, and if credits arrive before
-- the 12 h cut-off it is still booked on the next run.

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
        -- Out of time and out of credits: give this one week back — but
        -- only if it was held; a week never held has nothing to give back.
        if r.reserved_for = r.student_id then
          update public.schedule_slots set reserved_for = null
           where id = r.slot_id and reserved_for = r.student_id;
          insert into public.standing_booking_skips (standing_booking_id, occurs_on, reason)
          values (r.sb_id, r.day, 'no_credits') on conflict do nothing;
          insert into public.standing_booking_notices (standing_booking_id, student_id, slot_id, start_time, kind)
          values (r.sb_id, r.student_id, r.slot_id, r.start_time, 'released') on conflict do nothing;
          v_released := v_released + 1;
        end if;

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
