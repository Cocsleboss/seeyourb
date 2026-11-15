create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
-- ===== backfill
select 'backfill' as k, (select count(*) from events) as events, (select count(*) from rendezvous where event_id is null) as orphan,
  (select count(distinct event_id) from rendezvous where title='Poker') as poker_events,
  (select organizer_id = '00000000-0000-0000-0000-00000000000a' from events where title='Poker') as poker_org,
  (select locale from profiles where username='chris') as chris_locale;
-- ===== member can't change shared fields
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'member_edit' as k, pg_temp.expect_error($q$update rendezvous set title='Hacked' where user_id='00000000-0000-0000-0000-00000000000b' and title='Poker'$q$, 'not_organizer') as r;
-- ===== organizer moves the date (direct update of own copy)
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
update rendezvous set appointment_at = appointment_at + interval '1 day' where id='30000000-0000-0000-0000-000000000001';
select 'moved' as k, count(distinct appointment_at) = 1 as same_date,
  (select string_agg(params->>'change' || '>' || (select username from profiles where id=n.user_id), ',') from notifications n where kind='rdv_change') as notif
  from rendezvous where title='Poker';
-- ===== private event via save_event with invite
select 'cine' as k, save_event(jsonb_build_object('visibility','private','title','Ciné','appointment_at', now() + interval '3 days',
   'contact_ids', jsonb_build_array('10000000-0000-0000-0000-000000000001'),
   'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-00000000000b'))) is not null as ok;
select 'cine_copies' as k, string_agg((select username from profiles where id=r.user_id) || ':' || coalesce(rsvp,'org'), ',' order by rsvp nulls first) from rendezvous r where title='Ciné';
select 'cine_invite_notif' as k, params->>'name' as name, params->>'title' as title, url like '/rdv/%' as url_ok from notifications where kind='rdv_invite' order by created_at desc limit 1;
-- stranger c can't see it, can't attach a copy by hand
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'c_get_private' as k, count(*) from get_event((select id from events where title='Ciné'));
select 'c_attach' as k, pg_temp.expect_error(format($q$insert into rendezvous(user_id,title,appointment_at,event_id) values ('00000000-0000-0000-0000-00000000000c','x',now(),'%s')$q$, (select id from events where title='Ciné')), 'not_organizer') as r;
select 'c_join_private' as k, pg_temp.expect_error(format($q$select join_event('%s')$q$, (select id from events where title='Ciné')), 'event_not_visible') as r;
-- ===== contacts event with 3 slots
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select 'brunch' as k, save_event(jsonb_build_object('visibility','contacts','title','Brunch','location','Chez moi',
   'slots', jsonb_build_array(now() + interval '5 days', now() + interval '6 days', now() + interval '7 days'))) is not null as ok;
select 'brunch_event' as k, slots_open, appointment_at = (select min(starts_at) from event_slots s where s.event_id=e.id) as earliest,
  (select count(*) from event_slots s where s.event_id=e.id) as slots from events e where title='Brunch';
select 'broadcast' as k, string_agg((select username from profiles where id=n.user_id), ',') as to_users from notifications n where kind='event_new';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'b_feed_contacts' as k, string_agg(title || ':' || going || ':' || coalesce(my_rsvp,'-'), ',') from list_feed_events('contacts');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'c_feed_contacts' as k, count(*) from list_feed_events('contacts');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'b_vote_before_join' as k, pg_temp.expect_error(format($q$select vote_slot('%s','yes')$q$, (select s.id from event_slots s join events e on e.id=s.event_id where e.title='Brunch' order by starts_at limit 1)), 'not_participant') as r;
select 'b_join' as k, join_event((select id from events where title='Brunch')) is not null as ok;
select vote_slot(s.id, case when row_number() over (order by s.starts_at) = 2 then 'yes' else 'no' end) from event_slots s join events e on e.id=s.event_id where e.title='Brunch';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select vote_slot(s.id, 'maybe') from event_slots s join events e on e.id=s.event_id where e.title='Brunch';
select 'slots' as k, string_agg(yes || '/' || maybe || '/' || no || ':' || coalesce(my_answer,'-') || ':' || array_to_string(yes_names, '+'), ' ' order by starts_at) from list_event_slots((select id from events where title='Brunch'));
select 'join_notif' as k, count(*) from notifications where kind='event_join' and user_id='00000000-0000-0000-0000-00000000000a';
select choose_event_slot((select s.id from event_slots s join events e on e.id=s.event_id where e.title='Brunch' order by starts_at offset 1 limit 1));
select 'chosen' as k, e.slots_open, count(distinct r.appointment_at) as dates, min(r.appointment_at) = (select starts_at from event_slots s where s.event_id=e.id order by starts_at offset 1 limit 1) as right_slot
  from events e join rendezvous r on r.event_id=e.id where e.title='Brunch' group by e.slots_open, e.id;
