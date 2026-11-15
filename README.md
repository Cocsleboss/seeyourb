# SeeU — Flutter app (Android & iOS)

SeeU helps you keep seeing the people who matter: pick how often you want to see
each person, the app tells you when it's time, helps you plan a meeting, and
resets the counter once you've met. Friends on SeeU can share rendezvous, a
common photo gallery and a "want to see you" signal.

The full functional description (in French) is in [`description.md`](description.md); identifiers, URLs and secrets are mapped in [`docs/SETUP.md`](docs/SETUP.md);
reference screenshots are in [`docs/design/`](docs/design).

## Stack

| Layer | Choice | Why |
| --- | --- | --- |
| App | Flutter (Android + iOS), Riverpod, go_router | One codebase, native performance |
| Data | Supabase Postgres + Row Level Security | Relational data (friend graph, shared rendezvous) with per-row privacy |
| Business rules | SQL triggers & RPCs (`supabase/migrations`) | Same rules for every client, can't be bypassed |
| Server jobs | pg_cron (reminders, digest) + Edge Functions | No extra server to run |
| Push | Firebase Cloud Messaging (Android, iOS via APNs) | Only Firebase product used |
| Email fallback | Brevo or Resend | Used when no device can receive push |

```
lib/
  main.dart, app.dart        bootstrap, theme, offline screen, notification taps, quick actions
  core/                      config, theme tokens, router, push, error translation
  domain/                    pure Dart rules (dates, due states, birthdays, search, import dedupe)
  data/                      Supabase access (api.dart) + Riverpod providers
  ui/                        design kit (buttons, cards, pills, avatars, sheets, forms, rows)
  features/                  one folder per screen family (auth, home, contacts, rdv, friends, …)
supabase/
  migrations/                schema, RLS, triggers, RPCs, notifications outbox, pg_cron jobs
  functions/dispatch         delivers queued notifications (FCM, then email)
  functions/delete-account   deletes the user's files and account
test/                        domain unit tests + screen smoke tests (fake data, light/dark)
tool/                        launcher icon rendering
```

### How notifications work

1. Everything that must notify someone inserts a row in `public.notifications`
   (status `pending`) through `enqueue_notification()`:
   - **social events** come from database triggers (friend request/accept, wave,
     rendezvous invitation/response, shared rendezvous moved/validated/cancelled);
   - **reminders** come from `run_reminders()`, run every 10 minutes by pg_cron
     (daily digest at the user's hour, birthdays, reminder before a rendezvous,
     "did it happen?" follow-up).
   Rows only store a `kind` and `params`; the text is written by `dispatch` in the
   user's language and time zone (`supabase/functions/dispatch/templates.ts`).
   Mutes and blocks are applied in `enqueue_notification()`.
2. Each insert pings the `dispatch` Edge Function (pg_net); a cron job also pings it
   every minute as a safety net.
3. `dispatch` sends a push to every device of the user (FCM HTTP v1), falls back to
   email, and records the channel used (shown in Settings → Dernières notifications).

## Setup

### 1. Supabase

