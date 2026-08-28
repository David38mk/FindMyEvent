import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import 'review_providers.dart';
import 'star_rating.dart';

/// Write or edit the signed-in User's single Review for a Place.
Future<void> showReviewEditor(
  BuildContext context, {
  required String placeId,
  PlaceReview? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      // Lifts the sheet above the keyboard; without this the comment field is
      // hidden by it on most phones.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReviewEditor(placeId: placeId, existing: existing),
    ),
  );
}

class _ReviewEditor extends ConsumerStatefulWidget {
  const _ReviewEditor({required this.placeId, this.existing});

  final String placeId;
  final PlaceReview? existing;

  @override
  ConsumerState<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends ConsumerState<_ReviewEditor> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _text =
      TextEditingController(text: widget.existing?.text ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_rating < 1) {
      setState(() => _error = l10n.reviewRatingRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await saveReview(
        ref,
        placeId: widget.placeId,
        rating: _rating,
        text: _text.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showInfoSnack(context, l10n.reviewSaved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.reviewSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reviewDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await deleteReview(ref, widget.placeId);
      if (!mounted) return;
      Navigator.of(context).pop();
      showInfoSnack(context, l10n.reviewDeleted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.reviewSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? l10n.reviewAdd : l10n.reviewEdit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(l10n.reviewYourRating,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Center(
              child: StarRating(
                rating: _rating.toDouble(),
                semanticLabel: l10n.reviewYourRating,
                onRatingChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _rating = value;
                          _error = null;
                        }),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(labelText: l10n.reviewComment),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AppErrorText(_error!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.reviewDelete),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.reviewSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
