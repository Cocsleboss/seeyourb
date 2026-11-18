-- =====================================================================
--  SeeU — migration 0012: moderation, admins, activity
--  * Bans: profiles.banned_at / banned_reason. A banned account
--      - can't sign in again (auth.users.banned_until, sessions revoked),
--      - gets every API request refused (PostgREST pre-request hook,
--        error "seeu:banned", the app shows a clear screen),
--      - disappears for everyone: is_blocked() now counts a ban as a block
--        in both directions (search, feeds, events, participants, avatars,
--        notifications, friend requests); list_friends() hides them too.
--  * Reports: report_content() from the app (user, event, photo or message);
--    a reporter sees their own reports, never anyone else's.
--  * Admins: public.admins (managed in the SQL editor) + admin_* RPCs
--    (security definer, role checked first), every action logged in
--    public.admin_actions. Called by the website (step 2, docs/API_SITE.md).
--  * Activity: profiles.last_seen_at + public.app_sessions, written by
--    touch_session() from the app; admin_stats() / admin_stats_daily().
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Profile fields only the server writes
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists banned_at timestamptz,
  add column if not exists banned_reason text,
  add column if not exists last_seen_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_banned_reason_length') then
    alter table public.profiles add constraint profiles_banned_reason_length check (char_length(banned_reason) <= 500);
  end if;
end
$$;

create index if not exists idx_profiles_last_seen on public.profiles(last_seen_at);
create index if not exists idx_profiles_created on public.profiles(created_at);
create index if not exists idx_profiles_banned on public.profiles(banned_at) where banned_at is not null;

-- profiles_update_own lets a user change their own row: these columns stay
-- out of reach of the API (direct calls run as "authenticated"; security
-- definer functions run as their owner and may change them).
create or replace function public.profiles_guard_server_fields()
returns trigger
language plpgsql
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.banned_at := null;
    new.banned_reason := null;
    new.last_seen_at := null;
    new.created_at := now();
    return new;
  end if;
  if new.banned_at is distinct from old.banned_at
     or new.banned_reason is distinct from old.banned_reason
     or new.last_seen_at is distinct from old.last_seen_at
     or new.created_at is distinct from old.created_at then
    raise exception 'seeu:forbidden_field';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_guard_server_fields on public.profiles;
create trigger trg_profiles_guard_server_fields
  before insert or update on public.profiles
  for each row execute function public.profiles_guard_server_fields();

-- ---------------------------------------------------------------------
-- 2. A ban hides the account everywhere
-- ---------------------------------------------------------------------
create or replace function public.is_banned(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_user is not null and exists (select 1 from public.profiles where id = p_user and banned_at is not null)
$$;
revoke execute on function public.is_banned(uuid) from public, anon, authenticated;

-- Blocked = one blocked the other, or one of them is banned.
create or replace function public.is_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_a is not null and p_b is not null and (
    exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = p_a and b.blocked_id = p_b) or (b.blocker_id = p_b and b.blocked_id = p_a)
    )
    or exists (select 1 from public.profiles p where p.id in (p_a, p_b) and p.banned_at is not null)
  )
$$;
revoke execute on function public.is_blocked(uuid, uuid) from public, anon, authenticated;

