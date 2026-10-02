-- Welcome offer: a student's first three credits for 30€ (10€ each instead of
-- 15€, so 15€ off), paid through a Wise payment-request link.
--
-- Wise payment requests are SINGLE_USE and expire (about a month), so the
-- link is data, not code: Paulo pastes a fresh one into admin whenever the
-- current one is paid or runs out, and the offer-link-watch function tells
-- him on Telegram when that is needed.
--
-- Crediting still goes through the wise-payments importer. A payment for the
-- offer's amount from a student who has not used the offer yet (or one whose
-- email carries the request's Wise reference) is credited at the offer's
-- credits instead of amount / price.

create table if not exists public.offer_links (
  id uuid primary key default gen_random_uuid(),
  url text not null unique check (url ~ '^https://wise\.com/pay/r/[A-Za-z0-9_-]+$'),
  amount_eur numeric not null default 30 check (amount_eur > 0),
  credits numeric not null default 3 check (credits > 0),
  -- Read from the Wise page by offer-link-watch.
  wise_reference text,
  expires_at timestamptz,
  -- active: shown to eligible students.
  -- used: a payment through it was imported.
  -- closed: Wise no longer shows it (paid but not imported yet, or expired).
  -- replaced: Paulo pasted a newer link.
  status text not null default 'active' check (status in ('active', 'used', 'closed', 'replaced')),
  used_by_payment uuid references public.payments(id) on delete set null,
  expiry_warned_at timestamptz,
  checked_at timestamptz,
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

-- At most one live link at a time.
create unique index if not exists offer_links_one_active on public.offer_links ((true)) where status = 'active';

alter table public.offer_links enable row level security;

drop policy if exists offer_links_admin_read on public.offer_links;
create policy offer_links_admin_read on public.offer_links
  for select to authenticated using (public.is_admin());

revoke all on public.offer_links from anon, authenticated;
grant select on public.offer_links to authenticated;

alter table public.payments
  add column if not exists offer_link_id uuid references public.offer_links(id) on delete set null;

alter table public.profiles
  add column if not exists intro_offer_used boolean not null default false;

-- intro_offer_used joins the fields a student cannot write themselves.
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

  if (new.price_per_credit is distinct from old.price_per_credit
      or new.intro_offer_used is distinct from old.intro_offer_used)
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

  if (new.referral_code is distinct from old.referral_code
      or new.referred_by is distinct from old.referred_by
      or new.referral_reward_given is distinct from old.referral_reward_given)
     and auth.role() <> 'service_role'
     and not public.is_admin() then
    raise exception 'No tienes permiso para modificar los datos de referidos.';
  end if;

  if (new.terms_accepted_at is distinct from old.terms_accepted_at
      or new.withdrawal_right_waived is distinct from old.withdrawal_right_waived)
     and auth.role() <> 'service_role'
     and not public.is_admin() then
    raise exception 'No tienes permiso para modificar el registro de consentimiento.';
  end if;

  return new;
end;
$function$;

-- What the student's credits card shows. eligible is true until the offer
-- has been used; url is null when there is no live link right now (the card
-- then asks the student to message Paulo for one).
create or replace function public.my_intro_offer()
returns table (eligible boolean, url text, amount_eur numeric, credits numeric)
language sql stable security definer set search_path to '' as $function$
  select not p.intro_offer_used,
         case when not p.intro_offer_used then l.url end,
         coalesce(l.amount_eur, 30),
         coalesce(l.credits, 3)
  from public.profiles p
  left join public.offer_links l
    on l.status = 'active' and (l.expires_at is null or l.expires_at > now())
  where p.id = auth.uid() and not p.is_admin;
$function$;

revoke all on function public.my_intro_offer() from public, anon;
grant execute on function public.my_intro_offer() to authenticated;

-- The link a payment received at _received_at for _amount could have gone
-- through: not yet consumed, already pasted, not expired at that moment.
create or replace function public._offer_link_for(_amount numeric, _received_at timestamptz)
returns public.offer_links language sql stable set search_path to '' as $function$
  select * from public.offer_links
  where status in ('active', 'closed')
    and amount_eur = _amount
    and created_at <= _received_at + interval '1 hour'
    and (expires_at is null or expires_at >= _received_at - interval '1 hour')
  order by (status = 'active') desc, created_at desc
  limit 1;
$function$;

revoke all on function public._offer_link_for(numeric, timestamptz) from public, anon, authenticated;

-- Signature changes (new _offer_ref_seen argument), so drop the old one.
drop function if exists public.apply_wise_payment(text, timestamptz, numeric, text, text, uuid);

-- Called by the wise-payments Edge Function (service_role only).
-- _offer_ref_seen: the email contains the live link's Wise reference, i.e. the
-- money certainly came through the offer link.
create or replace function public.apply_wise_payment(
  _gmail_message_id text,
  _received_at timestamptz,
  _amount_eur numeric,
  _sender_name text,
  _reference text,
  _student_id uuid,
  _offer_ref_seen boolean default false
)
returns public.payments language plpgsql security definer set search_path to '' as $function$
declare
  v_row public.payments;
  v_price numeric;
  v_credits numeric;
  v_current numeric;
  v_offer_used boolean;
  v_link public.offer_links;
  v_is_offer boolean := false;
begin
  if _student_id is not null then
    select price_per_credit, credits, intro_offer_used into v_price, v_current, v_offer_used
    from public.profiles where id = _student_id for update;
  end if;

  v_link := public._offer_link_for(_amount_eur, _received_at);
  if v_link.id is not null then
    -- Certain when the reference matches; otherwise the right amount from a
    -- student who has not had the offer yet is taken as the offer.
    v_is_offer := _offer_ref_seen or (v_price is not null and not coalesce(v_offer_used, false));
  end if;

  if v_price is null then
    insert into public.payments (gmail_message_id, received_at, amount_eur, sender_name, reference,
                                 offer_link_id, status)
    values (_gmail_message_id, _received_at, _amount_eur, _sender_name, _reference,
            case when v_is_offer then v_link.id end, 'unmatched')
    on conflict (gmail_message_id) do nothing
    returning * into v_row;
  else
    if v_is_offer then
      v_credits := v_link.credits;
      v_price := round(_amount_eur / v_link.credits, 2);
    else
      v_credits := public._credits_for(_amount_eur, v_price);
    end if;

    insert into public.payments (gmail_message_id, received_at, amount_eur, sender_name, reference,
                                 student_id, price_per_credit, credits_granted, offer_link_id, status)
    values (_gmail_message_id, _received_at, _amount_eur, _sender_name, _reference,
            _student_id, v_price, v_credits, case when v_is_offer then v_link.id end, 'credited')
    on conflict (gmail_message_id) do nothing
    returning * into v_row;

    if v_row.id is not null then
      perform public._grant_credits_internal(_student_id, coalesce(v_current, 0) + v_credits);
      if v_is_offer then
        update public.profiles set intro_offer_used = true where id = _student_id;
      end if;
    end if;
  end if;

  -- The link is single-use: whoever paid, it is spent.
  if v_row.id is not null and v_row.offer_link_id is not null then
    update public.offer_links
       set status = 'used', used_by_payment = v_row.id, closed_at = coalesce(closed_at, now())
     where id = v_row.offer_link_id;
  end if;
  return v_row;
end;
$function$;

revoke all on function public.apply_wise_payment(text, timestamptz, numeric, text, text, uuid, boolean) from public, anon, authenticated;
grant execute on function public.apply_wise_payment(text, timestamptz, numeric, text, text, uuid, boolean) to service_role;

-- Admin: attach an unmatched payment to a student. An offer payment gives the
-- offer's credits; anything else is credited at the student's price.
create or replace function public.admin_assign_payment(_payment_id uuid, _student_id uuid)
returns void language plpgsql security definer set search_path to '' as $function$
declare
  v_amount numeric;
  v_received timestamptz;
  v_link uuid;
  v_price numeric;
  v_current numeric;
  v_offer_used boolean;
  v_credits numeric;
  v_offer_credits numeric;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;

  select amount_eur, received_at, offer_link_id into v_amount, v_received, v_link from public.payments
  where id = _payment_id and status = 'unmatched' for update;
  if v_amount is null then
    raise exception 'Ese pago no está pendiente de asignar.';
  end if;

  select price_per_credit, credits, intro_offer_used into v_price, v_current, v_offer_used
  from public.profiles where id = _student_id for update;
  if v_price is null then
    raise exception 'Alumno no encontrado.';
  end if;

  -- Same rule as the importer: the offer's amount from a student who has not
  -- had the offer yet is the offer.
  if v_link is null and not v_offer_used then
    v_link := (public._offer_link_for(v_amount, v_received)).id;
  end if;

  if v_link is not null then
    select credits into v_offer_credits from public.offer_links where id = v_link;
  end if;

  if v_offer_credits is not null then
    v_credits := v_offer_credits;
    v_price := round(v_amount / v_offer_credits, 2);
  else
    v_credits := public._credits_for(v_amount, v_price);
  end if;

  update public.payments
     set student_id = _student_id, price_per_credit = v_price,
         credits_granted = v_credits, status = 'credited'
   where id = _payment_id;
  perform public._grant_credits_internal(_student_id, coalesce(v_current, 0) + v_credits);
  if v_offer_credits is not null then
    update public.profiles set intro_offer_used = true where id = _student_id;
    update public.payments set offer_link_id = v_link where id = _payment_id;
    update public.offer_links
       set status = 'used', used_by_payment = _payment_id, closed_at = coalesce(closed_at, now())
     where id = v_link and status <> 'replaced';
  end if;
end;
$function$;

-- Admin: undo a credit. Undoing an offer payment makes the student eligible
-- for the offer again.
create or replace function public.admin_revert_payment(_payment_id uuid)
returns void language plpgsql security definer set search_path to '' as $function$
declare
  v_student uuid;
  v_credits numeric;
  v_link uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;

  select student_id, credits_granted, offer_link_id into v_student, v_credits, v_link
  from public.payments where id = _payment_id and status = 'credited' for update;
  if v_student is null then
    raise exception 'Ese pago no se puede deshacer.';
  end if;

  update public.payments set status = 'reverted' where id = _payment_id;
  perform set_config('app.trusted_credit_update', 'true', true);
  update public.profiles set credits = greatest(credits - v_credits, 0) where id = v_student;
  if v_link is not null then
    update public.profiles set intro_offer_used = false where id = v_student;
  end if;
end;
$function$;

-- Admin: paste a new Wise payment-request link. Any live link is retired.
create or replace function public.admin_set_offer_link(_url text, _credits numeric default 3)
returns public.offer_links language plpgsql security definer set search_path to '' as $function$
declare
  v_row public.offer_links;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  _url := btrim(_url);
  if _url !~ '^https://wise\.com/pay/r/[A-Za-z0-9_-]+$' then
    raise exception 'Pega un enlace de solicitud de pago de Wise (https://wise.com/pay/r/…).';
  end if;

  update public.offer_links set status = 'replaced', closed_at = now() where status = 'active';
  insert into public.offer_links (url, credits) values (_url, coalesce(_credits, 3))
  on conflict (url) do update set status = 'active', closed_at = null, credits = excluded.credits
  returning * into v_row;
  return v_row;
end;
$function$;

-- Admin: mark a student as having had (or not had) the welcome offer, e.g.
-- for clients who already paid before the offer existed.
create or replace function public.admin_set_intro_offer_used(_student_id uuid, _used boolean)
returns void language plpgsql security definer set search_path to '' as $function$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede hacer esto.';
  end if;
  update public.profiles set intro_offer_used = coalesce(_used, true) where id = _student_id;
end;
$function$;

revoke all on function public.admin_assign_payment(uuid, uuid) from public, anon;
revoke all on function public.admin_revert_payment(uuid) from public, anon;
revoke all on function public.admin_set_offer_link(text, numeric) from public, anon;
revoke all on function public.admin_set_intro_offer_used(uuid, boolean) from public, anon;
grant execute on function public.admin_assign_payment(uuid, uuid) to authenticated;
grant execute on function public.admin_revert_payment(uuid) to authenticated;
grant execute on function public.admin_set_offer_link(text, numeric) to authenticated;
grant execute on function public.admin_set_intro_offer_used(uuid, boolean) to authenticated;

-- The first link. Reference and expiry as Wise shows them; offer-link-watch
-- keeps them current.
insert into public.offer_links (url, amount_eur, credits, wise_reference, expires_at)
values ('https://wise.com/pay/r/g3gIUnvCetRFNbw', 30, 3, '811717', '2026-11-01T11:22:14Z')
on conflict (url) do nothing;

-- Hourly. Secret comes from Vault at call time, never inlined.
select cron.schedule(
  'offer-link-watch-job',
  '7 * * * *',
  $job$
  select net.http_post(
    url := 'https://xmpajzrbgnmlttmlwopf.supabase.co/functions/v1/offer-link-watch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $job$
);
