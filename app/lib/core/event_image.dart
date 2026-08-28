import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Event photo for a detail sheet or list row. Renders nothing at all when the
/// event has no image — most scraped events don't — so callers can drop it in
/// unconditionally without a null check of their own.
///
/// Uses cached_network_image (already a dependency, for map tiles): an event
/// photo re-opened from the same list should not be re-downloaded.
class EventImage extends StatelessWidget {
  const EventImage({
    super.key,
    required this.url,
    this.height = 160,
    this.borderRadius = 12,
  });

  final String? url;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: source,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        // A broken image URL must never push the rest of the sheet around.
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
