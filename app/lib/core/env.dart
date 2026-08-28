/// Build-time configuration, injected via --dart-define.
/// Keys are never committed to the repo (see app/README.md).
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static const maptilerKey = String.fromEnvironment('MAPTILER_KEY');

  static bool get hasMapTiler => maptilerKey.isNotEmpty;

  /// Google OAuth client IDs for native Google sign-in (google_sign_in +
  /// Supabase signInWithIdToken). Public-by-design identifiers, not secrets —
  /// but they don't exist yet, so the Google button hides itself until the
  /// human creates them (see app/README.md § Google sign-in).
  ///
  /// Android needs only the WEB client id (passed as `serverClientId`); the
  /// Android OAuth client is matched by package name + SHA-1, never by string.
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get hasGoogleSignIn => googleWebClientId.isNotEmpty;
}
