import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/env.dart';
import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_screen.dart';
import 'review_editor_sheet.dart';
import 'review_providers.dart';
import 'star_rating.dart';

/// Drop-in Reviews block for a Place detail sheet:
/// `PlaceReviewsSection(placeId: pin.id)`.
///
/// Self-contained on purpose — it fetches, renders, and writes on its own, so
/// the map screen only has to decide *where* it goes. Shows a short preview
/// inline (a detail sheet is not a review feed) with the full list one tap
/// away.
class PlaceReviewsSection extends ConsumerWidget {
  const PlaceReviewsSection({
    super.key,
    required this.placeId,
    this.previewCount = 2,
  });

  final String placeId;
  final int previewCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.hasSupabase) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(placeReviewsProvider(placeId));
    final userId = ref.watch(currentUserProvider)?.id;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: AppErrorText(l10n.reviewLoadError),
      ),
      data: (reviews) {
        final mine = reviews.mine(userId);
        final preview = reviews.reviews.take(previewCount).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.reviewsTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (reviews.count > 0) ...[
                  StarRating(
                    rating: reviews.average!,
                    semanticLabel: l10n.reviewsTitle,
                  ),
                  const SizedBox(width: 6),
                  // Numbers next to the stars: colour and shape never carry
                  // the rating alone.
                  Text(
                    '${reviews.average!.toStringAsFixed(1)} · '
                    '${l10n.reviewsCount(reviews.count)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (reviews.count == 0)
              Text(l10n.reviewsNone,
                  style: Theme.of(context).textTheme.bodySmall),
            for (final review in preview)
              _ReviewTile(
                review: review,
                placeId: placeId,
                isMine: review.userId == userId,
              ),
            if (reviews.count > preview.length)
              TextButton(
                onPressed: () => _showAllReviews(context, placeId),
                child: Text(l10n.reviewSeeAll),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit_outlined),
                label: Text(userId == null
                    ? l10n.reviewSignInPrompt
                    : (mine == null ? l10n.reviewAdd : l10n.reviewEdit)),
                onPressed: () {
                  if (userId == null) {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen()),
                    );
                    return;
                  }
                  showReviewEditor(context, placeId: placeId, existing: mine);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

void _showAllReviews(BuildContext context, String placeId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AllReviewsSheet(placeId: placeId),
  );
}

class _AllReviewsSheet extends ConsumerWidget {
  const _AllReviewsSheet({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reviews =
        ref.watch(placeReviewsProvider(placeId)).valueOrNull?.reviews ??
            const <PlaceReview>[];
    final userId = ref.watch(currentUserProvider)?.id;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(l10n.reviewsTitle,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final review in reviews)
            _ReviewTile(
              review: review,
              placeId: placeId,
              isMine: review.userId == userId,
            ),
        ],
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({
    required this.review,
    required this.placeId,
    required this.isMine,
  });

  final PlaceReview review;
  final String placeId;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = review.displayName?.trim().isNotEmpty == true
        ? review.displayName!.trim()
        : l10n.reviewAnonymous;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble(), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMine ? l10n.reviewYours : name,
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat.yMMMd(l10n.localeName).format(review.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (isMine)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.reviewEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => showReviewEditor(context,
                      placeId: placeId, existing: review),
                )
              else
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.reviewReport,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  onPressed: () => _report(context, ref),
                ),
            ],
          ),
          if (review.text != null && review.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(review.text!),
            ),
        ],
      ),
    );
  }

  /// Post-moderation: this files a flag for a Curator, it does not hide the
  /// Review (PLAN.md §4 — "report button instead of pre-moderation").
  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    if (ref.read(currentUserProvider) == null) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      );
      return;
    }
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reviewReportTitle),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.reviewReportReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reviewReportSend),
          ),
        ],
      ),
    );
    if (send != true) {
      controller.dispose();
      return;
    }
    try {
      await reportReview(ref, reviewId: review.id, reason: controller.text);
      if (context.mounted) showInfoSnack(context, l10n.reviewReportSent);
    } catch (_) {
      if (context.mounted) showErrorSnack(context, l10n.authErrorUnknown);
    } finally {
      controller.dispose();
    }
  }
}