select 'chosen_notif' as k, count(*) from notifications where kind='rdv_change' and params->>'change'='date_chosen';
select 'vote_closed' as k, pg_temp.expect_error(format($q$select vote_slot('%s','yes')$q$, (select s.id from event_slots s join events e on e.id=s.event_id where e.title='Brunch' limit 1)), 'slots_closed') as r;
-- ===== chat (RLS as authenticated)
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000b','Je ramène les croissants' from events where title='Brunch';
insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000b','Et du jus' from events where title='Brunch';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'c_reads_chat' as k, count(*) from event_messages;
select 'c_posts' as k, pg_temp.expect_error($q$insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000c','spam' from events where title='Brunch'$q$, 'row-level security') as r;
reset role;
create temp table brunch_id as select id from events where title='Brunch';
grant select on brunch_id to authenticated;
set role authenticated;
select 'c_posts_by_id' as k, pg_temp.expect_error($q$insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000c','spam' from brunch_id$q$, 'row-level security') as r;
select 'c_sees_events' as k, string_agg(title, ',' order by title) from events;
reset role;
select 'chat_notif_throttled' as k, count(*) from notifications where kind='event_message' and user_id='00000000-0000-0000-0000-00000000000a';
-- ===== public events
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select 'public_denied' as k, pg_temp.expect_error($q$select save_event(jsonb_build_object('visibility','public','title','Concert','appointment_at', now() + interval '10 days'))$q$, 'public_not_allowed') as r;
insert into public_event_creators(user_id, note) values ('00000000-0000-0000-0000-00000000000a', 'test');
select 'public_slots_denied' as k, pg_temp.expect_error($q$select save_event(jsonb_build_object('visibility','public','title','X','slots', jsonb_build_array(now()+interval '1 day', now()+interval '2 days')))$q$, 'slots_not_allowed') as r;
select 'concert' as k, save_event(jsonb_build_object('visibility','public','title','Concert','location','Bruxelles','description','Live jazz','appointment_at', now() + interval '10 days')) is not null as ok;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'c_public_feed' as k, string_agg(title || ':' || organizer_name, ',') from list_feed_events('public');
select 'c_join_public' as k, join_event((select id from events where title='Concert')) is not null as ok;
set role authenticated;
select 'c_post_public' as k, pg_temp.expect_error($q$insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000c','hi' from events where title='Concert'$q$, 'row-level security') as r;
select 'c_photo_public' as k, pg_temp.expect_error($q$insert into photos(user_id,rendezvous_id,storage_path) select '00000000-0000-0000-0000-00000000000c', id, '00000000-0000-0000-0000-00000000000c/p.jpg' from rendezvous where title='Concert' and user_id='00000000-0000-0000-0000-00000000000c'$q$, 'row-level security') as r;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into photos(user_id,rendezvous_id,storage_path,thumb_path) select '00000000-0000-0000-0000-00000000000a', id, '00000000-0000-0000-0000-00000000000a/c.jpg', '00000000-0000-0000-0000-00000000000a/c_t.jpg' from rendezvous where title='Concert' and user_id='00000000-0000-0000-0000-00000000000a';
insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000a','Doors at 8pm' from events where title='Concert';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'c_reads_photo' as k, can_read_shared_photo('00000000-0000-0000-0000-00000000000a/c_t.jpg') as thumb, can_read_shared_photo('00000000-0000-0000-0000-00000000000a/c.jpg') as full;
select 'c_shared_photos' as k, count(*) from list_shared_rdv_photos((select id from rendezvous where title='Concert' and user_id='00000000-0000-0000-0000-00000000000c'));
reset role;
select 'announce_notif' as k, count(*) from notifications where kind='event_announcement' and user_id='00000000-0000-0000-0000-00000000000c';
-- ===== mutes
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
insert into user_mutes(user_id, event_id) select '00000000-0000-0000-0000-00000000000c', id from events where title='Concert';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into event_messages(event_id,user_id,body) select id,'00000000-0000-0000-0000-00000000000a','Sold out!' from events where title='Concert';
reset role;
select 'muted_event' as k, count(*) from notifications where kind='event_announcement' and user_id='00000000-0000-0000-0000-00000000000c';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
insert into user_mutes(user_id, target_user) values ('00000000-0000-0000-0000-00000000000c','00000000-0000-0000-0000-00000000000a');
select 'muted_feed' as k, count(*) from list_feed_events('public');
select 'mutes_list' as k, count(*) from list_mutes();
delete from user_mutes where user_id='00000000-0000-0000-0000-00000000000c';
-- ===== blocks
select block_user('00000000-0000-0000-0000-00000000000a');
select 'blocked' as k, (select count(*) from rendezvous where user_id='00000000-0000-0000-0000-00000000000c') as c_copies,
  (select count(*) from list_feed_events('public')) as feed, (select count(*) from search_users('andr')) as search,
  (select count(*) from list_blocked_users()) as blocked;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select 'a_search_c' as k, count(*) from search_users('chri');
select 'a_req_c' as k, pg_temp.expect_error($q$select send_friend_request('chris')$q$, 'blocked') as r;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select unblock_user('00000000-0000-0000-0000-00000000000a');
select 'unblocked' as k, count(*) from list_feed_events('public');
-- ===== cancel by organizer, private validate sync
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select save_event(jsonb_build_object('rdv_id', (select id from rendezvous where title='Brunch' and user_id='00000000-0000-0000-0000-00000000000a'),
  'visibility','contacts','title','Brunch','location','Chez moi','appointment_at',(select appointment_at from events where title='Brunch'),'status','annule')) is not null as cancelled;
select 'brunch_cancelled' as k, string_agg(r.status::text, ',') from rendezvous r where title='Brunch';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
update rendezvous set status='valide' where title='Poker' and user_id='00000000-0000-0000-0000-00000000000b';
select 'poker_validated' as k, string_agg(r.status::text, ','), (select last_meeting_date is not null from contacts where id='10000000-0000-0000-0000-000000000001') as a_counter from rendezvous r where title='Poker';
select 'member_cancel' as k, pg_temp.expect_error($q$update rendezvous set status='annule' where title='Ciné' and user_id='00000000-0000-0000-0000-00000000000b'$q$, 'not_organizer') as r;
select pg_temp.as_user('');
select 'reminders' as k, run_reminders();
select 'pending_params' as k, kind, params from notifications where status='pending' order by created_at limit 3;
select 'counts' as k, string_agg(title || ':' || member_count || '/' || going_count, ',' order by title) from events;
-- ===== a poll whose earliest slot is past stays in the feed
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select save_event(jsonb_build_object('visibility','contacts','title','Apéro',
   'slots', jsonb_build_array(now() - interval '1 day', now() + interval '2 days'))) is not null as apero;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'past_slot_feed' as k, count(*) from list_feed_events('contacts') where title = 'Apéro';
-- ===== organizer cancels then deletes their copy: members see it cancelled
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
update rendezvous set status='annule' where title='Ciné' and user_id='00000000-0000-0000-0000-00000000000a';
delete from rendezvous where title='Ciné' and user_id='00000000-0000-0000-0000-00000000000a';
select 'org_deleted' as k, string_agg(status::text, ',') from rendezvous where title='Ciné';
