import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import '../organizer/add_event_screen.dart';
import '../organizer/my_submissions_screen.dart';
import 'auth_errors.dart';
import 'auth_providers.dart';

/// The signed-in menu: who you are, what your role lets you do, and the way
/// out. A bottom sheet rather than a screen — it is a menu, not a destination,
/// and the map behind it stays the app.
void showAccountSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final requestStatus = ref.watch(organizerRequestProvider).valueOrNull;

    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                profile?.displayName?.isNotEmpty == true
                    ? profile!.displayName!
                    : (user.email ?? l10n.authAccount),
              ),
              subtitle: Text(
                '${user.email ?? ''} · ${_roleLabel(l10n, profile?.role)}',
              ),
            ),
            const Divider(height: 1),
            if (profile?.canSubmitEvents ?? false) ...[
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined),
                title: Text(l10n.organizerAddEvent),
                onTap: () => _replaceWith(context, const AddEventScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(l10n.organizerMySubmissions),
                onTap: () => _replaceWith(context, const MySubmissionsScreen()),
              ),
            ] else
              _OrganizerRequestTile(status: requestStatus),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.authSignOut),
              onTap: () async {
                final navigator = Navigator.of(context);
                final messengerContext = context;
                try {
                  await ref.read(authServiceProvider).signOut();
                  if (navigator.mounted) navigator.pop();
                } catch (e) {
                  if (!messengerContext.mounted) return;
                  showErrorSnack(
                      messengerContext, authFailureText(l10n, e));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Close the menu, then open the destination on the root navigator — a
  /// screen pushed from inside a modal sheet would be trapped under it.
  void _replaceWith(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

String _roleLabel(AppLocalizations l10n, AppRole? role) => switch (role) {
      AppRole.organizer => l10n.authRoleOrganizer,
      AppRole.curator => l10n.authRoleCurator,
      _ => l10n.authRoleUser,
    };

/// Plain Users can ask to become Organizers; a Curator flips the row in the
/// Supabase dashboard and a trigger promotes profiles.role in the same
/// transaction (migration 20260828132139).
class _OrganizerRequestTile extends ConsumerWidget {
  const _OrganizerRequestTile({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (status == 'pending') {
      return ListTile(
        leading: const Icon(Icons.hourglass_top_outlined),
        title: Text(l10n.authRequestOrganizerPending),
      );
    }
    if (status == 'rejected') {
      return ListTile(
        leading: Icon(Icons.block_outlined,
            color: Theme.of(context).colorScheme.error),
        title: Text(
          l10n.authRequestOrganizerRejected,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: Text(l10n.authRequestOrganizer),
      onTap: () => _ask(context, ref),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.authRequestOrganizer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.authRequestOrganizerBody),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration:
                  InputDecoration(labelText: l10n.authRequestOrganizerNote),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.authRequestOrganizerSend),
          ),
        ],
      ),
    );
    if (send != true) {
      controller.dispose();
      return;
    }
    try {
      await requestOrganizerAccess(ref, controller.text);
      if (context.mounted) {
        showInfoSnack(context, l10n.authRequestOrganizerSent);
      }
    } catch (_) {
      if (context.mounted) showErrorSnack(context, l10n.authErrorUnknown);
    } finally {
      controller.dispose();
    }
  }
}