1. Create a project on [supabase.com](https://supabase.com).
2. Apply the migrations, either with the CLI (`supabase link --project-ref <ref>` then
   `supabase db push`) or by pasting each file of `supabase/migrations/` in order in the SQL editor.
3. In **Database → Extensions**, check that `pg_cron` and `pg_net` are enabled (the migration enables them).
4. Store two secrets in Vault (SQL editor), so the database can call the dispatcher:
   ```sql
   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
   select vault.create_secret('<a long random string>', 'dispatch_secret');
   ```
5. **Authentication → URL Configuration**: add `seeu://auth-callback` to the redirect URLs
   (used by confirmation emails, magic links and password reset).
6. Deploy the functions and their secrets:
   ```sh
   supabase functions deploy dispatch --no-verify-jwt
   supabase functions deploy delete-account
   supabase secrets set DISPATCH_SECRET='<same random string as above>'
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat firebase-service-account.json)"
   # optional email fallback
   supabase secrets set EMAIL_FROM='SeeU <hello@your-domain>' BREVO_API_KEY=...   # or RESEND_API_KEY=...
   ```

### 2. Firebase (push notifications)

The app runs without Firebase; push is simply unavailable until it's configured.

1. Create a Firebase project, add an **Android app** and an **iOS app**, both with the id `com.seeuapp.mobile`.
2. Download `google-services.json` → `android/app/` and `GoogleService-Info.plist` → `ios/Runner/`.
   Both files are git-ignored; the Xcode project already references `Runner/GoogleService-Info.plist`,
   so a fresh clone needs that file before building iOS.
3. iOS push needs a paid Apple Developer account (free "Personal Team" signing cannot use the
   Push Notifications capability). Until then the app runs on the simulator and on your iPhone,
   without push. When you have the account:
   - Xcode → Runner target → Signing & Capabilities: choose the team, add **Push Notifications**
     (Background Modes → Remote notifications is already declared in `Info.plist`);
   - developer.apple.com → Keys → new key with **APNs** → upload the `.p8` in
     Firebase → Project settings → Cloud Messaging (with its Key ID and your Team ID).
4. Firebase → Project settings → Service accounts → *Generate new private key*: that JSON is
   the `FCM_SERVICE_ACCOUNT` secret above.

### 3. Run the app

Requirements: Flutter 3.47+, Android SDK 37, Xcode 26.
`firebase_core` / `firebase_messaging` are pinned to 4.15.0 / 16.7.0 (Firebase iOS SDK 12.19.0)
because the current releases (Firebase iOS SDK 13) need Xcode 26.2+. After updating Xcode,
you can move to `firebase_core ^5` / `firebase_messaging ^17`.


```sh
cp config/env.example.json config/env.json   # fill SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
flutter pub get
flutter run --dart-define-from-file=config/env.json
```

Release builds: `flutter build appbundle --dart-define-from-file=config/env.json` and
`flutter build ipa --dart-define-from-file=config/env.json` (after setting up signing).

### Tests

```sh
flutter analyze
flutter test                                    # domain rules + every screen in light/dark
flutter test test/screens_test.dart --update-goldens   # also writes screenshots to test/goldens/
```

The SQL is validated against a throw-away PostgreSQL 17 (social flow, events and
visibility, timeslots, chat RLS, mutes/blocks, reminders): see `supabase/tests/README.md`.

Translations: edit `tool/i18n/strings/*.txt`, then
`python3 tool/i18n/build_arb.py && flutter gen-l10n`.

## Before the first store release

- **App id** is `com.seeuapp.mobile` on both platforms (`app.seeu` and `com.seeuapp.seeu` were already taken on Apple's side).
- **Share links** use the `seeu://` scheme, which most messaging apps don't make clickable.
  Set up a domain with Android App Links / iOS Universal Links and pass it as `SHARE_LINK_BASE`
  (and `APP_DOWNLOAD_URL` for invitations to people without the app).
- **Android signing**: replace the debug signing config in `android/app/build.gradle.kts`.
- **Icons**: `flutter test tool/render_icon_test.dart && dart run flutter_launcher_icons`
  regenerates the launcher icons from the logo drawn in `lib/ui/logo.dart`. Afterwards check
  `git diff ios/Runner.xcodeproj`: the tool rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
  to `AppIcon`, which makes Xcode 27 refuse to open the project. Set it back to `YES`.

## Notes for later

- Push uses FCM registration tokens. `firebase_messaging` 17+ deprecates them in favour of
  Firebase Installation IDs; when upgrading, migrate `lib/core/push.dart` and
  `supabase/functions/dispatch` together.
- `run_reminders()` scans the profiles due for their daily digest every 10 minutes. With a
  very large user base, store a precomputed `next_digest_at` (indexed) instead.
- Lists are loaded per user and refreshed after each change, when the app resumes and when a
  push arrives. Only the event chat is live (Supabase Realtime).
- Notifications to the members of a very large public event (chat announcements, date changes)
  are queued in one transaction by a trigger. Past a few thousand participants, move that
  fan-out to a background job.
