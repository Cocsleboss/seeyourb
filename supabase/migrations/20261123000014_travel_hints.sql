-- =====================================================================
--  SeeU — migration 0014: city of residence on contacts, travel hints
--  "Marie lives in Lyon, you could see her during your stay."
--  * contacts: city / country / coordinates (people without an account;
--    for SeeU friends their own profile city is used when they share it).
--  * No separate "trip" object: an event (even private and alone) whose
--    place is ≥ 40 km from my home IS the trip. people_near() lists my
--    friends and contacts living within 40 km of that place.
--  * run_travel_hints() (hourly, at each user's daily hour): one push
--    ("travel_nearby") 12 h – 4 days before such an event, if someone lives
--    there. Respects profiles.notify_travel, mutes and blocks.
-- =====================================================================

alter table public.contacts
  add column if not exists city text,
  add column if not exists country text,
  add column if not exists lat double precision,
  add column if not exists lng double precision;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'contacts_city_length') then
    alter table public.contacts add constraint contacts_city_length check (char_length(city) <= 120 and char_length(country) <= 80);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'contacts_coords') then
    alter table public.contacts add constraint contacts_coords
      check ((lat is null) = (lng is null) and (lat is null or (lat between -90 and 90 and lng between -180 and 180)));
  end if;
end
$$;

alter table public.profiles add column if not exists notify_travel boolean not null default true;
alter table public.rendezvous add column if not exists travel_hint_sent boolean not null default false;

-- Distance in km between two points (haversine; plenty for "same area").
create or replace function public.distance_km(p_lat1 double precision, p_lng1 double precision,
                                              p_lat2 double precision, p_lng2 double precision)
returns double precision
language sql
immutable
as $$
  select 6371.0 * 2 * asin(least(1.0, sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2))))
$$;

-- People of p_user living near (lat, lng), when that place is far from p_user's home.
-- Friends: their profile city if they share it with friends (or publicly).
-- Contacts: the city on my card (not repeated when the friend already shows).
-- Members of p_event are left out (they already know).
create or replace function public.people_near_for(p_user uuid, p_lat double precision, p_lng double precision,
                                                  p_event uuid default null, p_limit integer default 10)
returns table (kind text, user_id uuid, username text, contact_id uuid, name text, city text, km integer)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select pr.home_lat, pr.home_lng from public.profiles pr
    where pr.id = p_user and pr.home_lat is not null and p_lat is not null and p_lng is not null
      and public.distance_km(pr.home_lat, pr.home_lng, p_lat, p_lng) >= 40
  ),
  members as (
    select r.user_id from public.rendezvous r where p_event is not null and r.event_id = p_event and r.rsvp is distinct from 'declined'
    union select e.organizer_id from public.events e where e.id = p_event
  ),
  my_event_contacts as (
    select cr.contact_id from public.contact_rendezvous cr
    join public.rendezvous r on r.id = cr.rendezvous_id
    where p_event is not null and r.event_id = p_event and r.user_id = p_user
  ),
  friends as (
    select fp.id as uid, fp.username, c.id as cid,
           coalesce(c.name, nullif(trim(fp.display_name), ''), fp.username, 'SeeU') as name,
           fp.home_city as city,
           public.distance_km(fp.home_lat, fp.home_lng, p_lat, p_lng) as d
    from me
    join public.friendships f on f.status = 'accepted' and p_user in (f.requester_id, f.addressee_id)
    join public.profiles fp on fp.id = case when f.requester_id = p_user then f.addressee_id else f.requester_id end
    left join public.contacts c on c.user_id = p_user and c.linked_user_id = fp.id
    where fp.home_lat is not null and fp.banned_at is null
      and (fp.friends_see_city or (fp.public_profile and 'city' = any (fp.public_fields)))
      and public.distance_km(fp.home_lat, fp.home_lng, p_lat, p_lng) <= 40
  ),
  cards as (
    select c.linked_user_id as uid, lp.username, c.id as cid, c.name, c.city,
           public.distance_km(c.lat, c.lng, p_lat, p_lng) as d
    from me
    join public.contacts c on c.user_id = p_user
    left join public.profiles lp on lp.id = c.linked_user_id
    where c.lat is not null
      and public.distance_km(c.lat, c.lng, p_lat, p_lng) <= 40
      and (c.linked_user_id is null or c.linked_user_id not in (select uid from friends))
  )
  select x.kind, x.uid, x.username, x.cid, x.name, x.city, round(x.d)::int
  from (
    select 'friend'::text as kind, uid, username, cid, name, city, d from friends
    union all
    select 'contact', uid, username, cid, name, city, d from cards
  ) x
  where (x.uid is null or x.uid not in (select m.user_id from members m where m.user_id is not null))
    and (x.cid is null or x.cid not in (select contact_id from my_event_contacts))
    and (x.uid is null or not public.is_blocked(x.uid, p_user))
  order by x.d, x.name
  limit least(greatest(coalesce(p_limit, 10), 1), 30)
