-- Empty-state support (docs/DESIGN.md § Empty state): "nothing tonight, but
-- Saturday has 4 →". Returns the next Event Nights that actually have
-- approved, not-yet-expired events, so the app never dead-ends on a quiet night.
--
-- Security invoker (the default) on purpose: RLS still applies, so an
-- anonymous caller counts only the approved events they could already see.
create or replace function public.upcoming_event_nights(
  from_night date,
  max_nights int default 14
)
returns table (event_night date, event_count bigint)
language sql
stable
as $$
  select e.event_night, count(*) as event_count
  from events e
  where e.status = 'approved'
    and e.event_night >= from_night
    and coalesce(
          e.ends_at,
          ((e.event_night + 1)::timestamp + interval '6 hours')
            at time zone 'Europe/Skopje'
        ) > now()
  group by e.event_night
  order by e.event_night
  limit max_nights
$$;
