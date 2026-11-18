-- 0014: travel hints. Run after 90 (same users). dana lives in Lyon, eli (her friend) and
-- fanny (not her friend) in Paris; dana has two cards without account: one in Paris, one in Lyon.
create or replace function pg_temp.as_user(u text) returns void language sql as $$ select set_config('request.jwt.claim.sub', u, false) $$;
create or replace function pg_temp.expect_error(q text, code text) returns text language plpgsql as $$
begin execute q; return 'NO ERROR (expected ' || code || ')';
exception when others then return case when sqlerrm like '%' || code || '%' then 'ok' else 'WRONG: ' || sqlerrm end; end $$;
create or replace function pg_temp.check(label text, ok boolean) returns text language sql as $$
  select label || ': ' || case when ok then 'ok' else 'WRONG' end $$;

update profiles set home_city = 'Paris', home_country = 'France', home_lat = 48.8566, home_lng = 2.3522
 where username in ('eli', 'fanny');
select pg_temp.check('distance_paris_lyon', round(distance_km(48.8566, 2.3522, 45.76, 4.84)) between 385 and 395);
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
insert into contacts(user_id, name, frequency_value, frequency_unit, city, country, lat, lng) values
 ('00000000-0000-0000-0000-00000000000d', 'Tante Paris', 1, 'months', 'Paris', 'France', 48.87, 2.33),
 ('00000000-0000-0000-0000-00000000000d', 'Voisin Lyon', 1, 'months', 'Lyon', 'France', 45.75, 4.85);
select 'bad_coords' as k, pg_temp.expect_error($q$insert into contacts(user_id, name, frequency_value, frequency_unit, lat) values ('00000000-0000-0000-0000-00000000000d','X',1,'months',10)$q$, 'contacts_coords') as r;

-- a trip to Paris (private, alone): "Eli and Tante Paris live there"
select save_event(jsonb_build_object('visibility','private','title','Voyage Paris','location','Paris',
  'appointment_at', now() + interval '2 days', 'lat', 48.86, 'lng', 2.34)) is not null;
select 'near_paris' as k, string_agg(kind || ':' || name || ':' || city, ',' order by name) from people_near(48.86, 2.34);
select pg_temp.check('near_home_nothing', (select count(*) from people_near(45.75, 4.83)) = 0);
select pg_temp.check('fanny_not_friend_not_listed', not exists (select 1 from people_near(48.86, 2.34) where name = 'Fanny'));
-- eli stops sharing their city with friends
update profiles set friends_see_city = false where username = 'eli';
select pg_temp.check('city_not_shared', not exists (select 1 from people_near(48.86, 2.34) where name = 'Eli'));
update profiles set friends_see_city = true where username = 'eli';
-- invited to the trip: no longer suggested
select send_rdv_invite((select id from rendezvous where title='Voyage Paris' and user_id='00000000-0000-0000-0000-00000000000d'), '00000000-0000-0000-0000-00000000000e') is not null;
select pg_temp.check('members_left_out', (select string_agg(name, ',') from people_near(48.86, 2.34, (select event_id from rendezvous where title='Voyage Paris' and user_id='00000000-0000-0000-0000-00000000000d'))) = 'Tante Paris');
select pg_temp.as_user('');
-- push, at dana's daily hour, once
update profiles set daily_hour = extract(hour from now() at time zone timezone)::int where username = 'dana';
select pg_temp.check('hint_sent', run_travel_hints() >= 1);
select 'hint_notif' as k, params->>'city' as city, params->'names' as names, (params->>'count')::int as n, url like '/rdv/%' as url_ok
  from notifications where kind = 'travel_nearby' and user_id = '00000000-0000-0000-0000-00000000000d';
select pg_temp.check('hint_once', run_travel_hints() = 0 and (select count(*) from notifications where kind = 'travel_nearby' and user_id = '00000000-0000-0000-0000-00000000000d') = 1);
-- new place: sent again; notifications off: not sent
update rendezvous set location = 'Paris 11e' where title = 'Voyage Paris' and user_id = '00000000-0000-0000-0000-00000000000d';
select pg_temp.check('reset_on_move', (select not travel_hint_sent from rendezvous where title = 'Voyage Paris' and user_id = '00000000-0000-0000-0000-00000000000d'));
update profiles set notify_travel = false where username = 'dana';
select pg_temp.check('pref_respected', run_travel_hints() = 0);
update profiles set notify_travel = true where username = 'dana';
set role anon;
select 'anon_people_near' as k, pg_temp.expect_error($q$select * from people_near(48.86, 2.34)$q$, 'permission denied') as r;
reset role;
