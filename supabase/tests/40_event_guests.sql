-- 0006: people without a SeeU account visible to the other members (run before 30, which blocks b)
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into contacts(id,user_id,name,frequency_value,frequency_unit)
 values ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-00000000000a','Zoé',1,'months');
insert into contact_rendezvous values ('10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a');
select 'a_sees' as k, name, contact_id is not null as has_id, is_mine from list_event_guests((select event_id from rendezvous where id='30000000-0000-0000-0000-000000000001'));
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'b_sees' as k, name, contact_id is null as no_id, is_mine, added_by_name from list_event_guests((select event_id from rendezvous where id='30000000-0000-0000-0000-000000000001'));
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'c_sees' as k, count(*) from list_event_guests((select event_id from rendezvous where id='30000000-0000-0000-0000-000000000001'));
select pg_temp.as_user('');
