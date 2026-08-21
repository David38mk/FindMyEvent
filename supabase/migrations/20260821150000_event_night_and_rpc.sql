-- Event Night (ADR 0004): a night runs 06:00→06:00; a 01:00 party belongs to
-- the previous evening. Trigger, not a generated column — AT TIME ZONE is only
-- STABLE (tz db updates), and generated columns demand IMMUTABLE expressions.
alter table events add column event_night date;

create or replace function public.compute_event_night()
returns trigger
language plpgsql
as $$
declare
  local_ts timestamp;
begin
  local_ts := new.starts_at at time zone 'Europe/Skopje';
  new.event_night := case
    when local_ts::time < time '06:00' then local_ts::date - 1
    else local_ts::date
  end;
  return new;
end;
$$;

create trigger events_event_night
  before insert or update of starts_at on events
  for each row execute function public.compute_event_night();

-- Backfill existing rows through the trigger.
update events set starts_at = starts_at;

alter table events alter column event_night set not null;
create index events_event_night_idx on events (event_night);

-- Viewport RPC now takes a night RANGE (Weekend preset = 3 nights) and
-- applies expiry: an event disappears once ended; without an end time it
-- survives until 06:00 the morning after its Event Night. Return type
-- changes, so drop the old day-based signature.
drop function if exists public.map_events(
  double precision, double precision, double precision, double precision, date);

create or replace function public.map_events(
  min_lng double precision, min_lat double precision,
  max_lng double precision, max_lat double precision,
  night_from date, night_to date
)
returns table (
  id uuid, title text, description text, category_slug text, category_color text,
  lat double precision, lng double precision,
  starts_at timestamptz, ends_at timestamptz, place_name text, event_night date
)
language sql stable
as $$
  select e.id, e.title, e.description, c.slug, c.color,
         st_y(coalesce(e.geog, p.geog)::geometry) as lat,
         st_x(coalesce(e.geog, p.geog)::geometry) as lng,
         e.starts_at, e.ends_at, p.name as place_name, e.event_night
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

-- Dev seed refresh: the [SAMPLE] events carry dates from their original
-- deploy day and would be expired under the new rules. Push them forward so
-- the map has something to show (updates run the event_night trigger).
update events set starts_at = current_date + interval '22 hours',
                  ends_at   = current_date + interval '1 day 4 hours'
  where title = '[SAMPLE] Techno Night';
update events set starts_at = current_date + interval '1 day 20 hours',
                  ends_at   = current_date + interval '1 day 23 hours'
  where title = '[SAMPLE] Jazz Evening';
update events set starts_at = current_date + interval '2 days 21 hours',
                  ends_at   = current_date + interval '2 days 23 hours'
  where title = '[SAMPLE] Standup Open Mic';
