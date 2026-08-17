# FindMyEvent — Development Plan

Map-first mobile app for finding events and legal-vice places in your city. Launch Region: **Skopje**. Mobile only.

Terminology: see [CONTEXT.md](CONTEXT.md). Decisions with reasoning: see [docs/adr/](docs/adr/).

## 1. Product summary

One map screen is the app. The user opens it, sees Pins for tonight's Events and nearby Places, taps Filter chips (party, concert, cigarettes, alcohol, hookah, betting…) to narrow what renders. Tapping a Pin opens a detail sheet. That's the whole MVP promise: *"What's happening / what's open around me, right now."*

### Core user flows

1. **Browse (anonymous)** — open app → map centered on Skopje (or GPS position) → toggle Filters → tap Pin → detail sheet (name, category, time or opening hours, description, photo, "Directions" deep-link to Google/Apple Maps).
2. **Organizer submit** — register/login → "Add event" form (title, category, venue Place or map-drop pin, start/end, description, image) → lands in approval queue → visible after Curator approval.
3. **Curate/approve** — Curators review queue (Supabase dashboard in MVP), approve/reject/dedupe. Scraped events arrive in the same queue.
4. **Scrape** — scheduled server job pulls 2–3 Skopje Sources, normalizes into pending Events.

### Filter behavior (decided)

- Filters are Category chips over the map; multi-select; none selected = show all.
- Events auto-hide after end time. Places support an "Open Now" toggle derived from Opening Hours.
- **Time Scope selector** (decided 2026-08-17): Daily view (default = today, arrows/swipe to change day, event start times shown), Monthly view (switch between months), Yearly/Ongoing view (long-running events, e.g. season festivals). Phase 1 ships Daily; Monthly + Yearly land Phase 2.
- **Pin visuals** (decided 2026-08-17): pin body color + icon = Category; colored ring/border = Time Scope. A collapsible **map legend** explains both color systems (category colors + time-scope rings); ships with Phase 1.

## 2. Stack

| Layer | Choice | Why (short — full reasoning in ADRs) |
|---|---|---|
| App | **Flutter** (Dart 3, single codebase iOS+Android) | Team choice; one codebase, two devs |
| Map | **flutter_map** + OSM-compatible tiles (MapTiler free key) | No Google billing account needed; ADR 0001 |
| Marker clustering | `flutter_map_marker_cluster` | Many pins in city center |
| State mgmt | **Riverpod** | Compile-safe DI + reactive state; scales past setState without Bloc boilerplate |
| Backend | **Supabase** (Postgres + PostGIS, Auth, RLS, Edge Functions) | Real geo queries, free admin UI, free tier; ADR 0002 |
| Scraper | Supabase **Edge Function** on cron (Deno/TS) | Same platform, no extra hosting |
| Location | `geolocator` package | Standard Flutter geolocation |
| Localization | Flutter gen-l10n (ARB files) | MK + EN at launch, Albanian later = one more ARB file; wired Phase 0 because retrofit = full-app sweep. UI strings only — Event content stays in Organizer's language |
| CI (later) | GitHub Actions: `flutter analyze` + `flutter test` | Cheap safety net for 2-dev repo |

## 3. Data model (initial)

```
regions      id, name, center_lat, center_lng            -- Skopje only at launch
categories   id, slug, kind ('event'|'place'), icon, color
places       id, region_id, category_id, name, geog(point),
             address, opening_hours(jsonb), phone, active
events       id, region_id, category_id, title, description,
             place_id (nullable), geog(point), starts_at, ends_at,
             image_url, status ('pending'|'approved'|'rejected'),
             source ('organizer'|'scraper'|'curator'), source_url,
             submitted_by (nullable -> auth.users)
profiles     user_id -> auth.users, role ('user'|'organizer'|'curator'), display_name
reviews      id, place_id, user_id, rating (1-5), text (nullable),
             created_at, unique(place_id, user_id)
sources      id, name, url, trust ('trusted'|'unverified'), enabled
```

- `geog` = PostGIS geography point; one GiST index each on places/events.
- Core read query: viewport bounds + category slugs + (`now() < ends_at` for events | open-now for places) — single SQL call via a Postgres function exposed as RPC.
- RLS: anonymous reads see only `status = 'approved'` events and `active` places; organizers insert `pending` events and read their own; curators update status.

