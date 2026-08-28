-- Phase 2 (PLAN.md §4): accounts, organizer submissions, Place Reviews.
-- Everything here is additive; no existing policy semantics change except the
-- profiles UPDATE policy, which is tightened (see §1 — it is a real hole the
-- moment real users can sign in).

-- 1) Privilege-escalation fix on profiles -------------------------------------
-- The 08-17 policy was `for update using (user_id = auth.uid())` with no WITH
-- CHECK, so any signed-in user could PATCH their own row to role='curator' and
-- inherit every curator policy. Harmless while nobody could log in; live the
-- day Auth ships. A user may now edit their own row but NOT their own role.
--
-- The comparison has to come from a security-definer helper: a subquery on
-- profiles inside a profiles policy re-enters RLS and recurses (same bug fixed
-- for `is_curator()` in 20260818090000).
create or replace function public.current_profile_role()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from profiles where user_id = auth.uid();
$$;

drop policy "users update own profile" on profiles;
create policy "users update own profile" on profiles
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and role = public.current_profile_role());

-- handle_new_user() (security definer) normally creates the row, but if that
-- trigger ever fails the account is unusable with no way back. Let a user
-- create their OWN row, as a plain 'user' only.
create policy "users insert own profile" on profiles
  for insert
  with check (user_id = auth.uid() and role = 'user');

-- 2) Organizer access requests -----------------------------------------------
-- A signed-in User asks to become an Organizer; a Curator decides (Supabase
-- dashboard is the curator UI in MVP, PLAN.md §4 Phase 2).
create type organizer_request_status as enum ('pending', 'approved', 'rejected');

create table organizer_requests (
  user_id uuid primary key references auth.users (id) on delete cascade,
  note text,
  status organizer_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

alter table organizer_requests enable row level security;

create policy "users insert own organizer request" on organizer_requests
  for insert with check (user_id = auth.uid() and status = 'pending');

create policy "users read own organizer request" on organizer_requests
  for select using (user_id = auth.uid());

create policy "curators read organizer requests" on organizer_requests
  for select using (public.is_curator());

create policy "curators update organizer requests" on organizer_requests
  for update using (public.is_curator());

-- Approving a request promotes the profile in the same transaction, so the two
-- tables can't drift (a curator flipping status in the dashboard is the whole
-- approval UI — remembering to also edit profiles.role would be the drift).
create or replace function public.apply_organizer_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    update profiles set role = 'organizer'
      where user_id = new.user_id and role = 'user';
    new.decided_at := now();
  elsif new.status = 'rejected' and old.status is distinct from 'rejected' then
    new.decided_at := now();
  end if;
  return new;
end;
$$;

create trigger organizer_requests_apply
  before update on organizer_requests
  for each row execute function public.apply_organizer_request();

-- 3) Review reports (post-moderation, PLAN.md §4: "report button instead of
--    pre-moderation") ---------------------------------------------------------
create table review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references reviews (id) on delete cascade,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  unique (review_id, reporter_id)
);

create index review_reports_review_id_idx on review_reports (review_id);

alter table review_reports enable row level security;

-- Reporting requires an account: the unique(review_id, reporter_id) pair is
-- what stops one person spamming the queue, and anonymous reports have no such
-- key. Browsing stays anonymous; reporting does not.
create policy "users insert own review report" on review_reports
  for insert with check (reporter_id = auth.uid());

create policy "users read own review reports" on review_reports
  for select using (reporter_id = auth.uid());

create policy "curators read review reports" on review_reports
  for select using (public.is_curator());

create policy "curators delete review reports" on review_reports
  for delete using (public.is_curator());

-- 4) Reviews with author names ------------------------------------------------
-- `reviews` is already world-readable, but profiles is not: without this the
-- review list can only show raw user UUIDs. SECURITY DEFINER exposes exactly
-- one extra field (display_name) and nothing else from profiles.
create or replace function public.place_reviews(p_place_id uuid)
returns table (
  id uuid,
  user_id uuid,
  rating smallint,
  review_text text,
  created_at timestamptz,
  display_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select r.id, r.user_id, r.rating, r.text, r.created_at, pr.display_name
  from reviews r
  left join profiles pr on pr.user_id = r.user_id
  where r.place_id = p_place_id
  order by r.created_at desc;
$$;

-- 5) Grants -------------------------------------------------------------------
-- Explicit, because new Supabase projects no longer auto-expose new entities
-- to the Data API roles (see the auto_expose_new_tables note in config.toml).
grant execute on function public.place_reviews(uuid) to anon, authenticated;
grant execute on function public.current_profile_role() to authenticated;
-- RLS is what actually restricts these; the grants only open the Data API.
grant select, insert, update on table organizer_requests to authenticated;
grant select, insert, delete on table review_reports to authenticated;
