-- =====================================================================
--  SeeU — migration 0013: public profile, profile page in the app
--  * profiles: bio, city of residence (+ country, coordinates) and privacy
--    settings of the public profile:
--      public_profile   off by default
--      public_fields    what the public page shows: avatar, name, city, bio
--      public_events    none (default) | selected | all: which of my PUBLIC
--                       events (organized or going) appear on it;
--                       "selected" = rendezvous.show_on_profile on my copy
--      friends_see_city my SeeU friends see my city (travel suggestions)
--  * get_public_profile(username) / get_public_event(id): anonymous access
--    for the website; only what the user allowed, never 'contacts' or
--    'private' events, nothing for a disabled or banned profile.
--  * get_user_profile(username): another user's page in the app.
--  * Visibility levels, unchanged (see can_see_event):
--      public   everyone sees and joins it (no invitation needed)
--      contacts all the organizer's SeeU friends see and join it
--      private  only invited people (default); never on a profile or feed
-- =====================================================================

alter table public.profiles
  add column if not exists bio text,
  add column if not exists home_city text,
  add column if not exists home_country text,
  add column if not exists home_lat double precision,
  add column if not exists home_lng double precision,
  add column if not exists public_profile boolean not null default false,
  add column if not exists public_fields text[] not null default '{avatar,name}',
  add column if not exists public_events text not null default 'none',
  add column if not exists friends_see_city boolean not null default true;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_bio_length') then
    alter table public.profiles add constraint profiles_bio_length check (char_length(bio) <= 300);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_home_length') then
    alter table public.profiles add constraint profiles_home_length
      check (char_length(home_city) <= 120 and char_length(home_country) <= 80);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_home_coords') then
    alter table public.profiles add constraint profiles_home_coords
      check ((home_lat is null) = (home_lng is null)
             and (home_lat is null or (home_lat between -90 and 90 and home_lng between -180 and 180)));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_public_fields') then
    alter table public.profiles add constraint profiles_public_fields
      check (public_fields <@ array['avatar', 'name', 'city', 'bio']::text[]);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_public_events') then
    alter table public.profiles add constraint profiles_public_events
      check (public_events in ('none', 'selected', 'all'));
  end if;
end
$$;

-- My copy of a public event: show it on my public profile ("selected" mode).
alter table public.rendezvous add column if not exists show_on_profile boolean not null default false;

-- ---------------------------------------------------------------------
-- Public events of a profile (organized or going), as allowed by its owner.
-- ---------------------------------------------------------------------
create or replace function public.public_profile_events(p_user uuid, p_mode text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(x.j order by x.at), '[]'::jsonb)
  from (
    select e.appointment_at as at,
           jsonb_build_object(
             'id', e.id, 'title', e.title, 'location', e.location, 'starts_at', e.appointment_at,
             'going', e.going_count,
             'role', case when e.organizer_id = p_user then 'organizer' else 'going' end,
             'organizer_name', public.display_name_of(e.organizer_id)) as j
    from public.rendezvous r
    join public.events e on e.id = r.event_id
    where r.user_id = p_user
      and p_mode in ('all', 'selected')
      and (p_mode = 'all' or r.show_on_profile)
      and e.visibility = 'public'
      and e.status = 'planifie'
      and e.appointment_at > now() - interval '6 hours'
      and ((r.rsvp is null and e.organizer_id = p_user) or r.rsvp = 'accepted')
      and not public.is_banned(e.organizer_id)
    order by e.appointment_at
    limit 20
  ) x
