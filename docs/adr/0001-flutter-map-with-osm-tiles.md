# ADR 0001 — flutter_map + OpenStreetMap tiles instead of Google Maps

Date: 2026-08-17
Status: accepted (revisit if user answers say otherwise)

## Context

The app is map-first. Flutter offers two mainstream map routes:

1. `google_maps_flutter` — polished, familiar look, but requires a Google Cloud billing account with a credit card from day one, has per-load pricing after the free credit, and API keys per platform.
2. `flutter_map` — pure-Dart Leaflet-style widget, works with any raster tile server (OpenStreetMap, MapTiler, Stadia). No billing account, no native SDK setup, markers/clustering via plugins.

Team is two hobbyist devs, zero budget, single city (Skopje). OSM coverage of Skopje is good.

## Decision

Use `flutter_map` with OSM-compatible tiles (start with a free MapTiler/Stadia key to respect OSM tile-usage policy for production apps).

## Consequences

- No billing setup, no vendor lock-in; tile provider is swappable by changing one URL.
- Map looks less "Google-polished"; no built-in Places/POI data — fine, since our POIs are our own data.
- If the app later needs turn-by-turn navigation or Google POI search, that becomes a new decision (deep-link to Google/Apple Maps covers 90% of it cheaply).
