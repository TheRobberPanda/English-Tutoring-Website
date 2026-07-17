-- ============================================================
-- MIGRATION 2 — admin dashboard, credit protection, testimonials
-- Run this in the Supabase SQL editor. This is additive: it does NOT
-- re-run the original schema, so it's safe to run on your existing project.
-- ============================================================

-- 1. ADMIN FLAG + EMAIL ON PROFILES
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists email text;

-- Backfill email for any profiles created before this column existed.
update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;

-- Update the signup trigger so new profiles also store email.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, credits, email)
  values (new.id, new.raw_user_meta_data ->> 'full_name', 0, new.email);
  return new;
end;
$$ language plpgsql security definer;


-- 2. is_admin() HELPER
-- security definer so it can check the profiles table regardless of the
-- caller's own row-level permissions (avoids recursive RLS issues).
create or replace function public.is_admin()
returns boolean as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$ language sql security definer stable;


-- 3. CLOSE THE CREDIT/ADMIN-FLAG LOOPHOLE
-- The existing "update own profile" policy only restricts WHICH ROW a
-- student can update, not WHICH COLUMNS — so as it stood, a student could
-- open the browser console and grant themselves credits or admin rights.
-- This trigger blocks any change to `credits` or `is_admin` unless the
-- person making the change is an admin.
create or replace function public.protect_sensitive_profile_fields()
returns trigger as $$
begin
  if new.credits is distinct from old.credits and not public.is_admin() then
    raise exception 'No tienes permiso para modificar créditos.';
  end if;
  if new.is_admin is distinct from old.is_admin and not public.is_admin() then
    raise exception 'No tienes permiso para modificar este campo.';
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists protect_sensitive_profile_fields_trigger on public.profiles;
create trigger protect_sensitive_profile_fields_trigger
  before update on public.profiles
  for each row execute procedure public.protect_sensitive_profile_fields();


-- 4. ADMIN POLICIES — profiles (see & edit all students)
create policy "profiles_admin_select_all"
  on public.profiles for select
  using (public.is_admin());

create policy "profiles_admin_update_any"
  on public.profiles for update
  using (public.is_admin());


-- 5. ADMIN POLICIES — schedule_slots (create/edit/cancel classes)
create policy "slots_admin_insert"
  on public.schedule_slots for insert
  with check (public.is_admin());

create policy "slots_admin_update"
  on public.schedule_slots for update
  using (public.is_admin());

create policy "slots_admin_delete"
  on public.schedule_slots for delete
  using (public.is_admin());

grant insert, update, delete on public.schedule_slots to authenticated;


-- 6. TESTIMONIALS
create table public.testimonials (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.profiles(id) not null,
  student_name text,
  content text not null,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.testimonials enable row level security;

-- A student can submit their own testimonial.
create policy "testimonials_insert_own"
  on public.testimonials for insert
  with check (student_id = auth.uid());

-- Anyone (including logged-out visitors on the homepage) can read
-- APPROVED testimonials; a student can also see their own pending ones.
create policy "testimonials_select_approved_or_own"
  on public.testimonials for select
  using (approved = true or student_id = auth.uid());

-- Only you can approve/reject or delete testimonials.
create policy "testimonials_admin_update"
  on public.testimonials for update
  using (public.is_admin());

create policy "testimonials_admin_delete"
  on public.testimonials for delete
  using (public.is_admin());

grant select, insert on public.testimonials to authenticated;
grant select on public.testimonials to anon;
grant update, delete on public.testimonials to authenticated;


-- ============================================================
-- LAST STEP — make yourself admin.
-- Run this manually, replacing the email with your own account's email
-- (the one you use to log into cuenta.html):
-- ============================================================
-- update public.profiles set is_admin = true where email = 'tu-email@ejemplo.com';
