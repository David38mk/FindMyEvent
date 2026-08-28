import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../auth/auth_providers.dart';

class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.userId,
    required this.rating,
    required this.createdAt,
    this.text,
    this.displayName,
  });

  final String id;
  final String userId;
  final int rating;
  final DateTime createdAt;
  final String? text;
  final String? displayName;

  factory PlaceReview.fromRow(Map<String, dynamic> row) => PlaceReview(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        rating: (row['rating'] as num).toInt(),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        // The RPC renames reviews.text to review_text: an OUT parameter called
        // `text` shadows the type name inside the function body.
        text: row['review_text'] as String?,
        displayName: row['display_name'] as String?,
      );
}

/// All Reviews for one Place plus the derived summary. The average is computed
/// here rather than server-side because the section that shows it has already
/// loaded every row — a second round trip would buy nothing.
class PlaceReviews {
  const PlaceReviews(this.reviews);

  final List<PlaceReview> reviews;

  int get count => reviews.length;

  double? get average => reviews.isEmpty
      ? null
      : reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;

  PlaceReview? mine(String? userId) {
    if (userId == null) return null;
    for (final review in reviews) {
      if (review.userId == userId) return review;
    }
    return null;
  }
}

/// `.family` on placeId: several Places can be open in sequence and each keeps
/// its own cached list.
final placeReviewsProvider =
    FutureProvider.family<PlaceReviews, String>((ref, placeId) async {
  if (!Env.hasSupabase) return const PlaceReviews([]);
  // Rebuild after sign-in/out so "your review" and the edit affordances follow
  // the session.
  ref.watch(currentUserProvider);
  final rows = await Supabase.instance.client
      .rpc('place_reviews', params: {'p_place_id': placeId}) as List;
  return PlaceReviews([
    for (final row in rows) PlaceReview.fromRow(row as Map<String, dynamic>),
  ]);
});

/// One Review per User per Place is a DB constraint (unique(place_id,user_id)),
/// so writing is an upsert on that pair — "edit mine" and "leave one" are the
/// same operation and can't race into a duplicate.
Future<void> saveReview(
  WidgetRef ref, {
  required String placeId,
  required int rating,
  String? text,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) throw StateError('not signed in');
  await Supabase.instance.client.from('reviews').upsert({
    'place_id': placeId,
    'user_id': user.id,
    'rating': rating,
    'text': text == null || text.trim().isEmpty ? null : text.trim(),
  }, onConflict: 'place_id,user_id');
  ref.invalidate(placeReviewsProvider(placeId));
}

Future<void> deleteReview(WidgetRef ref, String placeId) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  await Supabase.instance.client
      .from('reviews')
      .delete()
      .eq('place_id', placeId)
      .eq('user_id', user.id);
  ref.invalidate(placeReviewsProvider(placeId));
}

/// Post-moderation (PLAN.md §4): reporting flags a Review for a Curator, it
/// does not hide it. Reporting twice hits unique(review_id, reporter_id) —
/// treated as success, since the user's intent is already recorded.
Future<void> reportReview(
  WidgetRef ref, {
  required String reviewId,
  String? reason,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) throw StateError('not signed in');
  try {
    await Supabase.instance.client.from('review_reports').insert({
      'review_id': reviewId,
      'reporter_id': user.id,
      'reason': reason == null || reason.trim().isEmpty ? null : reason.trim(),
    });
  } on PostgrestException catch (e) {
    if (e.code != '23505') rethrow; // 23505 = unique_violation
  }
}
