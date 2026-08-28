-- Phase 2: surface events.image_url through the map viewport RPC.
-- The column existed since the initial schema but was never returned, so an
-- uploaded organizer image could not be shown anywhere on the map. Return type
-- changes => drop + recreate (create or replace can't change OUT columns).
-- Parameters are unchanged, so the app's existing rpc('map_events', ...) call
-- keeps working; MapPin just gains an optional field.

drop function if exists public.map_events(
  double precision, double precision, double precision, double precision, date, date);

create or replace function public.map_events(
  min_lng double precision, min_lat double precision,
  max_lng double precision, max_lat double precision,
  night_from date, night_to date
)
returns table (
  id uuid, title text, description text, category_slug text, category_color text,
  lat double precision, lng double precision,
  starts_at timestamptz, ends_at timestamptz, place_name text, event_night date,
  image_url text, place_id uuid
)
language sql stable
as $$
  select e.id, e.title, e.description, c.slug, c.color,
         st_y(coalesce(e.geog, p.geog)::geometry) as lat,
         st_x(coalesce(e.geog, p.geog)::geometry) as lng,
         e.starts_at, e.ends_at, p.name as place_name, e.event_night,
         e.image_url, e.place_id
  from events e
  join categories c on c.id = e.category_id
  left join places p on p.id = e.place_id
  where e.status = 'approved'
    and e.event_night between night_from and night_to
    and coalesce(
          e.ends_at,
          ((e.event_night + 1)::timestamp + interval '6 hours')
            at time zone 'Europe/Skopje'
        ) > now()
    and st_intersects(
      coalesce(e.geog, p.geog),
      st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
    )
$$;

grant execute on function public.map_events(
  double precision, double precision, double precision, double precision, date, date)
  to anon, authenticated;
