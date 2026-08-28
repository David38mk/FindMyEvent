import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../l10n/app_localizations.dart';
import 'account_sheet.dart';
import 'auth_providers.dart';
import 'auth_screen.dart';
import 'update_password_screen.dart';

/// The one auth entry point for the map: signed out it opens [AuthScreen],
/// signed in it opens the account menu.
///
/// Shaped like the map's other top-row controls (Card + IconButton) so it
/// drops in next to the filter/theme buttons without touching their code.
/// Also the app's password-recovery listener — it is mounted for the whole
/// session, which is exactly what that deep link needs.
class AccountButton extends ConsumerStatefulWidget {
  const AccountButton({super.key});

  @override
  ConsumerState<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends ConsumerState<AccountButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(isSignedInProvider);

    // Recovery links land as an auth event, not a route: supabase_flutter
    // consumes the deep link itself and only tells us the session is now a
    // recovery session. Pushing the screen from here is the whole handoff.
    ref.listen(authStateProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery && mounted) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const UpdatePasswordScreen()),
        );
      }
    });

    return Card(
      margin: EdgeInsets.zero,
      child: IconButton(
        tooltip: signedIn ? l10n.authAccount : l10n.authSignIn,
        icon: Icon(signedIn ? Icons.person : Icons.person_outline),
        onPressed: !Env.hasSupabase
            ? null
            : () {
                if (signedIn) {
                  showAccountSheet(context);
                } else {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                  );
                }
              },
      ),
    );
  }
}
