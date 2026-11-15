-- Leaving an event (my copy deleted: "retirer de mon agenda", or a block) also
-- removes my timeslot votes, so the poll only counts people still taking part.
-- Re-inviting someone who left reopens their old invitation (and notifies them).

create or replace function public.rdv_drop_votes_on_leave()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.event_id is not null
     and not exists (select 1 from public.rendezvous where event_id = old.event_id and user_id = old.user_id)
     and not exists (select 1 from public.events where id = old.event_id and organizer_id = old.user_id) then
    delete from public.slot_votes v
    using public.event_slots s
    where s.id = v.slot_id and s.event_id = old.event_id and v.user_id = old.user_id;
  end if;
  return old;
end;
$$;

drop trigger if exists trg_rdv_drop_votes_on_leave on public.rendezvous;
create trigger trg_rdv_drop_votes_on_leave
  after delete on public.rendezvous
  for each row execute function public.rdv_drop_votes_on_leave();

-- Votes already left behind by people who are no longer in the event.
delete from public.slot_votes v
using public.event_slots s, public.events e
where s.id = v.slot_id and e.id = s.event_id
  and v.user_id <> e.organizer_id
  and not exists (select 1 from public.rendezvous r where r.event_id = e.id and r.user_id = v.user_id);

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
    -- declined, or accepted then left (their copy is gone): invite again
    where id = v_id and (status = 'declined' or (status = 'accepted' and to_rdv_id is null));
  end if;
  return v_id;
end;
$$;