## 4. Phases

### Phase 0 — Foundations (both devs, ~1 week)
- Flutter scaffold, repo structure, lint rules.
- gen-l10n wired from first screen (decided 2026-08-17): Macedonian + English ARB files; no hardcoded UI strings ever.
- Supabase project; SQL migrations for schema above; seed categories + Skopje region.
- HANDOFF.md workflow live (see §6).
- **Exit:** app builds on both machines and lists raw events from Supabase in a debug list.

### Phase 1 — Map MVP
- Map screen with tiles, GPS centering, pins from viewport RPC, filter chips, clustering.
- Daily Time Scope selector; pin visuals (category body + time-scope ring) + collapsible legend.
- Pin detail sheet + directions deep-link.
- Seed ~30 Places (OSM POI export + manual cleanup) and hand-entered Events for the coming weekends.
- **Exit:** installable APK/TestFlight build a stranger can use to find a real event tonight.

### Phase 2 — Accounts, submissions & reviews
- Supabase Auth (email + Google); roles: User / Organizer / Curator.
- Organizer "Add event" form; approval flow (Supabase dashboard is the curator UI; in-app curator screen only if dashboard hurts).
- Place Reviews: 1–5 stars + optional text, one per User per Place; average shown on detail sheet; "report" button instead of pre-moderation.
- **Exit:** an outside organizer can submit and an approved event appears on the map; a User can leave a Review on a Place.

### Phase 3 — Scraper
- Edge Function scraping local Skopje Sources on cron → pending events; duplicate flagging (same venue + start time).
- Source trust levels: Events from `unverified` Sources render a user-discretion notice on the detail sheet.
- Failure logging visible to curators.
- **Exit:** scraper runs a week unattended, produces real approved events.

### Phase 4 — Polish & growth (post-MVP menu)
- Favorites/save, push notification "tonight in Skopje", Open-Now refinements, event search, second Region, organizer analytics, monetization (promoted pins) — pick per traction.

## 5. Open questions (defaults chosen — override in HANDOFF.md)

1. **Scrape Sources**: local Skopje sites only (decided); exact list TBD — David researching legit ones. Suspicious/unverified Sources allowed but badge Events with a user-discretion notice.
2. **Category taxonomy v1** (confirmed 2026-08-17): events — `party, concert, standup, festival`; places — `bar, cigarettes, alcohol, hookah, betting, nightshop`.
3. ~~Age gating~~ — RESOLVED 2026-08-17: honest 18+ store content rating + one-time "I am 18+" dialog on first launch (local flag, works anonymous/offline). No real-money gambling features ever — betting shops shown as locations only.
4. ~~Anonymous browsing~~ — RESOLVED 2026-08-17: yes, no login wall; account only to submit Events or leave Reviews.
5. ~~Tile provider~~ — RESOLVED 2026-08-17: MapTiler free tier (Stadia = fallback if signup annoying).
7. **App name**: deliberating (David sleeping on it) — needs catchy marketing name; "FindMyEvent" = working title only. Shortlist from 2026-08-17 session: **Merak** (recommended — Balkan word for enjoying life's pleasures, unique in stores, survives regional expansion), Izlez, Večerva, NiteMap. Verify domain + store collisions before final. NOT blocking Phase 0: scaffold with placeholder package id; package id only frozen at first store upload (end of Phase 1).
6. ~~Pin color conflict~~ — RESOLVED 2026-08-17: pin body = Category color/icon, ring = Time Scope, plus on-map legend explaining both (see Filter behavior).

## 6. Two-dev + two-Claude workflow

- Coordination file: [HANDOFF.md](HANDOFF.md) — append-only log both Claudes read at session start and write at session end.
- Git: `main` always builds; short-lived feature branches; pull before session, push after. Small commits.
- Suggested ownership: **Dev A (David)** app/map UI, **Dev B (friend)** Supabase schema + scraper — swap per phase to both learn the stack. Ownership recorded per-phase in HANDOFF.md.
- Decisions that outlive a session → ADR in `docs/adr/`; term changes → CONTEXT.md. HANDOFF.md is for state, not decisions.
