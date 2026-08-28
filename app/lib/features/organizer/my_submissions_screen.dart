import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_labels.dart';
import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import 'add_event_screen.dart';
import 'organizer_providers.dart';

/// An Organizer's own submissions and where each one stands in the approval
/// queue. Without this the form is a black hole — you submit and never learn
/// whether a Curator approved it.
class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final submissions = ref.watch(mySubmissionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.organizerMySubmissions)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.organizerAddEvent),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddEventScreen()),
        ),
      ),
      body: submissions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorText(l10n.pinsLoadError),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.organizerNoSubmissions,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(mySubmissionsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _SubmissionCard(submission: list[index]),
                ),
              ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission});

  final EventSubmission submission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final imageUrl = submission.imageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: 140,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        submission.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: submission.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (submission.categorySlug != null)
                      categoryLabel(l10n, submission.categorySlug!),
                    DateFormat.yMMMEd(l10n.localeName)
                        .add_Hm()
                        .format(submission.startsAt),
                    if (submission.placeName != null) submission.placeName!,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status is icon + text, never colour alone (ADR 0005 red-brand discipline —
/// and "rejected" is exactly the case where colour-only would be worst).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (status) {
      'approved' => (
          Icons.check_circle_outline,
          l10n.organizerStatusApproved,
          scheme.onSurface,
        ),
      'rejected' => (
          Icons.cancel_outlined,
          l10n.organizerStatusRejected,
          scheme.error,
        ),
      _ => (
          Icons.hourglass_top_outlined,
          l10n.organizerStatusPending,
          scheme.onSurfaceVariant,
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
