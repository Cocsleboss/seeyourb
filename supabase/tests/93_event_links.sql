-- 0015: invitation links, removing a member, ex-friends in events, default reminder.
-- Fresh users: ivy (organizer) – jon friends, jon – lea friends, kim a stranger.
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
create or replace function pg_temp.check(label text, ok boolean) returns text language sql as $$
  select label || ': ' || case when ok then 'ok' else 'WRONG' end $$;

insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-0000000000a1','ivy@x.fr','{"username":"ivy","display_name":"Ivy"}'),
 ('00000000-0000-0000-0000-0000000000a2','jon@x.fr','{"username":"jon","display_name":"Jon"}'),
 ('00000000-0000-0000-0000-0000000000a3','kim@x.fr','{"username":"kim","display_name":"Kim"}'),
 ('00000000-0000-0000-0000-0000000000a4','lea@x.fr','{"username":"lea","display_name":"Lea"}');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select send_friend_request('jon') is not null;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
select send_friend_request('ivy') is not null;
select send_friend_request('lea') is not null;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a4');
select send_friend_request('jon') is not null;

-- ===== A. A private event alone, then a link
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select save_event(jsonb_build_object('visibility','private','title','SoloIvy','appointment_at', now()+interval '3 days')) is not null;
create temp table t(k text primary key, v text);
grant all on t to public;
insert into t select 'ev', id::text from events where title = 'SoloIvy';
insert into t select 'tok', create_event_link((select v::uuid from t where k='ev'));
select pg_temp.check('token_format', (select v ~ '^[A-Za-z0-9_-]{43}$' from t where k='tok'));
select pg_temp.check('same_link_again', create_event_link((select v::uuid from t where k='ev')) = (select v from t where k='tok'));
select pg_temp.check('my_link', get_my_event_link((select v::uuid from t where k='ev')) = (select v from t where k='tok'));
select pg_temp.check('tokens_differ', new_link_token() <> new_link_token());

-- a stranger can't see the event, but the link shows it
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a3');
select pg_temp.check('kim_no_get_event', not exists (select 1 from get_event((select v::uuid from t where k='ev'))));
select pg_temp.check('kim_preview', (get_event_by_link((select v from t where k='tok')))->>'title' = 'SoloIvy');
select pg_temp.check('bad_token_null', get_event_by_link('x' || (select v from t where k='tok')) is null);
select 'kim_create_link' as k, pg_temp.expect_error($q$select create_event_link((select v::uuid from t where k='ev'))$q$, 'not_organizer') as r;
select 'kim_join_declined' as k, pg_temp.expect_error($q$select join_event_by_link((select v from t where k='tok'), 'declined')$q$, 'bad_answer') as r;
select pg_temp.check('kim_joins', join_event_by_link((select v from t where k='tok')) is not null);
select pg_temp.check('kim_sees_now', exists (select 1 from get_event((select v::uuid from t where k='ev'))));
select pg_temp.check('join_twice_same_copy', join_event_by_link((select v from t where k='tok')) = (select id from rendezvous where user_id='00000000-0000-0000-0000-0000000000a3' and event_id=(select v::uuid from t where k='ev')));
-- kim and ivy aren't friends: no card created for kim
select pg_temp.check('no_card_for_stranger', not exists (select 1 from contacts where user_id='00000000-0000-0000-0000-0000000000a3'));
select pg_temp.check('kim_no_via_column', (select via_link from list_event_participants((select v::uuid from t where k='ev')) where username='kim') is null);
select pg_temp.as_user('');
select pg_temp.check('organizer_notified', (select count(*) from notifications where kind='event_join' and user_id='00000000-0000-0000-0000-0000000000a1' and params->>'via_link'='true') = 1);
select pg_temp.check('join_count', (select join_count from event_links where token=(select v from t where k='tok')) = 1);

-- the organizer sees who came by the link
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select 'participants' as k, string_agg(username || ':' || rsvp || ':' || coalesce(via_link::text, '-'), ',' order by username) from list_event_participants((select v::uuid from t where k='ev'));
-- anonymous website preview
set role anon;
select pg_temp.check('anon_preview', (get_link_preview((select v from t where k='tok')))->>'organizer_name' = 'Ivy');
select pg_temp.check('anon_preview_no_ids', not ((get_link_preview((select v from t where k='tok'))) ? 'event_id'));
select 'anon_by_link' as k, pg_temp.expect_error($q$select get_event_by_link('abc')$q$, 'permission denied') as r;
select 'anon_join' as k, pg_temp.expect_error($q$select join_event_by_link('abc')$q$, 'permission denied') as r;
reset role;

-- ===== B. Removing a member: no way back by the link, unless the organizer invites again
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a3');
select 'kim_remove' as k, pg_temp.expect_error($q$select remove_event_member((select v::uuid from t where k='ev'), '00000000-0000-0000-0000-0000000000a1')$q$, 'not_organizer') as r;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select remove_event_member((select v::uuid from t where k='ev'), '00000000-0000-0000-0000-0000000000a3');
select pg_temp.check('kim_gone', not exists (select 1 from rendezvous where user_id='00000000-0000-0000-0000-0000000000a3'));
select pg_temp.check('counts_updated', (select going_count from events where id=(select v::uuid from t where k='ev')) = 1);
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a3');
select 'kim_rejoin' as k, pg_temp.expect_error($q$select join_event_by_link((select v from t where k='tok'))$q$, 'removed_from_event') as r;
select pg_temp.check('kim_preview_says_removed', (get_event_by_link((select v from t where k='tok')))->>'removed' = 'true');

