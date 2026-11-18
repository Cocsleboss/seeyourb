-- 0012–0014: event visibility levels, public profile, profile page in the app.
-- Run after 0014. Fresh users: dana–eli friends, eli–fanny friends, gus a stranger.
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
create or replace function pg_temp.check(label text, ok boolean) returns text language sql as $$
  select label || ': ' || case when ok then 'ok' else 'WRONG' end $$;

insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000d','dana@x.fr','{"username":"dana","display_name":"Dana Secret"}'),
 ('00000000-0000-0000-0000-00000000000e','eli@x.fr','{"username":"eli","display_name":"Eli"}'),
 ('00000000-0000-0000-0000-00000000000f','fanny@x.fr','{"username":"fanny","display_name":"Fanny"}'),
 ('00000000-0000-0000-0000-000000000010','gus@x.fr','{"username":"gus","display_name":"Gus"}');
insert into public_event_creators(user_id, note) values ('00000000-0000-0000-0000-00000000000d', 'test');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select send_friend_request('eli') is not null;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select send_friend_request('dana') is not null;
select send_friend_request('fanny') is not null;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000f');
select send_friend_request('eli') is not null;

-- dana: one event per level (+ a second public one); eli invited to the private one
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select save_event(jsonb_build_object('visibility','private','title','PrivD','appointment_at', now()+interval '3 days',
  'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-00000000000e'))) is not null;
select save_event(jsonb_build_object('visibility','contacts','title','AmisD','appointment_at', now()+interval '4 days')) is not null;
select save_event(jsonb_build_object('visibility','public','title','PubD','appointment_at', now()+interval '5 days','lat',45.76,'lng',4.84)) is not null;
select save_event(jsonb_build_object('visibility','public','title','PubD2','appointment_at', now()+interval '6 days')) is not null;
select save_event(jsonb_build_object('title','Défaut','appointment_at', now()+interval '7 days')) is not null;
select pg_temp.check('default_private', (select string_agg(visibility, ',') from events where title = 'Défaut') = 'private');

-- ===== A. Visibility: get_event / join_event / feeds
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');   -- gus, stranger
select pg_temp.check('gus_sees_only_public', (select count(*) from events e, get_event(e.id) g where e.organizer_id='00000000-0000-0000-0000-00000000000d') = 2);
select 'gus_join_private' as k, pg_temp.expect_error($q$select join_event((select id from events where title='PrivD'))$q$, 'event_not_visible') as r;
select 'gus_join_friends' as k, pg_temp.expect_error($q$select join_event((select id from events where title='AmisD'))$q$, 'event_not_visible') as r;
select pg_temp.check('gus_joins_public_directly', join_event((select id from events where title='PubD')) is not null);
select pg_temp.check('gus_feed_public', (select string_agg(title, ',' order by title) from list_feed_events('public') where organizer_username='dana') = 'PubD,PubD2');
select pg_temp.check('gus_feed_friends_empty', (select count(*) from list_feed_events('contacts') where organizer_username='dana') = 0);
select pg_temp.as_user('00000000-0000-0000-0000-00000000000f');   -- fanny, friend of a friend
select pg_temp.check('fanny_no_friends_event', (select count(*) from get_event((select id from events where title='AmisD'))) = 0);
select pg_temp.check('fanny_no_private', (select count(*) from get_event((select id from events where title='PrivD'))) = 0);
select pg_temp.check('fanny_joins_public', join_event((select id from events where title='PubD')) is not null);
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');   -- eli, friend + invited
select pg_temp.check('eli_feed_friends', (select string_agg(title, ',') from list_feed_events('contacts') where organizer_username='dana') = 'AmisD');
select pg_temp.check('eli_sees_private_invited', (select count(*) from get_event((select id from events where title='PrivD'))) = 1);
select pg_temp.check('eli_joins_friends_event', join_event((select id from events where title='AmisD')) is not null);
select pg_temp.check('private_never_in_feeds', not exists (select 1 from list_feed_events('public') where title='PrivD')
  and not exists (select 1 from list_feed_events('contacts') where title='PrivD'));
-- same rules straight on the table (RLS events_select_visible)
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');
select pg_temp.check('rls_gus', (select string_agg(title, ',' order by title) from events where organizer_id='00000000-0000-0000-0000-00000000000d') = 'PubD,PubD2');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000f');
select pg_temp.check('rls_fanny', (select string_agg(title, ',' order by title) from events where organizer_id='00000000-0000-0000-0000-00000000000d') = 'PubD,PubD2');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check('rls_eli', (select string_agg(title, ',' order by title) from events where organizer_id='00000000-0000-0000-0000-00000000000d') = 'AmisD,PrivD,PubD,PubD2');
reset role;

