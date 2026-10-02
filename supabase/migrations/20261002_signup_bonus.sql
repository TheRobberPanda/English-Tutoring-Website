-- New accounts start with 0.5 credits as a welcome gift, advertised on the
-- homepage. Set at insert time rather than through _grant_credits_internal on
-- purpose: that path treats any increase as a "first top-up" and would pay the
-- referrer their +3 reward for a signup that never paid anything. Here the
-- referral reward still waits for the first real top-up, because it compares
-- new credits against the 0.5 already on the row.
-- 0.5 alone cannot book a 1-credit lesson, so a farmed account gets nothing
-- usable on its own; credits do not move between accounts.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  new_code text;
  attempts int := 0;
  v_referrer_id uuid;
  v_input_code text;
  v_terms_accepted boolean;
  v_signup_bonus numeric := 0.5;
begin
  loop
    new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.profiles where referral_code = new_code);
    attempts := attempts + 1;
    if attempts >= 10 then
      raise exception 'No se pudo generar un código de referido único.';
    end if;
  end loop;

  v_input_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'referral_code', '')));
  if v_input_code <> '' then
    select id into v_referrer_id from public.profiles where referral_code = v_input_code;
  end if;

  v_terms_accepted := coalesce((new.raw_user_meta_data ->> 'terms_accepted')::boolean, false);

  insert into public.profiles (
    id, full_name, credits, email, learn_english, learn_spanish, language,
    referral_code, referred_by, terms_accepted_at, withdrawal_right_waived
  )
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    v_signup_bonus,
    new.email,
    coalesce((new.raw_user_meta_data ->> 'learn_english')::boolean, false),
    coalesce((new.raw_user_meta_data ->> 'learn_spanish')::boolean, false),
    case when new.raw_user_meta_data ->> 'language' in ('es', 'pl', 'en')
         then new.raw_user_meta_data ->> 'language' else 'es' end,
    new_code,
    v_referrer_id,
    case when v_terms_accepted then now() else null end,
    v_terms_accepted and coalesce((new.raw_user_meta_data ->> 'waive_withdrawal')::boolean, false)
  );
  return new;
end;
$function$;
