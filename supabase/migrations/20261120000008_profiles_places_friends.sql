-- =====================================================================
--  SeeU — migration 0008
--  * profile pictures: profiles.avatar_path + public "avatars" bucket
--  * username can't change once chosen
--  * account emails never leave the server (list_friends, notification names)
--  * friend request tied to a contact: linked automatically on accept, and
--    linking a contact shares the upcoming events that contact is part of
--  * events: link + coordinates (place picked on a map)
--  * timeslots: the organizer doesn't vote; summary lists who said no
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Profile pictures
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists avatar_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true;

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Pictures of the given SeeU users (the app batches the ids it displays).
create or replace function public.profile_avatars(p_ids uuid[])
returns table (user_id uuid, avatar_path text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.avatar_path
  from public.profiles p
  where auth.uid() is not null and p.id = any(p_ids[1:300]) and p.avatar_path is not null
    and not public.is_blocked(p.id, auth.uid())
$$;
revoke execute on function public.profile_avatars(uuid[]) from public, anon;
grant execute on function public.profile_avatars(uuid[]) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Username: chosen once (it's how friends find you), then fixed
-- ---------------------------------------------------------------------
create or replace function public.profiles_username_fixed()
returns trigger
language plpgsql
as $$
begin
  if old.username is not null and new.username is distinct from old.username then
    raise exception 'seeu:username_fixed';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_profiles_username_fixed on public.profiles;
create trigger trg_profiles_username_fixed
  before update of username on public.profiles
  for each row execute function public.profiles_username_fixed();

-- ---------------------------------------------------------------------
-- 3. No account email in names shown to others
-- ---------------------------------------------------------------------
create or replace function public.display_name_of(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU')
  from public.profiles p where p.id = p_user
$$;

-- ---------------------------------------------------------------------
-- 4. Friend request ↔ contact
-- ---------------------------------------------------------------------
alter table public.friendships
  add column if not exists requester_contact_id uuid references public.contacts(id) on delete set null,
  add column if not exists addressee_contact_id uuid references public.contacts(id) on delete set null;

-- Links one of my contacts to a SeeU user (unlinking any other card for them).
create or replace function public.link_contact_internal(p_me uuid, p_contact uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_contact is null or p_user is null then return; end if;
  if not exists (select 1 from public.contacts where id = p_contact and user_id = p_me and linked_user_id is null) then
    return;
  end if;
  update public.contacts set linked_user_id = null where user_id = p_me and linked_user_id = p_user and id <> p_contact;
  update public.contacts set linked_user_id = p_user where id = p_contact;
end;
$$;
revoke execute on function public.link_contact_internal(uuid, uuid, uuid) from public, anon, authenticated;

drop function if exists public.send_friend_request(text);
create or replace function public.send_friend_request(p_username text, p_contact uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_target uuid;
  v_name text;
  v_username text;
  f public.friendships%rowtype;
  v_info jsonb;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_contact is not null and not exists (select 1 from public.contacts where id = p_contact and user_id = me) then
    p_contact := null;
  end if;

  select p.id, coalesce(nullif(trim(p.display_name), ''), p.username), p.username
    into v_target, v_name, v_username
  from public.profiles p
  where p.username = lower(trim(leading '@' from trim(coalesce(p_username, ''))))
  limit 1;

  if v_target is null then return jsonb_build_object('status', 'not_found'); end if;
  if v_target = me then return jsonb_build_object('status', 'self'); end if;
  v_info := jsonb_build_object('user_id', v_target, 'display_name', v_name, 'username', v_username);

  select * into f from public.friendships
  where (requester_id = me and addressee_id = v_target) or (requester_id = v_target and addressee_id = me);

  if found then
    if f.status = 'accepted' then
      perform public.link_contact_internal(me, p_contact, v_target);
      return v_info || jsonb_build_object('status', 'already_friends', 'friendship_id', f.id);
    elsif f.requester_id = me then
      if p_contact is not null then
        update public.friendships set requester_contact_id = p_contact where id = f.id;
      end if;
      return v_info || jsonb_build_object('status', 'already_sent', 'friendship_id', f.id);
    else
      -- they had already asked me: accept (my contact gets linked by the trigger)
      update public.friendships
      set status = 'accepted', responded_at = now(), addressee_contact_id = coalesce(p_contact, addressee_contact_id)
      where id = f.id;
      return v_info || jsonb_build_object('status', 'accepted', 'friendship_id', f.id);
    end if;
  end if;

  insert into public.friendships (requester_id, addressee_id, requester_contact_id)
  values (me, v_target, p_contact) returning * into f;
  return v_info || jsonb_build_object('status', 'sent', 'friendship_id', f.id);
end;
$$;
revoke execute on function public.send_friend_request(text, uuid) from public, anon;
grant execute on function public.send_friend_request(text, uuid) to authenticated;

-- On accept: each side's contact given with the request gets linked.
create or replace function public.friendships_link_contacts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    perform public.link_contact_internal(new.requester_id, new.requester_contact_id, new.addressee_id);
    perform public.link_contact_internal(new.addressee_id, new.addressee_contact_id, new.requester_id);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_friendships_link_contacts on public.friendships;
create trigger trg_friendships_link_contacts
  after update of status on public.friendships
  for each row execute function public.friendships_link_contacts();

drop function if exists public.list_friends();
create function public.list_friends()
returns table (
  friendship_id uuid, user_id uuid, username text, display_name text,
  status text, incoming boolean, created_at timestamptz, contact_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, p.id, p.username,
         coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'),
         f.status,
         f.addressee_id = auth.uid(),
         f.created_at,
         case when f.requester_id = auth.uid() then f.requester_contact_id else f.addressee_contact_id end
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where auth.uid() in (f.requester_id, f.addressee_id)
  order by f.created_at desc
$$;
revoke execute on function public.list_friends() from public, anon;
grant execute on function public.list_friends() to authenticated;

-- Invitations sent on behalf of a given user (used by triggers, where auth.uid()
-- is whoever triggered the change, e.g. the friend accepting).
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
    -- declined, or accepted then left (their copy is gone): invite again
    where id = v_id and (status = 'declined' or (status = 'accepted' and to_rdv_id is null));
  end if;
  return v_id;
end;
$$;

revoke execute on function public.send_rdv_invite_as(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.send_rdv_invite(p_rdv uuid, p_to uuid)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.send_rdv_invite_as(auth.uid(), p_rdv, p_to)
$$;

-- A contact becomes linked to a SeeU friend: the upcoming events that contact is
-- part of are shared with them (as invitations), where I'm allowed to invite.
create or replace function public.contacts_share_events_on_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if new.linked_user_id is null or old.linked_user_id is not distinct from new.linked_user_id then
    return new;
  end if;
  for r in
    select distinct rv.id
    from public.contact_rendezvous cr
    join public.rendezvous rv on rv.id = cr.rendezvous_id
    join public.events e on e.id = rv.event_id
    where cr.contact_id = new.id and rv.user_id = new.user_id
      and e.status = 'planifie' and (e.slots_open or e.appointment_at > now())
      and e.visibility <> 'public'
      and (e.organizer_id = new.user_id or e.guests_can_invite)
      and not public.is_blocked(new.linked_user_id, e.organizer_id)
      and not exists (select 1 from public.rendezvous x
                      where x.event_id = e.id and x.user_id = new.linked_user_id and x.rsvp is distinct from 'declined')
  loop
    begin
      perform public.send_rdv_invite_as(new.user_id, r.id, new.linked_user_id);
    exception when others then
      null; -- one event that can't be shared never blocks the link
    end;
  end loop;
  return new;
end;
$$;
drop trigger if exists trg_contacts_share_events_on_link on public.contacts;
create trigger trg_contacts_share_events_on_link
  after update of linked_user_id on public.contacts
  for each row execute function public.contacts_share_events_on_link();

-- ---------------------------------------------------------------------
-- 5. Events: link + coordinates (organizer only, via save_event)
-- ---------------------------------------------------------------------
alter table public.events
  add column if not exists link text,
  add column if not exists lat double precision,
  add column if not exists lng double precision;

create or replace function public.apply_event_guest_option(p_event uuid, p jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link text := nullif(trim(coalesce(p ->> 'link', '')), '');
  v_lat double precision := (p ->> 'lat')::double precision;
  v_lng double precision := (p ->> 'lng')::double precision;
begin
  if not exists (select 1 from public.events where id = p_event and organizer_id = auth.uid()) then return; end if;
  if v_link is not null and (v_link !~* '^https?://[^\s]+$' or length(v_link) > 500) then
    raise exception 'seeu:bad_link';
  end if;
  if v_lat is not null and (v_lat not between -90 and 90 or v_lng is null or v_lng not between -180 and 180) then
    v_lat := null; v_lng := null;
  end if;
  update public.events
  set guests_can_invite = case when p ? 'guests_can_invite' then coalesce((p ->> 'guests_can_invite')::boolean, guests_can_invite) else guests_can_invite end,
      link = case when p ? 'link' then v_link else link end,
      lat = case when p ? 'lat' then v_lat else lat end,
      lng = case when p ? 'lat' then v_lng else lng end
  where id = p_event;
end;
$$;
revoke execute on function public.apply_event_guest_option(uuid, jsonb) from public, anon, authenticated;

drop function if exists public.get_event(uuid);
create function public.get_event(p_event uuid)
returns table (
  id uuid, organizer_id uuid, organizer_name text, organizer_username text, visibility text,
  title text, location text, description text, appointment_at timestamptz, status text, slots_open boolean,
  going integer, my_rdv_id uuid, my_rsvp text, is_mine boolean, can_post boolean,
  organizer_is_friend boolean, muted_event boolean, muted_organizer boolean,
  link text, lat double precision, lng double precision
)
language sql
stable
security definer
set search_path = public
as $$
  select e.id, e.organizer_id,
         coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'), p.username, e.visibility,
         e.title, e.location, e.description, e.appointment_at, e.status::text, e.slots_open,
         e.going_count,
         mine.id, mine.rsvp, e.organizer_id = auth.uid(),
         public.can_post_in_event(e.id, auth.uid()),
         public.are_friends(e.organizer_id, auth.uid()),
         exists (select 1 from public.user_mutes m where m.user_id = auth.uid() and m.event_id = e.id),
         exists (select 1 from public.user_mutes m where m.user_id = auth.uid() and m.target_user = e.organizer_id),
         e.link, e.lat, e.lng
  from public.events e
  left join public.profiles p on p.id = e.organizer_id
  left join public.rendezvous mine on mine.event_id = e.id and mine.user_id = auth.uid()
  where e.id = p_event and public.can_see_event(e.id, auth.uid())
$$;
revoke execute on function public.get_event(uuid) from public, anon;
grant execute on function public.get_event(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Timeslots: the organizer proposed them (so is free for all of them) and
--    doesn't vote; the summary names who said yes / maybe / no.
-- ---------------------------------------------------------------------
delete from public.slot_votes v
using public.event_slots s, public.events e
where s.id = v.slot_id and e.id = s.event_id and v.user_id = e.organizer_id;

drop function if exists public.list_event_slots(uuid);
create function public.list_event_slots(p_event uuid)
returns table (
  id uuid, starts_at timestamptz, yes integer, maybe integer, no integer,
  my_answer text, yes_names text[], maybe_names text[], no_names text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.starts_at,
         count(v.user_id) filter (where v.answer = 'yes')::int,
         count(v.user_id) filter (where v.answer = 'maybe')::int,
         count(v.user_id) filter (where v.answer = 'no')::int,
         max(v.answer) filter (where v.user_id = auth.uid()),
         coalesce(array_agg(coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU') order by p.display_name)
                    filter (where v.answer = 'yes'), '{}'),
         coalesce(array_agg(coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU') order by p.display_name)
                    filter (where v.answer = 'maybe'), '{}'),
         coalesce(array_agg(coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU') order by p.display_name)
                    filter (where v.answer = 'no'), '{}')
  from public.event_slots s
  join public.events e on e.id = s.event_id
  left join public.slot_votes v on v.slot_id = s.id and v.user_id <> e.organizer_id
  left join public.profiles p on p.id = v.user_id
  where s.event_id = p_event and public.is_event_member(p_event, auth.uid())
  group by s.id, s.starts_at
  order by s.starts_at
$$;
revoke execute on function public.list_event_slots(uuid) from public, anon;
grant execute on function public.list_event_slots(uuid) to authenticated;

create or replace function public.slot_votes_not_organizer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.event_slots s join public.events e on e.id = s.event_id
             where s.id = new.slot_id and e.organizer_id = new.user_id) then
    raise exception 'seeu:organizer_no_vote';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_slot_votes_not_organizer on public.slot_votes;
create trigger trg_slot_votes_not_organizer
  before insert or update on public.slot_votes
  for each row execute function public.slot_votes_not_organizer();

notify pgrst, 'reload schema';
