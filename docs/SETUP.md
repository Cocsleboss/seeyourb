# SeeU — Configuration reference

Everything that ties the app, Supabase and Firebase together: identifiers, URLs,
secrets (names and where they live, **never their values**), and how the pieces talk.
Setup instructions are in the [README](../README.md); this page is the map.

## 1. Identifiers

| What | Value | Where it is set |
| --- | --- | --- |
| App name | SeeU | `android/app/src/main/AndroidManifest.xml` (`android:label`), `ios/Runner/Info.plist` (`CFBundleDisplayName`) |
| Android package / applicationId | `com.seeuapp.mobile` | `android/app/build.gradle.kts` (`namespace`, `applicationId`), Kotlin package `android/app/src/main/kotlin/com/seeuapp/mobile/` |
| iOS bundle ID | `com.seeuapp.mobile` | Xcode → Runner target (`PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj`) |
| iOS test target bundle ID | `com.seeuapp.mobile.RunnerTests` | same file |
| Apple development team | `52HGFA36M9` (free Personal Team for now) | Xcode → Signing & Capabilities (`DEVELOPMENT_TEAM`) |
| Dart package name | `seeu` | `pubspec.yaml` (internal only, never shown to users) |
| Supabase project | **SeeU**, ref `klqzmegiydmwtmxfguvl`, region eu-central-1 | supabase.com dashboard; local link in `supabase/.temp/` (git-ignored) |
| Supabase URL | `https://klqzmegiydmwtmxfguvl.supabase.co` | `config/env.json`, Vault secret `project_url` |
| Firebase project | **SeeU**, id `seeu-94040` | console.firebase.google.com |
| Firebase Android app | `com.seeuapp.mobile` | `android/app/google-services.json` |
| Firebase iOS app | `com.seeuapp.mobile` | `ios/Runner/GoogleService-Info.plist` |

> Rejected IDs, kept for history: `app.seeu` and `com.seeuapp.seeu` were already
> registered by someone else at Apple.

## 2. URLs and deep links

The app owns the custom URL scheme **`seeu://`**
(Android: intent filter in `AndroidManifest.xml`; iOS: `CFBundleURLTypes` in `Info.plist`).

| URL | Used for | Configured in |
| --- | --- | --- |
| `seeu://auth-callback` | Sign-up confirmation, magic link, password reset emails: Supabase redirects here after verifying the link, the app exchanges the code for a session (PKCE) | `config/env.json` → `AUTH_REDIRECT`; Supabase → Authentication → URL Configuration (**Site URL** and **Redirect URLs**) |
| `seeu://app/friends?q=<username>` | "Ajoute-moi sur SeeU : @andrea" share links: opens the Friends tab with the search prefilled | `config/env.json` → `SHARE_LINK_BASE` (`seeu://app`) |
| `https://seeu.app` (placeholder) | "Envoyer le lien de l'app" to people without the app | `config/env.json` → `APP_DOWNLOAD_URL` |
| `https://klqzmegiydmwtmxfguvl.supabase.co/functions/v1/dispatch` | Called by the database to deliver notifications | built from Vault `project_url` in `request_dispatch()` |
| `https://fcm.googleapis.com/v1/projects/seeu-94040/messages:send` | Push sending (FCM HTTP v1) | built from `FCM_SERVICE_ACCOUNT.project_id` in the `dispatch` function |

In-app paths (also used as notification targets): `/`, `/contacts`, `/contacts/<id>`,
`/contacts/new`, `/contacts/import`, `/rdv/new?contact=<id>`, `/rdv/<id>`, `/friends`,
`/history`, `/settings`.

> Before the public launch: custom schemes aren't clickable in most messaging apps.
> Get a domain, set up Android App Links + iOS Universal Links, and point
> `SHARE_LINK_BASE` / `APP_DOWNLOAD_URL` (and the auth redirect, optionally) to it.

## 3. Secrets and config files

