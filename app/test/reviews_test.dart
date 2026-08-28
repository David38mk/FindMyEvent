import 'package:flutter_test/flutter_test.dart';

import 'package:findmyevent/features/reviews/review_providers.dart';

PlaceReview _review({
  required String id,
  required String userId,
  required int rating,
}) =>
    PlaceReview(
      id: id,
      userId: userId,
      rating: rating,
      createdAt: DateTime(2026, 8, 28),
    );

void main() {
  group('PlaceReviews summary', () {
    test('no reviews has no average', () {
      const reviews = PlaceReviews([]);
      expect(reviews.count, 0);
      expect(reviews.average, isNull);
    });

    test('average is the mean of the ratings', () {
      final reviews = PlaceReviews([
        _review(id: 'a', userId: 'u1', rating: 5),
        _review(id: 'b', userId: 'u2', rating: 4),
        _review(id: 'c', userId: 'u3', rating: 3),
      ]);
      expect(reviews.count, 3);
      expect(reviews.average, closeTo(4.0, 0.0001));
    });

    test('mine finds the signed-in user own review, and nothing when signed out',
        () {
      final reviews = PlaceReviews([
        _review(id: 'a', userId: 'u1', rating: 5),
        _review(id: 'b', userId: 'u2', rating: 2),
      ]);
      expect(reviews.mine('u2')?.id, 'b');
      expect(reviews.mine('nobody'), isNull);
      // Anonymous browsing is the default (PLAN.md §5.4) — a null user id must
      // never accidentally match a review.
      expect(reviews.mine(null), isNull);
    });
  });

  test('PlaceReview.fromRow reads the RPC column names', () {
    final review = PlaceReview.fromRow({
      'id': 'r1',
      'user_id': 'u1',
      'rating': 4,
      // place_reviews() renames reviews.text to review_text.
      'review_text': 'Great sound system',
      'created_at': '2026-08-28T20:00:00Z',
      'display_name': 'Ana',
    });
    expect(review.rating, 4);
    expect(review.text, 'Great sound system');
    expect(review.displayName, 'Ana');
  });
}
