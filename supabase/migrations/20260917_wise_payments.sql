-- Automatic credits from Wise payments.
--
-- Paulo's Wise account is personal, and Wise gives EU personal accounts no API
-- access (PSD2), so there is no webhook. The wise-payments Edge Function reads
-- Wise's "you received money" emails from Gmail instead and calls
-- apply_wise_payment() for each one.

-- Per-student price, in EUR per credit.
alter table public.profiles
  add column if not exists price_per_credit numeric not null default 15
  check (price_per_credit > 0);

-- The price must not be student-editable. authenticated only holds
-- UPDATE (full_name) already; the trigger is the second lock.
create or replace function public.protect_sensitive_profile_fields()
returns trigger language plpgsql security definer set search_path to '' as $function$
begin
  if new.credits is distinct from old.credits
     and not public.is_admin()
     and coalesce(current_setting('app.trusted_credit_update', true), '') <> 'true' then
    raise exception 'No tienes permiso para modificar créditos.';
  end if;

  if new.is_admin is distinct from old.is_admin and not public.is_admin() then
    raise exception 'No tienes permiso para modificar este campo.';
  end if;

  if new.price_per_credit is distinct from old.price_per_credit
     and auth.role() <> 'service_role'
     and not public.is_admin() then
    raise exception 'No tienes permiso para modificar el precio.';
  end if;

  if (new.telegram_chat_id is distinct from old.telegram_chat_id
      or new.telegram_first_name is distinct from old.telegram_first_name
      or new.telegram_username is distinct from old.telegram_username)
     and auth.role() <> 'service_role'
     and not public.is_admin()
     and coalesce(current_setting('app.trusted_telegram_update', true), '') <> 'true' then
    raise exception 'No tienes permiso para modificar este campo directamente.';
  end if;

  -- Referral integrity: a student must not be able to point referred_by at
  -- themselves, rewind referral_reward_given to farm the bonus, or rewrite
  -- their referral_code.
  if (new.referral_code is distinct from old.referral_code
      or new.referred_by is distinct from old.referred_by
      or new.referral_reward_given is distinct from old.referral_reward_given)
     and auth.role() <> 'service_role'
     and not public.is_admin() then
    raise exception 'No tienes permiso para modificar los datos de referidos.';
  end if;

  -- GDPR / 14-day withdrawal-waiver evidence is recorded at signup and is not
  -- user-editable afterwards.
  if (new.terms_accepted_at is distinct from old.terms_accepted_at
      or new.withdrawal_right_waived is distinct from old.withdrawal_right_waived)
     and auth.role() <> 'service_role'
     and not public.is_admin() then
    raise exception 'No tienes permiso para modificar el registro de consentimiento.';
  end if;

  return new;
end;
$function$;

-- One row per Wise email. gmail_message_id is the idempotency key: a cron that
-- sees the same email twice can never credit it twice.
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  gmail_message_id text not null unique,
  received_at timestamptz not null,
  amount_eur numeric not null check (amount_eur > 0),
  sender_name text,
  reference text,
  student_id uuid references public.profiles(id) on delete set null,
  price_per_credit numeric,
  credits_granted numeric,
  status text not null check (status in ('credited', 'unmatched', 'reverted')),
  created_at timestamptz not null default now()
);

create index if not exists payments_student_idx on public.payments (student_id, received_at desc);

alter table public.payments enable row level security;

drop policy if exists payments_admin_read on public.payments;
create policy payments_admin_read on public.payments
  for select to authenticated using (public.is_admin());

drop policy if exists payments_own_read on public.payments;
create policy payments_own_read on public.payments
  for select to authenticated using (student_id = auth.uid());

revoke all on public.payments from anon, authenticated;
grant select on public.payments to authenticated;

-- The credit + referral logic, without the admin gate, so both the admin
-- panel and the payment importer share one implementation. Never callable by
-- clients directly.
create or replace function public._grant_credits_internal(_student_id uuid, _new_credits numeric)
returns void language plpgsql security definer set search_path to '' as $function$
declare
  v_old_credits numeric;
  v_referred_by uuid;
  v_reward_given boolean;
  -- Referral payout, in lessons.
  v_reward numeric := 3;
begin
  if _new_credits < 0 then
    raise exception 'Los créditos no pueden ser negativos.';
  end if;

  select credits, referred_by, referral_reward_given
    into v_old_credits, v_referred_by, v_reward_given
  from public.profiles where id = _student_id;

  perform set_config('app.trusted_credit_update', 'true', true);
  update public.profiles set credits = _new_credits where id = _student_id;

  if _new_credits > coalesce(v_old_credits, 0)
     and v_referred_by is not null
     and v_referred_by <> _student_id
     and not coalesce(v_reward_given, false) then
    perform set_config('app.trusted_credit_update', 'true', true);
    update public.profiles set credits = credits + v_reward where id = v_referred_by;

    update public.profiles set referral_reward_given = true where id = _student_id;

    insert into public.referral_rewards (referrer_id, referred_id, credits_awarded)
    values (v_referred_by, _student_id, v_reward);
  end if;
end;
$function$;

revoke all on function public._grant_credits_internal(uuid, numeric) from public, anon, authenticated;