| Name | Contains | Lives in | In git? |
| --- | --- | --- | --- |
| `config/env.json` | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (public by design), `AUTH_REDIRECT`, `SHARE_LINK_BASE`, `APP_DOWNLOAD_URL` | your machine; template `config/env.example.json` | No |
| `android/app/google-services.json` | Firebase Android client config | your machine | No |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS client config (the Xcode project references it: needed to build iOS) | your machine | No |
| Vault `project_url` | Supabase URL, so the DB can call Edge Functions | Supabase → Vault | — |
| Vault `dispatch_secret` | Shared secret DB → `dispatch` function | Supabase → Vault | — |
| Function secret `DISPATCH_SECRET` | Same value as Vault `dispatch_secret` | Supabase → Edge Functions → Secrets | — |
| Function secret `FCM_SERVICE_ACCOUNT` | Firebase service account JSON (`firebase-adminsdk-…`) | Supabase → Edge Functions → Secrets | — |
| Function secrets `EMAIL_FROM` + `BREVO_API_KEY` or `RESEND_API_KEY` | Email fallback for notifications | not set yet | — |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Admin access inside functions | provided automatically by Supabase | — |

Never put the Supabase **secret / service_role** key or the Firebase service account in the app.

## 4. How the pieces connect

```
                         ┌──────────────────────────── Supabase (SeeU) ────────────────────────────┐
  Flutter app            │                                                                          │
  (Android / iOS)        │  Auth ──────── emails ──► user ──► seeu://auth-callback ──► app          │
   │                     │                                                                          │
   │ supabase_flutter    │  Postgres (RLS on every table)                                           │
   ├────────────────────►│   tables · triggers · RPCs (friends, shared rdv, waves, invitations)     │
   │  queries / RPC      │        │ social events (triggers)      pg_cron every 10 min              │
   │                     │        ▼                               run_reminders()                   │
   │                     │   notifications (outbox, status pending → sent) ◄──┘                     │
   │                     │        │ pg_net (on insert + every minute)                               │
   │  storage (photos)   │        ▼                                                                 │
   ├────────────────────►│   Edge Function dispatch ──► FCM HTTP v1 ──┐   (fallback: email)         │
   │                     │   Edge Function delete-account             │                            │
   │                     └────────────────────────────────────────────┼────────────────────────────┘
   │                                                                  ▼
   │  register_device(token)                      Firebase Cloud Messaging (seeu-94040)
   └── firebase_messaging ◄──────── push ──────────  Android direct · iOS via APNs (needs paid Apple account)
```

- **Auth**: email + password, magic link, password reset; PKCE flow; sessions stored on device.
- **Data**: every query goes through Row Level Security; sharing between friends only through
  `SECURITY DEFINER` functions (`send_friend_request`, `send_rdv_invite`, `respond_rdv_invite`, …).
- **Photos**: private bucket `photos`, one folder per user (`<user_id>/<random>.jpg`), read through
  signed URLs (1 h). Shared rendezvous photos are readable by the other participants (storage policy
  `photos_storage_select_shared`).
- **Push tokens**: the app calls `register_device(token, platform)`; tokens are stored in
  `device_tokens`; `dispatch` deletes tokens FCM reports as invalid.
- **Scheduled jobs** (pg_cron): `seeu-reminders` (`*/10 * * * *`) and `seeu-dispatch` (`* * * * *`).

## 5. Platform accounts

| Service | What it's used for | Status |
| --- | --- | --- |
| Supabase | Database, auth, storage, Edge Functions, cron | ✅ configured (incl. auth redirect URLs) |
| Firebase | Push only (Cloud Messaging) | ✅ Android + iOS apps registered, service account set |
| Apple Developer (free Personal Team) | Running on your iPhone (7-day signing) | ✅ |
| Apple Developer Program (paid) | iOS push (APNs key), TestFlight, App Store | ❌ not yet |
| Google Play Console | Android release | ❌ not yet |
| Email provider (Brevo / Resend) | Notification email fallback, and custom SMTP for auth emails (Supabase's built-in mailer is rate-limited) | ❌ not yet |

## 6. Still to do

- [x] Supabase → Authentication → URL Configuration: Site URL + Redirect URL `seeu://auth-callback`.
- [ ] Paid Apple account → Xcode: add **Push Notifications** capability; developer.apple.com → APNs key
      (`.p8`) → upload in Firebase → Project settings → Cloud Messaging (Key ID + Team ID).
- [ ] Email provider: `EMAIL_FROM` + API key as function secrets; custom SMTP in Supabase Auth.
- [ ] Domain for share links / App Links / Universal Links.
- [ ] Android release signing (replace the debug signing config in `android/app/build.gradle.kts`).
