-- =====================================================================
--  SeeU — migration 0005
--  * events.guests_can_invite: may participants invite their own friends?
--  * submit_availability: saves my timeslot answers and derives my RSVP
--    (≥ 1 yes → accepted, all no → declined, otherwise "à confirmer")
--  * block_user also deletes my contact linked to that person
-- =====================================================================

alter table public.events add column if not exists guests_can_invite boolean not null default true;

-- save_event: + guests_can_invite (organizer only)
create or replace function public.apply_event_guest_option(p_event uuid, p jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  update public.events
  set guests_can_invite = coalesce((p ->> 'guests_can_invite')::boolean, guests_can_invite)
  where id = p_event and organizer_id = auth.uid() and p ? 'guests_can_invite'
$$;
revoke execute on function public.apply_event_guest_option(uuid, jsonb) from public, anon, authenticated;

-- Wrap save_event: apply the option before invitations are sent.
alter function public.save_event(jsonb) rename to save_event_core;
revoke execute on function public.save_event_core(jsonb) from public, anon, authenticated;

create or replace function public.save_event(p jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_event uuid;
begin
  -- invitations are sent by save_event_core; the option only restricts OTHER members,
  -- so applying it right after is enough.
  v_id := public.save_event_core(p);
  select event_id into v_event from public.rendezvous where id = v_id;
  perform public.apply_event_guest_option(v_event, p);
  return v_id;
end;
$$;

-- Invitations by members are refused when the organizer turned the option off.
create or replace function public.check_guest_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.events%rowtype;
begin
  select ev.* into e from public.rendezvous r join public.events ev on ev.id = r.event_id where r.id = new.rdv_id;
  if found and e.organizer_id <> new.from_user and not e.guests_can_invite then
    raise exception 'seeu:not_organizer';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_guest_invite on public.rdv_invitations;
create trigger trg_check_guest_invite
  before insert on public.rdv_invitations
  for each row execute function public.check_guest_invite();

-- ---------------------------------------------------------------------
-- My availability for every timeslot, in one go.
--   p_votes = [{"slot": "<uuid>", "answer": "yes"|"maybe"|"no"}, …]
--   Unanswered slots count as "maybe". Returns my resulting RSVP
--   (null for the organizer, who has no RSVP).
-- ---------------------------------------------------------------------
create or replace function public.submit_availability(p_event uuid, p_votes jsonb)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  e public.events%rowtype;
  v_rsvp text;
  v_yes int;
  v_no int;
  v_total int;
  v_invite uuid;
begin
  if me is null then raise exception 'seeu:not_signed_in'; end if;
  select * into e from public.events where id = p_event;
  if not found or not public.can_see_event(p_event, me) then raise exception 'seeu:event_not_visible'; end if;
  if not e.slots_open then raise exception 'seeu:slots_closed'; end if;

  -- answers (unanswered → maybe)
  insert into public.slot_votes (slot_id, user_id, answer)
  select s.id, me, coalesce(v.answer, 'maybe')
  from public.event_slots s
  left join lateral (
    select x ->> 'answer' as answer from jsonb_array_elements(coalesce(p_votes, '[]'::jsonb)) x
    where x ->> 'slot' = s.id::text and x ->> 'answer' in ('yes', 'maybe', 'no')
    limit 1
  ) v on true
  where s.event_id = p_event
  on conflict (slot_id, user_id) do update set answer = excluded.answer, updated_at = now();

  select count(*), count(*) filter (where v.answer = 'yes'), count(*) filter (where v.answer = 'no')
    into v_total, v_yes, v_no
  from public.slot_votes v join public.event_slots s on s.id = v.slot_id
  where s.event_id = p_event and v.user_id = me;
  v_rsvp := case when v_yes > 0 then 'accepted' when v_total > 0 and v_no = v_total then 'declined' else 'pending' end;

  if e.organizer_id = me then return null; end if;

  -- RSVP: through my invitation when there is one (notifies the organizer on
  -- accepted / declined), otherwise as a join.
  select i.id into v_invite
  from public.rdv_invitations i join public.rendezvous r on r.id = i.rdv_id
  where i.to_user = me and r.event_id = p_event
  order by i.created_at desc limit 1;
  if v_invite is not null then
    perform public.respond_rdv_invite(v_invite, v_rsvp);
  else
    perform public.join_event(p_event, v_rsvp);
  end if;
  return v_rsvp;
end;
$$;
revoke execute on function public.submit_availability(uuid, jsonb) from public, anon;
grant execute on function public.submit_availability(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- Blocking someone also deletes my contact for them (no more catch-up reminders).
-- ---------------------------------------------------------------------
alter function public.block_user(uuid) rename to block_user_core;
revoke execute on function public.block_user_core(uuid) from public, anon, authenticated;

create or replace function public.block_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'seeu:not_signed_in'; end if;
  -- before the friendship ends (that would only unlink the contact)
  delete from public.contacts where user_id = auth.uid() and linked_user_id = p_user;
  perform public.block_user_core(p_user);
end;
$$;
revoke execute on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

notify pgrst, 'reload schema';
