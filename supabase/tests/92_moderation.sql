-- 0012: reports, admins, bans, activity. Run last (after 90 and 91, same users).
-- hugo is the admin; dana gets reported and banned.
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
create or replace function pg_temp.check(label text, ok boolean) returns text language sql as $$
  select label || ': ' || case when ok then 'ok' else 'WRONG' end $$;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000011','hugo@x.fr','{"username":"hugo","display_name":"Hugo"}');
create temp table ids as
  select 'pubd' as k, (select id from events where title = 'PubD') as id
  union all select 'amisd', (select id from events where title = 'AmisD')
  union all select 'privd', (select id from events where title = 'PrivD');
grant select on ids to anon, authenticated;

-- ===== reports from the app
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');   -- gus
create temp table r1 as select report_content('spam', null, '00000000-0000-0000-0000-00000000000d') as id;
grant select on r1 to authenticated;
select pg_temp.check('same_report_updated', report_content('harassment', 'Messages insistants', '00000000-0000-0000-0000-00000000000d') = (select id from r1));
select 'report_row' as k, reason, comment, status, target_type, snapshot->'reported'->>'username' as who from reports where id = (select id from r1);
select 'bad_reason' as k, pg_temp.expect_error($q$select report_content('boring', null, '00000000-0000-0000-0000-00000000000d')$q$, 'bad_answer') as r;
select 'report_self' as k, pg_temp.expect_error($q$select report_content('spam', null, '00000000-0000-0000-0000-000000000010')$q$, 'report_self') as r;
select 'report_private_event' as k, pg_temp.expect_error($q$select report_content('spam', null, null, (select id from ids where k='privd'))$q$, 'report_target_not_found') as r;
select report_content('inappropriate', null, null, (select id from ids where k='pubd')) is not null;
select pg_temp.check('report_public_event', (select reported_user_id = '00000000-0000-0000-0000-00000000000d'
  from reports where target_type = 'event' and reporter_id = '00000000-0000-0000-0000-000000000010'));
-- a message: only members of the event can report it; the author is the reported person
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
insert into event_messages(event_id, user_id, body) values ((select id from ids where k='amisd'), '00000000-0000-0000-0000-00000000000e', 'Message limite');
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');
select 'stranger_reports_message' as k, pg_temp.expect_error($q$select report_content('harassment', null, null, null, null, (select id from event_messages where body='Message limite'))$q$, 'report_target_not_found') as r;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select report_content('harassment', null, null, null, null, (select id from event_messages where body='Message limite')) is not null;
select pg_temp.check('member_reports_message', (select reported_user_id = '00000000-0000-0000-0000-00000000000e' and snapshot->>'message' = 'Message limite'
  from reports where target_type = 'message'));
-- a photo of a public event (organizer's), reported by a participant
insert into photos(id, user_id, rendezvous_id, storage_path) values
 ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d',
  (select id from rendezvous where title='PubD' and user_id='00000000-0000-0000-0000-00000000000d'), '00000000-0000-0000-0000-00000000000d/p.jpg');
insert into storage.objects(bucket_id, name) values ('photos', '00000000-0000-0000-0000-00000000000d/p.jpg');
grant select on storage.objects to authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');
select report_content('inappropriate', 'Photo choquante', null, null, '70000000-0000-0000-0000-000000000001') is not null;
select pg_temp.check('photo_report', (select reported_user_id = '00000000-0000-0000-0000-00000000000d' and snapshot->>'storage_path' like '%p.jpg'
  from reports where target_type = 'photo'));

