-- =====================================================================
--  SeeU — migration 0004: events, timeslots, chat, mute/block,
--  localized notifications, photo thumbnails, profile language.
--
--  Model
--  -----
--  * public.events is the shared, canonical part of a rendezvous:
--    organizer, visibility, title, place, date, status, timeslot poll.
--  * Each participant keeps their OWN public.rendezvous row (a "copy") with
--    event_id → events.id: private notes, linked contacts, RSVP, reminders,
--    and their photos. Shared fields are mirrored from the event.
--  * visibility: 'private'  → only invited friends
--                'contacts' → also visible to (and joinable by) all the
--                             organizer's SeeU friends, who get notified
--                'public'   → anyone can see and join; only the organizer
--                             posts photos and messages (announcements);
--                             only allowed creators (public_event_creators)
--  * Errors are raised as stable codes "seeu:<code>"; the app translates them.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Profile language (notifications are rendered in it)
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists locale text not null default 'fr';
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_locale_format') then
    alter table public.profiles add constraint profiles_locale_format check (locale ~ '^[a-z]{2}$');
  end if;
end
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(leading '@' from trim(coalesce(new.raw_user_meta_data ->> 'username', ''))));
  v_locale text := lower(coalesce(new.raw_user_meta_data ->> 'locale', ''));
  v_name text;
begin
  if v_username !~ '^[a-z0-9][a-z0-9_.]{2,19}$'
     or exists (select 1 from public.profiles where username = v_username) then
    v_username := null;
  end if;
  if v_locale !~ '^[a-z]{2}$' then v_locale := 'fr'; end if;
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    v_username,
    split_part(coalesce(new.email, ''), '@', 1)
  );
  begin
    insert into public.profiles (id, email, display_name, username, locale)
    values (new.id, new.email, v_name, v_username, v_locale)
    on conflict (id) do update set email = excluded.email;
  exception when unique_violation then
    insert into public.profiles (id, email, display_name, locale)
    values (new.id, new.email, v_name, v_locale)
    on conflict (id) do update set email = excluded.email;
  end;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 2. Who may create public events (no client access: managed in the
--    SQL editor, see docs/SETUP.md)
-- ---------------------------------------------------------------------
create table if not exists public.public_event_creators (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);
alter table public.public_event_creators enable row level security;

create or replace function public.can_create_public_events()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.public_event_creators where user_id = auth.uid())
$$;

-- ---------------------------------------------------------------------
-- 3. Blocks and mutes
-- ---------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists idx_user_blocks_blocked on public.user_blocks(blocked_id);
alter table public.user_blocks enable row level security;

drop policy if exists "user_blocks_select_own" on public.user_blocks;
create policy "user_blocks_select_own" on public.user_blocks
  for select using ((select auth.uid()) = blocker_id);
drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own" on public.user_blocks
  for delete using ((select auth.uid()) = blocker_id);

create or replace function public.is_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_a is not null and p_b is not null and exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b) or (b.blocker_id = p_b and b.blocked_id = p_a)
  )
$$;

-- ---------------------------------------------------------------------
-- 4. Events
-- ---------------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references auth.users(id) on delete cascade,
  visibility text not null default 'private' check (visibility in ('private', 'contacts', 'public')),
  title text check (char_length(title) <= 120),
  location text check (char_length(location) <= 200),
  description text check (char_length(description) <= 2000),
  appointment_at timestamptz not null,
  status public.rdv_status not null default 'planifie',
  -- several timeslots proposed, final date not chosen yet (appointment_at = earliest slot)
  slots_open boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_events_organizer on public.events(organizer_id, appointment_at);
create index if not exists idx_events_feed on public.events(visibility, appointment_at) where status = 'planifie';
alter table public.events enable row level security;

-- Backfill: every existing rendezvous gets an event. Copies of a shared rendezvous
-- (same share_id) share one event; its organizer is whoever sent the invitations.
do $$
declare
  g record;
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'rendezvous' and column_name = 'share_id') then
    update public.rendezvous set share_id = gen_random_uuid() where share_id is null;
    for g in
      select distinct on (r.share_id) r.share_id, r.user_id, r.title, r.location, r.appointment_at, r.status, r.created_at
      from public.rendezvous r
      order by r.share_id,
               (exists (select 1 from public.rdv_invitations i where i.rdv_id = r.id)) desc,
               (r.rsvp is null) desc,
               r.created_at
    loop
      insert into public.events (id, organizer_id, title, location, appointment_at, status, created_at)
      values (g.share_id, g.user_id, g.title, g.location, g.appointment_at, g.status, g.created_at)
      on conflict (id) do nothing;
    end loop;
    alter table public.rendezvous rename column share_id to event_id;
  end if;
end
$$;

alter table public.rendezvous add column if not exists event_id uuid;
alter table public.rendezvous add column if not exists chat_read_at timestamptz;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'rendezvous_event_fk') then
    alter table public.rendezvous add constraint rendezvous_event_fk
      foreign key (event_id) references public.events(id) on delete set null;
  end if;
end
$$;
drop index if exists public.idx_rdv_share;
create index if not exists idx_rdv_event on public.rendezvous(event_id);
create unique index if not exists idx_rdv_event_user on public.rendezvous(event_id, user_id) where event_id is not null;

-- Denormalized counters (feeds, "shared" badge): members = copies not declined
-- (organizer included), going = organizer + accepted.
alter table public.events add column if not exists member_count integer not null default 0;
alter table public.events add column if not exists going_count integer not null default 0;

