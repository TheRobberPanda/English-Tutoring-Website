-- Students can ask Paulo for more / different lesson times. The request is
-- stored, then a trigger pings Paulo on Telegram through time-request-notify.
-- Also: state for the availability-watch alerts (throttle per alert kind).

create table if not exists public.time_requests (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  timezone text,
  created_at timestamptz not null default now()
);
create index if not exists time_requests_student_idx
  on public.time_requests (student_id, created_at desc);

alter table public.time_requests enable row level security;
-- No client write path: requests only arrive through request_more_times().
create policy time_requests_admin_read on public.time_requests
  for select to authenticated using (public.is_admin());
revoke all on public.time_requests from anon, authenticated;
grant select on public.time_requests to authenticated;

create or replace function public.request_more_times(p_timezone text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_tz text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- One request per student per 24h, so the button cannot be used to spam Paulo.
  if exists (
    select 1 from public.time_requests
    where student_id = v_uid and created_at > now() - interval '24 hours'
  ) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  -- Only store a real IANA zone name; anything else is client-supplied junk.
  select name into v_tz from pg_catalog.pg_timezone_names
  where name = left(coalesce(p_timezone, ''), 64) limit 1;

  insert into public.time_requests (student_id, timezone) values (v_uid, v_tz);
  return jsonb_build_object('ok', true);
end;
$function$;

revoke execute on function public.request_more_times(text) from public, anon;
grant execute on function public.request_more_times(text) to authenticated;

create or replace function public.trg_time_request_notify()
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
    url := 'https://xmpajzrbgnmlttmlwopf.supabase.co/functions/v1/time-request-notify',
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

revoke execute on function public.trg_time_request_notify() from public, anon, authenticated;

drop trigger if exists time_request_notify_trigger on public.time_requests;
create trigger time_request_notify_trigger
  after insert on public.time_requests
  for each row execute function public.trg_time_request_notify();

-- Throttle state for availability-watch (one row per alert kind).
create table if not exists public.admin_alert_state (
  key text primary key,
  last_sent_at timestamptz not null
);
alter table public.admin_alert_state enable row level security;
revoke all on public.admin_alert_state from anon, authenticated;

-- Daily 07:00 UTC (09:00 Warsaw in summer, 08:00 in winter).
select cron.schedule(
  'availability-watch-job',
  '0 7 * * *',
  $job$
  select net.http_post(
    url := 'https://xmpajzrbgnmlttmlwopf.supabase.co/functions/v1/availability-watch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $job$
);
