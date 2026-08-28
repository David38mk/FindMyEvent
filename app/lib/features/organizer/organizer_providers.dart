import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/models.dart';
import '../auth/auth_providers.dart';

/// One row of `categories` with kind='event' — the only categories an
/// Organizer may submit under (places are curated, not submitted).
final eventCategoriesProvider = FutureProvider<List<EventCategory>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final rows = await Supabase.instance.client
      .from('categories')
      .select('id, slug, color')
      .eq('kind', 'event')
      .order('slug');
  return [
    for (final row in rows)
      EventCategory(
        id: row['id'] as String,
        slug: row['slug'] as String,
        color: colorFromHex(row['color'] as String),
      ),
  ];
});

class EventCategory {
  const EventCategory({required this.id, required this.slug, required this.color});

  final String id;
  final String slug;
  final Color color;
}

class Region {
  const Region({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
  });

  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
}

final regionsProvider = FutureProvider<List<Region>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final rows = await Supabase.instance.client
      .from('regions')
      .select('id, name, center_lat, center_lng');
  return [
    for (final row in rows)
      Region(
        id: row['id'] as String,
        name: row['name'] as String,
        centerLat: (row['center_lat'] as num).toDouble(),
        centerLng: (row['center_lng'] as num).toDouble(),
      ),
  ];
});

class PlaceOption {
  const PlaceOption({
    required this.id,
    required this.name,
    required this.regionId,
    this.address,
  });

  final String id;
  final String name;
  final String regionId;
  final String? address;
}

/// Venue search over active Places. `.family` keyed on the query string, so
/// each keystroke's result is cached and going back a character is instant.
final placeSearchProvider =
    FutureProvider.family<List<PlaceOption>, String>((ref, query) async {
  if (!Env.hasSupabase) return const [];
  final q = query.trim();
  var request = Supabase.instance.client
      .from('places')
      .select('id, name, address, region_id')
      .eq('active', true);
  if (q.isNotEmpty) request = request.ilike('name', '%$q%');
  final rows = await request.order('name').limit(40);
  return [
    for (final row in rows)
      PlaceOption(
        id: row['id'] as String,
        name: row['name'] as String,
        regionId: row['region_id'] as String,
        address: row['address'] as String?,
      ),
  ];
});

class EventSubmission {
  const EventSubmission({
    required this.id,
    required this.title,
    required this.status,
    required this.startsAt,
    this.categorySlug,
    this.placeName,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime startsAt;
  final String? categorySlug;
  final String? placeName;
  final String? imageUrl;
}

/// This organizer's own submissions and their statuses. Readable thanks to the
/// existing "organizers read own events" policy — no new server code needed.
final mySubmissionsProvider = FutureProvider<List<EventSubmission>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !Env.hasSupabase) return const [];
  final rows = await Supabase.instance.client
      .from('events')
      .select(
          'id, title, status, starts_at, image_url, categories(slug), places(name)')
      .eq('submitted_by', user.id)
      .order('starts_at', ascending: false);
  return [
    for (final row in rows)
      EventSubmission(
        id: row['id'] as String,
        title: row['title'] as String,
        status: row['status'] as String,
        startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
        categorySlug: (row['categories'] as Map<String, dynamic>?)?['slug'] as String?,
        placeName: (row['places'] as Map<String, dynamic>?)?['name'] as String?,
        imageUrl: row['image_url'] as String?,
      ),
  ];
});

/// Everything the organizer form collects. Kept as one object so validation
/// happens in one place and the insert below can't be called half-filled.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.categoryId,
    required this.startsAt,
    this.description,
    this.placeId,
    this.lat,
    this.lng,
    this.endsAt,
    this.imageUrl,
  });

  final String title;
  final String categoryId;
  final DateTime startsAt;
  final String? description;
  final String? placeId;
  final double? lat;
  final double? lng;
  final DateTime? endsAt;
  final String? imageUrl;
}

/// Inserts the Event exactly in the shape the RLS policy demands:
/// status='pending', source='organizer', submitted_by=auth.uid(). Nothing
/// here is a permission check — the policy is, and a client that lied about
/// any of these three fields would simply be rejected by Postgres.
Future<void> submitEvent(WidgetRef ref, EventDraft draft) async {
  final user = ref.read(currentUserProvider);
  if (user == null) throw StateError('not signed in');

  final regions = await ref.read(regionsProvider.future);
  final regionId = _resolveRegionId(
    regions: regions,
    placeRegionId: draft.placeId == null ? null : await _regionOfPlace(draft.placeId!),
    lat: draft.lat,
    lng: draft.lng,
  );

  await Supabase.instance.client.from('events').insert({
    'region_id': regionId,
    'category_id': draft.categoryId,
    'title': draft.title.trim(),
    'description': draft.description?.trim().isEmpty ?? true
        ? null
        : draft.description!.trim(),
    'place_id': draft.placeId,
    // PostGIS geography over PostgREST: EWKT is parsed by the column's own
    // input function, so no RPC wrapper is needed just to build a point.
    'geog': draft.placeId == null && draft.lat != null && draft.lng != null
        ? 'SRID=4326;POINT(${draft.lng} ${draft.lat})'
        : null,
    'starts_at': draft.startsAt.toUtc().toIso8601String(),
    'ends_at': draft.endsAt?.toUtc().toIso8601String(),
    'image_url': draft.imageUrl,
    'status': 'pending',
    'source': 'organizer',
    'submitted_by': user.id,
    // event_night is derived by a BEFORE trigger (ADR 0004) — never sent.
  });
  ref.invalidate(mySubmissionsProvider);
}

Future<String?> _regionOfPlace(String placeId) async {
  final row = await Supabase.instance.client
      .from('places')
      .select('region_id')
      .eq('id', placeId)
      .maybeSingle();
  return row?['region_id'] as String?;
}

/// A chosen Place already knows its Region; a dropped pin does not, so it
/// takes the nearest Region centre. One Region exists today (Skopje), but
/// picking the nearest is the rule that still works at Region number two.
String _resolveRegionId({
  required List<Region> regions,
  String? placeRegionId,
  double? lat,
  double? lng,
}) {
  if (placeRegionId != null) return placeRegionId;
  if (regions.isEmpty) throw StateError('no regions configured');
  if (lat == null || lng == null) return regions.first.id;
  var best = regions.first;
  var bestDistance = double.infinity;
  for (final region in regions) {
    final dLat = region.centerLat - lat;
    final dLng = region.centerLng - lng;
    final distance = dLat * dLat + dLng * dLng;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = region;
    }
  }
  return best.id;
}
