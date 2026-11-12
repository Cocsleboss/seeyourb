-- =====================================================================
--  SeeYourB — schéma de base de données (Supabase / PostgreSQL)
--
--  À exécuter UNE SEULE FOIS :
--  Supabase → SQL Editor → "New query" → coller tout ce fichier → Run
--
--  Le script est idempotent : le relancer ne casse rien.
--  Chaque table a la Row Level Security activée : un utilisateur ne voit
--  et ne modifie QUE ses propres données, même avec la clé publique (anon).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Types énumérés
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'frequency_unit' and n.nspname = 'public') then
    create type public.frequency_unit as enum ('days', 'weeks', 'months', 'years');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'rdv_status' and n.nspname = 'public') then
    create type public.rdv_status as enum ('planifie', 'valide', 'annule');
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- Fonctions utilitaires
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Calcul de la prochaine échéance : dernière rencontre + fréquence.
-- IMMUTABLE pour pouvoir servir de colonne calculée (generated column).
create or replace function public.compute_next_due(p_last date, p_value integer, p_unit public.frequency_unit)
returns date
language sql
immutable
as $$
  select (
    p_last + case p_unit
      when 'days'   then make_interval(days   => p_value)
      when 'weeks'  then make_interval(weeks  => p_value)
      when 'months' then make_interval(months => p_value)
      when 'years'  then make_interval(years  => p_value)
    end
  )::date
$$;

-- ---------------------------------------------------------------------
-- PROFILES : préférences de notification, fuseau horaire, email
-- (1 ligne par utilisateur, créée automatiquement à l'inscription)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  timezone text not null default 'Europe/Paris',
  notify_push boolean not null default true,
  notify_email boolean not null default true,
  daily_hour integer not null default 8 check (daily_hour between 0 and 23),
  due_lead_days integer not null default 0 check (due_lead_days between 0 and 30),
  rdv_reminder_minutes integer not null default 30 check (rdv_reminder_minutes between 5 and 1440),
  last_digest_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Création automatique du profil à l'inscription
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Garde l'email du profil synchronisé si l'utilisateur change d'email
create or replace function public.handle_user_email_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute function public.handle_user_email_update();

-- ---------------------------------------------------------------------
-- CONTACTS
-- ---------------------------------------------------------------------
create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  photo_path text,
  category text,
  phone text,
  email text,
  birthday date,
  notes text,
  last_meeting_date date not null,
  frequency_value integer not null check (frequency_value > 0 and frequency_value <= 1000),
  frequency_unit public.frequency_unit not null,
  next_due_date date generated always as (
    public.compute_next_due(last_meeting_date, frequency_value, frequency_unit)
  ) stored,
  snooze_until date,
  notified_current_cycle boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_contacts_user on public.contacts(user_id);
create index if not exists idx_contacts_user_due on public.contacts(user_id, next_due_date);

alter table public.contacts enable row level security;

drop policy if exists "contacts_own" on public.contacts;
create policy "contacts_own" on public.contacts
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Quand la date de dernière rencontre ou la fréquence change, on repart
-- sur un nouveau cycle : le flag de notification et le report sont remis à zéro.
create or replace function public.contacts_before_update()
returns trigger
language plpgsql
as $$
begin
  if new.last_meeting_date is distinct from old.last_meeting_date
     or new.frequency_value is distinct from old.frequency_value
     or new.frequency_unit is distinct from old.frequency_unit then
    new.notified_current_cycle := false;
    new.snooze_until := null;
  elsif new.snooze_until is distinct from old.snooze_until then
    new.notified_current_cycle := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_contacts_before_update on public.contacts;
create trigger trg_contacts_before_update
  before update on public.contacts
  for each row execute function public.contacts_before_update();

-- ---------------------------------------------------------------------
-- RENDEZ-VOUS
-- ---------------------------------------------------------------------
create table if not exists public.rendezvous (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  location text,
  notes text,
  appointment_at timestamptz not null,
  status public.rdv_status not null default 'planifie',
  reminder_sent boolean not null default false,
  followup_sent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_rdv_user_date on public.rendezvous(user_id, appointment_at);
create index if not exists idx_rdv_reminder on public.rendezvous(status, reminder_sent, appointment_at);
create index if not exists idx_rdv_followup on public.rendezvous(status, followup_sent, appointment_at);

alter table public.rendezvous enable row level security;

drop policy if exists "rdv_own" on public.rendezvous;
create policy "rdv_own" on public.rendezvous
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Si la date du rendez-vous change, les rappels doivent être renvoyés.
create or replace function public.rdv_before_update()
returns trigger
language plpgsql
as $$
begin
  if new.appointment_at is distinct from old.appointment_at then
    new.reminder_sent := false;
    new.followup_sent := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_rdv_before_update on public.rendezvous;
create trigger trg_rdv_before_update
  before update on public.rendezvous
  for each row execute function public.rdv_before_update();

-- ---------------------------------------------------------------------
-- LIAISON CONTACTS <-> RENDEZ-VOUS (plusieurs contacts par rendez-vous)
-- ---------------------------------------------------------------------
create table if not exists public.contact_rendezvous (
  contact_id uuid not null references public.contacts(id) on delete cascade,
  rendezvous_id uuid not null references public.rendezvous(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (contact_id, rendezvous_id)
);

create index if not exists idx_cr_user on public.contact_rendezvous(user_id);
create index if not exists idx_cr_rdv on public.contact_rendezvous(rendezvous_id);
create index if not exists idx_cr_contact on public.contact_rendezvous(contact_id);

alter table public.contact_rendezvous enable row level security;

drop policy if exists "cr_own" on public.contact_rendezvous;
drop policy if exists "cr_select_own" on public.contact_rendezvous;
create policy "cr_select_own" on public.contact_rendezvous
  for select using ((select auth.uid()) = user_id);

drop policy if exists "cr_insert_own" on public.contact_rendezvous;
create policy "cr_insert_own" on public.contact_rendezvous
  for insert with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.contacts c where c.id = contact_id and c.user_id = (select auth.uid()))
    and exists (select 1 from public.rendezvous r where r.id = rendezvous_id and r.user_id = (select auth.uid()))
  );

drop policy if exists "cr_delete_own" on public.contact_rendezvous;
create policy "cr_delete_own" on public.contact_rendezvous
  for delete using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- PHOTOS (galerie des contacts et des rendez-vous)
-- ---------------------------------------------------------------------
create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete cascade,
  rendezvous_id uuid references public.rendezvous(id) on delete cascade,
  storage_path text not null,
  caption text,
  created_at timestamptz not null default now(),
  check (contact_id is not null or rendezvous_id is not null)
);

