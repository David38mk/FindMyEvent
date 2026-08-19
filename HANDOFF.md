# HANDOFF — Claude ↔ Claude coordination log

Two devs, two Claude Code instances, one repo. This file is the shared memory between sessions.

## Protocol (both Claudes MUST follow)

1. **Session start:** `git pull`, read the newest entry below, read [PLAN.md](PLAN.md) §5 open questions.
2. **Session end:** append an entry at the TOP of the log (newest first), then commit & push this file with the code.
3. Entries are **append-only** — never edit or delete another session's entry.
4. This file holds **state** (what's done, what's next, what's blocked). Durable decisions go to `docs/adr/`; term definitions go to `CONTEXT.md`; scope changes go to `PLAN.md`. Link them from your entry instead of restating.
5. Keep entries under ~15 lines. Bullet points, no prose walls.

## Entry template

```
### YYYY-MM-DD · <dev name> (<branch>)
**Done:** what was completed, with file paths
**Next:** the single most useful thing the other dev/Claude can pick up
**Blocked:** anything waiting on the other dev, or "-"
**Watch out:** gotchas discovered (env quirks, API surprises), or "-"
```

## Current ownership (Phase 0 → 1 transition, updated 2026-08-18)

- Shared: both members of the Supabase project; David covers backend tasks while sinanmarkic is busy (re-split in Phase 1)
- (Re-negotiate each phase; record changes here.)

---

## Log

### 2026-08-19 (afternoon) · sinanmarkic + Claude (main)
**Done:** (1) **Pin clustering** shipped ([app/lib/features/map/map_screen.dart](app/lib/features/map/map_screen.dart)) — `flutter_map_marker_cluster` (latest 8.2.2) turned out abandoned, pinned to `latlong2 ^0.9.1` vs. our `^0.10.1`; `flutter_map_supercluster` is 3 years stale on `flutter_map ^5.0.0` vs. our `^8.3.1`. Wrote a small greedy pixel-distance clustering function instead (no new dep): pins within 44px at current zoom collapse into one marker. Tapping a cluster opens a list sheet of what's inside (each item opens its own detail sheet) rather than blind-zooming — needed since hover previews don't exist on mobile, the actual target platform. Hover tooltip on both single pins and clusters previews contents on web/desktop. Caught + fixed a real bug in the process: first build accessed `_mapController.camera` before `FlutterMap` had rendered, which would've crashed on launch — guarded on `pins.isEmpty` (always true before `onMapReady`). (2) Surfaced `events.description` (was in the schema, never exposed) through `map_events` via [20260819113250](supabase/migrations/20260819113250_event_description_in_map_rpc.sql) (dropped+recreated the RPC, backfilled the 3 `[SAMPLE]` events with blurbs), added to `MapPin` + the pin detail sheet + hover tooltip snippet. Places still have no description column (PLAN.md §3 doesn't have one) — deferred, not built. Migration deployed live and verified via REST. Analyze + tests green throughout.
**Next:** Remaining Phase 1 backlog: time-scope ring visuals + map legend, tile caching. If Places ever need descriptions, that's a new column + migration, not yet decided. Name decision still open: Merak vs Vajb (PLAN.md §5.7).
**Blocked:** -
**Watch out:** Clustering is O(n²) greedy single-linkage from an arbitrary seed — fine for a city's viewport (dozens–low hundreds of pins), not something to scale up without revisiting. Two more personal access tokens were pasted into chat this session (for `db push`) and should be rotated at supabase.com/dashboard/account/tokens if not already.

### 2026-08-19 · sinanmarkic + Claude (main)
**Done:** (1) Installed Flutter 3.47.0 locally on sinanmarkic's machine, no-admin zip extract (choco needs elevation this box doesn't have) — `C:\Users\MarkoMatevski\flutter`, not on PATH yet. Ran app via `flutter run -d chrome --dart-define-from-file=dart_defines.json` for a quick visual check, web support auto-added. (2) Built the 18+ first-launch gate from the Phase 1 backlog: [app/lib/core/age_gate_prefs.dart](app/lib/core/age_gate_prefs.dart) (shared_preferences flag, self-attestation, offline-safe) + [app/lib/features/age_gate/age_gate_screen.dart](app/lib/features/age_gate/age_gate_screen.dart) (full-screen, confirm/decline, decline just shows a message — no enforcement to bypass). Wired via new `_AppGate` in [app/lib/main.dart](app/lib/main.dart): reads the flag, shows gate or `MapScreen`. l10n strings added EN+MK. `widget_test.dart` updated: one test with flag pre-set (boots to map), one fresh-device test (gate → confirm → map). Analyze + tests green.
**Next:** Pick up remaining Phase 1 backlog: pin clustering, time-scope ring visuals + map legend, tile caching. Name decision still open: Merak vs Vajb (PLAN.md §5.7).
**Blocked:** -
**Watch out:** MK translations for the age-gate strings are machine-drafted, not reviewed by a native speaker — worth a pass before shipping. `pubspec.lock` picked up a few transitive bumps from a plain `flutter pub get` (no manual version changes) — worth a diff check if anything behaves oddly.

