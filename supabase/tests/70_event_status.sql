-- 0010 (run after 60, before 30)
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select save_event(jsonb_build_object('visibility','contacts','title','Started','appointment_at', now() - interval '1 minute',
  'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-00000000000b'))) is not null as e1;
select save_event(jsonb_build_object('visibility','private','title','FiveHours','appointment_at', now() - interval '5 hours')) is not null as e2;
select save_event(jsonb_build_object('visibility','contacts','title','DayOld','appointment_at', now() - interval '25 hours',
  'invite_user_ids', jsonb_build_array('00000000-0000-0000-0000-00000000000b'))) is not null as e3;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select respond_rdv_invite((select i.id from rdv_invitations i join rendezvous r on r.id=i.rdv_id where r.title='Started' and i.to_user='00000000-0000-0000-0000-00000000000b'), 'accepted') is not null;
select respond_rdv_invite((select i.id from rdv_invitations i join rendezvous r on r.id=i.rdv_id where r.title='DayOld' and i.to_user='00000000-0000-0000-0000-00000000000b'), 'accepted') is not null;
select 'member_marks_done' as k, pg_temp.expect_error($q$update rendezvous set status='valide' where title='Started' and user_id='00000000-0000-0000-0000-00000000000b'$q$, 'not_organizer') as r;
select pg_temp.as_user('');
select 'checks' as k, run_event_checks();
select 'checks_again' as k, run_event_checks();
select 'dayold_copies' as k, string_agg(status::text, ',') from rendezvous where title='DayOld';
select 'notifs' as k, kind, count(*) from notifications where params->>'title' in ('Started','FiveHours','DayOld') and kind in ('rdv_check','rdv_auto_done','rdv_change') group by kind order by kind;
-- organizer marks it done: everyone's copy follows
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
update rendezvous set status='valide' where title='Started' and user_id='00000000-0000-0000-0000-00000000000a';
select 'started_copies' as k, string_agg(status::text, ',') from rendezvous where title='Started';
select pg_temp.as_user('');
