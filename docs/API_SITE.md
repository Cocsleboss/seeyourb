# SeeU — Backend for the website (step 2)

Everything the website (public pages + admin) may use. It talks to Supabase with the
**publishable (anon) key** only, plus the signed-in admin's session for `/admin`.
**Never** put the `service_role` key in the site. The site calls the RPCs below and
nothing else: no direct table access (RLS would refuse most of it anyway).

Defined in migrations `0012_moderation`, `0013_public_profiles`, `0014_travel_hints`;
tested in `supabase/tests/90_*`, `91_*`, `92_*`. Database reference: [`DATABASE.md`](DATABASE.md).

```js
import { createClient } from '@supabase/supabase-js'
const sb = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY)
const { data: profile } = await sb.rpc('get_public_profile', { p_username: 'andrea' })
if (!profile) notFound()   // null = unknown, disabled or banned: never say which
```

## 1. Public pages (anonymous)

### `get_public_profile(p_username text) → jsonb | null`

Page `/u/<username>`. Accepts `andrea`, `@andrea`, `Andrea`. Returns `null` when the
username doesn't exist, the user hasn't turned their public profile on, or the account
is banned. Otherwise **only the fields the user chose** (others are `null`):

| Field | Type | When filled |
| --- | --- | --- |
| `username` | text | always (it's the page address) |
| `display_name` | text \| null | user ticked "Nom affiché" |
| `avatar_path` | text \| null | user ticked "Photo de profil" |
| `city`, `country` | text \| null | user ticked "Ville de résidence" |
| `bio` | text \| null | user ticked "Bio" (≤ 300 chars) |
| `events` | array | see below; `[]` when the user shows none |

`events[]` — only events whose visibility is **`public`**, planned (not cancelled),
starting from 6 hours ago onwards, that the user organizes or is going to, and that the user
chose to show (all of them, or the ones ticked one by one). At most 20, by date.
`contacts` and `private` events never appear, even if ticked.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | link to `/e/<id>` |
| `title`, `location` | text \| null | |
| `starts_at` | timestamptz | ISO, UTC |
| `going` | int | organizer + people going |
| `role` | `organizer` \| `going` | the profile owner's role |
| `organizer_name` | text | |

Never returned: email, user id, contacts, friends, birthday, settings.

Profile picture URL (public bucket, unguessable file name):
`${SUPABASE_URL}/storage/v1/object/public/avatars/${avatar_path}`.

### `get_public_event(p_event uuid) → jsonb | null`

Page `/e/<id>`. `null` unless the event's visibility is `public` and its organizer isn't
banned (a malformed id raises `22P02`: treat it as not found).

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `title`, `description`, `location` | | |
| `starts_at` | timestamptz | |
| `status` | `planifie` \| `valide` \| `annule` | planned / happened / cancelled |
| `going` | int | |
| `link` | text \| null | organizer's web link (http/https only) |
| `lat`, `lng` | float \| null | place picked on a map |
| `organizer_name` | text | |
| `organizer_username` | text \| null | only when the organizer's public profile is on (link to `/u/…`) |

Participants are never exposed to anonymous visitors.

## 2. Links and deep links

| URL | App route | Notes |
| --- | --- | --- |
| `https://<domain>/u/<username>` | `/u/:username` (profile page in the app) | "Copier le lien", "Partager", QR code in the app |
| `https://<domain>/e/<event id>` | `/event/:id` (event preview, join) | shared from an event's ⋯ menu (public and "Entre amis" events) |
| `https://<domain>/friends?q=<username>` | Contacts tab, friend search | older shares, still handled |

- The app builds links from `SHARE_LINK_BASE` (`config/env.json`, no trailing slash):
  today `seeu://app`; set it to `https://<domain>` once the site is live.
- **App installed** (and the domain verified): the OS opens the app directly on that page.
- **Signed out**: the app remembers the destination (2 days, survives a restart while
  confirming the email), opens the sign-up screen with a banner ("Créez votre compte pour
  retrouver @andrea…"), then goes to the profile / event once the account is ready.
- **App not installed**: no deferred deep link yet. The site shows the page, the store
  buttons (`APP_DOWNLOAD_URL`) and "Après l'installation, rouvrez ce lien" (or a QR code of the
  same URL). Optional later: pass the path in the Play Store `referrer` parameter.

### Files to serve

Generated in [`deeplinks/.well-known/`](../deeplinks/README.md); serve them **as is**,
HTTPS, status 200, `Content-Type: application/json`, **no redirect**:

| File | URL |
| --- | --- |
| `assetlinks.json` | `https://<domain>/.well-known/assetlinks.json` |
| `apple-app-site-association` (no extension) | `https://<domain>/.well-known/apple-app-site-association` |

Placeholders to fill before launch (Android signing fingerprints, Apple Team ID) and the
app-side settings (`seeu.linkHost` in `android/gradle.properties`, Associated Domains in
Xcode) are listed in [`deeplinks/README.md`](../deeplinks/README.md).

## 3. Admin

### Who is admin

Accounts listed in `public.admins` (no app or site access to that table). In the SQL editor:

```sql
insert into public.admins (user_id, note)
select id, 'who / why' from public.profiles where username = 'their_username';
-- remove: delete from public.admins where user_id = (select id from public.profiles where username = 'their_username');
```

A banned admin loses the role. Admins can't be banned (remove them from `admins` first).

The site signs the admin in with Supabase Auth (email + password, same accounts as the app),
then checks **`is_admin() → boolean`** server-side; anything else → 403. Every `admin_*` RPC
checks the role again and raises `seeu:not_admin` otherwise (anonymous calls: `permission denied`).

### RPCs

All `security definer`, callable with the admin's session. Lists accept `p_limit`
(max 200, or 100 for users) and `p_offset`, and return `total_count` (rows matching, for pagination).

| RPC | Returns | Notes |
| --- | --- | --- |
| `is_admin()` | boolean | false for anonymous / non-admins |
| `admin_stats(p_tz text = 'Europe/Paris')` | jsonb | dashboard tiles, §3.1 |
| `admin_stats_daily(p_days int = 30, p_tz text = 'Europe/Paris')` | rows `day date, new_users int, active_users int, sessions int` | oldest first, max 366 days, for the curves |
| `admin_list_reports(p_status text = 'pending', p_reported_user uuid = null, p_report_id uuid = null, p_limit int = 50, p_offset int = 0)` | report rows, §3.2 | `p_status`: `pending` \| `reviewed` \| `dismissed` \| `actioned` \| `all`; newest first |
| `admin_get_report(p_id uuid)` | jsonb (same fields as a row) \| null | |
| `admin_update_report(p_id uuid, p_status text, p_note text = null)` | void | sets the status; a non-empty `p_note` replaces the admin note; logs `report_status` (or `report_note` if the status is unchanged) |
| `admin_ban_user(p_user uuid, p_reason text, p_report uuid = null)` | void | reason required (`seeu:reason_required`); marks `p_report` as `actioned`; logs `ban` |
| `admin_unban_user(p_user uuid, p_note text = null)` | void | logs `unban` |
| `admin_search_users(p_query text = null, p_limit int = 30, p_offset int = 0)` | rows `user_id, username, display_name, avatar_path, created_at, last_seen_at, banned_at, is_admin, reports_received, total_count` | username prefix or display-name substring; empty query = newest accounts |
| `admin_get_user(p_user uuid)` | jsonb, §3.3 | the "fiche utilisateur" |
| `admin_list_actions(p_limit int = 50, p_offset int = 0, p_user uuid = null)` | rows `id, created_at, action, admin_id, admin_username, target_user, target_username, report_id, details, total_count` | the moderation log; `p_user` filters on the target |

Every admin action is logged automatically in `public.admin_actions` (who, what, when,
details): the site doesn't write the log itself.

#### 3.1 `admin_stats()` keys

| Key | Meaning |
| --- | --- |
| `sessions_today` | app sessions started since midnight (`p_tz`). A session = the app open with gaps under 30 min |
| `total_users` | all accounts (banned included) |
| `active_today` | accounts with activity since midnight |
| `new_users_today` | accounts created since midnight |
| `active_7d` (WAU), `active_30d` (MAU) | accounts active in the last 7 / 30 days |
| `reports_pending` | reports with status `pending` |
| `banned_accounts` | accounts currently banned |
| `concurrent_now` | approximation of simultaneous users: active in the last 5 minutes |
| `generated_at`, `timezone`, `day_start` | context |

Activity comes from the app (`touch_session()` at launch, on resume, every 4 min while open).
History starts when migration 0012 is deployed and the new app version is installed.
To add a metric: add a key in `admin_stats()` (new migration, `create or replace`) and a tile on the site.

#### 3.2 Report rows (`admin_list_reports`, `admin_get_report`)

| Field | Notes |
| --- | --- |
| `id`, `created_at`, `updated_at`, `status`, `reason`, `comment` | `reason`: `spam` \| `harassment` \| `inappropriate` \| `fake_profile` \| `other` |
| `admin_note`, `reviewed_at`, `reviewed_by`, `reviewed_by_username` | |
| `target_type` | `user` \| `event` \| `photo` \| `message` |
| `event_id`, `photo_id`, `message_id` | null once the content is deleted |
| `snapshot` | jsonb kept at report time: `reported {username, display_name, avatar_path}` + event `{title, description, location, at, visibility}` or message `{message, message_at}` or photo `{storage_path, thumb_path, caption}` |
| `reporter_id`, `reporter_username`, `reporter_name` | the reporter is never shown to the reported person |
| `reported_user_id`, `reported_username`, `reported_name`, `reported_banned_at` | |
| `reported_reports_total`, `reported_reports_pending` | reports this person received |
| `total_count` | |

Reported photo: the `photos` bucket is private; with the admin's session,
`sb.storage.from('photos').createSignedUrl(snapshot.storage_path, 3600)` works for
reported photos only (storage policy `photos_storage_select_reported`).

#### 3.3 `admin_get_user(p_user)`

```jsonc
{
  "profile": { /* the whole profiles row: id, username, display_name, email, created_at,
                  last_seen_at, banned_at, banned_reason, home_city, public_profile, … */ },
  "is_admin": false,
  "status": "active",            // or "banned"
  "counts": { "friends", "friend_requests_pending", "contacts", "events_created", "events_joined",
              "messages", "photos", "reports_received", "reports_received_pending", "reports_sent",
              "sessions_30d" },
  "recent_reports": [ { "id", "created_at", "status", "reason", "target_type", "reporter_username" } ],  // last 10 received
  "recent_actions": [ { "id", "created_at", "action", "admin_username", "details" } ]                  // last 20 on this user
}
```

The account email is included for support; show it only inside `/admin`.

### What a ban does

`admin_ban_user` → `profiles.banned_at` set, `auth.users.banned_until` set (sign-in refused,
sessions revoked), every API request of that account refused (`seeu:banned`, PostgREST
pre-request hook), and the account disappears everywhere: search, feeds, events and their
participants, friends lists, avatars, public profile and public events (`get_public_*` → null).
The app shows "Compte suspendu". `admin_unban_user` reverses all of it.

## 4. Errors

RPCs raise `seeu:<code>` in the message:

| Code | When |
| --- | --- |
| `not_admin` | admin RPC without the role |
| `reason_required` | ban without a reason |
| `cannot_ban_admin` | banning an admin or oneself |
| `user_not_found`, `report_not_found` | unknown id |
| `bad_answer` | invalid status / reason value |
| `banned` | any request made by a banned account |

## 5. App-side RPCs (for reference, not for the site)

`report_content`, `get_user_profile`, `people_near`, `touch_session`: see [`DATABASE.md`](DATABASE.md) §6.
