import '../../l10n/app_localizations.dart';
import 'auth_service.dart';

/// [AuthFailure] → localized text. Kept out of AuthService so the service
/// stays UI-free, and out of the widgets so every screen says the same thing.
String authFailureText(AppLocalizations l10n, Object error) {
  final failure =
      error is AuthFailureException ? error.failure : AuthFailure.unknown;
  return switch (failure) {
    AuthFailure.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthFailure.emailAlreadyRegistered => l10n.authErrorEmailInUse,
    AuthFailure.weakPassword => l10n.authErrorWeakPassword,
    AuthFailure.emailNotConfirmed => l10n.authErrorEmailNotConfirmed,
    AuthFailure.rateLimited => l10n.authErrorRateLimited,
    AuthFailure.network => l10n.authErrorNetwork,
    AuthFailure.cancelled => l10n.authErrorCancelled,
    AuthFailure.googleNotConfigured => l10n.authErrorGoogleUnavailable,
    AuthFailure.notConfigured => l10n.authErrorNotConfigured,
    AuthFailure.unknown => l10n.authErrorUnknown,
  };
}
