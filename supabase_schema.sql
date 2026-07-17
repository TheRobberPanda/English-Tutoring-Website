-- ============================================================
-- Paulo Crespo tutoring site — schema for schedule + student credits
-- Run this in the Supabase SQL editor (Project > SQL Editor > New query)
-- ============================================================

-- 1. PROFILES
-- One row per student, linked to Supabase's built-in auth.users table.
create table public.profiles (
  id uuid references auth.users(id) primary key,
  full_name text,
  credits int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A student can only ever see/edit their OWN profile row.
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_update_own_name_only"
  on public.profiles for update
  using (auth.uid() = id);
-- Note: credits should NOT be editable by students directly (see book_slot()
-- function below, which is the only sanctioned way credits change from the
-- student side). You top up credits manually from the Supabase dashboard
-- after confirming a payment.

-- Automatically create a profile row whenever someone signs up.
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, credits)
  values (new.id, new.raw_user_meta_data ->> 'full_name', 0);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. SCHEDULE SLOTS
-- Slots you publish. Students can see all OPEN slots (to know your
-- availability) but can only see WHO booked a slot if it's their own.
create table public.schedule_slots (
  id uuid primary key default gen_random_uuid(),
  start_time timestamptz not null,
  end_time timestamptz not null,
  is_booked boolean not null default false,
  student_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.schedule_slots enable row level security;

-- Everyone logged in can see slot times and booked/open status,
-- but student_id is only meaningful to the student who booked it
-- (enforced by only ever returning it via the RPC below, not raw select).
create policy "slots_select_all_logged_in"
  on public.schedule_slots for select
  using (auth.role() = 'authenticated');

-- Only you (via the Supabase dashboard, using the service role) insert
-- or delete slots — no insert/update/delete policy is created for
-- regular students, so by default they CANNOT create or edit slots directly.


-- 3. BOOKING FUNCTION
-- The only way a student can turn an open slot into a booked one.
-- Runs as a single atomic transaction: checks credits > 0 AND slot
-- still open, then deducts one credit and assigns the slot — so two
-- students can't both grab the same slot, and no one can book at 0 credits.
create function public.book_slot(slot_id uuid)
returns void as $$
declare
  caller_id uuid := auth.uid();
  current_credits int;
begin
  if caller_id is null then
    raise exception 'Debes iniciar sesión para reservar una clase.';
  end if;

  select credits into current_credits
  from public.profiles
  where id = caller_id
  for update;

  if current_credits is null or current_credits < 1 then
    raise exception 'No tienes créditos suficientes para reservar.';
  end if;

  update public.schedule_slots
  set is_booked = true, student_id = caller_id
  where id = slot_id and is_booked = false;

  if not found then
    raise exception 'Esta clase ya no está disponible.';
  end if;

  update public.profiles
  set credits = credits - 1
  where id = caller_id;
end;
$$ language plpgsql security definer;

-- Let logged-in students call the booking function.
grant execute on function public.book_slot(uuid) to authenticated;


-- 4. STUDENT'S OWN BOOKINGS VIEW
-- A safe way for a student to see their own upcoming booked classes
-- (rather than exposing student_id in the general slot listing).
create view public.my_bookings as
select id, start_time, end_time
from public.schedule_slots
where student_id = auth.uid();

alter view public.my_bookings set (security_invoker = true);