-- ===== B. Public profile (website, anonymous). Ids are read before switching role
-- (anonymous visitors can't read the events table; the website gets ids from links).
create temp table ev as select title, id from events where organizer_id = '00000000-0000-0000-0000-00000000000d';
grant select on ev to anon, authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
update profiles set bio = 'Bio de Dana', home_city = 'Lyon', home_country = 'France', home_lat = 45.76, home_lng = 4.84,
  avatar_path = '00000000-0000-0000-0000-00000000000d/a.jpg' where id = '00000000-0000-0000-0000-00000000000d';
-- every copy marked "show on profile", even the private and friends ones
update rendezvous set show_on_profile = true where user_id = '00000000-0000-0000-0000-00000000000d';
set role anon;
select pg_temp.as_user('');
select pg_temp.check('off_by_default', get_public_profile('dana') is null);
reset role;
update profiles set public_profile = true, public_fields = '{name}', public_events = 'none' where username = 'dana';
set role anon;
select 'only_name' as k, get_public_profile('dana') - 'events' as profile, get_public_profile('dana') -> 'events' as events;
select pg_temp.check('never_email', get_public_profile('@Dana')::text not like '%@x.fr%' and not (get_public_profile('dana') ? 'email'));
reset role;
update profiles set public_fields = '{avatar,name,city,bio}', public_events = 'all' where username = 'dana';
set role anon;
select pg_temp.check('all_fields', (select j->>'city' = 'Lyon' and j->>'bio' = 'Bio de Dana' and j->>'avatar_path' like '%a.jpg' from (select get_public_profile('dana') j) x));
select pg_temp.check('all_public_events_only', (select string_agg(e->>'title', ',' order by e->>'title') from jsonb_array_elements(get_public_profile('dana')->'events') e) = 'PubD,PubD2');
reset role;
update profiles set public_events = 'selected' where username = 'dana';
update rendezvous set show_on_profile = false where user_id = '00000000-0000-0000-0000-00000000000d' and title = 'PubD2';
set role anon;
select pg_temp.check('selected_only', (select string_agg(e->>'title', ',') from jsonb_array_elements(get_public_profile('dana')->'events') e) = 'PubD');
select pg_temp.check('public_event_page', get_public_event((select id from ev where title='PubD')) ->> 'title' = 'PubD');
select pg_temp.check('no_friends_event_page', get_public_event((select id from ev where title='AmisD')) is null);
select pg_temp.check('no_private_event_page', get_public_event((select id from ev where title='PrivD')) is null);
select pg_temp.check('unknown_profile', get_public_profile('nobody') is null);
select 'anon_user_profile' as k, pg_temp.expect_error($q$select get_user_profile('dana')$q$, 'permission denied') as r;
reset role;
-- a participant's public profile lists the public events they go to
update profiles set public_profile = true, public_events = 'all' where username = 'fanny';
set role anon;
select pg_temp.check('going_event_listed', (select e->>'role' = 'going' from jsonb_array_elements(get_public_profile('fanny')->'events') e where e->>'title' = 'PubD'));
reset role;

-- ===== B5/C. Profile page in the app
select pg_temp.as_user('00000000-0000-0000-0000-000000000010');   -- gus: stranger, sees the public parts only
update profiles set public_fields = '{avatar,name}' where username = 'dana';
select pg_temp.check('stranger_no_city_bio', (select j->>'city' is null and j->>'bio' is null and j->>'relation' = 'none' from (select get_user_profile('dana') j) x));
select pg_temp.check('stranger_events', (select string_agg(e->>'title', ',') from jsonb_array_elements(get_user_profile('dana')->'events') e) = 'PubD');
select pg_temp.check('stranger_add_friend', send_friend_request('dana') ->> 'status' = 'sent');
select pg_temp.check('relation_sent', get_user_profile('dana') ->> 'relation' = 'sent');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');   -- eli: friend
select pg_temp.check('friend_city_bio', (select j->>'city' = 'Lyon' and j->>'bio' = 'Bio de Dana' and j->>'relation' = 'friends' from (select get_user_profile('dana') j) x));
select pg_temp.check('friend_events_no_private', (select string_agg(e->>'title', ',' order by e->>'title') from jsonb_array_elements(get_user_profile('dana')->'events') e) = 'AmisD,PubD,PubD2');
select pg_temp.check('fanny_from_participants', (select count(*) from list_event_participants((select id from events where title='PubD')) where username='fanny') = 1
  and get_user_profile('fanny') ->> 'username' = 'fanny');
update profiles set friends_see_city = false where username = 'dana';
select pg_temp.check('friend_city_hidden', get_user_profile('dana') ->> 'city' is null);
select pg_temp.check('mutual_friends', (get_user_profile('fanny') ->> 'mutual_friends')::int = 0 and (select (get_user_profile('dana') ->> 'mutual_friends')::int) = 0);
-- server-only profile fields can't be set through the API
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select 'self_unban_field' as k, pg_temp.expect_error($q$update profiles set banned_at = now() where id = '00000000-0000-0000-0000-00000000000d'$q$, 'forbidden_field') as r;
select 'self_last_seen' as k, pg_temp.expect_error($q$update profiles set last_seen_at = now() - interval '1 year' where id = '00000000-0000-0000-0000-00000000000d'$q$, 'forbidden_field') as r;
with u as (update profiles set bio = 'Nouvelle bio' where id = '00000000-0000-0000-0000-00000000000d' returning bio)
select pg_temp.check('own_fields_ok', (select bio = 'Nouvelle bio' from u));
select 'bad_public_field' as k, pg_temp.expect_error($q$update profiles set public_fields = '{email}' where id = '00000000-0000-0000-0000-00000000000d'$q$, 'profiles_public_fields') as r;
reset role;
select pg_temp.as_user('');
