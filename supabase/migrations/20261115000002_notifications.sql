-- =====================================================================
--  SeeU — notifications (native app)
--
--  How it works:
--    1. Everything that must notify someone calls public.enqueue_notification(),
--       which inserts a 'pending' row into public.notifications (the journal
--       shown in Settings is the same table).
--         - social events: database triggers (friend request / accept, wave,
--           rdv invitation / response, shared rdv changed). Clients can't
--           spoof or skip them.
--         - reminders: public.run_reminders(), run every 10 min by pg_cron
--           (daily digest, birthdays, rdv reminder, rdv follow-up).
--    2. Each insert pings the `dispatch` Edge Function through pg_net, and a
--       cron job pings it every minute as a safety net. `dispatch` sends the
--       push via FCM to every device of the user, falls back to email, and
--       writes the channel used back into the row.
--
--  Setup (once per project, SQL editor):
--    select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--    select vault.create_secret('<random string>', 'dispatch_secret');
--  and set the same DISPATCH_SECRET for the Edge Function (see README).
-- =====================================================================

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ---------------------------------------------------------------------
-- Devices (FCM registration tokens), one row per app install
-- ---------------------------------------------------------------------
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_device_tokens_user on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own" on public.device_tokens
  for select using ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own" on public.device_tokens
  for delete using ((select auth.uid()) = user_id);