create or replace function public.list_friends()
returns table (
  friendship_id uuid, user_id uuid, username text, display_name text,
  status text, incoming boolean, created_at timestamptz, contact_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, p.id, p.username,
         coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'),
         f.status,
         f.addressee_id = auth.uid(),
         f.created_at,
         case when f.requester_id = auth.uid() then f.requester_contact_id else f.addressee_contact_id end
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where auth.uid() in (f.requester_id, f.addressee_id)
    and p.banned_at is null
  order by f.created_at desc
$$;
revoke execute on function public.list_friends() from public, anon;
grant execute on function public.list_friends() to authenticated;

-- Every PostgREST request (tables and RPCs) of a banned account is refused.
-- Kept tiny: one primary-key lookup, nothing for anonymous requests.
create or replace function public.seeu_pre_request()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is not null and exists (select 1 from public.profiles where id = v_uid and banned_at is not null) then
    raise exception 'seeu:banned';
  end if;
end;
$$;
grant execute on function public.seeu_pre_request() to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticator') then
    begin
      execute 'alter role authenticator set pgrst.db_pre_request = ''public.seeu_pre_request''';
    exception when others then
      raise notice 'pre-request hook not set (%): banned accounts are still hidden and blocked at sign-in', sqlerrm;
    end;
  end if;
end
$$;

-- Sign-in side of a ban: GoTrue refuses banned_until in the future; existing
-- sessions are revoked so the refresh token stops working. Skipped quietly
-- where the auth schema differs (tests).
create or replace function public.set_auth_ban(p_user uuid, p_banned boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    execute 'update auth.users set banned_until = $1 where id = $2'
      using (case when p_banned then now() + interval '100 years' end), p_user;
    if p_banned then
      execute 'delete from auth.sessions where user_id = $1' using p_user;
    end if;
  exception when undefined_column or undefined_table or insufficient_privilege then
    raise notice 'auth ban not applied: %', sqlerrm;
  end;
end;
$$;
revoke execute on function public.set_auth_ban(uuid, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Admins (no app access: managed in the SQL editor, see docs/SETUP.md)
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.admins a join public.profiles p on p.id = a.user_id
    where a.user_id = auth.uid() and p.banned_at is null
  )
$$;
revoke execute on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- First line of every admin RPC: returns the admin's id or raises seeu:not_admin.
create or replace function public.require_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'seeu:not_admin';
  end if;
  return auth.uid();
end;
$$;
revoke execute on function public.require_admin() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Reports
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null default 'user' check (target_type in ('user', 'event', 'photo', 'message')),
  event_id uuid references public.events(id) on delete set null,
  photo_id uuid references public.photos(id) on delete set null,
  message_id uuid references public.event_messages(id) on delete set null,
  reason text not null check (reason in ('spam', 'harassment', 'inappropriate', 'fake_profile', 'other')),
  comment text check (char_length(comment) <= 1000),
  -- what was reported, as it was at that moment (kept if the content is deleted)
  snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed', 'actioned')),
  admin_note text check (char_length(admin_note) <= 2000),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (reporter_id is distinct from reported_user_id)
);
create index if not exists idx_reports_status on public.reports(status, created_at desc);
create index if not exists idx_reports_reported on public.reports(reported_user_id, created_at desc);
create index if not exists idx_reports_reporter on public.reports(reporter_id, created_at desc);
alter table public.reports enable row level security;

drop policy if exists "reports_select_own" on public.reports;
create policy "reports_select_own" on public.reports
  for select using ((select auth.uid()) = reporter_id);
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own" on public.reports
  for insert with check ((select auth.uid()) = reporter_id);
-- (no update / delete policy: only admins change reports, through RPCs)

-- Reporters never read the moderation columns (admin_note, reviewed_by, snapshot).
revoke all on public.reports from anon, authenticated;
grant select (id, reporter_id, reported_user_id, target_type, event_id, photo_id, message_id, reason, comment, status, created_at)
  on public.reports to authenticated;
grant insert (reporter_id, reported_user_id, event_id, photo_id, message_id, reason, comment)
  on public.reports to authenticated;

drop trigger if exists trg_reports_updated on public.reports;
create trigger trg_reports_updated
  before update on public.reports
  for each row execute function public.set_updated_at();

-- Every new report (RPC or direct insert): the target must be something the
-- reporter can see; the reported person comes from the target; a snapshot is
-- kept; at most 20 reports a day per person.
create or replace function public.reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := new.reporter_id;
  m public.event_messages%rowtype;
  ph public.photos%rowtype;
  e public.events%rowtype;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  new.status := 'pending';
  new.admin_note := null;
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.created_at := now();
  new.updated_at := now();
  new.comment := nullif(trim(coalesce(new.comment, '')), '');
  new.snapshot := '{}'::jsonb;

  if (select count(*) from public.reports where reporter_id = me and created_at > now() - interval '1 day') >= 20 then
    raise exception 'seeu:too_many_reports';
  end if;

  if new.message_id is not null then
    select * into m from public.event_messages where id = new.message_id;
    if not found or not public.is_event_member(m.event_id, me) then raise exception 'seeu:report_target_not_found'; end if;
    new.target_type := 'message';
    new.reported_user_id := m.user_id;
    new.event_id := m.event_id;
    new.photo_id := null;
    new.snapshot := jsonb_build_object('message', m.body, 'message_at', m.created_at);
  elsif new.photo_id is not null then
    select * into ph from public.photos where id = new.photo_id;
    if not found or not (
      ph.user_id = me
      or exists (select 1 from public.rendezvous r
                 where r.id = ph.rendezvous_id and r.event_id is not null and public.is_event_member(r.event_id, me))
    ) then
      raise exception 'seeu:report_target_not_found';
    end if;
    new.target_type := 'photo';
    new.reported_user_id := ph.user_id;
    new.event_id := (select r.event_id from public.rendezvous r where r.id = ph.rendezvous_id);
    new.snapshot := jsonb_build_object('storage_path', ph.storage_path, 'thumb_path', ph.thumb_path, 'caption', ph.caption);
  elsif new.event_id is not null then
    select * into e from public.events where id = new.event_id;
    -- visibility without the block check: one may block someone, then report them
    if not found or not (
      e.organizer_id = me or e.visibility = 'public'
      or (e.visibility = 'contacts' and public.are_friends(e.organizer_id, me))
      or exists (select 1 from public.rendezvous r where r.event_id = e.id and r.user_id = me)
    ) then
      raise exception 'seeu:report_target_not_found';
    end if;
    new.target_type := 'event';
    new.reported_user_id := e.organizer_id;
    new.snapshot := jsonb_build_object('title', e.title, 'description', e.description, 'location', e.location,
                                       'at', e.appointment_at, 'visibility', e.visibility);
  else
    new.target_type := 'user';
    if new.reported_user_id is null or not exists (select 1 from public.profiles where id = new.reported_user_id) then
      raise exception 'seeu:report_target_not_found';
    end if;
  end if;

  if new.reported_user_id = me then raise exception 'seeu:report_self'; end if;
  new.snapshot := new.snapshot || jsonb_build_object('reported', (
    select jsonb_build_object('username', p.username, 'display_name', p.display_name, 'avatar_path', p.avatar_path)
    from public.profiles p where p.id = new.reported_user_id));
  return new;
end;
$$;

drop trigger if exists trg_reports_before_insert on public.reports;
create trigger trg_reports_before_insert
  before insert on public.reports
  for each row execute function public.reports_before_insert();

-- The app's entry point. Reporting the same thing again while it's still
-- pending updates the reason / comment instead of adding a row.
--   p_reason: spam | harassment | inappropriate | fake_profile | other
--   target: p_message, else p_photo, else p_event, else the person p_user
create or replace function public.report_content(
  p_reason text, p_comment text default null, p_user uuid default null,
  p_event uuid default null, p_photo uuid default null, p_message uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_type text := case when p_message is not null then 'message' when p_photo is not null then 'photo'
                      when p_event is not null then 'event' else 'user' end;
  v_id uuid;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_reason is null or p_reason not in ('spam', 'harassment', 'inappropriate', 'fake_profile', 'other') then
    raise exception 'seeu:bad_answer';
  end if;
  if v_type = 'user' and p_user is null then raise exception 'seeu:report_target_not_found'; end if;

  select r.id into v_id from public.reports r
  where r.reporter_id = me and r.status = 'pending' and r.target_type = v_type
    and case v_type
          when 'message' then r.message_id = p_message
          when 'photo' then r.photo_id = p_photo
          when 'event' then r.event_id = p_event
          else r.reported_user_id = p_user end
  limit 1;
  if v_id is not null then
    update public.reports
    set reason = p_reason, comment = coalesce(nullif(trim(coalesce(p_comment, '')), ''), comment)
    where id = v_id;
    return v_id;
  end if;

  insert into public.reports (reporter_id, reported_user_id, event_id, photo_id, message_id, reason, comment)
  values (me, p_user, p_event, p_photo, p_message, p_reason, left(p_comment, 1000))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.report_content(text, text, uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.report_content(text, text, uuid, uuid, uuid, uuid) to authenticated;

-- Admins can open the photos that were reported (private bucket, signed URLs).
-- A function: policies run with the caller's rights, who can't read reports.
create or replace function public.admin_can_read_reported_photo(p_path text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() and exists (
    select 1 from public.reports r
    where r.target_type = 'photo'
      and (r.snapshot ->> 'storage_path' = p_path or r.snapshot ->> 'thumb_path' = p_path)
  )
$$;
revoke execute on function public.admin_can_read_reported_photo(text) from public, anon;
grant execute on function public.admin_can_read_reported_photo(text) to authenticated;

drop policy if exists "photos_storage_select_reported" on storage.objects;
create policy "photos_storage_select_reported" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and public.admin_can_read_reported_photo(name));

-- ---------------------------------------------------------------------
-- 5. Admin actions log
-- ---------------------------------------------------------------------
create table if not exists public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('ban', 'unban', 'report_status', 'report_note')),
  target_user uuid references auth.users(id) on delete set null,
  report_id uuid references public.reports(id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_admin_actions_created on public.admin_actions(created_at desc);
create index if not exists idx_admin_actions_target on public.admin_actions(target_user, created_at desc);
alter table public.admin_actions enable row level security;
revoke all on public.admin_actions from anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Activity: sessions and last activity
--   A session = the app in the foreground with gaps under 30 minutes.
--   The app calls touch_session() at launch, on resume and every few
--   minutes while open.
-- ---------------------------------------------------------------------
create table if not exists public.app_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  platform text check (platform in ('android', 'ios', 'web', 'other')),
  app_version text check (char_length(app_version) <= 40)
);
create index if not exists idx_app_sessions_user on public.app_sessions(user_id, last_seen_at desc);
create index if not exists idx_app_sessions_started on public.app_sessions(started_at);
create index if not exists idx_app_sessions_last_seen on public.app_sessions(last_seen_at);
alter table public.app_sessions enable row level security;

drop policy if exists "app_sessions_select_own" on public.app_sessions;
create policy "app_sessions_select_own" on public.app_sessions
  for select using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.app_sessions from anon, authenticated;

create or replace function public.touch_session(p_platform text default null, p_version text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_id uuid;
  v_last timestamptz;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if public.is_banned(me) then raise exception 'seeu:banned'; end if;
  select id, last_seen_at into v_id, v_last
  from public.app_sessions where user_id = me order by last_seen_at desc limit 1;
  if v_id is not null and v_last > now() - interval '30 minutes' then
    if v_last < now() - interval '1 minute' then
      update public.app_sessions set last_seen_at = now() where id = v_id;
    end if;
  else
    insert into public.app_sessions (user_id, platform, app_version)
    values (me,
            case when p_platform is null then null when p_platform in ('android', 'ios', 'web') then p_platform else 'other' end,
            left(nullif(trim(coalesce(p_version, '')), ''), 40))
    returning id into v_id;
  end if;
  update public.profiles set last_seen_at = now()
  where id = me and (last_seen_at is null or last_seen_at < now() - interval '1 minute');
  return v_id;
end;
$$;
revoke execute on function public.touch_session(text, text) from public, anon;
grant execute on function public.touch_session(text, text) to authenticated;

-- Sessions are kept a bit over a year (enough for yearly comparisons).
do $$
begin
  if exists (select 1 from cron.job where jobname = 'seeu-purge-sessions') then
    perform cron.unschedule('seeu-purge-sessions');
  end if;
end
$$;
select cron.schedule('seeu-purge-sessions', '17 3 * * *',
  $$delete from public.app_sessions where last_seen_at < now() - interval '400 days'$$);

-- ---------------------------------------------------------------------
-- 7. Admin RPCs (website, step 2). Each starts with require_admin().
-- ---------------------------------------------------------------------

-- Dashboard figures. "Today" starts at midnight in p_tz.
create or replace function public.admin_stats(p_tz text default 'Europe/Paris')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tz text := public.safe_tz(coalesce(p_tz, 'Europe/Paris'));
  v_day_start timestamptz := date_trunc('day', now() at time zone v_tz) at time zone v_tz;
begin
  perform public.require_admin();
  return jsonb_build_object(
    'generated_at', now(),
    'timezone', v_tz,
    'day_start', v_day_start,
    'sessions_today', (select count(*) from public.app_sessions where started_at >= v_day_start),
    'total_users', (select count(*) from public.profiles),
    'active_today', (select count(*) from public.profiles where last_seen_at >= v_day_start),
    'new_users_today', (select count(*) from public.profiles where created_at >= v_day_start),
    'active_7d', (select count(*) from public.profiles where last_seen_at >= now() - interval '7 days'),
    'active_30d', (select count(*) from public.profiles where last_seen_at >= now() - interval '30 days'),
    'reports_pending', (select count(*) from public.reports where status = 'pending'),
    'banned_accounts', (select count(*) from public.profiles where banned_at is not null),
    'concurrent_now', (select count(*) from public.profiles where last_seen_at >= now() - interval '5 minutes')
  );
end;
$$;

-- One row per day (oldest first) for the dashboard curves.
create or replace function public.admin_stats_daily(p_days integer default 30, p_tz text default 'Europe/Paris')
returns table (day date, new_users integer, active_users integer, sessions integer)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tz text := public.safe_tz(coalesce(p_tz, 'Europe/Paris'));
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 366);
  v_today date := (now() at time zone v_tz)::date;
begin
  perform public.require_admin();
  return query
  with d as (
    select g::date as day,
           (g::date)::timestamp at time zone v_tz as t0,
           (g::date + 1)::timestamp at time zone v_tz as t1
    from generate_series(v_today - (v_days - 1), v_today, interval '1 day') g
  )
  select d.day,
         (select count(*) from public.profiles p where p.created_at >= d.t0 and p.created_at < d.t1)::int,
         (select count(distinct s.user_id) from public.app_sessions s where s.started_at < d.t1 and s.last_seen_at >= d.t0)::int,
         (select count(*) from public.app_sessions s where s.started_at >= d.t0 and s.started_at < d.t1)::int
  from d
  order by d.day;
end;
$$;

-- Reports, newest first. p_status: pending (default) | reviewed | dismissed |
-- actioned | 'all'. total_count = number of rows matching (for pagination).
create or replace function public.admin_list_reports(
  p_status text default 'pending', p_reported_user uuid default null, p_report_id uuid default null,
  p_limit integer default 50, p_offset integer default 0
)
returns table (
  id uuid, created_at timestamptz, updated_at timestamptz, status text, reason text, comment text,
  admin_note text, reviewed_at timestamptz, reviewed_by uuid, reviewed_by_username text,
  target_type text, event_id uuid, photo_id uuid, message_id uuid, snapshot jsonb,
  reporter_id uuid, reporter_username text, reporter_name text,
  reported_user_id uuid, reported_username text, reported_name text, reported_banned_at timestamptz,
  reported_reports_total integer, reported_reports_pending integer, total_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select r.id, r.created_at, r.updated_at, r.status, r.reason, r.comment,
         r.admin_note, r.reviewed_at, r.reviewed_by, rv.username,
         r.target_type, r.event_id, r.photo_id, r.message_id, r.snapshot,
         r.reporter_id, rp.username, coalesce(nullif(trim(rp.display_name), ''), rp.username),
         r.reported_user_id, tp.username, coalesce(nullif(trim(tp.display_name), ''), tp.username), tp.banned_at,
         (select count(*) from public.reports x where x.reported_user_id = r.reported_user_id)::int,
         (select count(*) from public.reports x where x.reported_user_id = r.reported_user_id and x.status = 'pending')::int,
         count(*) over ()
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.profiles tp on tp.id = r.reported_user_id
  left join public.profiles rv on rv.id = r.reviewed_by
  where (p_report_id is null or r.id = p_report_id)
    and (p_report_id is not null or p_status is null or p_status = 'all' or r.status = p_status)
    and (p_reported_user is null or r.reported_user_id = p_reported_user)
  order by r.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.admin_get_report(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select to_jsonb(r) - 'total_count' from public.admin_list_reports('all', null, p_id, 1, 0) r
$$;

-- p_status: reviewed | dismissed | actioned | pending; p_note replaces the admin note (null keeps it).
create or replace function public.admin_update_report(p_id uuid, p_status text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := public.require_admin();
  r public.reports%rowtype;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if p_status is null or p_status not in ('pending', 'reviewed', 'dismissed', 'actioned') then
    raise exception 'seeu:bad_answer';
  end if;
  select * into r from public.reports where id = p_id for update;
  if not found then raise exception 'seeu:report_not_found'; end if;
  update public.reports
  set status = p_status,
      admin_note = coalesce(left(v_note, 2000), admin_note),
      reviewed_by = case when p_status = 'pending' then null else me end,
      reviewed_at = case when p_status = 'pending' then null else now() end
  where id = p_id;
  insert into public.admin_actions (admin_id, action, target_user, report_id, details)
  values (me, case when p_status = r.status then 'report_note' else 'report_status' end, r.reported_user_id, p_id,
          jsonb_build_object('from', r.status, 'to', p_status) || case when v_note is null then '{}'::jsonb else jsonb_build_object('note', v_note) end);
end;
$$;

-- p_reason is required (shown in the log, never to the user). p_report: the
-- report that led to it (marked "actioned").
create or replace function public.admin_ban_user(p_user uuid, p_reason text, p_report uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := public.require_admin();
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if v_reason is null then raise exception 'seeu:reason_required'; end if;
  if p_user is null or not exists (select 1 from public.profiles where id = p_user) then raise exception 'seeu:user_not_found'; end if;
  if p_user = me or exists (select 1 from public.admins where user_id = p_user) then raise exception 'seeu:cannot_ban_admin'; end if;
  update public.profiles
  set banned_at = coalesce(banned_at, now()), banned_reason = left(v_reason, 500)
  where id = p_user;
  perform public.set_auth_ban(p_user, true);
  insert into public.admin_actions (admin_id, action, target_user, report_id, details)
  values (me, 'ban', p_user, p_report, jsonb_build_object('reason', v_reason));
  if p_report is not null then
    update public.reports
    set status = 'actioned', reviewed_by = me, reviewed_at = now()
    where id = p_report and reported_user_id = p_user;
  end if;
end;
$$;

create or replace function public.admin_unban_user(p_user uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := public.require_admin();
begin
  if p_user is null or not exists (select 1 from public.profiles where id = p_user) then raise exception 'seeu:user_not_found'; end if;
  update public.profiles set banned_at = null, banned_reason = null where id = p_user;
  perform public.set_auth_ban(p_user, false);
  insert into public.admin_actions (admin_id, action, target_user, details)
  values (me, 'unban', p_user,
          case when nullif(trim(coalesce(p_note, '')), '') is null then '{}'::jsonb else jsonb_build_object('note', trim(p_note)) end);
end;
$$;

-- Search by username (prefix) or display name (contains); empty query = newest accounts.
create or replace function public.admin_search_users(p_query text default null, p_limit integer default 30, p_offset integer default 0)
returns table (
  user_id uuid, username text, display_name text, avatar_path text, created_at timestamptz, last_seen_at timestamptz,
  banned_at timestamptz, is_admin boolean, reports_received integer, total_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_q text := lower(trim(leading '@' from trim(coalesce(p_query, ''))));
begin
  perform public.require_admin();
  return query
  select p.id, p.username, coalesce(nullif(trim(p.display_name), ''), p.username), p.avatar_path,
         p.created_at, p.last_seen_at, p.banned_at,
         exists (select 1 from public.admins a where a.user_id = p.id),
         (select count(*) from public.reports r where r.reported_user_id = p.id)::int,
         count(*) over ()
  from public.profiles p
  where v_q = '' or starts_with(p.username, v_q) or p.display_name ilike '%' || v_q || '%'
  order by (p.username = v_q) desc, p.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- Everything important about one account, at a glance.
create or replace function public.admin_get_user(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  p public.profiles%rowtype;
begin
  perform public.require_admin();
  select * into p from public.profiles where id = p_user;
  if not found then return null; end if;
  return jsonb_build_object(
    'profile', to_jsonb(p),
    'is_admin', exists (select 1 from public.admins a where a.user_id = p.id),
    'status', case when p.banned_at is null then 'active' else 'banned' end,
    'counts', jsonb_build_object(
      'friends', (select count(*) from public.friendships f where f.status = 'accepted' and p.id in (f.requester_id, f.addressee_id)),
      'friend_requests_pending', (select count(*) from public.friendships f where f.status = 'pending' and p.id in (f.requester_id, f.addressee_id)),
      'contacts', (select count(*) from public.contacts c where c.user_id = p.id),
      'events_created', (select count(*) from public.events e where e.organizer_id = p.id),
      'events_joined', (select count(*) from public.rendezvous r join public.events e on e.id = r.event_id
                        where r.user_id = p.id and e.organizer_id <> p.id and r.rsvp = 'accepted'),
      'messages', (select count(*) from public.event_messages m where m.user_id = p.id),
      'photos', (select count(*) from public.photos ph where ph.user_id = p.id),
      'reports_received', (select count(*) from public.reports r where r.reported_user_id = p.id),
      'reports_received_pending', (select count(*) from public.reports r where r.reported_user_id = p.id and r.status = 'pending'),
      'reports_sent', (select count(*) from public.reports r where r.reporter_id = p.id),
      'sessions_30d', (select count(*) from public.app_sessions s where s.user_id = p.id and s.started_at >= now() - interval '30 days')
    ),
    'recent_reports', coalesce((
      select jsonb_agg(jsonb_build_object('id', r.id, 'created_at', r.created_at, 'status', r.status, 'reason', r.reason,
                                          'target_type', r.target_type, 'reporter_username', rp.username) order by r.created_at desc)
      from (select * from public.reports x where x.reported_user_id = p.id order by x.created_at desc limit 10) r
      left join public.profiles rp on rp.id = r.reporter_id), '[]'::jsonb),
    'recent_actions', coalesce((
      select jsonb_agg(jsonb_build_object('id', a.id, 'created_at', a.created_at, 'action', a.action,
                                          'admin_username', ap.username, 'details', a.details) order by a.created_at desc)
      from (select * from public.admin_actions x where x.target_user = p.id order by x.created_at desc limit 20) a
      left join public.profiles ap on ap.id = a.admin_id), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_list_actions(p_limit integer default 50, p_offset integer default 0, p_user uuid default null)
returns table (
  id uuid, created_at timestamptz, action text, admin_id uuid, admin_username text,
  target_user uuid, target_username text, report_id uuid, details jsonb, total_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select a.id, a.created_at, a.action, a.admin_id, ap.username, a.target_user, tp.username, a.report_id, a.details,
         count(*) over ()
  from public.admin_actions a
  left join public.profiles ap on ap.id = a.admin_id
  left join public.profiles tp on tp.id = a.target_user
  where p_user is null or a.target_user = p_user
  order by a.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.admin_stats(text)',
    'public.admin_stats_daily(integer, text)',
    'public.admin_list_reports(text, uuid, uuid, integer, integer)',
    'public.admin_get_report(uuid)',
    'public.admin_update_report(uuid, text, text)',
    'public.admin_ban_user(uuid, text, uuid)',
    'public.admin_unban_user(uuid, text)',
    'public.admin_search_users(text, integer, integer)',
    'public.admin_get_user(uuid)',
    'public.admin_list_actions(integer, integer, uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$$;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
