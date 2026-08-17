# ADR 0002 — Supabase (Postgres + PostGIS) as backend, not Firebase

Date: 2026-08-17
Status: accepted (revisit if user answers say otherwise)

## Context

The core query of the app is geospatial: "give me all Events and Places of Categories X,Y inside this map viewport, happening now / open now."

- **Firebase Firestore** has no native geo-queries; the standard workaround is geohash libraries, which can't combine geo + category + time filtering server-side cleanly and over-fetches.
- **Supabase** is hosted Postgres with the PostGIS extension: real geo indexes, one SQL query for viewport + category + time. Also bundles auth, row-level security, auto-generated REST API, and a table editor usable as a free admin panel for manual curation. Free tier fits a two-person, one-city project.
- **Custom backend** (Node/Go + Postgres) gives the same power but adds hosting and maintenance work two part-time devs don't need yet.

## Decision

Supabase. Schema in SQL migrations committed to this repo. Flutter talks to it via `supabase_flutter`.

## Consequences

- Viewport queries are one indexed SQL call; no geohash hacks.
- Supabase table editor doubles as the curation admin tool in MVP — no admin app to build.
- Free-tier projects pause after 1 week of inactivity — acceptable pre-launch, needs the paid tier (~$25/mo) or activity pings before real users arrive.
- If Supabase ever must go, the data is plain Postgres — portable.
