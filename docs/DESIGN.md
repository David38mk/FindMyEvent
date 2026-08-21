# Design system — FindMyEvent (working title)

Decisions from the UI grill session 2026-08-21. Complements PLAN.md (product) and CONTEXT.md (glossary). Implementation notes live here, not in the glossary.

## Theme strategy (decided 2026-08-21)

- **Follows system theme** (`ThemeMode.system`): light by day, dark by night.
- **Dark is the design-first target** — the brand soul; users decide "where tonight?" in the evening. Light variant must ship before store launch, not after.
- Both map tile styles required (MapTiler light + dark variants of the same style family) — swap by theme.
- Every future UI element gets designed/checked in BOTH themes before merge.

## Brand color (decided 2026-08-21)

- **Warm amber/gold family on dark charcoal** — kafana warmth, distinct in a category full of purple event apps, matches the product emotion (enjoyment).
- Exact hex pair chosen with the palette work below; ballpark `#FFB300` amber, `#1A1A2E`-ish charcoal.
- Note: this choice leans toward "Merak" on the open name decision (PLAN.md §5.7) — name still open.

## Map tiles (decided 2026-08-21)

- **MapTiler `dataviz` (light) + `dataviz-dark` (dark)** — near-monochrome data-first basemap; pins and brand amber are the only loud things on screen.
- Custom brand-tinted style (MapTiler style editor) = pre-launch polish item, not now.

## Category color system (decided 2026-08-21)

- **Events = color, Places = neutral.** Event categories (party/concert/standup/festival) get 4 curated harmonious hues — color means "happening". Place categories all use one quiet charcoal-slate pin with a white category glyph (from the existing `categories.icon` column) — neutral means "always there".
- Exact hex values picked in the palette workshop below; DB seed gets an update migration.

## Filter & legend UX (decided 2026-08-21, David's design)

- Top chip row + standalone map legend are REPLACED by one **filter button** (badge = active filter count) next to the day selector.
- Expanded: panel over the map listing all categories with their color/glyph — the filter panel doubles as the legend; no separate legend widget.
- Default: all categories visibly selected (map shows everything).
- **First tap isolates** (deselects all others, keeps the tapped one); subsequent taps toggle; "All" button resets. Same semantics as analytics-chart legends.
- (Time-scope footer idea dropped — pin time indication was removed entirely, see Pin system.)

## Pin system (decided 2026-08-21)

- Anchored pin shape stays (tip on exact coordinate).
- **No time indication on pins** — the day selector already filters "when"; duration/head-dot system from 08-20 is REMOVED. Rationale: in a day-filtered view almost every visible event is "today" — a constant indicator is noise.
- Event pin: curated category hue, plain head. Place pin: charcoal-slate, white category glyph head.
- Detail sheet gains full time info: start time AND the date range the event covers (`ends_at` display was missing).

## Typography (decided 2026-08-21)

- **Manrope everywhere** (single family) — warm, professional, first-class Cyrillic (hard requirement: Macedonian UI must never fall back to ugly system Cyrillic next to pretty Latin).
- Via `google_fonts` package for now (runtime fetch + cache); **bundle the TTFs as assets before store launch** so first offline run is correct.
- Logo/wordmark font = separate branding decision, tied to the name choice.

## Palette v2 (decided 2026-08-21, David's refinement — supersedes v1)

App-side tokens live in `app/lib/core/palette.dart` (AppPalette); category colors stay DB-owned.

| Token | Hex | Usage |
|---|---|---|
| Electric Amber (brand seed) | `#FFB000` | CTAs, FABs, selected states, badges, Happening Now |
| Amber Light | `#FFD166` | highlights, secondary emphasis (scheme.secondary) |
| Midnight | `#121212` | dark background |
| Elevated Surface | `#1C1B1A` | dark cards, sheets |
| Raised Surface | `#292725` | dark inputs, active containers |
| Warm Light BG | `#FAF9F6` | light background |
| Pure White | `#FFFFFF` | light cards |
| Danger | `#FF5C5C` | errors, urgent states (scheme.error) |
| Text 1 dark / 2 dark | `#F5F3EF` / `#AAA6A0` | dark-mode text |
| Text 1 light / 2 light | `#1C1917` / `#6B6560` | light-mode text |

Category hues (DB, migration `20260821180000`): party `#FF4D8D`, concert `#7C5CFC`, standup `#12C7B3`, festival `#4DBA63`, places `#64748B` slate.

## Date & night UX (decided 2026-08-21, research-driven — see ADR 0004)

- **Event Night** = 06:00→06:00 unit (ADR 0004); all selection/grouping/expiry on it.
- Selector = **preset chips with real dates**: "Tonight · пет 22", "Tomorrow · саб 23", "Weekend · 22–24", + calendar chip for a specific night. Arrows/day-strip pattern retired (no major app leads with it). Custom multi-night range picker = deferred; Weekend preset covers the 80% case.
- **Expiry**: pin stays until `ends_at` (or event_night+1 06:00 fallback); map data refreshes periodically so finished events vanish live.
- **Happening Now**: started-but-not-finished events get a distinct pin head (amber, enlarged) — white space none of the incumbents ship.
- **Event list**: 3-detent draggable bottom sheet over the map (peek strip / half list / full list), events of the selected nights sorted by time; tapping a row centers the map + opens the detail sheet. Google-Maps pattern; list/map toggle rejected (documented discoverability failures).

## Theme override (decided 2026-08-21)

- Default **Auto** (follows system); settings button on the map lets users pin Light or Dark. Persisted locally (shared_preferences), no account needed.

## Still open (next sessions)

- Custom brand-tinted map style (pre-launch)
- Logo/wordmark + final name
- `last_entry_at` field idea (RA's "last entry" deadline — more useful than end time for partygoers; consider in Phase 2 organizer form)
