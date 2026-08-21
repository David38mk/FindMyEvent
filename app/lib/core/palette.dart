import 'dart:ui';

/// App-side palette tokens (docs/DESIGN.md, David's v2 — 2026-08-21).
/// Category pin colors are NOT here — they live in the DB (`categories.color`)
/// so curators can retune them without an app release.
abstract final class AppPalette {
  static const brand = Color(0xFFFFB000); // Electric Amber: CTAs, FABs, selected, badges, Happening Now
  static const amberLight = Color(0xFFFFD166); // highlights, secondary emphasis
  static const midnightBg = Color(0xFF121212); // dark background
  static const elevatedSurface = Color(0xFF1C1B1A); // dark cards, sheets
  static const raisedSurface = Color(0xFF292725); // dark inputs, active containers
  static const warmLightBg = Color(0xFFFAF9F6); // light background
  static const danger = Color(0xFFFF5C5C); // errors, urgent states
  static const textPrimaryDark = Color(0xFFF5F3EF);
  static const textSecondaryDark = Color(0xFFAAA6A0);
  static const textPrimaryLight = Color(0xFF1C1917);
  static const textSecondaryLight = Color(0xFF6B6560);
}