-- ===== C. Revoking
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into t select 'tok2', create_event_link((select v::uuid from t where k='ev'), true);
select pg_temp.check('new_link_differs', (select v from t where k='tok2') <> (select v from t where k='tok'));
select pg_temp.check('old_link_dead', get_event_by_link((select v from t where k='tok')) is null);
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a4');
select 'lea_old_link' as k, pg_temp.expect_error($q$select join_event_by_link((select v from t where k='tok'))$q$, 'link_invalid') as r;
select pg_temp.check('lea_joins_pending', join_event_by_link((select v from t where k='tok2'), 'pending') is not null);
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select pg_temp.check('revoke_all', revoke_event_link((select v::uuid from t where k='ev'), true) = 1);
select pg_temp.check('revoked_dead', get_event_by_link((select v from t where k='tok2')) is null);
set role anon;
select pg_temp.check('anon_revoked_null', get_link_preview((select v from t where k='tok2')) is null);
reset role;

-- ===== D. Guests' links follow "guests can invite"
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into contacts(user_id, name, frequency_value, frequency_unit, linked_user_id)
 values ('00000000-0000-0000-0000-0000000000a1', 'Jon', 1, 'months', '00000000-0000-0000-0000-0000000000a2');
select save_event(jsonb_build_object('visibility','private','title','DinerIvy','appointment_at', now()+interval '4 days',
  'contact_ids', jsonb_build_array((select id from contacts where user_id='00000000-0000-0000-0000-0000000000a1' and name='Jon')),
  'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-0000000000a2'))) is not null;
insert into t select 'ev2', id::text from events where title = 'DinerIvy';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
select respond_rdv_invite((select id from rdv_invitations where to_user='00000000-0000-0000-0000-0000000000a2' and to_rdv_id in (select id from rendezvous where event_id=(select v::uuid from t where k='ev2'))), 'accepted') is not null;
insert into t select 'tok3', create_event_link((select v::uuid from t where k='ev2'));
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a3');
select pg_temp.check('shared_by_guest', (get_event_by_link((select v from t where k='tok3')))->>'shared_by_name' = 'Jon');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select save_event(jsonb_build_object('rdv_id', (select id from rendezvous where event_id=(select v::uuid from t where k='ev2') and user_id='00000000-0000-0000-0000-0000000000a1'),
  'visibility','private','title','DinerIvy','appointment_at', (select appointment_at from events where id=(select v::uuid from t where k='ev2')),
  'guests_can_invite', false)) is not null;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a3');
select pg_temp.check('guest_link_off', get_event_by_link((select v from t where k='tok3')) is null);
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
select 'jon_create_off' as k, pg_temp.expect_error($q$select create_event_link((select v::uuid from t where k='ev2'))$q$, 'not_organizer') as r;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select save_event(jsonb_build_object('rdv_id', (select id from rendezvous where event_id=(select v::uuid from t where k='ev2') and user_id='00000000-0000-0000-0000-0000000000a1'),
  'visibility','private','title','DinerIvy','appointment_at', (select appointment_at from events where id=(select v::uuid from t where k='ev2')),
  'guests_can_invite', true)) is not null;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a3');
select pg_temp.check('kim_joins_by_guest_link', join_event_by_link((select v from t where k='tok3')) is not null);
select pg_temp.as_user('');
select pg_temp.check('sharer_notified', (select count(*) from notifications where kind='event_join' and user_id='00000000-0000-0000-0000-0000000000a2' and params->>'via_link'='true') = 1);
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select pg_temp.check('organizer_sees_sharer', (select link_shared_by from list_event_participants((select v::uuid from t where k='ev2')) where username='kim') = 'Jon');

-- ===== E. A friend's page lists the private events we share
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
select pg_temp.check('friend_page_private_shared', (select count(*) from jsonb_array_elements(get_user_profile('ivy')->'events') x where x->>'title' = 'DinerIvy') = 1);
select pg_temp.check('friend_page_not_solo', (select count(*) from jsonb_array_elements(get_user_profile('ivy')->'events') x where x->>'title' = 'SoloIvy') = 0);

-- ===== F. Unfriending: jon stays himself in the event (no "pas sur SeeU" duplicate)
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select pg_temp.check('card_attached_before', exists (select 1 from contact_rendezvous cr join contacts c on c.id = cr.contact_id
  where c.user_id='00000000-0000-0000-0000-0000000000a1' and c.linked_user_id='00000000-0000-0000-0000-0000000000a2'));
select pg_temp.check('default_never', (select frequency_unit::text from contacts where user_id='00000000-0000-0000-0000-0000000000a2' and linked_user_id='00000000-0000-0000-0000-0000000000a1') = 'never');
delete from friendships where '00000000-0000-0000-0000-0000000000a2' in (requester_id, addressee_id) and '00000000-0000-0000-0000-0000000000a1' in (requester_id, addressee_id);
select pg_temp.check('jon_still_member', exists (select 1 from list_event_participants((select v::uuid from t where k='ev2')) where username='jon'));
select pg_temp.check('no_guest_duplicate', not exists (select 1 from list_event_guests((select v::uuid from t where k='ev2')) where name='Jon'));
select pg_temp.check('card_kept_unlinked', exists (select 1 from contacts where user_id='00000000-0000-0000-0000-0000000000a1' and name='Jon' and linked_user_id is null));
