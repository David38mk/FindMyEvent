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

1. **Brand** — Signal Red `#FF3B30`. UI chrome only (CTAs, FABs, selected
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

- Errors use Deep Red `#D91F26` + always icon+text, never bare color, so
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
