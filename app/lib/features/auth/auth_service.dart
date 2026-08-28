import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';

/// Why an auth call failed, in OUR vocabulary rather than the server's.
///
/// Supabase returns English prose in `AuthException.message`; showing it would
/// break the zero-hardcoded-strings rule for Macedonian users. Errors are
/// classified here and localized at the widget layer (see auth_errors.dart).
enum AuthFailure {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  emailNotConfirmed,
  rateLimited,
  network,
  cancelled,
  googleNotConfigured,
  notConfigured,
  unknown,
}

class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthFailureException($failure)';
}

/// All Supabase Auth calls in one place: email+password, Google, sign-out,
/// password reset. Thin on purpose — state lives in Riverpod providers
/// (auth_providers.dart), this only performs actions and normalizes errors.
class AuthService {
  const AuthService();

  static const _googleScopes = <String>['email', 'profile'];
  static bool _googleInitialized = false;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  User? get currentUser => Env.hasSupabase ? _auth.currentUser : null;

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _guard(() => _auth.signUp(
          email: email.trim(),
          password: password,
          // Picked up by the handle_new_user trigger, which copies it into
          // profiles.display_name — that's what review authors show as.
          data: {'display_name': displayName.trim()},
        ));
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _guard(() => _auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ));
  }

  Future<void> signOut() async {
    await _guard(() async {
      if (Env.hasGoogleSignIn && _googleInitialized) {
        // Best effort: clearing the Google session too means the next sign-in
        // shows the account chooser instead of silently reusing one account.
        try {
          await GoogleSignIn.instance.signOut();
        } on GoogleSignInException {
          // Not fatal — the Supabase session is what actually signs us out.
        }
      }
      await _auth.signOut();
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await _guard(() => _auth.resetPasswordForEmail(
          email.trim(),
          // Deep link back into the app; the scheme is registered in
          // AndroidManifest.xml and must be allow-listed in Supabase Auth
          // → URL Configuration (see app/README.md).
          redirectTo: _passwordResetRedirect,
        ));
  }

  Future<void> updatePassword(String password) async {
    await _guard(
        () => _auth.updateUser(UserAttributes(password: password)));
  }

  static const _passwordResetRedirect =
      'com.findmyevent.findmyevent://login-callback/';

  /// Native Google sign-in: the Google SDK hands us an ID token, Supabase
  /// exchanges it for a session. Chosen over the browser OAuth redirect flow
  /// because it uses the account already on the device — no browser hop, and
  /// no redirect-URL round trip to get wrong on mobile.
  Future<void> signInWithGoogle() async {
    if (!Env.hasSupabase) throw const AuthFailureException(AuthFailure.notConfigured);
    if (!Env.hasGoogleSignIn) {
      throw const AuthFailureException(AuthFailure.googleNotConfigured);
    }
    await _guard(() async {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize(
          // iOS/macOS identify the app by their own client id; Android has no
          // client id string at all and authenticates by package + SHA-1,
          // needing only the web client id as the token audience.
          clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
          serverClientId: Env.googleWebClientId,
        );
        _googleInitialized = true;
      }
      if (!google.supportsAuthenticate()) {
        throw const AuthFailureException(AuthFailure.googleNotConfigured);
      }
      final account = await google.authenticate(scopeHint: _googleScopes);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailureException(AuthFailure.unknown);
      }
      // Supabase only needs the access token when the ID token carries an
      // at_hash claim; asking for it is cheap and harmless when it doesn't.
      GoogleSignInClientAuthorization? authorization;
      try {
        authorization = await account.authorizationClient
                .authorizationForScopes(_googleScopes) ??
            await account.authorizationClient.authorizeScopes(_googleScopes);
      } on GoogleSignInException {
        authorization = null;
      }
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );
    });
  }

  /// Single funnel where every backend error becomes an [AuthFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    if (!Env.hasSupabase) {
      throw const AuthFailureException(AuthFailure.notConfigured);
    }
    try {
      return await action();
    } on AuthFailureException {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailureException(AuthFailure.network);
    } on AuthException catch (e) {
      throw AuthFailureException(_classify(e));
    } on GoogleSignInException catch (e) {
      throw AuthFailureException(switch (e.code) {
        GoogleSignInExceptionCode.canceled => AuthFailure.cancelled,
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          AuthFailure.googleNotConfigured,
        _ => AuthFailure.unknown,
      });
    }
  }

  AuthFailure _classify(AuthException e) => switch (e.code) {
        'invalid_credentials' => AuthFailure.invalidCredentials,
        'user_already_exists' ||
        'email_exists' =>
          AuthFailure.emailAlreadyRegistered,
        'weak_password' => AuthFailure.weakPassword,
        'email_not_confirmed' => AuthFailure.emailNotConfirmed,
        'over_email_send_rate_limit' ||
        'over_request_rate_limit' =>
          AuthFailure.rateLimited,
        _ => AuthFailure.unknown,
      };
}
