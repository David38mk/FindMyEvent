import 'dart:ui';

enum PinKind { event, place }

/// One pin on the map — an Event or a Place, flattened from the viewport RPCs.
class MapPin {
  const MapPin({
    required this.id,
    required this.title,
    required this.categorySlug,
    required this.color,
    required this.lat,
    required this.lng,
    required this.kind,
    this.subtitle,
    this.description,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String title;
  final String categorySlug;
  final Color color;
  final double lat;
  final double lng;
  final PinKind kind;

  /// Place name for events, address for places.
  final String? subtitle;

  /// Free-text description. Events only for now — places have no
  /// description column in the schema yet (PLAN.md §3).
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory MapPin.event(Map<String, dynamic> row) => MapPin(
        id: row['id'] as String,
        title: row['title'] as String,
        categorySlug: row['category_slug'] as String,
        color: colorFromHex(row['category_color'] as String),
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        kind: PinKind.event,
        subtitle: row['place_name'] as String?,
        description: row['description'] as String?,
        startsAt: DateTime.tryParse(row['starts_at'] as String? ?? '')?.toLocal(),
        endsAt: DateTime.tryParse(row['ends_at'] as String? ?? '')?.toLocal(),
      );

  factory MapPin.place(Map<String, dynamic> row) => MapPin(
        id: row['id'] as String,
        title: row['name'] as String,
        categorySlug: row['category_slug'] as String,
        color: colorFromHex(row['category_color'] as String),
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        kind: PinKind.place,
        subtitle: row['address'] as String?,
      );
}

/// Category as stored in the `categories` table; labels are localized
/// client-side by slug (see categoryLabel in map_screen.dart).
class MapCategory {
  const MapCategory({
    required this.slug,
    required this.kind,
    required this.icon,
    required this.color,
  });

  final String slug;
  final String kind; // 'event' | 'place'

  /// Material icon name string (e.g. 'local_bar') — mapped to IconData
  /// client-side; used as the white glyph on place pins.
  final String icon;
  final Color color;

  factory MapCategory.fromRow(Map<String, dynamic> row) => MapCategory(
        slug: row['slug'] as String,
        kind: row['kind'] as String,
        icon: row['icon'] as String,
        color: colorFromHex(row['color'] as String),
      );
}

/// '#RRGGBB' → Color. Categories own their colors in the DB (single source of
/// truth shared with any future web/admin UI).
Color colorFromHex(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
