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
  $M/20261120000008_profiles_places_friends.sql $T/60_profiles_places_friends.sql \
  $T/30_availability_guests.sql
```

`00_stubs.sql` fakes what Supabase provides (auth.uid(), storage, vault). pg_cron and
pg_net must be available as (fake) extensions in the embedded server; any line
printing `WRONG` or `NO ERROR` is a failed expectation.
