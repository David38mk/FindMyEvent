import 'package:flutter/material.dart';

import 'env.dart';

/// MapTiler `dataviz` / `dataviz-dark` per theme (docs/DESIGN.md map tiles),
/// with the OSM demo tiles as a dev-only fallback (ADR 0001).
///
/// Extracted so a second map (the organizer venue picker) renders exactly the
/// same basemap as the main map without copying the URL template. The main
/// map screen still has its own private copy — it can adopt this one whenever
/// it is next touched.
String mapTileUrl(Brightness brightness) => Env.hasMapTiler
    ? 'https://api.maptiler.com/maps/${brightness == Brightness.dark ? 'dataviz-dark' : 'dataviz'}/{z}/{x}/{y}.png?key=${Env.maptilerKey}'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
