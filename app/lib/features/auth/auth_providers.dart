import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => const AuthService());

/// Live session stream. supabase_flutter persists the session itself and
/// replays it on start-up, so watching this provider IS "session restore" —
/// no manual token bookkeeping.
final authStateProvider = StreamProvider<AuthState?>((ref) {
  if (!Env.hasSupabase) return Stream<AuthState?>.value(null);
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// The signed-in user, or null. Rebuilds on every auth event.
final currentUserProvider = Provider<User?>((ref) {
  if (!Env.hasSupabase) return null;
  // Watched purely for invalidation: currentUser is a synchronous snapshot,
  // the stream is what tells us it changed.
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

final isSignedInProvider = Provider<bool>((ref) => ref.watch(currentUserProvider) != null);

/// Roles live in profiles.role (PLAN.md §3), created by the handle_new_user
/// trigger. Never trusted for authorization — RLS decides that server-side;
/// this only chooses what UI to show.
enum AppRole { user, organizer, curator }

class UserProfile {
  const UserProfile({required this.userId, required this.role, this.displayName});

  final String userId;
  final AppRole role;
  final String? displayName;

  bool get canSubmitEvents => role == AppRole.organizer || role == AppRole.curator;

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
        userId: row['user_id'] as String,
        role: switch (row['role'] as String?) {
          'organizer' => AppRole.organizer,
          'curator' => AppRole.curator,
          _ => AppRole.user,
        },
        displayName: row['display_name'] as String?,
      );
}

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final row = await Supabase.instance.client
      .from('profiles')
      .select('user_id, role, display_name')
      .eq('user_id', user.id)
      .maybeSingle();
  return row == null ? null : UserProfile.fromRow(row);
});

/// Status of this user's Organizer access request, or null if never asked.
final organizerRequestProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final row = await Supabase.instance.client
      .from('organizer_requests')
      .select('status')
      .eq('user_id', user.id)
      .maybeSingle();
  return row?['status'] as String?;
});

Future<void> requestOrganizerAccess(WidgetRef ref, String note) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  await Supabase.instance.client.from('organizer_requests').insert({
    'user_id': user.id,
    'note': note.trim().isEmpty ? null : note.trim(),
    'status': 'pending',
  });
  ref.invalidate(organizerRequestProvider);
}
