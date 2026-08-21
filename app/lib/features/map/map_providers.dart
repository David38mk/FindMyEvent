import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/models.dart';

/// One or more consecutive Event Nights (ADR 0004) shown on the map.
class NightRange {
  const NightRange(this.from, this.to);

  final DateTime from; // date-only
  final DateTime to;

  bool get single => from == to;

  @override
  bool operator ==(Object other) =>
      other is NightRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// The Event Night happening right now: before 06:00 it's still "yesterday's"
/// night (ADR 0004).
DateTime currentEventNight() {
  var now = DateTime.now();
  if (now.hour < 6) now = now.subtract(const Duration(days: 1));
  return DateTime(now.year, now.month, now.day);
}

/// The upcoming (or in-progress) weekend as Event Nights: Fri–Sun, clamped to
/// start no earlier than tonight.
NightRange weekendRange() {
  final tonight = currentEventNight();
  if (tonight.weekday >= DateTime.friday) {
    return NightRange(
        tonight, tonight.add(Duration(days: 7 - tonight.weekday)));
  }
  final friday =
      tonight.add(Duration(days: DateTime.friday - tonight.weekday));
  return NightRange(friday, friday.add(const Duration(days: 2)));
}

final selectedNightsProvider = StateProvider<NightRange>((ref) {
  final tonight = currentEventNight();
  return NightRange(tonight, tonight);
});

/// Selected category slugs. Empty = show all (decided filter behavior).
final selectedCategoriesProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Current map viewport; pins are re-fetched when it changes (move end only,
/// so panning doesn't spam the backend).
final mapBoundsProvider = StateProvider<LatLngBounds?>((ref) => null);

final categoriesProvider = FutureProvider<List<MapCategory>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final rows = await Supabase.instance.client
      .from('categories')
      .select('slug, kind, icon, color');
  return rows.map(MapCategory.fromRow).toList();
});

final mapPinsProvider = FutureProvider<List<MapPin>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final bounds = ref.watch(mapBoundsProvider);
  if (bounds == null) return const [];
  final nights = ref.watch(selectedNightsProvider);

  final client = Supabase.instance.client;
  final viewport = {
    'min_lng': bounds.west,
    'min_lat': bounds.south,
    'max_lng': bounds.east,
    'max_lat': bounds.north,
  };
  String date(DateTime d) => d.toIso8601String().split('T').first;
  final results = await Future.wait([
    client.rpc('map_events', params: {
      ...viewport,
      'night_from': date(nights.from),
      'night_to': date(nights.to),
    }),
    client.rpc('map_places', params: viewport),
  ]);
  return [
    for (final row in results[0] as List) MapPin.event(row as Map<String, dynamic>),
    for (final row in results[1] as List) MapPin.place(row as Map<String, dynamic>),
  ];
});
