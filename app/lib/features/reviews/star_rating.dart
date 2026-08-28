import 'package:flutter/material.dart';

/// 1–5 stars, read-only or tappable.
///
/// Filled stars use Signal Red (`colorScheme.primary`) — ADR 0005 puts brand
/// colour on selected states, and the reserved Solar Yellow means "happening
/// now", not "rated". The shape (filled vs outlined star) carries the value on
/// its own, so the colour is decoration; callers pair it with the numeric
/// average in text.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.onRatingChanged,
    this.semanticLabel,
  });

  final double rating;
  final double size;
  final ValueChanged<int>? onRatingChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final interactive = onRatingChanged != null;
    return Semantics(
      label: semanticLabel,
      value: rating.toStringAsFixed(1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: interactive ? () => onRatingChanged!(i) : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: interactive ? 4 : 1),
                child: Icon(
                  // Half star at the .5 mark so a 4.5 average doesn't round
                  // away the half the user can plainly see in the numbers.
                  rating >= i
                      ? Icons.star
                      : (rating >= i - 0.5 ? Icons.star_half : Icons.star_border),
                  size: interactive ? size * 1.6 : size,
                  color: rating >= i - 0.5
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
