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

## Current ownership (Phase 0)

- David: Flutter scaffold, map screen groundwork
- Friend: Supabase project, schema migrations, seed data
- (Re-negotiate each phase; record changes here.)

---

## Log

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
