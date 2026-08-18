-- Fixes from HANDOFF 2026-08-17 (evening) schema review.

-- 1) RLS infinite recursion: "curators read all profiles" queried profiles
--    inside a profiles policy. security definer runs as owner, bypassing RLS
--    inside the function, which breaks the cycle (same trick as handle_new_user).
create or replace function public.is_curator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles
    where user_id = auth.uid() and role = 'curator'
  );
$$;

drop policy "curators read all profiles" on profiles;
create policy "curators read all profiles" on profiles
  for select using (public.is_curator());

-- Same helper for the curator policies on events — consistency + one less
-- RLS-filtered subquery per row.
drop policy "curators read all events" on events;
create policy "curators read all events" on events
  for select using (public.is_curator());

drop policy "curators update events" on events;
create policy "curators update events" on events
  for update using (public.is_curator());

-- 2) An event with neither a Place nor its own coordinates is invisible on a
--    map app — forbid it at the schema level.
alter table events
  add constraint events_has_location
  check (place_id is not null or geog is not null);
