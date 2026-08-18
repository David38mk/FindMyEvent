-- Phase 1: viewport RPCs for the map + hand-seeded sample data (PLAN.md Phase 1).
-- Both functions are SECURITY INVOKER (default): RLS still applies, so anon
-- callers only ever see approved events / active places.

-- Events visible on the map for one day, inside the given viewport.
-- NOTE: day boundaries use server time (UTC); Skopje is UTC+1/+2. Good enough
-- for now — revisit if "tonight at 00:30" events land on the wrong day.
create or replace function public.map_events(
  min_lng double precision, min_lat double precision,
  max_lng double precision, max_lat double precision,
  day date
)
returns table (
  id uuid, title text, category_slug text, category_color text,
  lat double precision, lng double precision,
  starts_at timestamptz, ends_at timestamptz, place_name text
)
language sql stable
as $$
  select e.id, e.title, c.slug, c.color,
         st_y(coalesce(e.geog, p.geog)::geometry) as lat,
         st_x(coalesce(e.geog, p.geog)::geometry) as lng,
         e.starts_at, e.ends_at, p.name as place_name
  from events e
  join categories c on c.id = e.category_id
  left join places p on p.id = e.place_id
  where e.status = 'approved'
    and st_intersects(
      coalesce(e.geog, p.geog),
      st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
    )
    and e.starts_at < (day + 1)::timestamptz
    and coalesce(e.ends_at, e.starts_at + interval '6 hours') >= day::timestamptz
$$;

-- Places inside the viewport. "Open Now" filtering happens client-side from
-- opening_hours (not returned yet — added when the Open Now toggle ships).
create or replace function public.map_places(
  min_lng double precision, min_lat double precision,
  max_lng double precision, max_lat double precision
)
returns table (
  id uuid, name text, category_slug text, category_color text,
  lat double precision, lng double precision, address text
)
language sql stable
as $$
  select p.id, p.name, c.slug, c.color,
         st_y(p.geog::geometry) as lat,
         st_x(p.geog::geometry) as lng,
         p.address
  from places p
  join categories c on c.id = p.category_id
  where p.active
    and st_intersects(
      p.geog,
      st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
    )
$$;

-- Dev seed: a few real Skopje spots + [SAMPLE] events so the map is not empty
-- during development. Remove before launch (delete where title like '[SAMPLE]%').
insert into places (region_id, category_id, name, geog, address)
select r.id, c.id, v.name, st_point(v.lng, v.lat)::geography, v.address
from (values
  ('Old Town Brewery',      'bar',        41.99648, 21.43108, 'Old Bazaar'),
  ('Kotur',                 'bar',        42.00030, 21.41750, 'Debar Maalo'),
  ('Menada',                'bar',        41.99780, 21.43580, 'Old Bazaar'),
  ('Tabak Centar',          'cigarettes', 41.99580, 21.42650, 'Centar'),
  ('Bunjakovec Night Shop', 'nightshop',  41.99860, 21.41520, 'Bunjakovec'),
  ('Sahara Hookah Lounge',  'hookah',     41.99250, 21.42300, 'Centar')
) as v(name, cat, lat, lng, address)
join regions r on r.name = 'Skopje'
join categories c on c.slug = v.cat;

insert into events (region_id, category_id, title, place_id, geog, starts_at, ends_at, status, source)
select r.id, c.id, v.title, p.id,
       case when v.lat is null then null
            else st_point(v.lng, v.lat)::geography end,
       current_date + v.start_offset, current_date + v.end_offset,
       'approved', 'curator'
from (values
  ('[SAMPLE] Techno Night',     'party',   'Old Town Brewery', null::double precision, null::double precision, interval '1 day 22 hours', interval '2 days 4 hours'),
  ('[SAMPLE] Jazz Evening',     'concert', null,               41.98950, 21.42160,                             interval '2 days 20 hours', interval '2 days 23 hours'),
  ('[SAMPLE] Standup Open Mic', 'standup', 'Menada',           null,     null,                                 interval '21 hours',        interval '23 hours')
) as v(title, cat, place_name, lat, lng, start_offset, end_offset)
join regions r on r.name = 'Skopje'
join categories c on c.slug = v.cat
left join places p on p.name = v.place_name;
