# FindMyEvent app (working title)

Flutter app. See root [PLAN.md](../PLAN.md) for product plan, [HANDOFF.md](../HANDOFF.md) for team log.

## Run

```sh
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` holds the Supabase URL + **publishable** key. Both are public by design (they ship inside the app binary; RLS protects the data), so the file is committed. The **secret** key (`sb_secret_...`) must NEVER appear in this repo or in any client code — it bypasses RLS entirely.

App boots without the defines too (map placeholder, no data) — fine for UI work.

## Rules

- **No hardcoded UI strings.** Every user-visible string goes in `lib/l10n/app_en.arb` + `app_mk.arb`, used via `AppLocalizations.of(context)`. Generated code lands in `lib/l10n/` on build (gitignored).
- Structure: `lib/core/` (env, shared infra), `lib/features/<feature>/` (screens + state per feature).
- Package id is a placeholder until the app name is decided (PLAN.md §5.7) — frozen at first store upload.
