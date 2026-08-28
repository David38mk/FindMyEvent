import 'dart:ui';

/// "Hot City" palette (docs/DESIGN.md v3, ADR 0005): city lights on asphalt.
/// Three layers — brand (UI chrome only), status (what's happening), category
/// (pins; hexes live in the DB). UI stays Void/Asphalt/white; color = signals.
abstract final class AppPalette {
  // Brand — Signal Red. UI chrome only (CTAs, FABs, selected), NEVER on pins.
  // Hue 348: blue sits above green, which is what keeps it reading sharp red
  // rather than tomato. Warmer reds (hue > 0) go orange against the basemap.
  static const brand = Color(0xFFFF1744);
  // Errors + destructive; deeper than brand and always paired with icon+text
  // so red-as-brand and red-as-error never get confused (ADR 0005).
  static const brandDeep = Color(0xFFD5002B);

  // Status layer. Only happeningNow is wired today; the rest are RESERVED for
  // future features (keep them from being reassigned to something else).
  static const happeningNow = Color(0xFFFFE600); // Solar Yellow — NEVER bare on light: always a filled chip with near-black text
  static const trending = Color(0xFFFF9F45); // reserved (lighter than festival tangerine on purpose)
  static const soldOut = Color(0xFF9299A8); // reserved
  static const almostSoldOut = Color(0xFFFFB000); // reserved
  static const freeEntry = Color(0xFF38E8C5); // reserved

  // Night surfaces
  static const voidBg = Color(0xFF0A0A0A);
  static const asphalt = Color(0xFF171717); // cards, sheets
  static const graphite = Color(0xFF242424); // inputs, active containers

  // Light surfaces
  static const cream = Color(0xFFFFFDF8);

  // Text
  static const textPrimaryDark = Color(0xFFF4F7FB); // Almost White
  static const textSecondaryDark = Color(0xFF9299A8); // Steel
  static const textPrimaryLight = Color(0xFF1C1917);
  static const textSecondaryLight = Color(0xFF6B6560);
}