$$;
revoke execute on function public.people_near_for(uuid, double precision, double precision, uuid, integer) from public, anon, authenticated;

-- App: suggestions for a place (event form) or an event of mine (event page).
create or replace function public.people_near(p_lat double precision, p_lng double precision, p_event uuid default null)
returns table (kind text, user_id uuid, username text, contact_id uuid, name text, city text, km integer)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_event is not null and not public.is_event_member(p_event, me) then
    p_event := null;
  end if;
  return query select * from public.people_near_for(me, p_lat, p_lng, p_event, 10);
end;
$$;
revoke execute on function public.people_near(double precision, double precision, uuid) from public, anon;
grant execute on function public.people_near(double precision, double precision, uuid) to authenticated;

-- A new date or place: the hint may be sent again for the new trip.
create or replace function public.rdv_before_update()
returns trigger
language plpgsql
as $$
begin
  if new.appointment_at is distinct from old.appointment_at then
    new.reminder_sent := false;
  end if;
  if new.appointment_at is distinct from old.appointment_at or new.location is distinct from old.location then
    new.travel_hint_sent := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.run_travel_hints()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_names text[];
  v_count int;
  v_city text;
  n int := 0;
begin
  for r in
    select rv.id, rv.user_id, rv.event_id, e.lat, e.lng
    from public.rendezvous rv
    join public.events e on e.id = rv.event_id
    join public.profiles p on p.id = rv.user_id
    where not rv.travel_hint_sent
      and rv.status = 'planifie' and rv.rsvp is distinct from 'declined'
      and not e.slots_open and e.lat is not null and e.lng is not null
      and e.appointment_at between now() + interval '12 hours' and now() + interval '4 days'
      and p.notify_travel and p.home_lat is not null and p.banned_at is null
      and extract(hour from now() at time zone p.timezone) = p.daily_hour
      and public.distance_km(p.home_lat, p.home_lng, e.lat, e.lng) >= 40
    for update of rv skip locked
  loop
    perform set_config('seeu.sync', 'on', true);
    update public.rendezvous set travel_hint_sent = true where id = r.id;
    perform set_config('seeu.sync', 'off', true);
    select array_agg(x.name order by x.km, x.name), count(*), (array_agg(x.city order by x.km) filter (where x.city is not null))[1]
      into v_names, v_count, v_city
    from public.people_near_for(r.user_id, r.lat, r.lng, r.event_id, 10) x;
    if coalesce(v_count, 0) > 0 then
      perform public.enqueue_notification(
        r.user_id, 'travel_nearby',
        public.event_params(r.event_id) || jsonb_build_object(
          'names', to_jsonb(v_names[1:3]), 'count', v_count, 'city', v_city),
        '/rdv/' || r.id, false, null, r.event_id);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke execute on function public.run_travel_hints() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'seeu-travel-hints') then
    perform cron.unschedule('seeu-travel-hints');
  end if;
end
$$;
select cron.schedule('seeu-travel-hints', '5 * * * *', 'select public.run_travel_hints()');

notify pgrst, 'reload schema';
