-- Lesson reminders: ~20 minutes before each booked lesson.
-- NOT YET APPLIED — awaiting approval before touching production.

-- Claim marker so a 5-minute cron can never send the same reminder twice.
alter table public.schedule_slots
  add column if not exists reminder_sent_at timestamptz;

-- Only unsent, upcoming, booked slots are ever scanned.
create index if not exists schedule_slots_reminder_idx
  on public.schedule_slots (start_time)
  where is_booked = true and reminder_sent_at is null;

-- A cancelled-and-rebooked slot must be eligible for a fresh reminder,
-- otherwise the second student would silently get none.
create or replace function public.reset_reminder_on_unbook()
returns trigger language plpgsql security definer set search_path to '' as $function$
begin
  if new.is_booked = false and old.is_booked = true then
    new.reminder_sent_at := null;
  end if;
  return new;
end;
$function$;

revoke execute on function public.reset_reminder_on_unbook() from public;

drop trigger if exists reset_reminder_on_unbook_trigger on public.schedule_slots;
create trigger reset_reminder_on_unbook_trigger
  before update on public.schedule_slots
  for each row execute function public.reset_reminder_on_unbook();

-- Every 5 minutes. Secret comes from Vault at call time, never inlined.
select cron.schedule(
  'lesson-reminders-job',
  '*/5 * * * *',
  $job$
  select net.http_post(
    url := 'https://xmpajzrbgnmlttmlwopf.supabase.co/functions/v1/lesson-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $job$
);
