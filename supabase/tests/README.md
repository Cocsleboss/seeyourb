# SQL scenario tests

Runs the migrations on a throw-away PostgreSQL 17 (no Docker needed) and prints
the result of every check (`ok`, counts, notifications queued…).

```sh
mkdir -p /tmp/seeu-pg && cd /tmp/seeu-pg
npm init -y >/dev/null && npm i embedded-postgres pg
cp <repo>/supabase/tests/run.mjs .
M=<repo>/supabase/migrations; T=<repo>/supabase/tests
node run.mjs /tmp/seeu-pg/db $T/00_stubs.sql $M/20261115000001_init.sql \
  $M/20261115000002_notifications.sql $M/20261116000003_categories_rsvp.sql \
  $T/10_fixture_before_0004.sql $M/20261117000004_events_social.sql $T/20_events_social.sql \
  $M/20261118000005_availability_guests.sql $M/20261119000006_event_guests.sql \
  $T/40_event_guests.sql $M/20261119000007_leave_event.sql $T/50_leave_event.sql \
  $M/20261120000008_profiles_places_friends.sql $T/60_profiles_places_friends.sql $M/20261120000009_no_emails.sql \
  $M/20261121000010_event_status.sql $T/70_event_status.sql \
  $M/20261122000011_no_reminder.sql $T/80_no_reminder.sql \
  $T/30_availability_guests.sql \
  $M/20261123000012_moderation.sql $M/20261123000013_public_profiles.sql $M/20261123000014_travel_hints.sql \
  $T/90_visibility_profiles.sql $T/91_travel_hints.sql $T/92_moderation.sql \
  $M/20261124000015_event_links.sql $T/93_event_links.sql
```

- `90_visibility_profiles.sql`: the three event visibility levels (RPCs and RLS), the public
  profile (only allowed fields, never a private / friends event, nothing when off), the profile
  page in the app, server-only profile columns.
- `91_travel_hints.sql`: who lives near a place far from home, the hourly push (once, reset on a
  new place, `notify_travel`).
- `92_moderation.sql`: reports (own only, no admin columns), admin RPCs refused to others,
  ban effects (hidden everywhere, requests refused), sessions and `admin_stats()`.

- `93_event_links.sql`: invitation links (token format, preview for a stranger and for the
  website, joining, organizer notified, renew / revoke, guests' links follow "guests can invite"),
  removing a member (no way back by the link), a friend's page lists shared private events,
  unfriending keeps the ex-friend as themselves in the event, cards default to no reminder.

Each file creates its own users; run 90 → 91 → 92 → 93 in that order (92 bans and unbans).

`00_stubs.sql` fakes what Supabase provides (auth.uid(), storage, vault). pg_cron and
pg_net must be available as (fake) extensions in the embedded server: add `pg_net.control` /
`pg_cron.control` + `--1.0.sql` scripts creating `net.http_post(...)` and `cron.job`,
`cron.schedule(...)`, `cron.unschedule(...)` in
`node_modules/@embedded-postgres/<platform>/native/share/postgresql/extension/`. Any line
printing `WRONG` or `NO ERROR` is a failed expectation (`20_events_social` → `c_posts` prints
`NO ERROR` because its insert selects no row; `c_posts_by_id` right after is the real check).
