-- =====================================================================
--  SeeU — 0003
--    1. "Dernière rencontre" becomes optional: a contact without any meeting
--       is due one period after it was added (added_on).
--    2. A contact can have several categories (categories text[]).
--    3. Rendezvous invitations: the invitee gets a tentative copy right away
--       ("À confirmer"), and can switch between à confirmer / accepté / refusé
--       at any time. Only accept / decline notify the organizer.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Optional last meeting
-- ---------------------------------------------------------------------
alter table public.contacts add column if not exists added_on date;
update public.contacts set added_on = (created_at at time zone 'UTC')::date where added_on is null;
alter table public.contacts alter column added_on set default current_date;
alter table public.contacts alter column added_on set not null;
alter table public.contacts alter column last_meeting_date drop not null;
alter table public.contacts alter column next_due_date
  set expression as (public.compute_next_due(coalesce(last_meeting_date, added_on), frequency_value, frequency_unit));

-- ---------------------------------------------------------------------
-- 2. Several categories per contact
-- ---------------------------------------------------------------------
alter table public.contacts add column if not exists categories text[] not null default '{}';
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'contacts' and column_name = 'category') then
    update public.contacts set categories = array[trim(category)]
    where category is not null and trim(category) <> '' and categories = '{}';
    alter table public.contacts drop column category;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'contacts_categories_limit') then
    alter table public.contacts add constraint contacts_categories_limit check (cardinality(categories) <= 10);
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 3. Tentative invitations (RSVP on the invitee's copy)
--    rsvp: null = my own rendezvous; 'pending' (à confirmer) | 'accepted' | 'declined'
-- ---------------------------------------------------------------------
alter table public.rendezvous add column if not exists rsvp text
  check (rsvp in ('pending', 'accepted', 'declined'));
update public.rendezvous r set rsvp = 'accepted'
where r.rsvp is null and exists (select 1 from public.rdv_invitations i where i.to_rdv_id = r.id and i.status = 'accepted');

-- A tentative or declined copy never resets the invitee's counter.
create or replace function public.apply_validated_rdv(p_rdv_id uuid, p_user uuid, p_at timestamptz, p_contact uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  d date := public.rdv_local_date(p_user, p_at);
begin
  if exists (select 1 from public.rendezvous where id = p_rdv_id and rsvp in ('pending', 'declined')) then
    return;
  end if;
  update public.contacts c
  set last_meeting_date = greatest(c.last_meeting_date, d)
  where c.user_id = p_user
    and (
      (p_contact is not null and c.id = p_contact)
      or (p_contact is null and c.id in (
        select cr.contact_id from public.contact_rendezvous cr where cr.rendezvous_id = p_rdv_id
      ))
    );
end;
$$;

-- Invite a friend: creates (or reuses) their tentative copy right away.
create or replace function public.send_rdv_invite(p_rdv uuid, p_to uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  r public.rendezvous%rowtype;
  v_share uuid;
  v_copy uuid;
  v_copy_rsvp text;
  v_contact uuid;
  v_id uuid;
begin
  if me is null then raise exception 'Non connecté'; end if;
  select * into r from public.rendezvous where id = p_rdv and user_id = me;
  if not found then raise exception 'Rendez-vous introuvable.'; end if;
  if r.status = 'annule' then raise exception 'Ce rendez-vous est annulé.'; end if;
  if not public.are_friends(me, p_to) then raise exception 'Cette personne ne fait pas partie de vos amis SeeU.'; end if;

  v_share := r.share_id;
  if v_share is null then
    v_share := gen_random_uuid();
    update public.rendezvous set share_id = v_share where id = p_rdv;
  end if;

  select id, rsvp into v_copy, v_copy_rsvp from public.rendezvous where user_id = p_to and share_id = v_share limit 1;
  if v_copy is null then
    insert into public.rendezvous (user_id, title, location, appointment_at, status, share_id, rsvp)
    values (p_to, r.title, r.location, r.appointment_at, r.status, v_share, 'pending')
    returning id into v_copy;
    select id into v_contact from public.contacts where user_id = p_to and linked_user_id = me limit 1;
    if v_contact is not null then
      insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_copy, p_to);
    end if;
  elsif v_copy_rsvp = 'declined' then
    update public.rendezvous set rsvp = 'pending' where id = v_copy;
  end if;

  select id into v_id from public.rdv_invitations where rdv_id = p_rdv and to_user = p_to;
  if v_id is null then
    insert into public.rdv_invitations (rdv_id, from_user, to_user, to_rdv_id)
    values (p_rdv, me, p_to, v_copy)
    returning id into v_id;
  else
    -- declined before: propose it again
    update public.rdv_invitations
    set status = 'pending', created_at = now(), responded_at = null, to_rdv_id = v_copy
    where id = v_id and status = 'declined';
  end if;
  return v_id;
end;
$$;

-- Answer an invitation: 'pending' (à confirmer) | 'accepted' | 'declined'. Returns my copy's id.
drop function if exists public.respond_rdv_invite(uuid, boolean);
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
  sender public.profiles%rowtype;
  v_copy uuid;
  v_contact uuid;
  v_at timestamptz;
  v_status public.rdv_status;
begin
  if me is null then raise exception 'Non connecté'; end if;
  if p_status not in ('pending', 'accepted', 'declined') then raise exception 'Réponse invalide.'; end if;
  select * into inv from public.rdv_invitations where id = p_invite and to_user = me for update;
  if not found then raise exception 'Invitation introuvable.'; end if;
  if p_status = 'accepted' and not public.are_friends(me, inv.from_user) then
    raise exception 'Vous n''êtes plus amis sur SeeU.';
  end if;

  v_copy := inv.to_rdv_id;
  if v_copy is null and p_status <> 'declined' then
    -- my copy was deleted: recreate it from the organizer's rendezvous
    select * into r from public.rendezvous where id = inv.rdv_id;
    if not found then raise exception 'Ce rendez-vous n''existe plus.'; end if;
    if r.share_id is null then
      update public.rendezvous set share_id = gen_random_uuid() where id = r.id returning * into r;
    end if;
    insert into public.rendezvous (user_id, title, location, appointment_at, status, share_id, rsvp)
    values (me, r.title, r.location, r.appointment_at, r.status, r.share_id, p_status)
    returning id into v_copy;
  end if;

  if v_copy is not null then
    update public.rendezvous set rsvp = p_status where id = v_copy;

    if p_status = 'accepted' then
      -- attach my contact for the organizer (created if needed) so my counter can reset
      if not exists (select 1 from public.contact_rendezvous where rendezvous_id = v_copy) then
        select id into v_contact from public.contacts where user_id = me and linked_user_id = inv.from_user limit 1;
        if v_contact is null then
          select * into sender from public.profiles where id = inv.from_user;
          insert into public.contacts (user_id, name, email, frequency_value, frequency_unit, linked_user_id)
          values (
            me,
            left(coalesce(nullif(trim(sender.display_name), ''), sender.username, nullif(split_part(coalesce(sender.email, ''), '@', 1), ''), 'Ami SeeU'), 120),
            sender.email, 1, 'months', inv.from_user
          )
          returning id into v_contact;
        end if;
        insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_copy, me);
      end if;
      -- accepting a meeting that already took place resets my counter now
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

-- Organizer cancels a pending invitation (or the friendship ends): the tentative copy goes away.
create or replace function public.rdv_invitations_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.to_rdv_id is not null then
    delete from public.rendezvous where id = old.to_rdv_id and rsvp in ('pending', 'declined');
  end if;
  return old;
end;
$$;

drop trigger if exists trg_rdv_invitations_after_delete on public.rdv_invitations;
create trigger trg_rdv_invitations_after_delete
  after delete on public.rdv_invitations
  for each row execute function public.rdv_invitations_after_delete();

-- Pending invitations I received (now also returns my tentative copy).
drop function if exists public.list_rdv_invites();
create function public.list_rdv_invites()
returns table (
  id uuid,
  rdv_id uuid,
  to_rdv_id uuid,
  from_user uuid,
  from_name text,
  title text,
  location text,
  appointment_at timestamptz,
  rdv_status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select i.id,
         i.rdv_id,
         i.to_rdv_id,
         i.from_user,
         coalesce(nullif(trim(p.display_name), ''), p.username, nullif(split_part(coalesce(p.email, ''), '@', 1), ''), 'Un ami'),
         r.title,
         r.location,
         r.appointment_at,
         r.status::text,
         i.created_at
  from public.rdv_invitations i
  join public.rendezvous r on r.id = i.rdv_id
  left join public.profiles p on p.id = i.from_user
  where i.to_user = auth.uid()
    and i.status = 'pending'
    and r.status <> 'annule'
  order by r.appointment_at
$$;

-- Notifications: the invitee is notified when the ORGANIZER (re)sends; the organizer
-- when the invitee accepts or declines. Going back to "à confirmer" notifies nobody.
create or replace function public.notify_rdv_invitation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.rendezvous%rowtype;
  v_tz text;
  v_details text;
begin
  select * into r from public.rendezvous where id = new.rdv_id;
  if not found then return new; end if;

  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending')
     and auth.uid() is distinct from new.to_user then
    v_tz := public.user_tz(new.to_user);
    v_details := public.fr_when(r.appointment_at, v_tz) || coalesce(' · ' || nullif(trim(r.location), ''), '');
    perform public.enqueue_notification(
      new.to_user, 'rdv_invite',
      public.display_name_of(new.from_user) ||
        case when r.status = 'valide' then ' partage une rencontre avec vous' else ' vous propose un rendez-vous' end,
      coalesce(nullif(trim(r.title), '') || ' — ', '') || v_details || '. Acceptez ou refusez dans SeeU.',
      case when new.to_rdv_id is not null then '/rdv/' || new.to_rdv_id else '/contacts' end
    );
  elsif tg_op = 'UPDATE' and new.status in ('accepted', 'declined') and new.status is distinct from old.status then
    v_tz := public.user_tz(new.from_user);
    perform public.enqueue_notification(
      new.from_user, 'rdv_response',
      public.display_name_of(new.to_user) ||
        case when new.status = 'accepted' then ' a accepté votre rendez-vous ✅' else ' a décliné votre rendez-vous' end,
      coalesce(nullif(trim(r.title), '') || ' — ', '') || public.fr_when(r.appointment_at, v_tz),
      '/rdv/' || r.id
    );
  end if;
  return new;
end;
$$;

-- Shared rendezvous changed: don't bother people who declined.
create or replace function public.notify_shared_rdv_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_name text;
  v_when text;
  v_label text;
  v_title text;
  v_body text;
  v_moved boolean := new.appointment_at is distinct from old.appointment_at;
  v_status boolean := new.status is distinct from old.status;
begin
  if new.share_id is null or pg_trigger_depth() > 1 or not (v_moved or v_status) then
    return new;
  end if;
  v_name := public.display_name_of(new.user_id);
  for c in
    select r.id, r.user_id from public.rendezvous r
    where r.share_id = new.share_id and r.user_id <> new.user_id and r.rsvp is distinct from 'declined'
  loop
    v_when := public.fr_when(new.appointment_at, public.user_tz(c.user_id));
    v_label := coalesce(nullif(trim(new.title), '') || ' — ', '') || v_when;
    if v_status and new.status = 'valide' then
      v_title := v_name || ' a confirmé votre rencontre ✅';
      v_body := v_label || '. Votre période est remise à zéro.';
    elsif v_status and new.status = 'annule' then
      v_title := v_name || ' a annulé votre rendez-vous';
      v_body := v_label;
    elsif v_status then
      v_title := v_name || ' a replanifié votre rendez-vous';
      v_body := v_label;
    else
      v_title := v_name || ' a déplacé votre rendez-vous';
      v_body := 'Nouvelle date : ' || v_when || coalesce(' (' || nullif(trim(new.title), '') || ')', '') || '.';
    end if;
    perform public.enqueue_notification(c.user_id, 'rdv_change', v_title, v_body, '/rdv/' || c.id);
  end loop;
  return new;
end;
$$;

-- Reminders: no reminder for declined copies; no "did it happen?" for tentative/declined ones.
-- (Same function as 0002, with two extra conditions.)
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
  v_tz text;
  v_minutes numeric;
  v_when text;
  v_names text[];
  v_title text;
  v_body text;
  v_local timestamp;
  v_date date;
  v_horizon date;
  v_due record;
  v_due_ids uuid[];
  v_parts text[];
  v_count int;
  v_overdue int;
  v_bday_names text[];
  n_rem int := 0;
  n_follow int := 0;
  n_digest int := 0;
  n_bday int := 0;
begin
  for r in
    select rv.*, coalesce(pr.rdv_reminder_minutes, 30) as lead, coalesce(pr.timezone, 'Europe/Paris') as tz
    from public.rendezvous rv
    left join public.profiles pr on pr.id = rv.user_id
    where rv.status = 'planifie' and not rv.reminder_sent
      and rv.rsvp is distinct from 'declined'
      and rv.appointment_at between v_now - interval '15 minutes' and v_now + interval '25 hours'
      and rv.appointment_at <= v_now + make_interval(mins => coalesce(pr.rdv_reminder_minutes, 30) + 5)
    for update of rv skip locked
  loop
    update public.rendezvous set reminder_sent = true where id = r.id;
    v_minutes := extract(epoch from (r.appointment_at - v_now)) / 60;
    v_when := case
      when v_minutes <= 1 then 'maintenant'
      when v_minutes < 90 then 'dans ' || round(v_minutes) || ' min'
      else 'à ' || public.fr_time(r.appointment_at, r.tz) end;
    select array_agg(c.name order by c.name) into v_names
      from public.contact_rendezvous cr join public.contacts c on c.id = cr.contact_id
      where cr.rendezvous_id = r.id;
    v_title := case when coalesce(array_length(v_names, 1), 0) > 0
      then 'Rendez-vous avec ' || public.join_names(v_names) || ' ' || v_when
      else 'Rendez-vous ' || v_when end;
    v_body := concat_ws(' · ', nullif(trim(r.title), ''), public.fr_when(r.appointment_at, r.tz), '📍 ' || nullif(trim(r.location), ''));
    perform public.enqueue_notification(r.user_id, 'rdv_reminder', v_title, v_body, '/rdv/' || r.id);
    n_rem := n_rem + 1;
  end loop;

  for r in
    select rv.* from public.rendezvous rv
    where rv.status = 'planifie' and not rv.followup_sent
      and (rv.rsvp is null or rv.rsvp = 'accepted')
      and rv.appointment_at between v_now - interval '26 hours' and v_now - interval '2 hours'
    for update skip locked
  loop
    update public.rendezvous set followup_sent = true where id = r.id;
    select array_agg(c.name order by c.name) into v_names
      from public.contact_rendezvous cr join public.contacts c on c.id = cr.contact_id
      where cr.rendezvous_id = r.id;
    v_title := case when coalesce(array_length(v_names, 1), 0) > 0
      then 'Votre rendez-vous avec ' || public.join_names(v_names) || ' a-t-il eu lieu ?'
      else 'Votre rendez-vous a-t-il eu lieu ?' end;
    perform public.enqueue_notification(r.user_id, 'rdv_followup', v_title,
      'Confirmez-le pour mettre à jour la date de dernière rencontre, ou marquez-le comme annulé.', '/rdv/' || r.id);
    n_follow := n_follow + 1;
  end loop;

  for p in
    select * from public.profiles pr
    where extract(hour from v_now at time zone pr.timezone) >= pr.daily_hour
      and (pr.last_digest_date is null or pr.last_digest_date < (v_now at time zone pr.timezone)::date)
    for update skip locked
  loop
    v_tz := p.timezone;
    v_local := v_now at time zone v_tz;
    v_date := v_local::date;
    update public.profiles set last_digest_date = v_date where id = p.id;
    v_horizon := v_date + coalesce(p.due_lead_days, 0);

    v_parts := '{}';
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
        v_parts := v_parts || (v_due.name || ' (' || case
          when v_due.due < v_date then 'en retard de ' || (v_date - v_due.due) || ' j'
          when v_due.due = v_date then 'aujourd''hui'
          else 'dans ' || (v_due.due - v_date) || ' j' end || ')');
      end if;
    end loop;

    if v_count > 0 then
      select count(*) into v_overdue from public.contacts c
        where c.user_id = p.id and greatest(c.next_due_date, coalesce(c.snooze_until, c.next_due_date)) < v_date;
      v_title := case when v_count = 1
        then (select name from public.contacts where id = v_due_ids[1]) || ' est à recontacter'
        else v_count || ' contacts à recontacter' end;
      v_body := array_to_string(v_parts, ', ');
      if v_count > 5 then
        v_body := v_body || ' et ' || (v_count - 5) || ' autre' || case when v_count - 5 > 1 then 's' else '' end;
      end if;
      if v_overdue > v_count then v_body := v_body || ' · ' || v_overdue || ' en retard au total'; end if;
      perform public.enqueue_notification(p.id, 'due_digest', v_title, v_body, '/');
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
        case when array_length(v_bday_names, 1) = 1
          then '🎂 C''est l''anniversaire de ' || v_bday_names[1] || ' !'
          else '🎂 ' || array_length(v_bday_names, 1) || ' anniversaires aujourd''hui' end,
        case when array_length(v_bday_names, 1) = 1
          then 'Un petit message lui fera plaisir.'
          else public.join_names(v_bday_names, 4) end,
        '/contacts');
      n_bday := n_bday + 1;
    end if;
  end loop;

  update public.notifications set status = 'pending'
  where status = 'sending' and created_at < v_now - interval '10 minutes' and created_at > v_now - interval '1 day';

  return jsonb_build_object('reminders', n_rem, 'followups', n_follow, 'digests', n_digest, 'birthdays', n_bday);
end;
$$;

revoke execute on function public.run_reminders() from public, anon, authenticated;
revoke execute on function public.respond_rdv_invite(uuid, text) from public, anon;
revoke execute on function public.list_rdv_invites() from public, anon;
grant execute on function public.respond_rdv_invite(uuid, text) to authenticated;
grant execute on function public.list_rdv_invites() to authenticated;

notify pgrst, 'reload schema';
