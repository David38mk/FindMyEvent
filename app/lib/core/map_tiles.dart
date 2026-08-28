import 'package:flutter/material.dart';

import 'env.dart';

/// MapTiler `basic-v2` / `basic-v2-dark` per theme (docs/DESIGN.md map tiles),
/// with the OSM demo tiles as a dev-only fallback (ADR 0001).
///
/// Extracted so a second map (the organizer venue picker) renders exactly the
/// same basemap as the main map without copying the URL template. The main
/// map screen still has its own private copy — it can adopt this one whenever
/// it is next touched.
String mapTileUrl(Brightness brightness) => Env.hasMapTiler
    ? 'https://api.maptiler.com/maps/${brightness == Brightness.dark ? 'basic-v2-dark' : 'basic-v2'}/{z}/{x}/{y}.png?key=${Env.maptilerKey}'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Strips the basemap down to greyscale before it is drawn.
///
/// The basemap carries no hue at all: parks, water and landuse become grey,
/// street names and POI labels survive untouched. That is the whole point of
/// the palette rule read from the other side — on this map, saturated colour
/// means an event, and nothing else on screen is allowed to claim it. Green
/// landuse was the worst offender, sitting almost opposite Signal Red on the
/// wheel so the two vibrated against each other.
///
/// A paint-time filter rather than a custom MapTiler style: it costs no extra
/// tile requests, works on both the light and dark style variants, and tunes
/// per theme without a redeploy.
ColorFilter basemapFilter(Brightness brightness) {
  // Dark is trimmed slightly further down so neon pins read as light sources
  // against the ground rather than stickers on top of it.
  final b = brightness == Brightness.dark ? 0.92 : 1.0;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722; // luminance weights
  return ColorFilter.matrix(<double>[
    lr * b, lg * b, lb * b, 0, 0, //
    lr * b, lg * b, lb * b, 0, 0, //
    lr * b, lg * b, lb * b, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}
