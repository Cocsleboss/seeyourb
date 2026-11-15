-- 0007: leaving drops my votes; re-inviting someone who left reopens the invitation (run before 30)
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select save_event(jsonb_build_object('visibility','private','title','Lasagne',
  'slots', jsonb_build_array(now()+interval '2 days', now()+interval '3 days'),
  'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-00000000000b'))) is not null as lasagne;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'b_votes' as k, submit_availability((select id from events where title='Lasagne'),
  (select jsonb_agg(jsonb_build_object('slot', s.id, 'answer','yes')) from event_slots s where s.event_id=(select id from events where title='Lasagne')));
select 'votes_before' as k, count(*) from slot_votes where user_id='00000000-0000-0000-0000-00000000000b'
  and slot_id in (select id from event_slots where event_id=(select id from events where title='Lasagne'));
delete from rendezvous where title='Lasagne' and user_id='00000000-0000-0000-0000-00000000000b';
select 'votes_after_leave' as k, count(*) from slot_votes where user_id='00000000-0000-0000-0000-00000000000b'
  and slot_id in (select id from event_slots where event_id=(select id from events where title='Lasagne'));
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select 'reinvite' as k, send_rdv_invite((select id from rendezvous where title='Lasagne' and user_id='00000000-0000-0000-0000-00000000000a'), '00000000-0000-0000-0000-00000000000b') is not null as sent;
select 'invite_status' as k, status, to_rdv_id is not null as has_copy from rdv_invitations
  where rdv_id=(select id from rendezvous where title='Lasagne' and user_id='00000000-0000-0000-0000-00000000000a');
select 'b_copy' as k, rsvp from rendezvous where title='Lasagne' and user_id='00000000-0000-0000-0000-00000000000b';
select 'notified' as k, count(*) from notifications where kind='rdv_invite' and user_id='00000000-0000-0000-0000-00000000000b' and params->>'title'='Lasagne';
select pg_temp.as_user('');
