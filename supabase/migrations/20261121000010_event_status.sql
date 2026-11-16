-- =====================================================================
--  SeeU — migration 0010
--  * only the organizer changes an event's status (happened / cancelled /
--    planned again); it applies to every participant's copy
--  * "Is it happening?" asked to the organizer when the event starts, again
--    4 h later, then marked as happened automatically after 24 h
--    (replaces the per-copy "did it happen?" of the day after)
-- =====================================================================

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
     or new.status is distinct from old.status then -- only the organizer says it happened / is cancelled
    raise exception 'seeu:not_organizer';
  end if;
  return new;
end;
$$;

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
        status = new.status
    where id = e.id
      and (title is distinct from new.title or location is distinct from new.location
        or appointment_at is distinct from new.appointment_at
        or status is distinct from new.status);
  end if;
  return new;
end;
$$;

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
  v_status_sync boolean := true; -- the organizer's status is everyone's
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
    when new.status is distinct from old.status and new.status = 'valide' then 'done'
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

-- Old per-copy follow-up ("did it happen?" the day after, to everyone) is off:
-- the organizer is asked at the start instead.
alter table public.rendezvous alter column followup_sent set default true;
update public.rendezvous set followup_sent = true where not followup_sent;
create or replace function public.rdv_before_update()
returns trigger
language plpgsql
as $$
begin
  if new.appointment_at is distinct from old.appointment_at then
    new.reminder_sent := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

alter table public.events
  add column if not exists check_sent boolean not null default false,
  add column if not exists check_resent boolean not null default false;

-- Asking again when the date moves.
create or replace function public.events_reset_checks()
returns trigger
language plpgsql
as $$
begin
  if new.appointment_at is distinct from old.appointment_at or (new.status = 'planifie' and old.status <> 'planifie') then
    new.check_sent := false;
    new.check_resent := false;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_events_reset_checks on public.events;
create trigger trg_events_reset_checks
  before update on public.events
  for each row execute function public.events_reset_checks();

create or replace function public.run_event_checks()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  e record;
  v_rdv uuid;
  n_ask int := 0;
  n_again int := 0;
  n_auto int := 0;
begin
  -- 3) 24 h after the start, still no answer: it happened.
  for e in
    select * from public.events
    where status = 'planifie' and not slots_open and appointment_at <= now() - interval '24 hours'
      and appointment_at > now() - interval '30 days'
    for update skip locked
  loop
    update public.events set status = 'valide' where id = e.id;
    select id into v_rdv from public.rendezvous where event_id = e.id and user_id = e.organizer_id;
    perform public.enqueue_notification(e.organizer_id, 'rdv_auto_done', public.event_params(e.id),
      coalesce('/rdv/' || v_rdv, '/history'), false, null, e.id);
    n_auto := n_auto + 1;
  end loop;

  -- 1) At the start: "Is it happening?"
  for e in
    select * from public.events
    where status = 'planifie' and not slots_open and not check_sent
      and appointment_at <= now() and appointment_at > now() - interval '24 hours'
    for update skip locked
  loop
    update public.events set check_sent = true, check_resent = appointment_at <= now() - interval '4 hours' where id = e.id;
    select id into v_rdv from public.rendezvous where event_id = e.id and user_id = e.organizer_id;
    perform public.enqueue_notification(e.organizer_id, 'rdv_check', public.event_params(e.id) || jsonb_build_object('again', false),
      coalesce('/rdv/' || v_rdv, '/'), false, null, e.id);
    n_ask := n_ask + 1;
  end loop;

  -- 2) Still no answer 4 h later: ask again.
  for e in
    select * from public.events
    where status = 'planifie' and not slots_open and check_sent and not check_resent
      and appointment_at <= now() - interval '4 hours' and appointment_at > now() - interval '24 hours'
    for update skip locked
  loop
    update public.events set check_resent = true where id = e.id;
    select id into v_rdv from public.rendezvous where event_id = e.id and user_id = e.organizer_id;
    perform public.enqueue_notification(e.organizer_id, 'rdv_check', public.event_params(e.id) || jsonb_build_object('again', true),
      coalesce('/rdv/' || v_rdv, '/'), true, null, e.id);
    n_again := n_again + 1;
  end loop;

  return jsonb_build_object('asked', n_ask, 'asked_again', n_again, 'auto_done', n_auto);
end;
$$;
revoke execute on function public.run_event_checks() from public, anon, authenticated;

-- Events already started before this migration aren't asked (only auto-done after 24 h).
update public.events set check_sent = true, check_resent = true where appointment_at <= now();

do $$
begin
  perform cron.unschedule('seeu-event-checks');
exception when others then null;
end $$;
select cron.schedule('seeu-event-checks', '*/10 * * * *', 'select public.run_event_checks()');
