create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
-- a & b friends (fixture), c friend of b
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select send_friend_request('chris') is not null;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select send_friend_request('marie') is not null;
-- a: private event with 3 slots, guests can't invite, b invited
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select save_event(jsonb_build_object('visibility','private','title','Resto','guests_can_invite', false,
  'slots', jsonb_build_array(now()+interval '2 days', now()+interval '3 days', now()+interval '4 days'),
  'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-00000000000b'))) is not null as resto;
select 'guest_option' as k, guests_can_invite from events where title='Resto';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'b_invites_c' as k, pg_temp.expect_error($q$select send_rdv_invite((select id from rendezvous where title='Resto' and user_id='00000000-0000-0000-0000-00000000000b'), '00000000-0000-0000-0000-00000000000c')$q$, 'not_organizer') as r;
-- b: all maybe (one unanswered) → stays pending, no notification
select 'b_maybe' as k, submit_availability((select id from events where title='Resto'),
  jsonb_build_array(jsonb_build_object('slot', (select id from event_slots s where s.event_id=(select id from events where title='Resto') order by starts_at limit 1), 'answer','maybe')));
select 'votes' as k, count(*) from slot_votes where user_id='00000000-0000-0000-0000-00000000000b';
-- all no → declined + organizer notified
select 'b_no' as k, submit_availability((select id from events where title='Resto'),
  (select jsonb_agg(jsonb_build_object('slot', s.id, 'answer','no')) from event_slots s where s.event_id=(select id from events where title='Resto')));
select 'b_copy' as k, rsvp from rendezvous where title='Resto' and user_id='00000000-0000-0000-0000-00000000000b';
-- one yes → accepted
select 'b_yes' as k, submit_availability((select id from events where title='Resto'),
  (select jsonb_agg(jsonb_build_object('slot', s.id, 'answer', case when s.starts_at = (select max(starts_at) from event_slots where event_id=s.event_id) then 'yes' else 'no' end)) from event_slots s where s.event_id=(select id from events where title='Resto')));
select 'responses' as k, string_agg(params->>'answer', ',' order by created_at) from notifications where kind='rdv_response' and params->>'title'='Resto';
-- block deletes the linked contact
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select 'contact_before' as k, count(*) from contacts where user_id='00000000-0000-0000-0000-00000000000a' and linked_user_id='00000000-0000-0000-0000-00000000000b';
select block_user('00000000-0000-0000-0000-00000000000b');
select 'contact_after' as k, count(*) from contacts where user_id='00000000-0000-0000-0000-00000000000a' and name='Marie';
