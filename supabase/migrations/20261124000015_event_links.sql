-- =====================================================================
--  SeeU — migration 0015: invitation links for events, removing a member,
--  ex-friends stay themselves in events, "no reminder" by default
--  * event_links: a secret token per (event, creator). Anyone holding the
--    link can join the event (private or friends): https://<site>/j/<token>,
--    opened in the app as seeu://app/j/<token>. The organizer always may
--    create one; members only when the event lets guests invite
--    (events.guests_can_invite, which now covers links too). A link stops
--    working when revoked, when the event is cancelled, or when its creator
--    is no longer allowed to invite.
--  * join_event_by_link: joins (or answers "à confirmer"), notifies the
--    organizer (and the member who shared the link): kind event_join with
--    params.via_link = true.
--  * rendezvous.joined_via_link_of: who shared the link I used (shown to the
--    organizer in the participants list).
--  * remove_event_member: the organizer removes someone; they can't come
--    back by a link or the friends feed, only if the organizer invites them.
--  * friendships_after_delete: my card for an ex-friend is detached from the
--    events they're still in, so they stay listed as themselves (SeeU account),
--    not duplicated as "pas sur SeeU".
--  * get_user_profile: a friend's page also lists the events (even private)
--    we're both in, e.g. the ones they invited me to.
--  * New contacts default to no recurring reminder (frequency_unit 'never').
-- =====================================================================

