-- Surface events.description (already in the schema, never exposed) through
-- the map RPC so the pin detail sheet / hover tooltip can show it.
-- Places have no description column yet (PLAN.md §3 only has
-- name/address/opening_hours/phone) — deferred until that's asked for.

drop function if exists public.map_events(
  double precision, double precision, double precision, double precision, date
);

create function public.map_events(
  min_lng double precision, min_lat double precision,
  max_lng double precision, max_lat double precision,
  day date
)
returns table (
  id uuid, title text, description text, category_slug text, category_color text,
  lat double precision, lng double precision,
  starts_at timestamptz, ends_at timestamptz, place_name text
)
language sql stable
as $$
  select e.id, e.title, e.description, c.slug, c.color,
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

-- Dev seed backfill: give the [SAMPLE] events something to show.
update events set description = 'Live DJs, cheap drinks, dance floor open till late.'
  where title = '[SAMPLE] Techno Night';
update events set description = 'An intimate open-air jazz set overlooking the river.'
  where title = '[SAMPLE] Jazz Evening';
update events set description = 'Local comedians doing short sets, open mic slots after.'
  where title = '[SAMPLE] Standup Open Mic';
