-- Practice area and video lessons.
--
-- Practice: the starter exercises ship as a static file (practice-data.js);
-- only Paulo's own exercises live in practice_items. practice_progress holds
-- one spaced-repetition row per student per exercise, keyed by item_key:
--   s:<id>   a starter exercise from practice-data.js
--   c:<uuid> a practice_items row
--
-- Video lessons are YouTube (unlisted) ids, never uploaded files: Storage's
-- free tier is 1 GB and is already shared with chat attachments.
--
-- Lesson recordings and their transcripts are deliberately NOT here: they
-- stay on Paulo's computer (IndexedDB in admin.html) and are never uploaded.

-- ---------------------------------------------------------------------------
-- Practice
create table if not exists public.practice_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('verb', 'preposition', 'translation')),
  target_lang text not null check (target_lang in ('en', 'es')),
  source_lang text check (source_lang in ('es', 'pl', 'en')),
  prompt text not null check (length(prompt) between 1 and 500),
  -- One entry per blank, each a list of accepted answers: [["went"],["gone"]]
  answers jsonb not null check (jsonb_typeof(answers) = 'array' and jsonb_array_length(answers) between 1 and 4),
  hint text check (length(hint) <= 300),
  student_id uuid references public.profiles(id) on delete cascade,   -- null = every student
  created_at timestamptz not null default now()
);
create index if not exists practice_items_student_idx on public.practice_items (student_id);

alter table public.practice_items enable row level security;
create policy practice_items_read on public.practice_items for select to authenticated
  using (student_id is null or student_id = (select auth.uid()) or public.is_admin());
create policy practice_items_admin_insert on public.practice_items for insert to authenticated
  with check (public.is_admin());
create policy practice_items_admin_update on public.practice_items for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy practice_items_admin_delete on public.practice_items for delete to authenticated
  using (public.is_admin());
revoke all on public.practice_items from anon, authenticated;
grant select, insert, update, delete on public.practice_items to authenticated;

create table if not exists public.practice_progress (
  student_id uuid not null references public.profiles(id) on delete cascade,
  item_key text not null,
  box smallint not null default 0 check (box between 0 and 6),
  correct int not null default 0,
  wrong int not null default 0,
  last_result boolean,
  last_seen timestamptz not null default now(),
  due_at timestamptz not null default now(),
  primary key (student_id, item_key)
);

alter table public.practice_progress enable row level security;
create policy practice_progress_read on public.practice_progress for select to authenticated
  using (student_id = (select auth.uid()) or public.is_admin());
-- Written only through record_practice(), which validates the key and caps
-- the row count, so a client cannot bloat the table with junk keys.
revoke all on public.practice_progress from anon, authenticated;
grant select on public.practice_progress to authenticated;

-- Leitner boxes: right moves an exercise up a box (1d, 3d, 7d, 14d, 30d, 60d),
-- wrong sends it back to box 0 and due again in 10 minutes.
create or replace function public.record_practice(p_item_key text, p_correct boolean)
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  c_steps constant interval[] := array[interval '1 day', interval '3 days', interval '7 days',
                                       interval '14 days', interval '30 days', interval '60 days'];
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_item_key is null or p_item_key !~ '^(s:[a-z0-9_.-]{1,80}|c:[0-9a-f-]{36})$' then
    raise exception 'bad_item';
  end if;
  if not exists (select 1 from public.practice_progress where student_id = v_uid and item_key = p_item_key)
     and (select count(*) from public.practice_progress where student_id = v_uid) >= 5000 then
    raise exception 'too_many_items';
  end if;

  insert into public.practice_progress as p
    (student_id, item_key, box, correct, wrong, last_result, last_seen, due_at)
  values (v_uid, p_item_key,
          case when p_correct then 1 else 0 end,
          case when p_correct then 1 else 0 end,
          case when p_correct then 0 else 1 end,
          p_correct, now(),
          now() + case when p_correct then c_steps[1] else interval '10 minutes' end)
  on conflict (student_id, item_key) do update set
    box = case when p_correct then least(p.box + 1, 6) else 0 end,
    correct = p.correct + case when p_correct then 1 else 0 end,
    wrong = p.wrong + case when p_correct then 0 else 1 end,
    last_result = p_correct,
    last_seen = now(),
    due_at = now() + case when p_correct then c_steps[least(p.box + 1, 6)] else interval '10 minutes' end;
end;
$function$;
revoke all on function public.record_practice(text, boolean) from public, anon;
grant execute on function public.record_practice(text, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Video lessons
create table if not exists public.video_lessons (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(title) between 1 and 200),
  description text check (length(description) <= 2000),
  youtube_id text not null check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  target_lang text check (target_lang in ('en', 'es')),
  student_id uuid references public.profiles(id) on delete cascade,   -- null = every student
  published boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.video_lessons enable row level security;
-- Students only: an unlisted link is not meant for the anonymous web.
create policy video_lessons_read on public.video_lessons for select to authenticated
  using (public.is_admin() or (published and (student_id is null or student_id = (select auth.uid()))));
create policy video_lessons_admin_insert on public.video_lessons for insert to authenticated
  with check (public.is_admin());
create policy video_lessons_admin_update on public.video_lessons for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy video_lessons_admin_delete on public.video_lessons for delete to authenticated
  using (public.is_admin());
revoke all on public.video_lessons from anon, authenticated;
grant select, insert, update, delete on public.video_lessons to authenticated;
