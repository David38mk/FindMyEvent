-- Initial schema for FindMyEvent (PLAN.md §3)

create extension if not exists postgis;

create table regions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  center_lat double precision not null,
  center_lng double precision not null
);

create type category_kind as enum ('event', 'place');

create table categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  kind category_kind not null,
  icon text not null,
  color text not null
);

create type user_role as enum ('user', 'organizer', 'curator');

create table profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role user_role not null default 'user',
  display_name text
);

create table places (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  category_id uuid not null references categories (id),
  name text not null,
  geog geography(point, 4326) not null,
  address text,
  opening_hours jsonb,
  phone text,
  active boolean not null default true
);

create index places_geog_idx on places using gist (geog);
create index places_region_id_idx on places (region_id);
create index places_category_id_idx on places (category_id);

create type source_trust as enum ('trusted', 'unverified');

create table sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  url text not null,
  trust source_trust not null default 'unverified',
  enabled boolean not null default true
);

create type event_status as enum ('pending', 'approved', 'rejected');
create type event_source as enum ('organizer', 'scraper', 'curator');

create table events (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  category_id uuid not null references categories (id),
  title text not null,
  description text,
  place_id uuid references places (id),
  geog geography(point, 4326),
  starts_at timestamptz not null,
  ends_at timestamptz,
  image_url text,
  status event_status not null default 'pending',
  source event_source not null,
  source_url text,
  submitted_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

create index events_geog_idx on events using gist (geog);
create index events_region_id_idx on events (region_id);
create index events_status_idx on events (status);
create index events_starts_at_idx on events (starts_at);

create table reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references places (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  text text,
  created_at timestamptz not null default now(),
  unique (place_id, user_id)
);

-- Row Level Security -----------------------------------------------------

alter table regions enable row level security;
alter table categories enable row level security;
alter table places enable row level security;
alter table sources enable row level security;
alter table events enable row level security;
alter table reviews enable row level security;
alter table profiles enable row level security;

-- regions / categories: public reference data, readable by everyone
create policy "regions readable by everyone" on regions
  for select using (true);

create policy "categories readable by everyone" on categories
  for select using (true);

-- places: anonymous reads only see active places
create policy "active places readable by everyone" on places
  for select using (active = true);

-- events: anonymous reads only see approved events
create policy "approved events readable by everyone" on events
  for select using (status = 'approved');

-- organizers insert their own pending events
create policy "organizers insert pending events" on events
  for insert
  with check (
    status = 'pending'
    and submitted_by = auth.uid()
    and exists (
      select 1 from profiles
      where user_id = auth.uid() and role in ('organizer', 'curator')
    )
  );

-- organizers can read their own submissions regardless of status
create policy "organizers read own events" on events
  for select using (submitted_by = auth.uid());

-- curators can read and update any event (approve/reject/dedupe)
create policy "curators read all events" on events
  for select using (
    exists (select 1 from profiles where user_id = auth.uid() and role = 'curator')
  );

create policy "curators update events" on events
  for update using (
    exists (select 1 from profiles where user_id = auth.uid() and role = 'curator')
  );

-- reviews: readable by everyone, writable only by their author
create policy "reviews readable by everyone" on reviews
  for select using (true);

create policy "users insert own review" on reviews
  for insert with check (user_id = auth.uid());

create policy "users update own review" on reviews
  for update using (user_id = auth.uid());

create policy "users delete own review" on reviews
  for delete using (user_id = auth.uid());

-- profiles: users manage their own row; curators can read all
create policy "users read own profile" on profiles
  for select using (user_id = auth.uid());

create policy "users update own profile" on profiles
  for update using (user_id = auth.uid());

create policy "curators read all profiles" on profiles
  for select using (
    exists (select 1 from profiles p where p.user_id = auth.uid() and p.role = 'curator')
  );

-- New auth users get a default 'user' profile row automatically.
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (user_id, role, display_name)
  values (new.id, 'user', new.raw_user_meta_data ->> 'display_name');
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