create or replace function public.admin_grant_credits(_student_id uuid, _new_credits numeric)
returns void language plpgsql security definer set search_path to '' as $function$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  perform public._grant_credits_internal(_student_id, _new_credits);
end;
$function$;

-- Credits bought by an amount at a price. Partial credits are kept, rounded
-- down to the cent of a credit so a student is never over-credited.
create or replace function public._credits_for(_amount numeric, _price numeric)
returns numeric language sql immutable set search_path to '' as $function$
  select trunc(_amount / _price, 2);
$function$;

-- Called by the wise-payments Edge Function (service_role only).
-- Returns the payments row so the function can notify.
create or replace function public.apply_wise_payment(
  _gmail_message_id text,
  _received_at timestamptz,
  _amount_eur numeric,
  _sender_name text,
  _reference text,
  _student_id uuid
)
returns public.payments language plpgsql security definer set search_path to '' as $function$
declare
  v_row public.payments;
  v_price numeric;
  v_credits numeric;
  v_current numeric;
begin
  if _student_id is not null then
    select price_per_credit, credits into v_price, v_current
    from public.profiles where id = _student_id for update;
  end if;

  if v_price is null then
    insert into public.payments (gmail_message_id, received_at, amount_eur, sender_name, reference, status)
    values (_gmail_message_id, _received_at, _amount_eur, _sender_name, _reference, 'unmatched')
    on conflict (gmail_message_id) do nothing
    returning * into v_row;
    return v_row;
  end if;

  v_credits := public._credits_for(_amount_eur, v_price);

  insert into public.payments (gmail_message_id, received_at, amount_eur, sender_name, reference,
                               student_id, price_per_credit, credits_granted, status)
  values (_gmail_message_id, _received_at, _amount_eur, _sender_name, _reference,
          _student_id, v_price, v_credits, 'credited')
  on conflict (gmail_message_id) do nothing
  returning * into v_row;

  -- Already imported: v_row is null, nothing to grant.
  if v_row.id is not null then
    perform public._grant_credits_internal(_student_id, coalesce(v_current, 0) + v_credits);
  end if;
  return v_row;
end;
$function$;

revoke all on function public.apply_wise_payment(text, timestamptz, numeric, text, text, uuid) from public, anon, authenticated;
grant execute on function public.apply_wise_payment(text, timestamptz, numeric, text, text, uuid) to service_role;

-- Admin: attach an unmatched payment to a student (credits at their price).
create or replace function public.admin_assign_payment(_payment_id uuid, _student_id uuid)
returns void language plpgsql security definer set search_path to '' as $function$
declare
  v_amount numeric;
  v_price numeric;
  v_current numeric;
  v_credits numeric;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;

  select amount_eur into v_amount from public.payments
  where id = _payment_id and status = 'unmatched' for update;
  if v_amount is null then
    raise exception 'Ese pago no está pendiente de asignar.';
  end if;

  select price_per_credit, credits into v_price, v_current
  from public.profiles where id = _student_id for update;
  if v_price is null then
    raise exception 'Alumno no encontrado.';
  end if;

  v_credits := public._credits_for(v_amount, v_price);
  update public.payments
     set student_id = _student_id, price_per_credit = v_price,
         credits_granted = v_credits, status = 'credited'
   where id = _payment_id;
  perform public._grant_credits_internal(_student_id, coalesce(v_current, 0) + v_credits);
end;
$function$;

-- Admin: undo an automatic credit (wrong student, refund…). Takes the credits
-- back, floored at zero; a referral reward already paid is not clawed back.
create or replace function public.admin_revert_payment(_payment_id uuid)
returns void language plpgsql security definer set search_path to '' as $function$
declare
  v_student uuid;
  v_credits numeric;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;

  select student_id, credits_granted into v_student, v_credits
  from public.payments where id = _payment_id and status = 'credited' for update;
  if v_student is null then
    raise exception 'Ese pago no se puede deshacer.';
  end if;

  update public.payments set status = 'reverted' where id = _payment_id;
  perform set_config('app.trusted_credit_update', 'true', true);
  update public.profiles set credits = greatest(credits - v_credits, 0) where id = v_student;
end;
$function$;

-- Admin: set a student's price.
create or replace function public.admin_set_price(_student_id uuid, _price numeric)
returns void language plpgsql security definer set search_path to '' as $function$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  if _price is null or _price <= 0 then
    raise exception 'El precio debe ser mayor que cero.';
  end if;
  update public.profiles set price_per_credit = _price where id = _student_id;
end;
$function$;

revoke all on function public.admin_assign_payment(uuid, uuid) from public, anon;
revoke all on function public.admin_revert_payment(uuid) from public, anon;
revoke all on function public.admin_set_price(uuid, numeric) from public, anon;
revoke all on function public._credits_for(numeric, numeric) from public, anon, authenticated;
grant execute on function public.admin_assign_payment(uuid, uuid) to authenticated;
grant execute on function public.admin_revert_payment(uuid) to authenticated;
grant execute on function public.admin_set_price(uuid, numeric) to authenticated;

-- Every 10 minutes. Secret comes from Vault at call time, never inlined.
select cron.schedule(
  'wise-payments-job',
  '*/10 * * * *',
  $job$
  select net.http_post(
    url := 'https://xmpajzrbgnmlttmlwopf.supabase.co/functions/v1/wise-payments',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $job$
);
