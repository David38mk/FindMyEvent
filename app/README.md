# FindMyEvent app (working title)

Flutter app. See root [PLAN.md](../PLAN.md) for product plan, [HANDOFF.md](../HANDOFF.md) for team log.

## Run

```sh
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` holds the Supabase URL + **publishable** key. Both are public by design (they ship inside the app binary; RLS protects the data), so the file is committed. The **secret** key (`sb_secret_...`) must NEVER appear in this repo or in any client code — it bypasses RLS entirely.

App boots without the defines too (map placeholder, no data) — fine for UI work.

## Google sign-in — NOT WORKING YET (human setup required)

Email+password sign-in works as soon as the app runs. **Google sign-in is built but
the button stays hidden until `GOOGLE_WEB_CLIENT_ID` is defined** (`Env.hasGoogleSignIn`),
because the OAuth clients do not exist yet. To turn it on:

1. **Google Cloud console** → create (or reuse) a project → *APIs & Services → Credentials*.
2. Create an **OAuth client ID of type "Web application"**. Copy its client ID → this is
   `GOOGLE_WEB_CLIENT_ID`. It is the token *audience*; Android and Supabase both need it.
3. Create an **OAuth client ID of type "Android"**:
   - Package name: `com.findmyevent.findmyevent` (the placeholder id — must be re-created
     if the package id changes at store upload, PLAN.md §5.7).
   - SHA-1: `cd android && ./gradlew signingReport` (or
     `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`).
     Add the **debug** SHA-1 now and the **release/Play App Signing** SHA-1 before launch —
     an APK signed with a key Google doesn't know about fails with a bare "sign in failed".
   - This client has no ID string to copy; it is matched by package + SHA-1.
4. (iOS, when that ships) create an **iOS** OAuth client → its client ID is
   `GOOGLE_IOS_CLIENT_ID`, and its reversed form goes into `Info.plist` as a URL scheme.
5. **Supabase dashboard** → *Authentication → Providers → Google*: enable it, and put the
   **web client ID** in "Client IDs" (the *Authorized Client IDs* list — native sign-in
   validates the ID token against it; no client secret is needed for the native flow).
6. Add the IDs to `dart_defines.json` (public-by-design identifiers, safe to commit —
   the client *secret* is not, and this flow never needs one):

   ```json
   "GOOGLE_WEB_CLIENT_ID": "...apps.googleusercontent.com",
   "GOOGLE_IOS_CLIENT_ID": "...apps.googleusercontent.com"
   ```

## Password reset deep link — human setup required

`resetPasswordForEmail` sends a link pointing at
`com.findmyevent.findmyevent://login-callback/` (registered in `AndroidManifest.xml`).
Add that exact URI to **Supabase → Authentication → URL Configuration → Redirect URLs**,
otherwise the email link opens the Site URL in a browser and the in-app
"set a new password" screen is never reached.

## Rules

- **No hardcoded UI strings.** Every user-visible string goes in `lib/l10n/app_en.arb` + `app_mk.arb`, used via `AppLocalizations.of(context)`. Generated code lands in `lib/l10n/` on build (gitignored).
- Structure: `lib/core/` (env, shared infra), `lib/features/<feature>/` (screens + state per feature).
- Package id is a placeholder until the app name is decided (PLAN.md §5.7) — frozen at first store upload.
