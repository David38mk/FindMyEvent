import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/models.dart';

/// The day the map shows events for (Daily Time Scope; Monthly/Yearly = Phase 2).
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
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
      .select('slug, kind, color');
  return rows.map(MapCategory.fromRow).toList();
});

final mapPinsProvider = FutureProvider<List<MapPin>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final bounds = ref.watch(mapBoundsProvider);
  if (bounds == null) return const [];
  final day = ref.watch(selectedDayProvider);

  final client = Supabase.instance.client;
  final viewport = {
    'min_lng': bounds.west,
    'min_lat': bounds.south,
    'max_lng': bounds.east,
    'max_lat': bounds.north,
  };
  final results = await Future.wait([
    client.rpc('map_events', params: {
      ...viewport,
      'day': day.toIso8601String().split('T').first,
    }),
    client.rpc('map_places', params: viewport),
  ]);
  return [
    for (final row in results[0] as List) MapPin.event(row as Map<String, dynamic>),
    for (final row in results[1] as List) MapPin.place(row as Map<String, dynamic>),
  ];
});
