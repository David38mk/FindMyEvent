# 5. "Hot City" brand identity — Signal Red, three color layers

Date: 2026-08-21

## Status

Accepted

## Context

The first two palettes (amber v1, David's amber-refinement v2) were competent
Material systems but read as "a normal app with colored categories" — no point
of view. David researched nightlife/event brand systems (DICE's high-energy
multi-color identity, festival branding, recent nightlife UI concepts) and
proposed three directions: "After Dark Playground" (Electric Blue #635BFF),
"Hot City" (Signal Red), and "Electric Underground" (Ultraviolet).

Deliberation: Electric Blue sits in the most colonized hue in tech (Stripe,
Discord) and returns to the purple-blue lane every event competitor occupies.
Ultraviolet is premium but over-promises electronic music for an app that also
maps standup, bars, and betting shops. Signal Red is unclaimed in the event
space, reads as urgency and city energy, and pairs with a Solar Yellow
"happening now" signal — the one feature no incumbent surfaces.

## Decision

**Hot City locked.** Structure matters more than hexes — three color layers:

1. **Brand** — Signal Red `#FF1744`. UI chrome only (CTAs, FABs, selected
   states). Never on map pins.
2. **Status** — what's happening: Solar Yellow `#FFE600` = Happening Now
   (live today); Trending `#FF9F45`, Sold Out, Almost Sold Out, Free = reserved
   tokens for future features.
3. **Category** — pin colors, DB-owned: party `#FF3D81`, concert `#8F5BFF`,
   standup `#19D3C5`, festival `#FF7A00`; places stay muted slate `#64748B`.

Surfaces: Void `#0A0A0A` / Asphalt `#171717` / Graphite `#242424` dark;
Cream `#FFFDF8` light. UI stays near-monochrome; color is the signal layer,
like lights in a dark club.

Guardrails accepted with the decision:

- Errors use Deep Red `#D5002B` + always icon+text, never bare color, so
  red-as-brand and red-as-error stay distinguishable.
- Solar Yellow never appears bare on light surfaces — always a filled chip
  with near-black text.
- Trending was deliberately shifted lighter (`#FF9F45`) so it can't collide
  with festival tangerine `#FF7A00`.

## Consequences

- Brand identity is now a real decision, not a placeholder — store assets,
  icon, and marketing build on Signal Red. Reversing later = rebrand.
- The amber era (v1–v2) is fully superseded; `AppPalette` in
  `app/lib/core/palette.dart` is the single app-side source of truth.
- The red-error discipline is a standing constraint on all future form work
  (Phase 2 organizer form especially).
- Palette leans toward the "Vajb" name candidate energy-wise; name decision
  (PLAN.md §5.7) still open.

## Amendment — 2026-08-28: Signal Red re-hued

Status: accepted. The three-layer structure and every other token stand; only
the two brand hexes move.

Seen on device, `#FF3B30` read orange rather than red. It is measurably warm:
green sits 11 points above blue, and red mixed toward green is orange. On the
map that lean was amplified by the green landuse behind the pins.

| Token | Was | Now | Hue |
| --- | --- | --- | --- |
| `brand` | `#FF3B30` | `#FF1744` | 3° → 348° |
| `brandDeep` | `#D91F26` | `#D5002B` | 358° → 348° |

Deep Red moved with it. Left at `#D91F26` it would have been *warmer* than the
brand it is supposed to be a deeper shade of, so the two would have read as
unrelated reds instead of one family. Both now sit at 348°, differing only in
depth — which is what the original guardrail intended.

Contrast consequences: white on `brand` is 3.9:1 (was 3.6:1) — still large-text
only, which is all it is used for. White on `brandDeep` is 5.4:1, clearing AA
for body text, so error text is safe at any size.

`#FF3B30` was also Apple's system red; the app ships Android-first, so that
association was never load-bearing either way.
