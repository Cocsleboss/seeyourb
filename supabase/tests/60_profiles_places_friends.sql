-- 0008 (run after 50, before 30)
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
-- a: contact "Chris" (not on SeeU yet for a), attached to an upcoming event; then a friend request tied to that card
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into contacts(id,user_id,name,frequency_value,frequency_unit)
 values ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-00000000000a','Chris',1,'months');
select save_event(jsonb_build_object('visibility','private','title','Ciné','appointment_at', now()+interval '5 days',
  'contact_ids', jsonb_build_array('10000000-0000-0000-0000-000000000003'),
  'link','https://example.com/cine','lat',50.85,'lng',4.35)) is not null as cine;
select 'event_extra' as k, link, lat, lng from events where title='Ciné';
select 'bad_link' as k, pg_temp.expect_error($q$select save_event(jsonb_build_object('visibility','private','title','X','appointment_at', now()+interval '1 day','contact_ids', jsonb_build_array('10000000-0000-0000-0000-000000000003'),'link','javascript:alert(1)'))$q$, 'bad_link') as r;
select 'request' as k, send_friend_request('chris', '10000000-0000-0000-0000-000000000003') ->> 'status';
select 'pending_contact' as k, contact_id is not null as has_contact, status from list_friends() where username='chris';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select respond_friend_request((select id from friendships where addressee_id='00000000-0000-0000-0000-00000000000c' and requester_id='00000000-0000-0000-0000-00000000000a'), true);
select 'c_got_cine' as k, rsvp from rendezvous where title='Ciné' and user_id='00000000-0000-0000-0000-00000000000c';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select 'linked' as k, linked_user_id = '00000000-0000-0000-0000-00000000000c' as ok from contacts where id='10000000-0000-0000-0000-000000000003';
select 'invite_row' as k, status from rdv_invitations where to_user='00000000-0000-0000-0000-00000000000c'
  and rdv_id in (select id from rendezvous where title='Ciné');
-- username fixed
select 'username_fixed' as k, pg_temp.expect_error($q$update profiles set username='andrea2' where id='00000000-0000-0000-0000-00000000000a'$q$, 'username_fixed') as r;
-- organizer can't vote
select save_event(jsonb_build_object('visibility','contacts','title','Poll',
  'slots', jsonb_build_array(now()+interval '2 days', now()+interval '3 days'))) is not null as poll;
select 'org_vote' as k, pg_temp.expect_error($q$select vote_slot((select s.id from event_slots s join events e on e.id=s.event_id where e.title='Poll' limit 1), 'yes')$q$, 'organizer_no_vote') as r;
select 'slots_cols' as k, count(*), bool_and(no_names is not null) from list_event_slots((select id from events where title='Poll'));
-- avatars
update profiles set avatar_path = '00000000-0000-0000-0000-00000000000a/me.jpg' where id='00000000-0000-0000-0000-00000000000a';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'avatars' as k, count(*) from profile_avatars(array['00000000-0000-0000-0000-00000000000a'::uuid, '00000000-0000-0000-0000-00000000000b'::uuid]);
select pg_temp.as_user('');
