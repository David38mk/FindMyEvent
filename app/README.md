# FindMyEvent app (working title)

Flutter app. See root [PLAN.md](../PLAN.md) for product plan, [HANDOFF.md](../HANDOFF.md) for team log.

## Run

Supabase keys are injected at build time and never committed. Get the project URL + publishable key from the Supabase dashboard (Settings → API) — ask sinanmarkic.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

App boots without the defines too (map placeholder, no data) — fine for UI work.

## Rules

- **No hardcoded UI strings.** Every user-visible string goes in `lib/l10n/app_en.arb` + `app_mk.arb`, used via `AppLocalizations.of(context)`. Generated code lands in `lib/l10n/` on build (gitignored).
- Structure: `lib/core/` (env, shared infra), `lib/features/<feature>/` (screens + state per feature).
- Package id is a placeholder until the app name is decided (PLAN.md §5.7) — frozen at first store upload.