-- A token moves to the current user if another account used it on this device before.
create or replace function public.register_device(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  insert into public.device_tokens (user_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;

-- ---------------------------------------------------------------------
-- Notifications: journal + outbox
-- ---------------------------------------------------------------------
alter table public.notifications add column if not exists status text not null default 'sent'
  check (status in ('pending', 'sending', 'sent'));
alter table public.notifications add column if not exists sent_at timestamptz;
alter table public.notifications add column if not exists force_push boolean not null default false;
alter table public.notifications alter column status set default 'pending';
create index if not exists idx_notifications_pending on public.notifications(created_at) where status <> 'sent';

-- Safe timezone (falls back to Europe/Paris)
create or replace function public.safe_tz(p_tz text)
returns text
language plpgsql
stable
as $$
begin
  perform now() at time zone p_tz;
  return p_tz;
exception when others then
  return 'Europe/Paris';
end;
$$;

-- Profiles always hold a valid timezone (cheap reads in the scheduler)
create or replace function public.profiles_check_tz()
returns trigger
language plpgsql
as $$
begin
  new.timezone := public.safe_tz(coalesce(new.timezone, 'Europe/Paris'));
  return new;
end;
$$;

drop trigger if exists trg_profiles_check_tz on public.profiles;
create trigger trg_profiles_check_tz
  before insert or update of timezone on public.profiles
  for each row execute function public.profiles_check_tz();

create or replace function public.user_tz(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select timezone from public.profiles where id = p_user), 'Europe/Paris')
$$;

-- 'vendredi 4 décembre' in the given timezone
create or replace function public.fr_day(p_at timestamptz, p_tz text)
returns text
language sql
stable
as $$
  with l as (select (p_at at time zone public.safe_tz(p_tz)) as t)
  select (array['dimanche','lundi','mardi','mercredi','jeudi','vendredi','samedi'])[extract(dow from t)::int + 1]
         || ' ' || extract(day from t)::int || ' '
         || (array['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'])[extract(month from t)::int]
  from l
$$;

-- '18:30' in the given timezone
create or replace function public.fr_time(p_at timestamptz, p_tz text)
returns text
language sql
stable
as $$
  select to_char(p_at at time zone public.safe_tz(p_tz), 'HH24:MI')
$$;

-- 'vendredi 4 décembre à 18:30'
create or replace function public.fr_when(p_at timestamptz, p_tz text)
returns text
language sql
stable
as $$
  select public.fr_day(p_at, p_tz) || ' à ' || public.fr_time(p_at, p_tz)
$$;

-- 'Marie, Paul et Léa' / 'Marie, Paul, Léa et 2 autres'
create or replace function public.join_names(p_names text[], p_max int default 3)
returns text
language plpgsql
immutable
as $$
declare
  n int := coalesce(array_length(p_names, 1), 0);
begin
  if n = 0 then return ''; end if;
  if n = 1 then return p_names[1]; end if;
  if n <= p_max then
    return array_to_string(p_names[1:n-1], ', ') || ' et ' || p_names[n];
  end if;
  return array_to_string(p_names[1:p_max], ', ') || ' et ' || (n - p_max) || ' autre' || case when n - p_max > 1 then 's' else '' end;
end;
$$;

create or replace function public.display_name_of(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(nullif(trim(p.display_name), ''), p.username, nullif(split_part(coalesce(p.email, ''), '@', 1), ''), 'Un ami')
  from public.profiles p where p.id = p_user
$$;

-- Queue a notification for a user and wake up the dispatcher.
create or replace function public.enqueue_notification(
  p_user uuid, p_kind text, p_title text, p_body text, p_url text, p_force_push boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.notifications (user_id, kind, title, body, url, channel, status, force_push)
  values (p_user, p_kind, p_title, p_body, p_url, 'none', 'pending', p_force_push)
  returning id into v_id;
  perform public.request_dispatch();
  return v_id;
end;
$$;

-- Ask the `dispatch` Edge Function to deliver pending notifications (async, via pg_net).
-- Does nothing until the vault secrets are configured.
create or replace function public.request_dispatch()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  begin
    select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
    select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'dispatch_secret';
  exception when others then
    return;
  end;
  if v_url is null or v_secret is null then return; end if;
  perform net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/dispatch',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
end;
$$;

-- "Envoyer une notification de test" (Settings)
create or replace function public.send_test_notification()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  return public.enqueue_notification(
    auth.uid(), 'test', 'Notification de test ✅', 'Les rappels SeeU fonctionnent sur cet appareil.', '/settings', true
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Social notifications (triggers)
-- ---------------------------------------------------------------------
create or replace function public.notify_friendship()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    select username into v_username from public.profiles where id = new.requester_id;
    perform public.enqueue_notification(
      new.addressee_id, 'friend_request',
      public.display_name_of(new.requester_id) || coalesce(' (@' || v_username || ')', '') || ' vous a ajouté sur SeeU',
      'Acceptez sa demande pour partager vos rendez-vous et vos photos.',
      '/friends'
    );
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted' then
    perform public.enqueue_notification(
      new.requester_id, 'friend_accept',
      public.display_name_of(new.addressee_id) || ' a accepté votre demande',
      'Vous pouvez maintenant lui proposer des rendez-vous.',
      '/friends'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_friendship on public.friendships;
create trigger trg_notify_friendship
  after insert or update of status on public.friendships
  for each row execute function public.notify_friendship();

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
    '👋 ' || public.display_name_of(new.from_user) || ' aimerait vous voir',
    case when v_contact is not null
      then 'Proposez un rendez-vous : ce contact est en tête de votre liste « À voir bientôt ».'
      else 'Proposez un rendez-vous dans SeeU.' end,
    case when v_contact is not null then '/contacts/' || v_contact else '/friends' end
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_wave on public.waves;
create trigger trg_notify_wave
  after insert on public.waves
  for each row execute function public.notify_wave();

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

  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    v_tz := public.user_tz(new.to_user);
    v_details := public.fr_when(r.appointment_at, v_tz) || coalesce(' · ' || nullif(trim(r.location), ''), '');
    perform public.enqueue_notification(
      new.to_user, 'rdv_invite',
      public.display_name_of(new.from_user) ||
        case when r.status = 'valide' then ' partage une rencontre avec vous' else ' vous propose un rendez-vous' end,
      coalesce(nullif(trim(r.title), '') || ' — ', '') || v_details || '. Acceptez ou refusez dans SeeU.',
      '/friends'
    );
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status in ('accepted', 'declined') then
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

drop trigger if exists trg_notify_rdv_invitation on public.rdv_invitations;
create trigger trg_notify_rdv_invitation
  after insert or update of status on public.rdv_invitations
  for each row execute function public.notify_rdv_invitation();

-- Shared rendezvous changed by its owner (not by the sync cascade): warn the other copies' owners.
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
  -- only the row the user actually edited (the copies are updated by a nested trigger)
  if new.share_id is null or pg_trigger_depth() > 1 or not (v_moved or v_status) then
    return new;
  end if;
  v_name := public.display_name_of(new.user_id);
  for c in select r.id, r.user_id from public.rendezvous r where r.share_id = new.share_id and r.user_id <> new.user_id loop
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

drop trigger if exists trg_notify_shared_rdv_change on public.rendezvous;
create trigger trg_notify_shared_rdv_change
  after update on public.rendezvous
  for each row execute function public.notify_shared_rdv_change();

-- ---------------------------------------------------------------------
-- Reminders (pg_cron, every 10 minutes)
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
  -- 1) Rendezvous reminders (user's lead time, 30 min by default)
  for r in
    select rv.*, coalesce(pr.rdv_reminder_minutes, 30) as lead, coalesce(pr.timezone, 'Europe/Paris') as tz
    from public.rendezvous rv
    left join public.profiles pr on pr.id = rv.user_id
    where rv.status = 'planifie' and not rv.reminder_sent
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

  -- 2) "Did it happen?" 2 hours after a rendezvous left planned
  for r in
    select rv.* from public.rendezvous rv
    where rv.status = 'planifie' and not rv.followup_sent
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

  -- 3) Daily digest + birthdays, at the user's chosen local hour
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
        -- born on Feb 29: celebrated on Feb 28 in non-leap years
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

  -- 4) Notifications stuck in 'sending' (dispatcher crashed) are retried
  update public.notifications set status = 'pending'
  where status = 'sending' and created_at < v_now - interval '10 minutes' and created_at > v_now - interval '1 day';

  return jsonb_build_object('reminders', n_rem, 'followups', n_follow, 'digests', n_digest, 'birthdays', n_bday);
end;
$$;

-- Dispatcher safety net: ping only when something is waiting.
create or replace function public.dispatch_if_pending()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.notifications where status = 'pending' and created_at > now() - interval '1 day') then
    perform public.request_dispatch();
  end if;
end;
$$;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'seeu-reminders') then
    perform cron.unschedule('seeu-reminders');
  end if;
  if exists (select 1 from cron.job where jobname = 'seeu-dispatch') then
    perform cron.unschedule('seeu-dispatch');
  end if;
end
$$;

select cron.schedule('seeu-reminders', '*/10 * * * *', 'select public.run_reminders()');
select cron.schedule('seeu-dispatch', '* * * * *', 'select public.dispatch_if_pending()');

-- ---------------------------------------------------------------------
-- Permissions: internal functions are not callable by clients
-- ---------------------------------------------------------------------
revoke execute on function public.enqueue_notification(uuid, text, text, text, text, boolean) from public, anon, authenticated;
revoke execute on function public.request_dispatch() from public, anon, authenticated;
revoke execute on function public.run_reminders() from public, anon, authenticated;
revoke execute on function public.dispatch_if_pending() from public, anon, authenticated;
revoke execute on function public.user_tz(uuid) from public, anon, authenticated;
revoke execute on function public.display_name_of(uuid) from public, anon, authenticated;
revoke execute on function public.register_device(text, text) from public, anon;
revoke execute on function public.send_test_notification() from public, anon;
grant execute on function public.register_device(text, text) to authenticated;
grant execute on function public.send_test_notification() to authenticated;

notify pgrst, 'reload schema';
