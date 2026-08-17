# ADR 0003 — Event data from Organizer submissions + automated scraping

Date: 2026-08-17
Status: accepted (per David, 2026-08-17)

## Context

An event map with an empty map is dead on arrival. Considered:

1. Organizer self-service — venues/promoters post their own events.
2. Team-only manual curation — guaranteed quality, recurring grunt work, doesn't scale past one city.
3. Automated scraping/APIs — Facebook's event API is effectively closed; international APIs (Songkick, Bandsintown) have thin Macedonia coverage; local ticket sites (e.g. mktickets, karti) and venue Instagram/Facebook pages are scrapeable but fragile and need per-source maintenance.

## Decision

Combo of 1 + 3, chosen by the team:

- **Organizer accounts** exist from MVP: an Organizer registers, submits Events, and they appear after Curator approval (approval flow keeps spam and fake events out).
- **Scraping pipeline** runs server-side on a schedule, pulling from a maintained list of Sources (local ticket sites, selected venue pages). Scraped Events enter the same approval queue flagged `source = scraper`.

Known risk accepted: cold-start — organizers won't sign up for an app with no users. Mitigation: the two devs act as Curators and hand-enter/seed events themselves in the first weeks (effectively bootstrapping via the same submission flow), plus the scraper provides baseline coverage.

## Consequences

- MVP scope grows vs. curation-only: needs auth, Organizer role, submission UI, approval queue, and a scheduled scraper job (Supabase Edge Functions / cron).
- Every scrape Source is a maintenance liability; keep the Source list small (2–3 to start) and log scrape failures visibly.
- Deduplication needed: the same event can arrive from an Organizer and a Source — approval queue must surface likely duplicates (same venue + same start time).