-- ===== RLS: a reporter sees their own reports, never the others' nor the admin columns
set role authenticated;
select pg_temp.check('gus_sees_own', (select count(id) from reports) = 3);
select 'no_admin_note' as k, pg_temp.expect_error($q$select admin_note from reports$q$, 'permission denied') as r;
insert into reports(reporter_id, reported_user_id, reason) values ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-00000000000f', 'fake_profile');
select pg_temp.check('direct_insert_ok', (select status = 'pending' and target_type = 'user' from reports where reported_user_id = '00000000-0000-0000-0000-00000000000f'));
select 'spoof_reporter' as k, pg_temp.expect_error($q$insert into reports(reporter_id, reported_user_id, reason) values ('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000f', 'spam')$q$, 'row-level security') as r;
select 'no_status_column' as k, pg_temp.expect_error($q$insert into reports(reporter_id, reported_user_id, reason, status) values ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-00000000000f', 'spam', 'dismissed')$q$, 'permission denied') as r;
select 'no_update' as k, pg_temp.expect_error($q$update reports set status = 'dismissed'$q$, 'permission denied') as r;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000f');
select pg_temp.check('fanny_sees_none', (select count(id) from reports) = 0);
-- ===== admin RPCs refused to non-admins
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');
select 'user_lists_reports' as k, pg_temp.expect_error($q$select * from admin_list_reports()$q$, 'not_admin') as r;
select 'user_stats' as k, pg_temp.expect_error($q$select admin_stats()$q$, 'not_admin') as r;
select 'user_bans' as k, pg_temp.expect_error($q$select admin_ban_user('00000000-0000-0000-0000-00000000000d', 'x')$q$, 'not_admin') as r;
select pg_temp.check('is_admin_false', not is_admin());
select pg_temp.check('participant_sees_shared_photo', (select count(*) from storage.objects where name = '00000000-0000-0000-0000-00000000000d/p.jpg') = 1);
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check('photo_hidden_to_eli', (select count(*) from storage.objects where name = '00000000-0000-0000-0000-00000000000d/p.jpg') = 0);
reset role;
set role anon;
select pg_temp.as_user('');
select 'anon_reports' as k, pg_temp.expect_error($q$select * from admin_list_reports()$q$, 'permission denied') as r;
select pg_temp.check('anon_is_admin_false', not is_admin());
reset role;

-- ===== admin
insert into admins(user_id, note) values ('00000000-0000-0000-0000-000000000011', 'test');
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-000000000011');
select pg_temp.check('is_admin', is_admin());
select pg_temp.check('admin_reads_pending', (select count(*) from admin_list_reports()) = 5 and (select max(total_count) from admin_list_reports()) = 5);
select 'admin_report' as k, j->>'reporter_username' as reporter, j->>'reported_username' as reported, j->>'reason' as reason,
  (j->>'reported_reports_total')::int as total, j ? 'admin_note' as has_note from (select admin_get_report((select id from r1)) j) x;
select pg_temp.check('admin_sees_photo', (select count(*) from storage.objects where name = '00000000-0000-0000-0000-00000000000d/p.jpg') = 1);
select admin_update_report((select id from r1), 'reviewed', 'Vu, à surveiller');
select pg_temp.check('report_reviewed', (select status = 'reviewed' and admin_note = 'Vu, à surveiller' and reviewed_by_username = 'hugo'
  from admin_list_reports('all', null, (select id from r1))));
select 'bad_status' as k, pg_temp.expect_error($q$select admin_update_report((select id from r1), 'closed')$q$, 'bad_answer') as r;
select 'reason_required' as k, pg_temp.expect_error($q$select admin_ban_user('00000000-0000-0000-0000-00000000000d', '   ')$q$, 'reason_required') as r;
select 'no_self_ban' as k, pg_temp.expect_error($q$select admin_ban_user('00000000-0000-0000-0000-000000000011', 'x')$q$, 'cannot_ban_admin') as r;
select admin_ban_user('00000000-0000-0000-0000-00000000000d', 'Spam répété',
  (select id from admin_list_reports('pending') where target_type = 'event' limit 1));
select pg_temp.check('banned', (select j->'profile'->>'banned_at' is not null and j->'profile'->>'banned_reason' = 'Spam répété'
  from (select admin_get_user('00000000-0000-0000-0000-00000000000d') j) x));
select pg_temp.check('report_actioned', (select count(*) from admin_list_reports('actioned')) = 1);
select 'actions_log' as k, string_agg(action, ',' order by created_at) from admin_list_actions();
reset role;

-- ===== a banned account disappears and is refused
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');
select pg_temp.check('banned_not_in_search', (select count(*) from search_users('dan')) = 0);
select pg_temp.check('banned_no_profile_page', get_user_profile('dana') is null);
select pg_temp.check('banned_events_hidden', not exists (select 1 from list_feed_events('public') where organizer_username = 'dana')
  and (select count(*) from get_event((select id from ids where k='pubd'))) = 0);
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check('banned_not_in_friends', not exists (select 1 from list_friends() where username = 'dana'));
select pg_temp.check('banned_avatar_hidden', (select count(*) from profile_avatars(array['00000000-0000-0000-0000-00000000000d'::uuid])) = 0);
set role anon;
select pg_temp.as_user('');
select pg_temp.check('banned_public_profile', get_public_profile('dana') is null);
select pg_temp.check('banned_public_event', get_public_event((select id from ids where k='pubd')) is null);
reset role;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select 'banned_request' as k, pg_temp.expect_error($q$select seeu_pre_request()$q$, 'seeu:banned') as r;
select 'banned_session' as k, pg_temp.expect_error($q$select touch_session('ios', '1.0.0')$q$, 'seeu:banned') as r;
select 'banned_self_unban' as k, pg_temp.expect_error($q$update profiles set banned_at = null where id = '00000000-0000-0000-0000-00000000000d'$q$, 'forbidden_field') as r;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check('others_pass', (select count(*) from (select seeu_pre_request()) s) = 1);

-- ===== activity + dashboard
select touch_session('android', '1.0.0') is not null;
select touch_session('android', '1.0.0') is not null;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000f');
select touch_session('ios', '1.0.0') is not null;
select pg_temp.check('one_session_per_visit', (select count(*) from app_sessions) = 1);  -- RLS: fanny sees her own only
select 'no_session_insert' as k, pg_temp.expect_error($q$insert into app_sessions(user_id) values ('00000000-0000-0000-0000-00000000000f')$q$, 'permission denied') as r;
select pg_temp.as_user('00000000-0000-0000-0000-000000000011');
select 'stats' as k, admin_stats() - 'generated_at' - 'day_start' as stats;
select pg_temp.check('stats_keys', admin_stats() ?& array['sessions_today','total_users','active_today','new_users_today','active_7d',
  'active_30d','reports_pending','banned_accounts','concurrent_now']);
select pg_temp.check('stats_values', (select (j->>'sessions_today')::int = 2 and (j->>'active_today')::int = 2 and (j->>'concurrent_now')::int = 2
  and (j->>'banned_accounts')::int = 1 and (j->>'reports_pending')::int = 3 and (j->>'total_users')::int = 8 from (select admin_stats() j) x));
select pg_temp.check('daily', (select count(*) = 7 and max(sessions) = 2 and max(new_users) >= 5 from admin_stats_daily(7)));
select pg_temp.check('search_users', (select banned_at is not null and reports_received = 3 from admin_search_users('da') where username = 'dana'));
select 'user_card' as k, j->>'status' as status, j->'counts' as counts, jsonb_array_length(j->'recent_reports') as reports,
  j->'profile' ? 'email' as has_email from (select admin_get_user('00000000-0000-0000-0000-00000000000d') j) x;
select admin_unban_user('00000000-0000-0000-0000-00000000000d', 'Erreur');
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');
select pg_temp.check('unbanned_visible', (select count(*) from search_users('dan')) = 1);
reset role;
select pg_temp.check('unban_logged', (select string_agg(action, ',' order by created_at) from admin_actions) = 'report_status,ban,unban');
select pg_temp.as_user('');