### 2026-08-18 · David + Claude (main)
**Done:** (1) David linked his machine to Supabase (shared membership), deployed [20260818090000](supabase/migrations/20260818090000_fix_rls_recursion_and_event_location.sql) — both 08-17 review issues fixed live. (2) Supabase publishable + MapTiler keys wired via committed [app/dart_defines.json](app/dart_defines.json) (public-by-design keys only; secret key NEVER goes in repo). (3) Phase 1 map built: [20260818150000](supabase/migrations/20260818150000_map_rpcs_and_dev_seed.sql) adds `map_events`/`map_places` viewport RPCs (security invoker, RLS applies) + dev seed (6 Skopje places, 3 `[SAMPLE]` events); app map screen rewritten — MapTiler tiles (OSM fallback), pins colored from DB category colors, category FilterChips, daily selector (no past days), GPS button, pin detail bottom sheet; location permissions added to AndroidManifest + Info.plist. Analyze + tests green.
**Next:** All three migrations deployed + Phase 1 map code pushed; David ran it on the Pixel_6 emulator (`flutter run --dart-define-from-file=dart_defines.json`). Remaining Phase 1 (anyone can grab): pin clustering, time-scope ring visuals + map legend, 18+ first-launch gate, tile caching. Name decision: Merak vs Vajb (PLAN.md §5.7).
**Blocked:** -
**Watch out:** Both machines can `db push` — coordinate here first, migration files append-only. `[SAMPLE]` seed data must be deleted before launch. MapTiler key is on David's personal account (fine for now, swappable one-liner).

### 2026-08-17 (evening) · David + Claude (main)
**Done:** Phase 0 David side — Flutter scaffold in [app/](app/), placeholder package id `com.findmyevent.findmyevent`. gen-l10n wired: EN+MK ARB files, `nullable-getter: false`, generated files gitignored (regenerate via `flutter pub get`/`run`). Deps: supabase_flutter, flutter_riverpod, flutter_map, latlong2, geolocator, shared_preferences. [app/lib/core/env.dart](app/lib/core/env.dart) reads `--dart-define` config (app boots without keys). Placeholder MapScreen + smoke test; `flutter analyze` + `flutter test` green.
**Next:** sinanmarkic: two schema fixes found in review — (1) **RLS infinite recursion**: "curators read all profiles" policy ([initial_schema.sql:164](supabase/migrations/20260817120000_initial_schema.sql)) queries `profiles` inside a `profiles` policy → Postgres errors on profile reads once a curator exists; fix = `security definer` helper (e.g. `is_curator()`), same trick as `handle_new_user`. (2) `events` allows `place_id` AND `geog` both null → add `check (place_id is not null or geog is not null)`. Then Phase 1: viewport RPC + real map screen (David).
**Blocked:** David needs Supabase URL + publishable key from sinanmarkic to run app against live backend (app runs without them for UI work).
**Watch out:** supabase_flutter deprecated `anonKey` → code uses `publishableKey` and `SUPABASE_PUBLISHABLE_KEY` define (app/README.md has run command). `intl` must stay `^0.20.2` — flutter_localizations pins it. David's Flutter SDK: `C:\Users\david\flutter` (not on PATH).

### 2026-08-17 · sinanmarkic + Claude (main)
**Done:** Created Supabase project `findmyevent` (ref `cojvcfyqgggcssjbbecz`, eu-west-1), linked via CLI. Pushed initial schema migration ([supabase/migrations/20260817120000_initial_schema.sql](supabase/migrations/20260817120000_initial_schema.sql)): regions/categories/profiles/places/sources/events/reviews per PLAN.md §3, PostGIS geography cols + GiST indexes, RLS policies (anon sees approved events/active places; organizers insert+read own; curators read/update all). Seeded Skopje region + taxonomy v1 categories ([supabase/seed.sql](supabase/seed.sql)); verified live via REST API.
**Next:** David: Flutter scaffold + gen-l10n wiring (remaining Phase 0 piece). Whoever wires the app needs the project URL + anon/publishable key from Supabase dashboard (Settings → API) — not committed anywhere, ask sinanmarkic.
**Blocked:** App name still undecided (PLAN.md §5.7) — doesn't block this work.
**Watch out:** Category icon/color values in seed.sql are placeholders (arbitrary Material icon names + hex) — swap once a real palette is chosen; no code depends on current values yet. No Supabase CLI installed system-wide, used `npx supabase` instead.

### 2026-08-17 · David + Claude (main)
**Done:** Full planning session. Created [PLAN.md](PLAN.md) (stack, data model, phases), [CONTEXT.md](CONTEXT.md) (glossary), ADRs 0001–0003 (flutter_map+OSM, Supabase, organizer+scraper data strategy). Decided with David: taxonomy v1 (+`bar`), Place Reviews by Users (Phase 2), Time Scope selector daily/monthly/yearly with pin ring colors + on-map legend, MK+EN localization wired from Phase 0, 18+ gate + honest store rating, anonymous browsing, MapTiler tiles.
**Next:** Friend: read PLAN.md + CONTEXT.md + ADRs, veto/confirm anything, then start Phase 0 — Supabase project + first migration (schema in PLAN.md §3). David side: Flutter scaffold (placeholder package id fine, see PLAN §5.7) + researching scrape Source list.
**Blocked:** App name — David deliberating (shortlist in PLAN.md §5.7); only blocks store upload, not development.
**Watch out:** No code exists yet — repo is docs-only. Data strategy = organizers + scraping WITH curator approval queue (ADR 0003), devs still hand-seed first weeks. l10n rule: zero hardcoded UI strings from the very first screen.