$$;
revoke execute on function public.public_profile_events(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Website: public profile page /u/<username>. null = "profile not found"
-- (unknown, disabled or banned: the reason is never told).
-- ---------------------------------------------------------------------
create or replace function public.get_public_profile(p_username text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select (
    select jsonb_build_object(
      'username', p.username,
      'display_name', case when 'name' = any (p.public_fields) then nullif(trim(p.display_name), '') end,
      'avatar_path', case when 'avatar' = any (p.public_fields) then p.avatar_path end,
      'city', case when 'city' = any (p.public_fields) then p.home_city end,
      'country', case when 'city' = any (p.public_fields) then p.home_country end,
      'bio', case when 'bio' = any (p.public_fields) then nullif(trim(p.bio), '') end,
      'events', public.public_profile_events(p.id, p.public_events)
    )
    from public.profiles p
    where p.username = lower(trim(leading '@' from trim(coalesce(p_username, ''))))
      and p.public_profile
      and p.banned_at is null
  )
$$;
revoke execute on function public.get_public_profile(text) from public;
grant execute on function public.get_public_profile(text) to anon, authenticated;

-- Website: public event page /e/<id>. null unless the event is 'public'
-- (and its organizer not banned).
create or replace function public.get_public_event(p_event uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select (
    select jsonb_build_object(
      'id', e.id, 'title', e.title, 'description', e.description, 'location', e.location,
      'starts_at', e.appointment_at, 'status', e.status::text, 'going', e.going_count,
      'link', e.link, 'lat', e.lat, 'lng', e.lng,
      'organizer_name', coalesce(nullif(trim(op.display_name), ''), op.username, 'SeeU'),
      -- only when the organizer has a public profile to link to
      'organizer_username', case when op.public_profile then op.username end
    )
    from public.events e
    join public.profiles op on op.id = e.organizer_id
    where e.id = p_event and e.visibility = 'public' and op.banned_at is null
  )
$$;
revoke execute on function public.get_public_event(uuid) from public;
grant execute on function public.get_public_event(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- App: another user's page (or mine). null = not found / blocked / banned.
-- Always shown (as everywhere in the app): name, @username, picture.
-- City: me; friends if friends_see_city; anyone if public and allowed.
-- Bio: me and friends; anyone if public and allowed.
-- Events: the public ones of the public profile + (friends) the events
-- they organize for their friends or everyone. Never a private event.
-- ---------------------------------------------------------------------
create or replace function public.get_user_profile(p_username text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  p public.profiles%rowtype;
  f public.friendships%rowtype;
  v_rel text;
  v_self boolean;
  v_friends boolean;
  v_city boolean;
  v_bio boolean;
  v_events jsonb;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  select * into p from public.profiles
  where username = lower(trim(leading '@' from trim(coalesce(p_username, ''))));
  if not found or p.banned_at is not null then return null; end if;
  v_self := p.id = me;
  if not v_self and public.is_blocked(p.id, me) then return null; end if;

  select * into f from public.friendships
  where (requester_id = me and addressee_id = p.id) or (requester_id = p.id and addressee_id = me);
  v_rel := case when v_self then 'self'
                when f.id is null then 'none'
                when f.status = 'accepted' then 'friends'
                when f.requester_id = me then 'sent'
                else 'received' end;
  v_friends := v_rel = 'friends';
  v_city := v_self or (v_friends and p.friends_see_city) or (p.public_profile and 'city' = any (p.public_fields));
  v_bio := v_self or v_friends or (p.public_profile and 'bio' = any (p.public_fields));

  select coalesce(jsonb_agg(x.j order by x.at), '[]'::jsonb) into v_events
  from (
    select e.appointment_at as at,
           jsonb_build_object(
             'id', e.id, 'title', e.title, 'location', e.location, 'starts_at', e.appointment_at,
             'slots_open', e.slots_open, 'visibility', e.visibility, 'going', e.going_count,
             'role', case when e.organizer_id = p.id then 'organizer' else 'going' end,
             'organizer_name', public.display_name_of(e.organizer_id),
             'my_rdv_id', mine.id, 'my_rsvp', mine.rsvp) as j
    from public.rendezvous r
    join public.events e on e.id = r.event_id
    left join public.rendezvous mine on mine.event_id = e.id and mine.user_id = me
    where r.user_id = p.id
      and e.status = 'planifie'
      and (e.slots_open or e.appointment_at > now() - interval '6 hours')
      and ((r.rsvp is null and e.organizer_id = p.id) or r.rsvp = 'accepted')
      and e.visibility in ('public', 'contacts')
      and public.can_see_event(e.id, me)
      and (
        (e.visibility = 'public' and p.public_profile
         and (p.public_events = 'all' or (p.public_events = 'selected' and r.show_on_profile)))
        or ((v_friends or v_self) and e.organizer_id = p.id)
      )
    order by e.appointment_at
    limit 20
  ) x;

  return jsonb_build_object(
    'user_id', p.id,
    'username', p.username,
    'display_name', coalesce(nullif(trim(p.display_name), ''), p.username),
    'avatar_path', p.avatar_path,
    'bio', case when v_bio then nullif(trim(p.bio), '') end,
    'city', case when v_city then p.home_city end,
    'country', case when v_city then p.home_country end,
    'relation', v_rel,
    'friendship_id', f.id,
    'contact_id', (select c.id from public.contacts c where c.user_id = me and c.linked_user_id = p.id limit 1),
    'public_profile', p.public_profile,
    'mutual_friends', case when v_self then 0 else (
      select count(*)::int from public.friendships a
      join public.friendships b
        on b.status = 'accepted'
       and (case when b.requester_id = p.id then b.addressee_id else b.requester_id end)
         = (case when a.requester_id = me then a.addressee_id else a.requester_id end)
       and p.id in (b.requester_id, b.addressee_id)
      where a.status = 'accepted' and me in (a.requester_id, a.addressee_id)) end,
    'events', v_events
  );
end;
$$;
revoke execute on function public.get_user_profile(text) from public, anon;
grant execute on function public.get_user_profile(text) to authenticated;

notify pgrst, 'reload schema';