create index if not exists idx_photos_user on public.photos(user_id);
create index if not exists idx_photos_contact on public.photos(contact_id);
create index if not exists idx_photos_rdv on public.photos(rendezvous_id);

alter table public.photos enable row level security;

drop policy if exists "photos_own" on public.photos;
drop policy if exists "photos_select_own" on public.photos;
create policy "photos_select_own" on public.photos
  for select using ((select auth.uid()) = user_id);

drop policy if exists "photos_insert_own" on public.photos;
create policy "photos_insert_own" on public.photos
  for insert with check (
    (select auth.uid()) = user_id
    and storage_path like ((select auth.uid())::text || '/%')
    and (contact_id is null or exists (select 1 from public.contacts c where c.id = contact_id and c.user_id = (select auth.uid())))
    and (rendezvous_id is null or exists (select 1 from public.rendezvous r where r.id = rendezvous_id and r.user_id = (select auth.uid())))
  );

drop policy if exists "photos_update_own" on public.photos;
create policy "photos_update_own" on public.photos
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "photos_delete_own" on public.photos;
create policy "photos_delete_own" on public.photos
  for delete using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- ABONNEMENTS WEB PUSH (un par appareil / navigateur)
-- ---------------------------------------------------------------------
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists idx_push_user on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;

drop policy if exists "push_own" on public.push_subscriptions;
create policy "push_own" on public.push_subscriptions
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- JOURNAL DES NOTIFICATIONS ENVOYÉES (lecture seule côté app)
-- ---------------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  url text,
  channel text not null default 'none',
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using ((select auth.uid()) = user_id);

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own" on public.notifications
  for delete using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- LOGIQUE MÉTIER : un rendez-vous VALIDÉ met à jour la date de
-- dernière rencontre de chaque contact associé (jamais en arrière).
-- ---------------------------------------------------------------------

-- Date "locale" (selon le fuseau de l'utilisateur) d'un instant donné.
create or replace function public.rdv_local_date(p_user uuid, p_at timestamptz)
returns date
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tz text;
  d date;
begin
  select timezone into tz from public.profiles where id = p_user;
  begin
    d := (p_at at time zone coalesce(nullif(tz, ''), 'Europe/Paris'))::date;
  exception when others then
    d := (p_at at time zone 'UTC')::date;
  end;
  return d;
end;
$$;

create or replace function public.apply_validated_rdv(p_rdv_id uuid, p_user uuid, p_at timestamptz, p_contact uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  d date := public.rdv_local_date(p_user, p_at);
begin
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

-- Trigger sur rendezvous : passage à "valide" (ou changement de date d'un rdv validé)
create or replace function public.rdv_after_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'valide' and (
       tg_op = 'INSERT'
       or old.status is distinct from 'valide'
       or old.appointment_at is distinct from new.appointment_at
     ) then
    perform public.apply_validated_rdv(new.id, new.user_id, new.appointment_at, null);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rdv_validated on public.rendezvous;
drop trigger if exists trg_rdv_after_write on public.rendezvous;
create trigger trg_rdv_after_write
  after insert or update on public.rendezvous
  for each row execute function public.rdv_after_write();

-- Trigger sur la liaison : si on rattache un contact à un rdv déjà validé
-- (cas d'une rencontre passée saisie directement comme "a eu lieu").
create or replace function public.cr_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select status, appointment_at, user_id into r from public.rendezvous where id = new.rendezvous_id;
  if r.status = 'valide' then
    perform public.apply_validated_rdv(new.rendezvous_id, r.user_id, r.appointment_at, new.contact_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cr_after_insert on public.contact_rendezvous;
create trigger trg_cr_after_insert
  after insert on public.contact_rendezvous
  for each row execute function public.cr_after_insert();

-- ---------------------------------------------------------------------
-- STOCKAGE DES PHOTOS (bucket privé "photos", 1 dossier par utilisateur)
-- Chemin des fichiers : <user_id>/<uuid>.jpg
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'photos', 'photos', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

drop policy if exists "photos_storage_select" on storage.objects;
create policy "photos_storage_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "photos_storage_insert" on storage.objects;
create policy "photos_storage_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "photos_storage_update" on storage.objects;
create policy "photos_storage_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "photos_storage_delete" on storage.objects;
create policy "photos_storage_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------------
-- Fin. Vérification rapide (doit renvoyer 7 tables avec rls = true) :
-- select tablename, rowsecurity from pg_tables where schemaname = 'public';
-- ---------------------------------------------------------------------
