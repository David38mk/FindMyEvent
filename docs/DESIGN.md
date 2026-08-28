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

## Palette v3 — "Hot City" (LOCKED 2026-08-21, supersedes v1/v2 — see ADR 0005)

"The city is on. Go out." Dark near-monochrome UI; color = signal layer, like lights in a club. Three layers — brand / status / category — tokens in `app/lib/core/palette.dart`, category hexes DB-owned.

**Layer 1 — Brand (UI chrome only, never on pins):**

| Token | Hex | Usage |
|---|---|---|
| Signal Red | `#FF3B30` | seed: CTAs, FABs, selected states |
| Deep Red | `#D91F26` | errors + destructive — ALWAYS with icon+text (red-brand discipline) |

**Layer 2 — Status:**

| Token | Hex | State |
|---|---|---|
| Solar Yellow | `#FFE600` | Happening Now (live) — never bare on light: filled chip + near-black text |
| Tangerine-light | `#FF9F45` | Trending (reserved) |
| Steel | `#9299A8` | Sold out (reserved) |
| Amber | `#FFB000` | Almost sold out (reserved) |
| Mint | `#38E8C5` | Free entry (reserved) |

**Layer 3 — Category (DB, migration `20260821200000`):** party `#FF3D81`, concert `#8F5BFF`, standup `#19D3C5` aqua, festival `#FF7A00` tangerine; places `#64748B` slate (furniture, not signal). Culture `#635BFF` / sports `#D7FF3F` reserved for future taxonomy.

**Surfaces & text:** dark = Void `#0A0A0A` bg, Asphalt `#171717` cards, Graphite `#242424` inputs; light = Cream `#FFFDF8` bg, white cards. Text dark `#F4F7FB`/`#9299A8`, light `#1C1917`/`#6B6560`.

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

## App shape (decided 2026-08-28)

- **The map is the whole app.** No bottom tab bar: controls float over the map, the event list is the draggable sheet, account is a button. Matches the map-first positioning in PLAN.md §7.
- Findzzer's five-tab shell (Events / Booking / Map / Chat / Profile) is deliberately NOT copied — they have booking and chat to fill it; ours would be a navigation frame around one real screen, with an empty "Saved" tab reading as an unfinished app.
- **Revisit when tabs are earned:** once Phase 4 lands saved events, notifications and a real profile, a tab bar becomes justified. Cheap to add then.

## Pin system v2 — card pins (decided 2026-08-28, supersedes the pin shape above)

Inspired by Findzzer's poster pins, adapted to our data reality: **no event in the database has an image today** (the kadevecer scraper never reads the `<img>`, sample events have none, and organizer uploads — the only source of posters — number zero).

- **Event pins become small rounded cards, always.** Real poster when `image_url` exists; otherwise generated artwork from the category colour + glyph. Consistent shape now, silently upgrades as real posters arrive — no half-empty-poster map.
- **Places stay small slate pins**, unchanged. This sharpens the rule already locked: events are loud, places are furniture.
- **A cluster renders as a stack of cards** (Findzzer's look), not a numbered bubble.
- Card pins are roughly 3× a teardrop's footprint, so **cluster radius must be re-tuned upward** — Debar Maalo on a Saturday is the stress case.
- **Backend prerequisite:** teach the kadevecer scraper to capture poster images, or card pins stay permanently on fallback artwork.

## Basemap v2 (decided 2026-08-28, supersedes the dataviz choice above)

- **MapTiler `basic-v2` / `basic-v2-dark`** — major landmarks and street names return, far calmer than `streets-v2`. Rationale: `dataviz` was clean but anonymous; people in Skopje navigate by landmark ("the place next to Tinex"), which Findzzer gets from Apple Maps' POI layer and we had thrown away.
- **Custom MapTiler style stays the real answer** (dataviz base + major POIs re-enabled in muted grey) — still the pre-launch polish item, now with a concrete brief.
- Verify against real card pins on device before finalising: this is a look-at-it decision, not an argue-about-it one.

## Map chrome layout (decided 2026-08-28, supersedes the filter-button placement above)

The 08-21 layout put night chips + filter button + theme button in one top row; on a real phone the chips were already clipped, and Phase 2's account button would have made four controls fight for one row.

- **Top row: night chips only**, full width — no more clipping.
- **Top-right: account avatar** (Findzzer's placement; identity belongs there). `AccountButton` from Phase 2.
- **Bottom-centre: a floating "Filters · n" pill** above the sheet — thumb-reachable, and the active-filter count stays visible without opening anything. Panel contents unchanged (still doubles as the legend, still first-tap-isolates).
- **Theme switcher stops being map chrome** and moves inside the account sheet, where a rarely-touched setting belongs. One fewer button on the map.
- Right edge keeps the zoom / my-location stack.

## Detail sheet (decided 2026-08-28)

Tapping a pin opens an **expandable, scrollable sheet**: opens at ~55% with poster, title, time, venue and the action row (Directions, later Call); drag to full screen for description and all reviews. Same drag language as the event-list sheet, so the gesture is taught once and the map stays in context while browsing.

- Fixes a real bug: the 08-21 sheet is a non-scrollable `Padding`+`Column`, so `PlaceReviewsSection` would overflow off-screen.
- Hosts the Phase 2 widgets: `EventImage` as the header, `PlaceReviewsSection` at the bottom (places, and events held at a Place via `MapPin.placeId`).
- Full-screen push routes (Posh/DICE/RA pattern) rejected: they trade away map context for a bigger poster, and add a navigation concept the app doesn't otherwise need.

## Empty state & sheet peek (decided 2026-08-28)

With 3 sample events, a scraper resolving 0, and no organizers yet, **an empty night is the normal case, not an edge case** — the empty state is effectively the main screen today.

- **Peek shows a real teaser**, not a bare count: `6 tonight · next 21:00 Techno Night`.
- **Never dead-end.** An empty night shows "Nothing listed tonight" plus a one-tap jump to the next night that actually has events ("Saturday has 4 →"). Needs a small backend query for "which upcoming nights have events".
- **The vices layer is the empty-state filler**: no party tonight still means bars, night shops and hookah places are open nearby. Our sparsest moment becomes the thing no competitor can answer.
- A swipeable card carousel in the peek was rejected for now: with zero events an empty carousel looks more broken than a sentence. Reconsider once event density is real.
