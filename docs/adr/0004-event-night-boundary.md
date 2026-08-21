# 4. Event Night with a 06:00 boundary, stored as its own column

Date: 2026-08-21

## Status

Accepted

## Context

A party starting Saturday 01:00 culturally belongs to Friday night. Filtering
the map by raw calendar date puts it on the wrong day and makes it vanish from
"tonight" at midnight — exactly when nightlife users are deciding where to go
next. We researched how others solve this (5-agent sweep over Resident
Advisor, Dice, Fever, Eventbrite, Bandsintown, GTFS transit, broadcast TV):

- The boundary hour converges on **06:00** across industries: TV "broadcast
  day", Japan's 30-hour clock (posters print "25:00"), bar POS defaults.
  Nothing uses 07:00 (David's initial guess) — and 07:00 would misclassify
  legitimate early-morning events.
- The data architecture converges too: RA (`listingDate`) and GTFS
  (service-day times past 24:00) independently store an **explicit "which
  night" field** next to the real timestamps, and run ALL day-based UI on it.
  Deriving it per-query from timestamps is the bug-prone road.
- Expiry: Eventbrite hides events at start time — an event running right now
  is invisible; the anti-pattern for nightlife (late arrival is normal). RA
  keeps the event all night. We follow RA, with `ends_at` or a 06:00-next-day
  fallback as the expiry moment.

## Decision

`events.event_night` (date) is a stored generated column: start before 06:00
local (Europe/Skopje) → previous date, else same date. Indexed; the viewport
RPC filters and groups exclusively on it. Expiry = `ends_at`, falling back to
event_night + 1 day at 06:00. Started-but-not-expired events render as
"Happening Now", never hidden.

Timezone is hardcoded to Europe/Skopje for now; multi-region later means the
generated column must become per-region (regions gain a tz column) — accepted
future cost, noted here so it isn't a surprise.

## Consequences

- Day selection semantics change app-wide: "Tonight" spans into tomorrow's
  early hours; queries use `event_night between X and Y` (ranges cheap).
- Curators/organizers never enter the night manually — derived, no drift.
- Post-midnight events display with their real clock time but group under the
  previous day's label, matching cinema/TV conventions users already know.