alter table public.contacts alter column frequency_unit set default 'never';

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------
create table if not exists public.event_links (
  token text primary key,
  event_id uuid not null references public.events (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  join_count integer not null default 0,
  constraint event_links_token_format check (token ~ '^[A-Za-z0-9_-]{32,64}$')
);
create unique index if not exists event_links_one_active on public.event_links (event_id, created_by) where revoked_at is null;
create index if not exists event_links_event on public.event_links (event_id);
alter table public.event_links enable row level security;
-- no policy: only through the functions below (the token is the secret)

create table if not exists public.event_removals (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  removed_by uuid references auth.users (id) on delete set null,
  removed_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table public.event_removals enable row level security;

alter table public.rendezvous
  add column if not exists joined_via_link_of uuid references auth.users (id) on delete set null;

-- ---------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------
-- 43 url-safe characters from two v4 uuids (gen_random_uuid uses the
-- server's cryptographically strong random source): ~244 random bits.
create or replace function public.new_link_token()
returns text
language sql
volatile
as $$
  select left(translate(encode(decode(replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), 'hex'), 'base64'), '+/=', '-_'), 43)
$$;
revoke execute on function public.new_link_token() from public, anon, authenticated;

-- May p_user share this event (link or direct invitation)?
create or replace function public.can_share_event(p_event uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event and e.status <> 'annule'
      and (e.organizer_id = p_user
           or (e.guests_can_invite and e.visibility <> 'public'
               and exists (select 1 from public.rendezvous r
                           where r.event_id = e.id and r.user_id = p_user and r.rsvp is distinct from 'declined')))
  )
$$;
revoke execute on function public.can_share_event(uuid, uuid) from public, anon, authenticated;

-- The usable link behind a token (null: unknown, revoked, or no longer valid).
create or replace function public.valid_event_link(p_token text)
returns public.event_links
language sql
stable
security definer
set search_path = public
as $$
  select l.* from public.event_links l
  where l.token = p_token and l.revoked_at is null
    and public.can_share_event(l.event_id, l.created_by)
    and not public.is_banned(l.created_by)
$$;
revoke execute on function public.valid_event_link(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Creating / revoking links
-- ---------------------------------------------------------------------
-- My link for this event (the active one, or a new one). p_new: replace it
-- (the old link stops working).
create or replace function public.create_event_link(p_event uuid, p_new boolean default false)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_token text;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if not public.can_share_event(p_event, me) then
    if exists (select 1 from public.events where id = p_event and status = 'annule') then
      raise exception 'seeu:rdv_cancelled';
    end if;
    raise exception 'seeu:not_organizer';
  end if;
  if p_new then
    update public.event_links set revoked_at = now()
    where event_id = p_event and created_by = me and revoked_at is null;
  end if;
  select token into v_token from public.event_links
  where event_id = p_event and created_by = me and revoked_at is null;
  if v_token is null then
    v_token := public.new_link_token();
    insert into public.event_links (token, event_id, created_by) values (v_token, p_event, me);
  end if;
  return v_token;
end;
$$;
revoke execute on function public.create_event_link(uuid, boolean) from public, anon;
grant execute on function public.create_event_link(uuid, boolean) to authenticated;

-- My active link, if any (null: none yet). Doesn't create one.
create or replace function public.get_my_event_link(p_event uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select l.token from public.event_links l
  where l.event_id = p_event and l.created_by = auth.uid() and l.revoked_at is null
    and public.can_share_event(p_event, auth.uid())
$$;
revoke execute on function public.get_my_event_link(uuid) from public, anon;
grant execute on function public.get_my_event_link(uuid) to authenticated;

-- Disable my link; the organizer may disable every link of the event (p_all).
create or replace function public.revoke_event_link(p_event uuid, p_all boolean default false)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  n integer;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_all and not exists (select 1 from public.events where id = p_event and organizer_id = me) then
    raise exception 'seeu:not_organizer';
  end if;
  update public.event_links set revoked_at = now()
  where event_id = p_event and revoked_at is null and (p_all or created_by = me);
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function public.revoke_event_link(uuid, boolean) from public, anon;
grant execute on function public.revoke_event_link(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Opening a link
-- ---------------------------------------------------------------------
-- App: what the link leads to (before joining). null = invalid link.
create or replace function public.get_event_by_link(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  l public.event_links%rowtype;
  e public.events%rowtype;
  mine public.rendezvous%rowtype;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  l := public.valid_event_link(p_token);
  if l.token is null then return null; end if;
  select * into e from public.events where id = l.event_id;
  if public.is_blocked(e.organizer_id, me) or public.is_banned(e.organizer_id) then return null; end if;
  select * into mine from public.rendezvous where event_id = e.id and user_id = me;
  return jsonb_build_object(
    'event_id', e.id,
    'title', e.title,
    'location', e.location,
    'description', e.description,
    'starts_at', e.appointment_at,
    'slots_open', e.slots_open,
    'status', e.status::text,
    'visibility', e.visibility,
    'going', e.going_count,
    'link', e.link, 'lat', e.lat, 'lng', e.lng,
    'organizer_id', e.organizer_id,
    'organizer_name', public.display_name_of(e.organizer_id),
    'organizer_username', (select username from public.profiles where id = e.organizer_id),
    'shared_by_name', case when l.created_by <> e.organizer_id then public.display_name_of(l.created_by) end,
    'is_mine', e.organizer_id = me,
    'my_rdv_id', mine.id,
    'my_rsvp', mine.rsvp,
    'removed', exists (select 1 from public.event_removals x where x.event_id = e.id and x.user_id = me)
  );
end;
$$;
revoke execute on function public.get_event_by_link(text) from public, anon;
grant execute on function public.get_event_by_link(text) to authenticated;

-- Website: the preview of /j/<token> for anyone holding the link (they may
-- join anyway): no participants, no exact coordinates, no ids. null = invalid.
create or replace function public.get_link_preview(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select (
    select jsonb_build_object(
      'title', e.title,
      'location', e.location,
      'description', e.description,
      'starts_at', case when e.slots_open then null else e.appointment_at end,
      'slots_open', e.slots_open,
      'status', e.status::text,
      'going', e.going_count,
      'organizer_name', coalesce(nullif(trim(op.display_name), ''), op.username, 'SeeU'),
      'organizer_avatar_path', op.avatar_path
    )
    from public.valid_event_link(p_token) l
    join public.events e on e.id = l.event_id
    join public.profiles op on op.id = e.organizer_id
    where l.token is not null and op.banned_at is null
  )
$$;
revoke execute on function public.get_link_preview(text) from public;
grant execute on function public.get_link_preview(text) to anon, authenticated;

-- Join through a link. p_status: 'accepted' | 'pending' (à confirmer, or
-- "I'll give my availability" when timeslots are open). Returns my copy's id.
create or replace function public.join_event_by_link(p_token text, p_status text default 'accepted')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  l public.event_links%rowtype;
  e public.events%rowtype;
  v_copy uuid;
  v_old text;
  v_contact uuid;
  v_org_rdv uuid;
  v_params jsonb;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_status not in ('pending', 'accepted') then raise exception 'seeu:bad_answer'; end if;
  l := public.valid_event_link(p_token);
  if l.token is null then raise exception 'seeu:link_invalid'; end if;
  select * into e from public.events where id = l.event_id for update;
  if public.is_blocked(e.organizer_id, me) or public.is_banned(e.organizer_id) then raise exception 'seeu:link_invalid'; end if;
  if e.organizer_id = me then
    return (select id from public.rendezvous where event_id = e.id and user_id = me);
  end if;
  if exists (select 1 from public.event_removals where event_id = e.id and user_id = me) then
    raise exception 'seeu:removed_from_event';
  end if;

  select id, rsvp into v_copy, v_old from public.rendezvous where event_id = e.id and user_id = me;
  if v_copy is null then
    perform set_config('seeu.sync', 'on', true);
    insert into public.rendezvous (user_id, title, location, appointment_at, status, event_id, rsvp, joined_via_link_of)
    values (me, e.title, e.location, e.appointment_at, e.status, e.id, p_status, l.created_by)
    returning id into v_copy;
    perform set_config('seeu.sync', 'off', true);
    update public.event_links set join_count = join_count + 1 where token = l.token;
  elsif v_old is distinct from p_status then
    update public.rendezvous set rsvp = p_status where id = v_copy;
  end if;

  update public.rdv_invitations
  set status = p_status, responded_at = case when p_status = 'pending' then null else now() end
  where to_user = me and to_rdv_id = v_copy and status is distinct from p_status;

  -- my card for the organizer, when we're friends (never created for a stranger)
  if not exists (select 1 from public.contact_rendezvous where rendezvous_id = v_copy) then
    v_contact := public.ensure_friend_contact(me, e.organizer_id);
    if v_contact is not null then
      insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_copy, me)
      on conflict do nothing;
    end if;
  end if;

  -- newly in (or from "declined"): tell the organizer, and the member who shared the link
  if v_old is null or v_old = 'declined' then
    select id into v_org_rdv from public.rendezvous where event_id = e.id and user_id = e.organizer_id;
    v_params := public.event_params(e.id) || jsonb_build_object(
      'name', public.display_name_of(me), 'via_link', true, 'rsvp', p_status,
      'shared_by', case when l.created_by <> e.organizer_id then public.display_name_of(l.created_by) end);
    perform public.enqueue_notification(e.organizer_id, 'event_join', v_params,
      coalesce('/rdv/' || v_org_rdv, '/'), false, me, e.id);
    if l.created_by <> e.organizer_id and l.created_by <> me then
      perform public.enqueue_notification(l.created_by, 'event_join', v_params,
        coalesce('/rdv/' || (select id from public.rendezvous where event_id = e.id and user_id = l.created_by), '/'),
        false, me, e.id);
    end if;
  end if;
  return v_copy;
end;
$$;
revoke execute on function public.join_event_by_link(text, text) from public, anon;
grant execute on function public.join_event_by_link(text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Removing a member (organizer)
-- ---------------------------------------------------------------------
create or replace function public.remove_event_member(p_event uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  e public.events%rowtype;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  select * into e from public.events where id = p_event;
  if not found or e.organizer_id <> me then raise exception 'seeu:not_organizer'; end if;
  if p_user = me then raise exception 'seeu:bad_answer'; end if;
  insert into public.event_removals (event_id, user_id, removed_by) values (p_event, p_user, me)
  on conflict (event_id, user_id) do update set removed_at = now(), removed_by = me;
  -- their invitations to this event, then their copy (votes and counters follow by trigger)
  delete from public.rdv_invitations i
  using public.rendezvous r
  where i.rdv_id = r.id and r.event_id = p_event and i.to_user = p_user;
  delete from public.rendezvous where event_id = p_event and user_id = p_user;
  perform public.refresh_event_counts(p_event);
end;
$$;
revoke execute on function public.remove_event_member(uuid, uuid) from public, anon;
grant execute on function public.remove_event_member(uuid, uuid) to authenticated;

-- Joining from the friends feed: not after being removed.
alter function public.join_event(uuid, text) rename to join_event_core;
revoke execute on function public.join_event_core(uuid, text) from public, anon, authenticated;

create function public.join_event(p_event uuid, p_status text default 'accepted')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_status <> 'declined'
     and exists (select 1 from public.event_removals where event_id = p_event and user_id = auth.uid())
     and not exists (select 1 from public.rendezvous where event_id = p_event and user_id = auth.uid()) then
    raise exception 'seeu:removed_from_event';
  end if;
  return public.join_event_core(p_event, p_status);
end;
$$;
revoke execute on function public.join_event(uuid, text) from public, anon;
grant execute on function public.join_event(uuid, text) to authenticated;

-- Direct invitations: the organizer may invite a removed person again (that
-- lifts the removal); a guest can't.
create or replace function public.send_rdv_invite_as(p_me uuid, p_rdv uuid, p_to uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := p_me;
  r public.rendezvous%rowtype;
  e public.events%rowtype;
  v_copy uuid;
  v_copy_rsvp text;
  v_contact uuid;
  v_id uuid;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  select * into r from public.rendezvous where id = p_rdv and user_id = me;
  if not found then raise exception 'seeu:rdv_not_found'; end if;
  if r.status = 'annule' then raise exception 'seeu:rdv_cancelled'; end if;
  if not public.are_friends(me, p_to) then raise exception 'seeu:not_friends'; end if;

  if r.event_id is null then
    insert into public.events (organizer_id, title, location, appointment_at, status)
    values (me, r.title, r.location, r.appointment_at, r.status) returning id into r.event_id;
    perform set_config('seeu.sync', 'on', true);
    update public.rendezvous set event_id = r.event_id where id = p_rdv;
    perform set_config('seeu.sync', 'off', true);
  end if;
  select * into e from public.events where id = r.event_id;
  if e.visibility = 'public' and e.organizer_id <> me then raise exception 'seeu:not_organizer'; end if;
  if public.is_blocked(p_to, e.organizer_id) then raise exception 'seeu:blocked'; end if;
  if exists (select 1 from public.event_removals where event_id = e.id and user_id = p_to) then
    if e.organizer_id <> me then raise exception 'seeu:removed_from_event'; end if;
    delete from public.event_removals where event_id = e.id and user_id = p_to;
  end if;

  select id, rsvp into v_copy, v_copy_rsvp from public.rendezvous where user_id = p_to and event_id = e.id limit 1;
  if v_copy is null then
    perform set_config('seeu.sync', 'on', true);
    insert into public.rendezvous (user_id, title, location, appointment_at, status, event_id, rsvp)
    values (p_to, e.title, e.location, e.appointment_at, e.status, e.id, 'pending')
    returning id into v_copy;
    perform set_config('seeu.sync', 'off', true);
    v_contact := public.copy_contact_for(p_to, me);
    if v_contact is not null then
      insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_copy, p_to)
      on conflict do nothing;
    end if;
  elsif v_copy_rsvp = 'declined' then
    update public.rendezvous set rsvp = 'pending' where id = v_copy;
  elsif v_copy_rsvp is distinct from 'pending' then
    return null; -- already in (accepted or organizer): nothing to send
  end if;

  select id into v_id from public.rdv_invitations where rdv_id = p_rdv and to_user = p_to;
  if v_id is null then
    insert into public.rdv_invitations (rdv_id, from_user, to_user, to_rdv_id)
    values (p_rdv, me, p_to, v_copy)
    returning id into v_id;
  else
    update public.rdv_invitations
    set status = 'pending', created_at = now(), responded_at = null, to_rdv_id = v_copy
    where id = v_id and (status = 'declined' or (status = 'accepted' and to_rdv_id is null));
  end if;
  return v_id;
end;
$$;
revoke execute on function public.send_rdv_invite_as(uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Participants: + how they joined (the organizer sees "via un lien")
--    Return columns change: drop and re-create.
-- ---------------------------------------------------------------------
drop function if exists public.list_event_participants(uuid);
create function public.list_event_participants(p_event uuid)
returns table (user_id uuid, display_name text, username text, rsvp text, is_friend boolean,
               via_link boolean, link_shared_by text)
language sql
stable
security definer
set search_path = public
as $$
  select x.uid, coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'), p.username, x.rsvp,
         public.are_friends(x.uid, auth.uid()),
         case when x.org = auth.uid() then x.via is not null end,
         case when x.org = auth.uid() and x.via is not null and x.via <> x.org then public.display_name_of(x.via) end
  from (
    select e.organizer_id as uid, 'organizer' as rsvp, 0 as rank, null::uuid as via, e.organizer_id as org
    from public.events e where e.id = p_event
    union all
    select r.user_id, r.rsvp, case r.rsvp when 'accepted' then 1 else 2 end, r.joined_via_link_of, e.organizer_id
    from public.rendezvous r join public.events e on e.id = r.event_id
    where r.event_id = p_event and r.user_id <> e.organizer_id and r.rsvp in ('accepted', 'pending')
  ) x
  left join public.profiles p on p.id = x.uid
  where public.can_see_event(p_event, auth.uid())
    and not public.is_blocked(x.uid, auth.uid())
  order by x.rank, 2
  limit 500
$$;
revoke execute on function public.list_event_participants(uuid) from public, anon;
grant execute on function public.list_event_participants(uuid) to authenticated;

-- Members (not only the organizer) invite only when allowed: links follow the
-- same option. Turning it off disables the guests' links (see can_share_event).

-- ---------------------------------------------------------------------
-- 7. End of a friendship: my card for them leaves the events they're still in
-- ---------------------------------------------------------------------
create or replace function public.friendships_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.contact_rendezvous cr
  using public.contacts c, public.rendezvous r
  where c.id = cr.contact_id and r.id = cr.rendezvous_id
    and ((c.user_id = old.requester_id and c.linked_user_id = old.addressee_id)
      or (c.user_id = old.addressee_id and c.linked_user_id = old.requester_id))
    and r.event_id is not null
    and public.is_event_member(r.event_id, c.linked_user_id);
  update public.contacts set linked_user_id = null
  where (user_id = old.requester_id and linked_user_id = old.addressee_id)
     or (user_id = old.addressee_id and linked_user_id = old.requester_id);
  delete from public.rdv_invitations
  where status = 'pending'
    and ((from_user = old.requester_id and to_user = old.addressee_id)
      or (from_user = old.addressee_id and to_user = old.requester_id));
  return old;
end;
$$;

-- ---------------------------------------------------------------------
-- 8. Cards created automatically for a friend: no recurring reminder
-- ---------------------------------------------------------------------
create or replace function public.ensure_friend_contact(p_user uuid, p_friend uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contact uuid := public.copy_contact_for(p_user, p_friend);
  sender public.profiles%rowtype;
begin
  if v_contact is null and public.are_friends(p_user, p_friend) then
    select * into sender from public.profiles where id = p_friend;
    insert into public.contacts (user_id, name, frequency_value, frequency_unit, linked_user_id)
    values (
      p_user,
      left(coalesce(nullif(trim(sender.display_name), ''), sender.username, 'SeeU'), 120),
      1, 'never', p_friend
    )
    returning id into v_contact;
  end if;
  return v_contact;
end;
$$;

-- ---------------------------------------------------------------------
-- 9. A friend's page: + the events we're both in (even private)
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
      and public.can_see_event(e.id, me)
      and (
        (e.visibility = 'public' and p.public_profile
         and (p.public_events = 'all' or (p.public_events = 'selected' and r.show_on_profile)))
        or ((v_friends or v_self) and e.organizer_id = p.id and e.visibility in ('public', 'contacts'))
        -- events we're both in (they invited me, or we go together)
        or (not v_self and mine.id is not null and mine.rsvp is distinct from 'declined')
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