create or replace function public.refresh_event_counts(p_event uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.events e
  set member_count = x.members, going_count = x.going
  from (
    select count(*) filter (where r.rsvp is distinct from 'declined')::int as members,
           count(*) filter (where r.rsvp = 'accepted' or (r.rsvp is null and r.user_id = ev.organizer_id))::int as going
    from public.events ev left join public.rendezvous r on r.event_id = ev.id
    where ev.id = p_event
  ) x
  where e.id = p_event and (e.member_count, e.going_count) is distinct from (x.members, x.going)
$$;

create or replace function public.rdv_after_change_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.event_id is not null then
    perform public.refresh_event_counts(old.event_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.event_id is not null
     and (tg_op = 'INSERT' or new.event_id is distinct from old.event_id or new.rsvp is distinct from old.rsvp) then
    perform public.refresh_event_counts(new.event_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_rdv_counts on public.rendezvous;
create trigger trg_rdv_counts
  after insert or delete or update of event_id, rsvp on public.rendezvous
  for each row execute function public.rdv_after_change_counts();

do $$
declare
  v uuid;
begin
  for v in select id from public.events loop
    perform public.refresh_event_counts(v);
  end loop;
end
$$;

-- Membership helpers ----------------------------------------------------
-- Member = organizer, or has a copy that is not declined.
create or replace function public.is_event_member(p_event uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.events e where e.id = p_event and e.organizer_id = p_user)
      or exists (select 1 from public.rendezvous r
                 where r.event_id = p_event and r.user_id = p_user and r.rsvp is distinct from 'declined')
$$;

-- Visible = member, invited, or allowed by the visibility; never across a block.
create or replace function public.can_see_event(p_event uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and not public.is_blocked(e.organizer_id, p_user)
      and (
        e.organizer_id = p_user
        or e.visibility = 'public'
        or (e.visibility = 'contacts' and public.are_friends(e.organizer_id, p_user))
        or exists (select 1 from public.rendezvous r where r.event_id = e.id and r.user_id = p_user)
      )
  )
$$;

drop policy if exists "events_select_visible" on public.events;
create policy "events_select_visible" on public.events
  for select using (public.can_see_event(id, (select auth.uid())));
-- (no insert/update/delete policy: events change through save_event & co.)

drop trigger if exists trg_events_updated on public.events;
create trigger trg_events_updated
  before update on public.events
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 5. Timeslot poll
-- ---------------------------------------------------------------------
create table if not exists public.event_slots (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  starts_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (event_id, starts_at)
);
create table if not exists public.slot_votes (
  slot_id uuid not null references public.event_slots(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer text not null check (answer in ('yes', 'maybe', 'no')),
  updated_at timestamptz not null default now(),
  primary key (slot_id, user_id)
);
create index if not exists idx_slot_votes_user on public.slot_votes(user_id);
alter table public.event_slots enable row level security;
alter table public.slot_votes enable row level security;

drop policy if exists "event_slots_select_members" on public.event_slots;
create policy "event_slots_select_members" on public.event_slots
  for select using (public.is_event_member(event_id, (select auth.uid())));
drop policy if exists "slot_votes_select_members" on public.slot_votes;
create policy "slot_votes_select_members" on public.slot_votes
  for select using (exists (
    select 1 from public.event_slots s where s.id = slot_id and public.is_event_member(s.event_id, (select auth.uid()))
  ));

-- ---------------------------------------------------------------------
-- 6. Event chat / announcements
-- ---------------------------------------------------------------------
create table if not exists public.event_messages (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists idx_event_messages_event on public.event_messages(event_id, created_at desc);
alter table public.event_messages enable row level security;

create or replace function public.can_post_in_event(p_event uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and public.is_event_member(e.id, p_user)
      and (e.visibility <> 'public' or e.organizer_id = p_user)
      and not public.is_blocked(e.organizer_id, p_user)
  )
$$;

drop policy if exists "event_messages_select_members" on public.event_messages;
create policy "event_messages_select_members" on public.event_messages
  for select using (
    public.is_event_member(event_id, (select auth.uid()))
    and not exists (select 1 from public.user_blocks b where b.blocker_id = (select auth.uid()) and b.blocked_id = user_id)
  );
drop policy if exists "event_messages_insert_members" on public.event_messages;
create policy "event_messages_insert_members" on public.event_messages
  for insert with check ((select auth.uid()) = user_id and public.can_post_in_event(event_id, (select auth.uid())));
drop policy if exists "event_messages_delete_own" on public.event_messages;
create policy "event_messages_delete_own" on public.event_messages
  for delete using ((select auth.uid()) = user_id);

-- Live updates in the app (Supabase Realtime respects the select policy above).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'event_messages') then
    alter publication supabase_realtime add table public.event_messages;
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 7. Mutes: a person (all their events & messages) or one event
-- ---------------------------------------------------------------------
create table if not exists public.user_mutes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_user uuid references auth.users(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (num_nonnulls(target_user, event_id) = 1),
  check (target_user is distinct from user_id)
);
create unique index if not exists idx_user_mutes_user on public.user_mutes(user_id, target_user) where target_user is not null;
create unique index if not exists idx_user_mutes_event on public.user_mutes(user_id, event_id) where event_id is not null;
alter table public.user_mutes enable row level security;

drop policy if exists "user_mutes_own" on public.user_mutes;
create policy "user_mutes_own" on public.user_mutes
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create or replace function public.is_muted(p_user uuid, p_actor uuid, p_event uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_mutes m
    where m.user_id = p_user
      and (
        (p_actor is not null and m.target_user = p_actor)
        or (p_event is not null and m.event_id = p_event)
        or (p_event is not null and m.target_user = (select e.organizer_id from public.events e where e.id = p_event))
      )
  )
$$;

-- ---------------------------------------------------------------------
-- 8. Photos: thumbnails; on public events only the organizer adds photos
-- ---------------------------------------------------------------------
alter table public.photos add column if not exists thumb_path text;

drop policy if exists "photos_insert_own" on public.photos;
create policy "photos_insert_own" on public.photos
  for insert with check (
    (select auth.uid()) = user_id
    and storage_path like ((select auth.uid())::text || '/%')
    and (thumb_path is null or thumb_path like ((select auth.uid())::text || '/%'))
    and (contact_id is null or exists (select 1 from public.contacts c where c.id = contact_id and c.user_id = (select auth.uid())))
    and (rendezvous_id is null or exists (
      select 1 from public.rendezvous r
      left join public.events e on e.id = r.event_id
      where r.id = rendezvous_id and r.user_id = (select auth.uid())
        and (e.id is null or e.visibility <> 'public' or e.organizer_id = (select auth.uid()))
    ))
  );

-- Photos added by the other members of the event of my copy p_rdv (read-only).
create or replace function public.list_shared_rdv_photos(p_rdv uuid)
returns setof public.photos
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.rendezvous mine
  join public.rendezvous r on r.event_id = mine.event_id and r.id <> mine.id
  join public.photos p on p.rendezvous_id = r.id
  where mine.id = p_rdv
    and mine.user_id = auth.uid()
    and mine.event_id is not null
    and public.is_event_member(mine.event_id, auth.uid())
    and not public.is_blocked(r.user_id, auth.uid())
  order by p.created_at desc
$$;

create or replace function public.can_read_shared_photo(p_path text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.photos p
    join public.rendezvous r on r.id = p.rendezvous_id
    where (p.storage_path = p_path or p.thumb_path = p_path)
      and r.event_id is not null
      and public.is_event_member(r.event_id, auth.uid())
  )
$$;

-- ---------------------------------------------------------------------
-- 9. Notifications: kind + params, rendered by the dispatcher in the
--    recipient's language and time zone. Mutes and blocks apply here.
-- ---------------------------------------------------------------------
alter table public.notifications add column if not exists params jsonb not null default '{}'::jsonb;
alter table public.notifications alter column title drop not null;

drop function if exists public.enqueue_notification(uuid, text, text, text, text, boolean);
create or replace function public.enqueue_notification(
  p_user uuid, p_kind text, p_params jsonb, p_url text,
  p_force_push boolean default false, p_actor uuid default null, p_event uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_user is null or p_user = p_actor then return null; end if;
  if public.is_blocked(p_user, p_actor) or public.is_muted(p_user, p_actor, p_event) then return null; end if;
  if p_event is not null and public.is_blocked(p_user, (select organizer_id from public.events where id = p_event)) then
    return null;
  end if;
  insert into public.notifications (user_id, kind, params, url, channel, status, force_push)
  values (p_user, p_kind, coalesce(p_params, '{}'::jsonb), p_url, 'none', 'pending', p_force_push)
  returning id into v_id;
  perform public.request_dispatch();
  return v_id;
end;
$$;

create or replace function public.send_test_notification()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'seeu:not_signed_in'; end if;
  return public.enqueue_notification(auth.uid(), 'test', '{}'::jsonb, '/settings', true);
end;
$$;

create or replace function public.notify_friendship()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    perform public.enqueue_notification(
      new.addressee_id, 'friend_request',
      jsonb_build_object('name', public.display_name_of(new.requester_id),
                         'username', (select username from public.profiles where id = new.requester_id)),
      '/contacts', false, new.requester_id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted' then
    perform public.enqueue_notification(
      new.requester_id, 'friend_accept',
      jsonb_build_object('name', public.display_name_of(new.addressee_id)),
      '/contacts', false, new.addressee_id);
  end if;
  return new;
end;
$$;

create or replace function public.notify_wave()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contact uuid;
begin
  select id into v_contact from public.contacts where user_id = new.to_user and linked_user_id = new.from_user limit 1;
  perform public.enqueue_notification(
    new.to_user, 'wave',
    jsonb_build_object('name', public.display_name_of(new.from_user), 'has_contact', v_contact is not null),
    case when v_contact is not null then '/contacts/' || v_contact else '/contacts' end,
    false, new.from_user);
  return new;
end;
$$;

-- Event summary used by several notifications.
create or replace function public.event_params(p_event uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select jsonb_build_object('title', nullif(trim(e.title), ''), 'at', e.appointment_at,
                              'location', nullif(trim(e.location), ''), 'slots', e.slots_open,
                              'visibility', e.visibility)
    from public.events e where e.id = p_event), '{}'::jsonb)
$$;

create or replace function public.notify_rdv_invitation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.rendezvous%rowtype;
begin
  select * into r from public.rendezvous where id = new.rdv_id;
  if not found then return new; end if;

  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending')
     and auth.uid() is distinct from new.to_user then
    perform public.enqueue_notification(
      new.to_user, 'rdv_invite',
      public.event_params(r.event_id) || jsonb_build_object('name', public.display_name_of(new.from_user),
                                                             'past', r.status = 'valide'),
      case when new.to_rdv_id is not null then '/rdv/' || new.to_rdv_id else '/contacts' end,
      false, new.from_user, r.event_id);
  elsif tg_op = 'UPDATE' and new.status in ('accepted', 'declined') and new.status is distinct from old.status then
    perform public.enqueue_notification(
      new.from_user, 'rdv_response',
      public.event_params(r.event_id) || jsonb_build_object('name', public.display_name_of(new.to_user), 'answer', new.status),
      '/rdv/' || r.id,
      false, new.to_user, r.event_id);
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 10. Keeping copies in sync with their event
-- ---------------------------------------------------------------------
-- Old per-copy sync is replaced by the event.
drop trigger if exists trg_rdv_sync_shared on public.rendezvous;
drop trigger if exists trg_notify_shared_rdv_change on public.rendezvous;
drop function if exists public.rdv_sync_shared();
drop function if exists public.notify_shared_rdv_change();

-- Only the organizer changes the shared fields or cancels; others edit their notes,
-- contacts, RSVP, and (outside private events) their own "it happened".
-- A copy can't be attached to someone else's event by hand (that would grant access):
-- copies of other people's events are created by the functions below (seeu.sync = on).
create or replace function public.rdv_guard_shared()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.events%rowtype;
begin
  if coalesce(current_setting('seeu.sync', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.event_id is not null
       and not exists (select 1 from public.events where id = new.event_id and organizer_id = new.user_id) then
      raise exception 'seeu:not_organizer';
    end if;
    return new;
  end if;
  if new.event_id is null then
    return new; -- detached (event deleted)
  end if;
  if new.event_id is distinct from old.event_id then
    raise exception 'seeu:not_organizer';
  end if;
  select * into e from public.events where id = new.event_id;
  if not found or e.organizer_id = new.user_id then
    return new;
  end if;
  if new.title is distinct from old.title
     or new.location is distinct from old.location
     or new.appointment_at is distinct from old.appointment_at
     or (new.status is distinct from old.status and 'annule' in (new.status, old.status)) then
    raise exception 'seeu:not_organizer';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rdv_guard_shared on public.rendezvous;
create trigger trg_rdv_guard_shared
  before insert or update on public.rendezvous
  for each row execute function public.rdv_guard_shared();

-- A copy edited by its owner pushes the shared fields to the event
-- (organizer), or "it happened" on a private event (any member).
create or replace function public.rdv_push_to_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.events%rowtype;
begin
  if new.event_id is null or coalesce(current_setting('seeu.sync', true), '') = 'on' then
    return new;
  end if;
  select * into e from public.events where id = new.event_id;
  if not found then return new; end if;
  if e.organizer_id = new.user_id then
    update public.events
    set title = new.title,
        location = new.location,
        appointment_at = new.appointment_at,
        status = case
          when e.visibility = 'private' or new.status = 'annule' or e.status = 'annule' then new.status
          else e.status end
    where id = e.id
      and (title is distinct from new.title or location is distinct from new.location
        or appointment_at is distinct from new.appointment_at
        or (status is distinct from new.status
            and (e.visibility = 'private' or new.status = 'annule' or e.status = 'annule')));
  elsif e.visibility = 'private' and new.status is distinct from old.status and new.rsvp is distinct from 'declined' then
    update public.events set status = new.status where id = e.id and status is distinct from new.status;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rdv_push_to_event on public.rendezvous;
create trigger trg_rdv_push_to_event
  after update on public.rendezvous
  for each row execute function public.rdv_push_to_event();

-- Event changed: mirror it on every copy, then tell the members.
create or replace function public.events_after_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_actor uuid := coalesce(auth.uid(), new.organizer_id);
  v_change text;
  v_status_sync boolean := new.visibility = 'private' or new.status = 'annule' or old.status = 'annule';
begin
  if new.title is distinct from old.title or new.location is distinct from old.location
     or new.appointment_at is distinct from old.appointment_at
     or (new.status is distinct from old.status and v_status_sync) then
    perform set_config('seeu.sync', 'on', true);
    update public.rendezvous r
    set title = new.title,
        location = new.location,
        appointment_at = new.appointment_at,
        status = case when v_status_sync then new.status else r.status end
    where r.event_id = new.id
      and (r.title is distinct from new.title or r.location is distinct from new.location
        or r.appointment_at is distinct from new.appointment_at
        or (v_status_sync and r.status is distinct from new.status));
    perform set_config('seeu.sync', 'off', true);
  end if;

  v_change := case
    when old.slots_open and not new.slots_open then 'date_chosen'
    when new.status is distinct from old.status and new.status = 'annule' then 'cancelled'
    when new.status is distinct from old.status and new.status = 'valide' and new.visibility = 'private' then 'done'
    when new.status is distinct from old.status and old.status = 'annule' then 'replanned'
    when new.appointment_at is distinct from old.appointment_at and not new.slots_open then 'moved'
    else null end;
  if v_change is not null then
    for c in
      select r.id, r.user_id from public.rendezvous r
      where r.event_id = new.id and r.rsvp is distinct from 'declined'
      union all
      select null, new.organizer_id
      where not exists (select 1 from public.rendezvous r where r.event_id = new.id and r.user_id = new.organizer_id)
    loop
      perform public.enqueue_notification(
        c.user_id, 'rdv_change',
        public.event_params(new.id) || jsonb_build_object('name', public.display_name_of(v_actor), 'change', v_change),
        coalesce('/rdv/' || c.id, '/event/' || new.id),
        false, v_actor, new.id);
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_events_after_update on public.events;
create trigger trg_events_after_update
  after update on public.events
  for each row execute function public.events_after_update();

-- Reminders resend when the date changes (unchanged), and a copy never resets the
-- counter while tentative/declined (unchanged from 0003).

-- ---------------------------------------------------------------------
-- 11. Saving an event (create or edit) in one call
--   p = { rdv_id?, visibility, title, location, description, notes,
--         appointment_at, status, contact_ids[], slots[], invite_user_ids[] }
--   Returns my copy's id.
-- ---------------------------------------------------------------------
create or replace function public.copy_contact_for(p_user uuid, p_other uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.contacts where user_id = p_user and linked_user_id = p_other limit 1
$$;

-- Broadcasts a "contacts" event to the organizer's friends (except members/invitees).
create or replace function public.broadcast_event(p_event uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.events%rowtype;
  f record;
  n integer := 0;
begin
  select * into e from public.events where id = p_event;
  if not found or e.visibility <> 'contacts' or e.status <> 'planifie' then return 0; end if;
  for f in
    select case when fr.requester_id = e.organizer_id then fr.addressee_id else fr.requester_id end as uid
    from public.friendships fr
    where fr.status = 'accepted' and e.organizer_id in (fr.requester_id, fr.addressee_id)
  loop
    if not exists (select 1 from public.rendezvous r where r.event_id = e.id and r.user_id = f.uid) then
      perform public.enqueue_notification(
        f.uid, 'event_new',
        public.event_params(e.id) || jsonb_build_object('name', public.display_name_of(e.organizer_id)),
        '/event/' || e.id, false, e.organizer_id, e.id);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;

create or replace function public.set_event_slots(p_event uuid, p_slots timestamptz[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slots timestamptz[] := array(select distinct s from unnest(coalesce(p_slots, '{}')) s where s is not null order by 1);
begin
  if cardinality(v_slots) > 10 then raise exception 'seeu:too_many_slots'; end if;
  delete from public.event_slots where event_id = p_event and not (starts_at = any (v_slots));
  insert into public.event_slots (event_id, starts_at)
  select p_event, s from unnest(v_slots) s
  on conflict (event_id, starts_at) do nothing;
end;
$$;

create or replace function public.save_event(p jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_rdv uuid := nullif(p ->> 'rdv_id', '')::uuid;
  v_vis text := coalesce(nullif(p ->> 'visibility', ''), 'private');
  v_slots timestamptz[] := array(
    select distinct (x)::timestamptz from jsonb_array_elements_text(coalesce(p -> 'slots', '[]'::jsonb)) x order by 1);
  v_multi boolean;
  v_at timestamptz;
  v_status public.rdv_status := coalesce(nullif(p ->> 'status', ''), 'planifie')::public.rdv_status;
  v_contacts uuid[] := array(select (x)::uuid from jsonb_array_elements_text(coalesce(p -> 'contact_ids', '[]'::jsonb)) x);
  v_invite uuid;
  r public.rendezvous%rowtype;
  e public.events%rowtype;
  v_was_contacts boolean := false;
  v_is_org boolean;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if v_vis not in ('private', 'contacts', 'public') then raise exception 'seeu:bad_answer'; end if;
  v_multi := cardinality(v_slots) >= 2;
  if v_multi and v_vis = 'public' then raise exception 'seeu:slots_not_allowed'; end if;
  if cardinality(v_slots) > 10 then raise exception 'seeu:too_many_slots'; end if;
  v_at := case when v_multi then v_slots[1] else coalesce((p ->> 'appointment_at')::timestamptz, v_slots[1]) end;
  if v_at is null then raise exception 'seeu:bad_answer'; end if;
  if v_multi then v_status := 'planifie'; end if;

  if v_rdv is null then
    -- create
    if v_vis = 'public' and not public.can_create_public_events() then raise exception 'seeu:public_not_allowed'; end if;
    insert into public.events (organizer_id, visibility, title, location, description, appointment_at, status, slots_open)
    values (me, v_vis, nullif(trim(p ->> 'title'), ''), nullif(trim(p ->> 'location'), ''),
            nullif(trim(p ->> 'description'), ''), v_at, v_status, v_multi)
    returning * into e;
    perform set_config('seeu.sync', 'on', true);
    insert into public.rendezvous (user_id, event_id, title, location, notes, appointment_at, status)
    values (me, e.id, e.title, e.location, nullif(trim(p ->> 'notes'), ''), e.appointment_at, e.status)
    returning * into r;
    perform set_config('seeu.sync', 'off', true);
    if v_multi then perform public.set_event_slots(e.id, v_slots); end if;
  else
    -- edit
    select * into r from public.rendezvous where id = v_rdv and user_id = me for update;
    if not found then raise exception 'seeu:rdv_not_found'; end if;
    if r.event_id is null then
      insert into public.events (organizer_id, title, location, appointment_at, status)
      values (me, r.title, r.location, r.appointment_at, r.status) returning id into r.event_id;
      perform set_config('seeu.sync', 'on', true);
      update public.rendezvous set event_id = r.event_id where id = r.id;
      perform set_config('seeu.sync', 'off', true);
    end if;
    select * into e from public.events where id = r.event_id for update;
    v_is_org := e.organizer_id = me;

    if v_is_org then
      if v_vis = 'public' and e.visibility <> 'public' and not public.can_create_public_events() then
        raise exception 'seeu:public_not_allowed';
      end if;
      v_was_contacts := e.visibility = 'contacts';
      if v_multi then
        perform public.set_event_slots(e.id, v_slots);
      elsif e.slots_open then
        delete from public.event_slots where event_id = e.id;
      end if;
      update public.events
      set visibility = v_vis,
          title = nullif(trim(p ->> 'title'), ''),
          location = nullif(trim(p ->> 'location'), ''),
          description = nullif(trim(p ->> 'description'), ''),
          appointment_at = v_at,
          slots_open = v_multi,
          status = case when visibility = 'private' or v_vis = 'private' or v_status = 'annule' or status = 'annule'
                        then v_status else status end
      where id = e.id
      returning * into e;
      -- organizer's own copy: shared fields came from the event sync; personal ones here
      perform set_config('seeu.sync', 'on', true);
      update public.rendezvous
      set notes = nullif(trim(p ->> 'notes'), ''), status = v_status,
          title = e.title, location = e.location, appointment_at = e.appointment_at
      where id = r.id;
      perform set_config('seeu.sync', 'off', true);
    else
      -- member: personal fields only
      update public.rendezvous
      set notes = nullif(trim(p ->> 'notes'), ''),
          status = case when v_status = 'annule' or r.status = 'annule' then r.status else v_status end
      where id = r.id;
    end if;
  end if;

  -- my linked contacts (replace)
  if p ? 'contact_ids' then
    delete from public.contact_rendezvous where rendezvous_id = r.id and not (contact_id = any (v_contacts));
    insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id)
    select c.id, r.id, me from public.contacts c
    where c.user_id = me and c.id = any (v_contacts)
    on conflict do nothing;
  end if;

  -- invitations (any member can invite their friends, except on public events: organizer only)
  for v_invite in select (x)::uuid from jsonb_array_elements_text(coalesce(p -> 'invite_user_ids', '[]'::jsonb)) x loop
    begin
      perform public.send_rdv_invite(r.id, v_invite);
    exception when others then
      raise warning 'invite % failed: %', v_invite, sqlerrm;
    end;
  end loop;

  if e.organizer_id = me and e.visibility = 'contacts' and not v_was_contacts then
    perform public.broadcast_event(e.id);
  end if;
  return r.id;
end;
$$;

-- ---------------------------------------------------------------------
-- 12. Invitations (now event-based)
-- ---------------------------------------------------------------------
create or replace function public.send_rdv_invite(p_rdv uuid, p_to uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
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
    where id = v_id and status = 'declined';
  end if;
  return v_id;
end;
$$;

create or replace function public.respond_rdv_invite(p_invite uuid, p_status text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  inv public.rdv_invitations%rowtype;
  r public.rendezvous%rowtype;
  e public.events%rowtype;
  v_copy uuid;
  v_contact uuid;
  v_at timestamptz;
  v_status public.rdv_status;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_status not in ('pending', 'accepted', 'declined') then raise exception 'seeu:bad_answer'; end if;
  select * into inv from public.rdv_invitations where id = p_invite and to_user = me for update;
  if not found then raise exception 'seeu:invite_not_found'; end if;
  if p_status = 'accepted' and not public.are_friends(me, inv.from_user) then
    raise exception 'seeu:no_longer_friends';
  end if;

  v_copy := inv.to_rdv_id;
  if v_copy is null and p_status <> 'declined' then
    select * into r from public.rendezvous where id = inv.rdv_id;
    if not found or r.event_id is null then raise exception 'seeu:rdv_gone'; end if;
    select * into e from public.events where id = r.event_id;
    select id into v_copy from public.rendezvous where user_id = me and event_id = e.id;
    if v_copy is null then
      perform set_config('seeu.sync', 'on', true);
      insert into public.rendezvous (user_id, title, location, appointment_at, status, event_id, rsvp)
      values (me, e.title, e.location, e.appointment_at, e.status, e.id, p_status)
      returning id into v_copy;
      perform set_config('seeu.sync', 'off', true);
    end if;
  end if;

  if v_copy is not null then
    update public.rendezvous set rsvp = p_status where id = v_copy;
    if p_status = 'accepted' then
      if not exists (select 1 from public.contact_rendezvous where rendezvous_id = v_copy) then
        v_contact := public.ensure_friend_contact(me, inv.from_user);
        insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_copy, me)
        on conflict do nothing;
      end if;
      select status, appointment_at into v_status, v_at from public.rendezvous where id = v_copy;
      if v_status = 'valide' then
        perform public.apply_validated_rdv(v_copy, me, v_at, null);
      end if;
    end if;
  end if;

  update public.rdv_invitations
  set status = p_status,
      to_rdv_id = v_copy,
      responded_at = case when p_status = 'pending' then null else now() end
  where id = inv.id;
  return v_copy;
end;
$$;

-- My contact for a friend, created if missing (used when accepting / joining).
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
    insert into public.contacts (user_id, name, email, frequency_value, frequency_unit, linked_user_id)
    values (
      p_user,
      left(coalesce(nullif(trim(sender.display_name), ''), sender.username,
                    nullif(split_part(coalesce(sender.email, ''), '@', 1), ''), 'SeeU'), 120),
      sender.email, 1, 'months', p_friend
    )
    returning id into v_contact;
  end if;
  return v_contact;
end;
$$;

-- ---------------------------------------------------------------------
-- 13. Joining / leaving events seen in the feeds
--   p_status: 'accepted' (je viens) | 'pending' (à confirmer) | 'declined' (je ne viens pas)
-- ---------------------------------------------------------------------
create or replace function public.join_event(p_event uuid, p_status text default 'accepted')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  e public.events%rowtype;
  v_copy uuid;
  v_old text;
  v_contact uuid;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_status not in ('pending', 'accepted', 'declined') then raise exception 'seeu:bad_answer'; end if;
  select * into e from public.events where id = p_event;
  if not found or not public.can_see_event(p_event, me) then raise exception 'seeu:event_not_visible'; end if;
  if e.organizer_id = me then return (select id from public.rendezvous where event_id = e.id and user_id = me); end if;
  if e.status = 'annule' and p_status <> 'declined' then raise exception 'seeu:rdv_cancelled'; end if;

  select id, rsvp into v_copy, v_old from public.rendezvous where event_id = e.id and user_id = me;
  if v_copy is null then
    if p_status = 'declined' then return null; end if;
    perform set_config('seeu.sync', 'on', true);
    insert into public.rendezvous (user_id, title, location, appointment_at, status, event_id, rsvp)
    values (me, e.title, e.location, e.appointment_at, e.status, e.id, p_status)
    returning id into v_copy;
    perform set_config('seeu.sync', 'off', true);
  else
    update public.rendezvous set rsvp = p_status where id = v_copy;
  end if;

  -- keep any invitation in step
  update public.rdv_invitations
  set status = p_status, responded_at = case when p_status = 'pending' then null else now() end
  where to_user = me and to_rdv_id = v_copy and status is distinct from p_status;

  if p_status = 'accepted' and not exists (select 1 from public.contact_rendezvous where rendezvous_id = v_copy) then
    -- link my contact for the organizer (friends only: never auto-create for public strangers)
    v_contact := case when e.visibility = 'public' then public.copy_contact_for(me, e.organizer_id)
                      else public.ensure_friend_contact(me, e.organizer_id) end;
    if v_contact is not null then
      insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_copy, me)
      on conflict do nothing;
    end if;
  end if;

  if p_status = 'accepted' and v_old is distinct from 'accepted' and e.visibility = 'contacts' then
    perform public.enqueue_notification(
      e.organizer_id, 'event_join',
      public.event_params(e.id) || jsonb_build_object('name', public.display_name_of(me)),
      coalesce('/rdv/' || (select id from public.rendezvous where event_id = e.id and user_id = e.organizer_id), '/'),
      false, me, e.id);
  end if;
  return v_copy;
end;
$$;

-- ---------------------------------------------------------------------
-- 14. Reading events
-- ---------------------------------------------------------------------
-- Feed: scope 'contacts' (events friends opened to their friends) or 'public'.
-- Keyset pagination on (appointment_at, id).
create or replace function public.list_feed_events(
  p_scope text, p_query text default null, p_limit integer default 30,
  p_after_at timestamptz default null, p_after_id uuid default null
)
returns table (
  id uuid, organizer_id uuid, organizer_name text, organizer_username text, visibility text,
  title text, location text, description text, appointment_at timestamptz, slots_open boolean,
  going integer, my_rdv_id uuid, my_rsvp text, is_mine boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (select auth.uid() as uid)
  select e.id, e.organizer_id,
         coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'), p.username, e.visibility,
         e.title, e.location, e.description, e.appointment_at, e.slots_open,
         e.going_count,
         mine.id, mine.rsvp, e.organizer_id = me.uid
  from me
  join public.events e on true
  left join public.profiles p on p.id = e.organizer_id
  left join public.rendezvous mine on mine.event_id = e.id and mine.user_id = me.uid
  where me.uid is not null
    and e.status = 'planifie'
    and e.appointment_at > now() - interval '3 hours'
    and (
      (p_scope = 'public' and e.visibility = 'public')
      or (p_scope = 'contacts' and e.visibility = 'contacts' and e.organizer_id <> me.uid
          and public.are_friends(e.organizer_id, me.uid))
    )
    and not public.is_blocked(e.organizer_id, me.uid)
    and not exists (select 1 from public.user_mutes m
                    where m.user_id = me.uid and (m.target_user = e.organizer_id or m.event_id = e.id))
    and (p_query is null or trim(p_query) = ''
         or e.title ilike '%' || trim(p_query) || '%' or e.location ilike '%' || trim(p_query) || '%'
         or p.username ilike trim(leading '@' from trim(p_query)) || '%')
    and (p_after_at is null or (e.appointment_at, e.id) > (p_after_at, p_after_id))
  order by e.appointment_at, e.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;

-- One event as seen by me (preview before joining, or details of my copy).
create or replace function public.get_event(p_event uuid)
returns table (
  id uuid, organizer_id uuid, organizer_name text, organizer_username text, visibility text,
  title text, location text, description text, appointment_at timestamptz, status text, slots_open boolean,
  going integer, my_rdv_id uuid, my_rsvp text, is_mine boolean, can_post boolean,
  organizer_is_friend boolean, muted_event boolean, muted_organizer boolean
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
         exists (select 1 from public.user_mutes m where m.user_id = auth.uid() and m.target_user = e.organizer_id)
  from public.events e
  left join public.profiles p on p.id = e.organizer_id
  left join public.rendezvous mine on mine.event_id = e.id and mine.user_id = auth.uid()
  where e.id = p_event and public.can_see_event(e.id, auth.uid())
$$;

-- Participants (organizer first, then going, then "à confirmer"); declined are hidden.
create or replace function public.list_event_participants(p_event uuid)
returns table (user_id uuid, display_name text, username text, rsvp text, is_friend boolean)
language sql
stable
security definer
set search_path = public
as $$
  select x.uid, coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'), p.username, x.rsvp,
         public.are_friends(x.uid, auth.uid())
  from (
    select e.organizer_id as uid, 'organizer' as rsvp, 0 as rank
    from public.events e where e.id = p_event
    union all
    select r.user_id, r.rsvp, case r.rsvp when 'accepted' then 1 else 2 end
    from public.rendezvous r join public.events e on e.id = r.event_id
    where r.event_id = p_event and r.user_id <> e.organizer_id and r.rsvp in ('accepted', 'pending')
  ) x
  left join public.profiles p on p.id = x.uid
  where public.can_see_event(p_event, auth.uid())
    and not public.is_blocked(x.uid, auth.uid())
  order by x.rank, 2
  limit 500
$$;

-- ---------------------------------------------------------------------
-- 15. Timeslot votes
-- ---------------------------------------------------------------------
create or replace function public.list_event_slots(p_event uuid)
returns table (
  id uuid, starts_at timestamptz, yes integer, maybe integer, no integer,
  my_answer text, yes_names text[], maybe_names text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.starts_at,
         count(*) filter (where v.answer = 'yes')::int,
         count(*) filter (where v.answer = 'maybe')::int,
         count(*) filter (where v.answer = 'no')::int,
         max(v.answer) filter (where v.user_id = auth.uid()),
         coalesce(array_agg(coalesce(nullif(trim(p.display_name), ''), p.username) order by p.display_name)
                    filter (where v.answer = 'yes'), '{}'),
         coalesce(array_agg(coalesce(nullif(trim(p.display_name), ''), p.username) order by p.display_name)
                    filter (where v.answer = 'maybe'), '{}')
  from public.event_slots s
  left join public.slot_votes v on v.slot_id = s.id
  left join public.profiles p on p.id = v.user_id
  where s.event_id = p_event and public.is_event_member(p_event, auth.uid())
  group by s.id, s.starts_at
  order by s.starts_at
$$;

-- p_answer: 'yes' | 'maybe' | 'no' | null (remove my vote)
create or replace function public.vote_slot(p_slot uuid, p_answer text)
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
  select ev.* into e from public.event_slots s join public.events ev on ev.id = s.event_id where s.id = p_slot;
  if not found then raise exception 'seeu:rdv_not_found'; end if;
  if not e.slots_open then raise exception 'seeu:slots_closed'; end if;
  if not public.is_event_member(e.id, me) then raise exception 'seeu:not_participant'; end if;
  if p_answer is null then
    delete from public.slot_votes where slot_id = p_slot and user_id = me;
  elsif p_answer in ('yes', 'maybe', 'no') then
    insert into public.slot_votes (slot_id, user_id, answer) values (p_slot, me, p_answer)
    on conflict (slot_id, user_id) do update set answer = excluded.answer, updated_at = now();
  else
    raise exception 'seeu:bad_answer';
  end if;
end;
$$;

-- Organizer picks the final timeslot: the event gets that date, the poll closes.
create or replace function public.choose_event_slot(p_slot uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  s public.event_slots%rowtype;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  select * into s from public.event_slots where id = p_slot;
  if not found then raise exception 'seeu:rdv_not_found'; end if;
  if not exists (select 1 from public.events where id = s.event_id and organizer_id = me) then
    raise exception 'seeu:not_organizer';
  end if;
  update public.events set appointment_at = s.starts_at, slots_open = false where id = s.event_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 16. Chat
-- ---------------------------------------------------------------------
create or replace function public.list_event_messages(p_event uuid, p_before timestamptz default null, p_limit integer default 50)
returns table (id uuid, user_id uuid, author_name text, body text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select m.id, m.user_id, coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'), m.body, m.created_at
  from public.event_messages m
  left join public.profiles p on p.id = m.user_id
  where m.event_id = p_event
    and public.is_event_member(p_event, auth.uid())
    and (p_before is null or m.created_at < p_before)
    and not exists (select 1 from public.user_blocks b where b.blocker_id = auth.uid() and b.blocked_id = m.user_id)
    and not exists (select 1 from public.user_mutes u where u.user_id = auth.uid() and u.target_user = m.user_id)
  order by m.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
$$;

-- New message → members who said yes (and the organizer), at most one push per
-- event every 5 minutes for chat; announcements on public events always go out.
create or replace function public.notify_event_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.events%rowtype;
  c record;
  v_kind text;
  v_params jsonb;
  v_url text;
begin
  select * into e from public.events where id = new.event_id;
  if not found then return new; end if;
  v_kind := case when e.visibility = 'public' then 'event_announcement' else 'event_message' end;
  v_params := public.event_params(e.id) || jsonb_build_object(
    'name', public.display_name_of(new.user_id), 'text', left(new.body, 140));
  for c in
    select r.id, r.user_id from public.rendezvous r
    where r.event_id = e.id and r.user_id <> new.user_id
      and (r.rsvp = 'accepted' or (r.rsvp is null and r.user_id = e.organizer_id))
  loop
    v_url := '/rdv/' || c.id || '/chat';
    if v_kind = 'event_message' and exists (
      select 1 from public.notifications n
      where n.user_id = c.user_id and n.kind = 'event_message' and n.url = v_url
        and n.created_at > now() - interval '5 minutes') then
      continue;
    end if;
    perform public.enqueue_notification(c.user_id, v_kind, v_params, v_url, false, new.user_id, e.id);
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_notify_event_message on public.event_messages;
create trigger trg_notify_event_message
  after insert on public.event_messages
  for each row execute function public.notify_event_message();

-- ---------------------------------------------------------------------
-- 17. Block / unblock, moderation lists
-- ---------------------------------------------------------------------
create or replace function public.block_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  if p_user is null or p_user = me then raise exception 'seeu:bad_answer'; end if;
  insert into public.user_blocks (blocker_id, blocked_id) values (me, p_user) on conflict do nothing;
  -- end the friendship (contacts are unlinked, pending invitations removed by its trigger)
  delete from public.friendships
  where (requester_id = me and addressee_id = p_user) or (requester_id = p_user and addressee_id = me);
  delete from public.rdv_invitations
  where status <> 'accepted' and ((from_user = me and to_user = p_user) or (from_user = p_user and to_user = me));
  -- leave each other's upcoming events (tentative / joined copies)
  delete from public.rendezvous r using public.events e
  where e.id = r.event_id and r.status = 'planifie' and r.rsvp is not null
    and ((r.user_id = me and e.organizer_id = p_user) or (r.user_id = p_user and e.organizer_id = me));
end;
$$;

create or replace function public.unblock_user(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.user_blocks where blocker_id = auth.uid() and blocked_id = p_user
$$;

create or replace function public.list_blocked_users()
returns table (user_id uuid, display_name text, username text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select b.blocked_id, coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'), p.username, b.created_at
  from public.user_blocks b left join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc
$$;

create or replace function public.list_mutes()
returns table (id uuid, target_user uuid, user_name text, username text, event_id uuid, event_title text,
               event_at timestamptz, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select m.id, m.target_user, coalesce(nullif(trim(p.display_name), ''), p.username), p.username,
         m.event_id, e.title, e.appointment_at, m.created_at
  from public.user_mutes m
  left join public.profiles p on p.id = m.target_user
  left join public.events e on e.id = m.event_id
  where m.user_id = auth.uid()
  order by m.created_at desc
$$;

-- Blocked people don't find each other, nor send friend requests or waves.
create or replace function public.search_users(p_query text)
returns table (user_id uuid, username text, display_name text, relation text)
language sql
stable
security definer
set search_path = public
as $$
  with q as (select lower(trim(leading '@' from trim(coalesce(p_query, '')))) as v)
  select p.id,
         p.username,
         coalesce(nullif(trim(p.display_name), ''), p.username),
         case
           when f.id is null then 'none'
           when f.status = 'accepted' then 'friends'
           when f.requester_id = auth.uid() then 'sent'
           else 'received'
         end
  from q
  join public.profiles p
    on length(q.v) >= 2 and p.username is not null and starts_with(p.username, q.v)
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.requester_id = p.id and f.addressee_id = auth.uid())
  where auth.uid() is not null and p.id <> auth.uid()
    and not public.is_blocked(p.id, auth.uid())
  order by (p.username = q.v) desc, p.username
  limit 8
$$;

create or replace function public.friendships_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_blocked(new.requester_id, new.addressee_id) then
    raise exception 'seeu:blocked';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_friendships_before_insert on public.friendships;
create trigger trg_friendships_before_insert
  before insert on public.friendships
  for each row execute function public.friendships_before_insert();

-- ---------------------------------------------------------------------
-- 18. Reminders: same rules as 0003 + skip events still choosing a date,
--     texts rendered by the dispatcher (params).
-- ---------------------------------------------------------------------
create or replace function public.run_reminders()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  r record;
  p record;
  v_names text[];
  v_date date;
  v_horizon date;
  v_due record;
  v_due_ids uuid[];
  v_items jsonb;
  v_count int;
  v_overdue int;
  v_bday_names text[];
  n_rem int := 0;
  n_follow int := 0;
  n_digest int := 0;
  n_bday int := 0;
begin
  -- 1) Reminder before a rendezvous
  for r in
    select rv.*, coalesce(pr.rdv_reminder_minutes, 30) as lead
    from public.rendezvous rv
    left join public.profiles pr on pr.id = rv.user_id
    left join public.events ev on ev.id = rv.event_id
    where rv.status = 'planifie' and not rv.reminder_sent
      and rv.rsvp is distinct from 'declined'
      and not coalesce(ev.slots_open, false)
      and rv.appointment_at between v_now - interval '15 minutes' and v_now + interval '25 hours'
      and rv.appointment_at <= v_now + make_interval(mins => coalesce(pr.rdv_reminder_minutes, 30) + 5)
    for update of rv skip locked
  loop
    update public.rendezvous set reminder_sent = true where id = r.id;
    select array_agg(c.name order by c.name) into v_names
      from public.contact_rendezvous cr join public.contacts c on c.id = cr.contact_id
      where cr.rendezvous_id = r.id;
    perform public.enqueue_notification(r.user_id, 'rdv_reminder',
      jsonb_build_object('names', coalesce(to_jsonb(v_names), '[]'::jsonb), 'title', nullif(trim(r.title), ''),
                         'at', r.appointment_at, 'location', nullif(trim(r.location), ''),
                         'minutes', round(extract(epoch from (r.appointment_at - v_now)) / 60)),
      '/rdv/' || r.id, false, null, r.event_id);
    n_rem := n_rem + 1;
  end loop;

  -- 2) "Did it happen?" the day after
  for r in
    select rv.* from public.rendezvous rv
    left join public.events ev on ev.id = rv.event_id
    where rv.status = 'planifie' and not rv.followup_sent
      and (rv.rsvp is null or rv.rsvp = 'accepted')
      and not coalesce(ev.slots_open, false)
      and rv.appointment_at between v_now - interval '26 hours' and v_now - interval '2 hours'
    for update of rv skip locked
  loop
    update public.rendezvous set followup_sent = true where id = r.id;
    select array_agg(c.name order by c.name) into v_names
      from public.contact_rendezvous cr join public.contacts c on c.id = cr.contact_id
      where cr.rendezvous_id = r.id;
    perform public.enqueue_notification(r.user_id, 'rdv_followup',
      jsonb_build_object('names', coalesce(to_jsonb(v_names), '[]'::jsonb), 'title', nullif(trim(r.title), '')),
      '/rdv/' || r.id);
    n_follow := n_follow + 1;
  end loop;

  -- 3) Daily digest + birthdays, at the user's chosen hour
  for p in
    select * from public.profiles pr
    where extract(hour from v_now at time zone pr.timezone) >= pr.daily_hour
      and (pr.last_digest_date is null or pr.last_digest_date < (v_now at time zone pr.timezone)::date)
    for update skip locked
  loop
    v_date := (v_now at time zone p.timezone)::date;
    update public.profiles set last_digest_date = v_date where id = p.id;
    v_horizon := v_date + coalesce(p.due_lead_days, 0);

    v_items := '[]'::jsonb;
    v_due_ids := '{}';
    v_count := 0;
    for v_due in
      select c.id, c.name, greatest(c.next_due_date, coalesce(c.snooze_until, c.next_due_date)) as due
      from public.contacts c
      where c.user_id = p.id and not c.notified_current_cycle
        and greatest(c.next_due_date, coalesce(c.snooze_until, c.next_due_date)) <= v_horizon
      order by 3, c.name
    loop
      v_count := v_count + 1;
      v_due_ids := v_due_ids || v_due.id;
      if v_count <= 5 then
        v_items := v_items || jsonb_build_array(jsonb_build_object('name', v_due.name, 'days', v_due.due - v_date));
      end if;
    end loop;

    if v_count > 0 then
      select count(*) into v_overdue from public.contacts c
        where c.user_id = p.id and greatest(c.next_due_date, coalesce(c.snooze_until, c.next_due_date)) < v_date;
      perform public.enqueue_notification(p.id, 'due_digest',
        jsonb_build_object('count', v_count, 'items', v_items, 'overdue_total', v_overdue), '/');
      update public.contacts set notified_current_cycle = true where id = any(v_due_ids);
      n_digest := n_digest + 1;
    end if;

    select array_agg(c.name order by c.name) into v_bday_names
    from public.contacts c
    where c.user_id = p.id and c.birthday is not null
      and (to_char(c.birthday, 'MM-DD') = to_char(v_date, 'MM-DD')
        or (to_char(c.birthday, 'MM-DD') = '02-29' and to_char(v_date, 'MM-DD') = '02-28'
            and to_char(v_date + 1, 'MM-DD') = '03-01'));
    if coalesce(array_length(v_bday_names, 1), 0) > 0 then
      perform public.enqueue_notification(p.id, 'birthday',
        jsonb_build_object('names', to_jsonb(v_bday_names)), '/contacts');
      n_bday := n_bday + 1;
    end if;
  end loop;

  -- 4) Notifications stuck in 'sending' are retried
  update public.notifications set status = 'pending'
  where status = 'sending' and created_at < v_now - interval '10 minutes' and created_at > v_now - interval '1 day';

  return jsonb_build_object('reminders', n_rem, 'followups', n_follow, 'digests', n_digest, 'birthdays', n_bday);
end;
$$;

-- ---------------------------------------------------------------------
-- 19. Permissions
-- ---------------------------------------------------------------------
revoke execute on function public.enqueue_notification(uuid, text, jsonb, text, boolean, uuid, uuid) from public, anon, authenticated;
revoke execute on function public.run_reminders() from public, anon, authenticated;
revoke execute on function public.is_blocked(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.is_muted(uuid, uuid, uuid) from public, anon, authenticated;
revoke execute on function public.event_params(uuid) from public, anon, authenticated;
revoke execute on function public.broadcast_event(uuid) from public, anon, authenticated;
revoke execute on function public.refresh_event_counts(uuid) from public, anon, authenticated;
revoke execute on function public.set_event_slots(uuid, timestamptz[]) from public, anon, authenticated;
revoke execute on function public.copy_contact_for(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.ensure_friend_contact(uuid, uuid) from public, anon, authenticated;
-- used inside RLS policies: callable, but they only answer about the given ids
revoke execute on function public.is_event_member(uuid, uuid) from public, anon;
revoke execute on function public.can_see_event(uuid, uuid) from public, anon;
revoke execute on function public.can_post_in_event(uuid, uuid) from public, anon;
grant execute on function public.is_event_member(uuid, uuid) to authenticated;
grant execute on function public.can_see_event(uuid, uuid) to authenticated;
grant execute on function public.can_post_in_event(uuid, uuid) to authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.can_create_public_events()',
    'public.save_event(jsonb)',
    'public.send_rdv_invite(uuid, uuid)',
    'public.respond_rdv_invite(uuid, text)',
    'public.join_event(uuid, text)',
    'public.list_feed_events(text, text, integer, timestamptz, uuid)',
    'public.get_event(uuid)',
    'public.list_event_participants(uuid)',
    'public.list_event_slots(uuid)',
    'public.vote_slot(uuid, text)',
    'public.choose_event_slot(uuid)',
    'public.list_event_messages(uuid, timestamptz, integer)',
    'public.block_user(uuid)',
    'public.unblock_user(uuid)',
    'public.list_blocked_users()',
    'public.list_mutes()',
    'public.search_users(text)',
    'public.list_shared_rdv_photos(uuid)',
    'public.can_read_shared_photo(text)',
    'public.send_test_notification()'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$$;

notify pgrst, 'reload schema';
