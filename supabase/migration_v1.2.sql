-- =====================================================================
--  SeeU — MIGRATION vers la v1.2 (base déjà en production)
--
--  Supabase → SQL Editor → "New query" → coller tout ce fichier → Run
--
--  À lancer AVANT de déployer la nouvelle version de l'app.
--  - Fonctionne depuis la v1.0 comme depuis la v1.1.
--  - Ne supprime et ne modifie aucune donnée existante (contacts,
--    rendez-vous, photos, comptes) : uniquement des ajouts.
--  - Tout ou rien (transaction) et relançable sans risque.
--  - Les comptes existants n'ont pas encore de nom d'utilisateur :
--    l'app le leur demandera à leur prochaine ouverture.
--
--  (Fichier généré à partir de supabase/schema.sql, qui reste la
--  référence pour une installation neuve.)
-- =====================================================================

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. PROFILS : nom d'utilisateur et anniversaire
-- ---------------------------------------------------------------------
-- v1.2 : nom d'utilisateur unique (affiché avec un "@" devant, sert à s'ajouter entre amis)
-- et date d'anniversaire (visible par les amis SeeU). NULL = pas encore choisi : l'app le demande.
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists birthday date;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_username_format') then
    alter table public.profiles add constraint profiles_username_format
      check (username ~ '^[a-z0-9][a-z0-9_.]{2,19}$');
  end if;
end
$$;
create unique index if not exists idx_profiles_username on public.profiles(username);

-- ---------------------------------------------------------------------
-- 2. Inscription : le nom d'utilisateur choisi est enregistré dans le profil
-- ---------------------------------------------------------------------
-- Création automatique du profil à l'inscription.
-- Le nom d'utilisateur demandé à l'inscription est repris s'il est valide et libre ;
-- sinon il reste vide et l'app le demandera à la première ouverture.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(leading '@' from trim(coalesce(new.raw_user_meta_data ->> 'username', ''))));
  v_name text;
begin
  if v_username !~ '^[a-z0-9][a-z0-9_.]{2,19}$'
     or exists (select 1 from public.profiles where username = v_username) then
    v_username := null;
  end if;
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    v_username,
    split_part(coalesce(new.email, ''), '@', 1)
  );
  begin
    insert into public.profiles (id, email, display_name, username)
    values (new.id, new.email, v_name, v_username)
    on conflict (id) do update set email = excluded.email;
  exception when unique_violation then
    -- nom d'utilisateur pris entre-temps : le compte est créé sans, l'app le redemandera
    insert into public.profiles (id, email, display_name)
    values (new.id, new.email, v_name)
    on conflict (id) do update set email = excluded.email;
  end;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Comptes existants sans profil
-- ---------------------------------------------------------------------
-- Comptes créés avant l'existence de leur profil (sécurité : ne fait rien si tout est en ordre)
insert into public.profiles (id, email, display_name)
select u.id, u.email, split_part(coalesce(u.email, ''), '@', 1)
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- ---------------------------------------------------------------------
-- 4. CONTACTS : « à voir bientôt » et compte ami associé
-- ---------------------------------------------------------------------
-- v1.1 : "À voir bientôt" (ajout manuel à la liste, même si l'échéance est loin)
alter table public.contacts add column if not exists see_soon boolean not null default false;
-- v1.1 : compte SeeU associé à ce contact (ami) — voir la section "AMIS" plus bas
alter table public.contacts add column if not exists linked_user_id uuid references auth.users(id) on delete set null;
create unique index if not exists idx_contacts_linked_user
  on public.contacts(user_id, linked_user_id) where linked_user_id is not null;

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
    if new.last_meeting_date is distinct from old.last_meeting_date then
      new.see_soon := false; -- on vient de se voir : plus besoin de "à voir bientôt"
    end if;
  elsif new.snooze_until is distinct from old.snooze_until then
    new.notified_current_cycle := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. RENDEZ-VOUS : identifiant de partage
-- ---------------------------------------------------------------------
-- v1.1 : identifiant commun aux copies d'un même rendez-vous partagé entre amis
-- (chaque utilisateur garde SA ligne ; les copies portent le même share_id)
alter table public.rendezvous add column if not exists share_id uuid;
create index if not exists idx_rdv_share on public.rendezvous(share_id) where share_id is not null;

-- =====================================================================
--  v1.1 / v1.2 — AMIS SeeU, RENDEZ-VOUS PARTAGÉS, GALERIE COMMUNE
--
--  Principe : chaque utilisateur garde ses propres lignes (contacts,
--  rendez-vous, photos) protégées par la RLS. Le partage passe par des
--  fonctions "security definer" qui vérifient elles-mêmes les droits.
-- =====================================================================

-- ---------------------------------------------------------------------
-- AMITIÉS (demande par nom d'utilisateur, acceptée ou non par l'autre)
-- ---------------------------------------------------------------------
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);

create unique index if not exists idx_friendships_pair
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index if not exists idx_friendships_addressee on public.friendships(addressee_id);

alter table public.friendships enable row level security;

drop policy if exists "friendships_select_mine" on public.friendships;
create policy "friendships_select_mine" on public.friendships
  for select using ((select auth.uid()) in (requester_id, addressee_id));

-- Retirer un ami / annuler ou refuser une demande : l'un ou l'autre peut supprimer la ligne.
-- (Pas de policy insert/update : tout passe par les fonctions ci-dessous.)
drop policy if exists "friendships_delete_mine" on public.friendships;
create policy "friendships_delete_mine" on public.friendships
  for delete using ((select auth.uid()) in (requester_id, addressee_id));

create or replace function public.are_friends(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = p_a and f.addressee_id = p_b) or (f.requester_id = p_b and f.addressee_id = p_a))
  )
$$;
revoke execute on function public.are_friends(uuid, uuid) from public, anon, authenticated;

-- Un contact ne peut être associé qu'à un ami accepté.
create or replace function public.contacts_check_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.linked_user_id is not null
     and (tg_op = 'INSERT' or new.linked_user_id is distinct from old.linked_user_id) then
    if new.linked_user_id = new.user_id or not public.are_friends(new.user_id, new.linked_user_id) then
      raise exception 'Cette personne ne fait pas partie de vos amis SeeU.';
    end if;
    -- l'ami a renseigné son anniversaire : on le reprend si le contact n'en a pas
    if new.birthday is null then
      select p.birthday into new.birthday from public.profiles p where p.id = new.linked_user_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_contacts_check_link on public.contacts;
create trigger trg_contacts_check_link
  before insert or update on public.contacts
  for each row execute function public.contacts_check_link();

-- Fin d'une amitié : les contacts ne sont plus associés (ils ne sont pas supprimés).
create or replace function public.friendships_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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

-- Un ami qui renseigne (ou corrige) son anniversaire : les contacts associés chez ses amis suivent,
-- sauf si l'ami y avait saisi lui-même une autre date.
create or replace function public.profiles_after_birthday()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.birthday is not null and new.birthday is distinct from old.birthday then
    update public.contacts c
    set birthday = new.birthday
    where c.linked_user_id = new.id
      and (c.birthday is null or c.birthday = old.birthday);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_birthday on public.profiles;
create trigger trg_profiles_birthday
  after update of birthday on public.profiles
  for each row execute function public.profiles_after_birthday();

-- Nom d'utilisateur valide et libre ? (utilisé à l'inscription, donc ouvert aux visiteurs)
create or replace function public.username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    lower(trim(p_username)) ~ '^[a-z0-9][a-z0-9_.]{2,19}$'
    and lower(trim(p_username)) not in ('seeu', 'admin', 'support')
    and not exists (
      select 1 from public.profiles p
      where p.username = lower(trim(p_username)) and p.id is distinct from auth.uid()
    ),
    false)
$$;

-- Recherche d'utilisateurs par début de nom d'utilisateur (2 caractères minimum, 8 résultats).
-- Ne renvoie que le nom d'utilisateur et le nom affiché — jamais l'email.
-- relation : 'none' | 'friends' | 'sent' (demande envoyée) | 'received' (demande reçue)
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
  order by (p.username = q.v) desc, p.username
  limit 8
$$;

-- Envoie une demande d'ami à partir d'un nom d'utilisateur (exact, avec ou sans "@").
-- Renvoie {status: 'sent' | 'accepted' | 'already_sent' | 'already_friends' | 'self' | 'not_found', ...}
-- (drop : en v1.1 la fonction prenait une adresse email)
drop function if exists public.send_friend_request(text);
create function public.send_friend_request(p_username text)
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
  if me is null then raise exception 'Non connecté'; end if;

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
      return v_info || jsonb_build_object('status', 'already_friends', 'friendship_id', f.id);
    elsif f.requester_id = me then
      return v_info || jsonb_build_object('status', 'already_sent', 'friendship_id', f.id);
    else
      -- l'autre m'avait déjà envoyé une demande : on l'accepte
      update public.friendships set status = 'accepted', responded_at = now() where id = f.id;
      return v_info || jsonb_build_object('status', 'accepted', 'friendship_id', f.id);
    end if;
  end if;

  insert into public.friendships (requester_id, addressee_id) values (me, v_target) returning * into f;
  return v_info || jsonb_build_object('status', 'sent', 'friendship_id', f.id);
end;
$$;

-- Répond à une demande reçue : accepter, ou refuser (la demande est alors supprimée).
create or replace function public.respond_friend_request(p_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'Non connecté'; end if;
  if p_accept then
    update public.friendships set status = 'accepted', responded_at = now()
    where id = p_id and addressee_id = me and status = 'pending';
  else
    delete from public.friendships where id = p_id and addressee_id = me and status = 'pending';
  end if;
  if not found then raise exception 'Demande introuvable.'; end if;
end;
$$;

-- Mes amis et demandes en cours. L'email n'est renvoyé que pour les amis acceptés.
-- (drop : les colonnes renvoyées ont changé depuis la v1.1)
drop function if exists public.list_friends();
create function public.list_friends()
returns table (
  friendship_id uuid,
  user_id uuid,
  username text,
  display_name text,
  email text,
  status text,
  incoming boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id,
         p.id,
         p.username,
         coalesce(nullif(trim(p.display_name), ''), p.username, split_part(coalesce(p.email, ''), '@', 1)),
         case when f.status = 'accepted' then p.email end,
         f.status,
         f.addressee_id = auth.uid(),
         f.created_at
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where auth.uid() in (f.requester_id, f.addressee_id)
  order by f.created_at desc
$$;

-- ---------------------------------------------------------------------
-- « ENVIE DE SE VOIR » : un signe envoyé à un ami. Il reçoit une
-- notification et je passe dans SA liste « à voir bientôt ».
-- ---------------------------------------------------------------------
create table if not exists public.waves (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (from_user <> to_user)
);

create index if not exists idx_waves_pair on public.waves(from_user, to_user, created_at desc);

alter table public.waves enable row level security;

drop policy if exists "waves_select_mine" on public.waves;
create policy "waves_select_mine" on public.waves
  for select using ((select auth.uid()) in (from_user, to_user));

-- Un signe par ami et par 24 h. Renvoie l'id du signe.
create or replace function public.send_wave(p_to uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_id uuid;
begin
  if me is null then raise exception 'Non connecté'; end if;
  if not public.are_friends(me, p_to) then raise exception 'Cette personne ne fait pas partie de vos amis SeeU.'; end if;
  if exists (select 1 from public.waves where from_user = me and to_user = p_to and created_at > now() - interval '24 hours') then
    raise exception 'Vous lui avez déjà fait signe aujourd''hui.';
  end if;
  insert into public.waves (from_user, to_user) values (me, p_to) returning id into v_id;
  update public.contacts set see_soon = true
  where user_id = p_to and linked_user_id = me and not see_soon;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- INVITATIONS À UN RENDEZ-VOUS
-- A crée un rendez-vous et l'envoie à son ami B. Si B accepte, B reçoit
-- sa propre copie (même share_id). Statut, date, titre et lieu restent
-- ensuite synchronisés ; les notes restent privées.
-- ---------------------------------------------------------------------
create table if not exists public.rdv_invitations (
  id uuid primary key default gen_random_uuid(),
  rdv_id uuid not null references public.rendezvous(id) on delete cascade,
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  to_rdv_id uuid references public.rendezvous(id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (rdv_id, to_user)
);

create index if not exists idx_rdv_inv_to on public.rdv_invitations(to_user, status);
create index if not exists idx_rdv_inv_from on public.rdv_invitations(from_user);

alter table public.rdv_invitations enable row level security;

drop policy if exists "rdv_inv_select_mine" on public.rdv_invitations;
create policy "rdv_inv_select_mine" on public.rdv_invitations
  for select using ((select auth.uid()) in (from_user, to_user));

-- L'expéditeur peut annuler une invitation restée sans réponse.
drop policy if exists "rdv_inv_delete_sender" on public.rdv_invitations;
create policy "rdv_inv_delete_sender" on public.rdv_invitations
  for delete using ((select auth.uid()) = from_user and status <> 'accepted');

-- (le trigger est créé ici car la fonction utilise rdv_invitations)
drop trigger if exists trg_friendships_after_delete on public.friendships;
create trigger trg_friendships_after_delete
  after delete on public.friendships
  for each row execute function public.friendships_after_delete();

create or replace function public.send_rdv_invite(p_rdv uuid, p_to uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  r public.rendezvous%rowtype;
  v_id uuid;
begin
  if me is null then raise exception 'Non connecté'; end if;
  select * into r from public.rendezvous where id = p_rdv and user_id = me;
  if not found then raise exception 'Rendez-vous introuvable.'; end if;
  if r.status = 'annule' then raise exception 'Ce rendez-vous est annulé.'; end if;
  if not public.are_friends(me, p_to) then raise exception 'Cette personne ne fait pas partie de vos amis SeeU.'; end if;

  if r.share_id is null then
    update public.rendezvous set share_id = gen_random_uuid() where id = p_rdv;
  end if;

  select id into v_id from public.rdv_invitations where rdv_id = p_rdv and to_user = p_to;
  if v_id is null then
    insert into public.rdv_invitations (rdv_id, from_user, to_user) values (p_rdv, me, p_to) returning id into v_id;
  else
    -- déjà refusée : on la propose à nouveau
    update public.rdv_invitations
    set status = 'pending', created_at = now(), responded_at = null
    where id = v_id and status = 'declined';
  end if;
  return v_id;
end;
$$;

-- Invitations reçues en attente, avec le détail du rendez-vous proposé.
create or replace function public.list_rdv_invites()
returns table (
  id uuid,
  rdv_id uuid,
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
         i.from_user,
         coalesce(nullif(trim(p.display_name), ''), nullif(split_part(coalesce(p.email, ''), '@', 1), ''), 'Un ami'),
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

-- Répond à une invitation. Si acceptée : crée ma copie du rendez-vous, rattachée à mon
-- contact associé à l'expéditeur (créé au besoin), et renvoie l'id de ma copie.
create or replace function public.respond_rdv_invite(p_invite uuid, p_accept boolean)
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
  v_share uuid;
  v_contact uuid;
  v_rdv uuid;
begin
  if me is null then raise exception 'Non connecté'; end if;
  select * into inv from public.rdv_invitations where id = p_invite and to_user = me for update;
  if not found then raise exception 'Invitation introuvable.'; end if;
  if inv.status <> 'pending' then raise exception 'Vous avez déjà répondu à cette invitation.'; end if;

  if not p_accept then
    update public.rdv_invitations set status = 'declined', responded_at = now() where id = inv.id;
    return null;
  end if;

  select * into r from public.rendezvous where id = inv.rdv_id;
  if not found then raise exception 'Ce rendez-vous n''existe plus.'; end if;
  if not public.are_friends(me, inv.from_user) then raise exception 'Vous n''êtes plus amis sur SeeU.'; end if;

  v_share := r.share_id;
  if v_share is null then
    v_share := gen_random_uuid();
    update public.rendezvous set share_id = v_share where id = r.id;
  end if;

  -- déjà une copie de ce rendez-vous chez moi ? (invité par deux participants)
  select id into v_rdv from public.rendezvous where user_id = me and share_id = v_share limit 1;

  if v_rdv is null then
    select id into v_contact from public.contacts where user_id = me and linked_user_id = inv.from_user limit 1;
    if v_contact is null then
      select * into sender from public.profiles where id = inv.from_user;
      insert into public.contacts (user_id, name, email, last_meeting_date, frequency_value, frequency_unit, linked_user_id)
      values (
        me,
        left(coalesce(nullif(trim(sender.display_name), ''), nullif(split_part(coalesce(sender.email, ''), '@', 1), ''), 'Ami SeeU'), 120),
        sender.email,
        public.rdv_local_date(me, now()),
        1,
        'months',
        inv.from_user
      )
      returning id into v_contact;
    end if;

    insert into public.rendezvous (user_id, title, location, appointment_at, status, share_id)
    values (me, r.title, r.location, r.appointment_at, r.status, v_share)
    returning id into v_rdv;

    insert into public.contact_rendezvous (contact_id, rendezvous_id, user_id) values (v_contact, v_rdv, me);
  end if;

  update public.rdv_invitations
  set status = 'accepted', to_rdv_id = v_rdv, responded_at = now()
  where id = inv.id;
  return v_rdv;
end;
$$;

-- Synchronisation des copies d'un rendez-vous partagé : quand l'un valide, annule,
-- déplace ou renomme, les autres copies suivent. La validation déclenche chez chacun
-- (trigger rdv_after_write) la remise à zéro de SA période avec SON contact.
create or replace function public.rdv_sync_shared()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.share_id is null then
    return new;
  end if;
  if new.status is distinct from old.status
     or new.appointment_at is distinct from old.appointment_at
     or new.title is distinct from old.title
     or new.location is distinct from old.location then
    update public.rendezvous r
    set status = new.status,
        appointment_at = new.appointment_at,
        title = new.title,
        location = new.location
    where r.share_id = new.share_id
      and r.id <> new.id
      and (r.status is distinct from new.status
        or r.appointment_at is distinct from new.appointment_at
        or r.title is distinct from new.title
        or r.location is distinct from new.location);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rdv_sync_shared on public.rendezvous;
create trigger trg_rdv_sync_shared
  after update on public.rendezvous
  for each row execute function public.rdv_sync_shared();

-- ---------------------------------------------------------------------
-- GALERIE COMMUNE d'un rendez-vous partagé
-- Chacun stocke ses photos dans son dossier ; les autres participants
-- peuvent les VOIR (jamais les modifier ni les supprimer).
-- ---------------------------------------------------------------------
create index if not exists idx_photos_path on public.photos(storage_path);

-- Photos ajoutées par les autres participants à mon rendez-vous p_rdv.
create or replace function public.list_shared_rdv_photos(p_rdv uuid)
returns setof public.photos
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.rendezvous mine
  join public.rendezvous r on r.share_id = mine.share_id and r.id <> mine.id
  join public.photos p on p.rendezvous_id = r.id
  where mine.id = p_rdv
    and mine.user_id = auth.uid()
    and mine.share_id is not null
  order by p.created_at desc
$$;

-- Vrai si le fichier appartient à la galerie d'un rendez-vous que je partage.
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
    join public.rendezvous mine on mine.share_id = r.share_id
    where p.storage_path = p_path
      and mine.user_id = auth.uid()
  )
$$;

drop policy if exists "photos_storage_select_shared" on storage.objects;
create policy "photos_storage_select_shared" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and public.can_read_shared_photo(name));

-- Les fonctions appelées par l'app ne sont ouvertes qu'aux utilisateurs connectés.
revoke execute on function public.search_users(text) from public, anon;
revoke execute on function public.send_wave(uuid) from public, anon;
revoke execute on function public.send_friend_request(text) from public, anon;
revoke execute on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke execute on function public.list_friends() from public, anon;
revoke execute on function public.send_rdv_invite(uuid, uuid) from public, anon;
revoke execute on function public.list_rdv_invites() from public, anon;
revoke execute on function public.respond_rdv_invite(uuid, boolean) from public, anon;
revoke execute on function public.list_shared_rdv_photos(uuid) from public, anon;
revoke execute on function public.can_read_shared_photo(text) from public, anon;
grant execute on function public.username_available(text) to anon, authenticated;
grant execute on function public.search_users(text) to authenticated;
grant execute on function public.send_wave(uuid) to authenticated;
grant execute on function public.send_friend_request(text) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.list_friends() to authenticated;
grant execute on function public.send_rdv_invite(uuid, uuid) to authenticated;
grant execute on function public.list_rdv_invites() to authenticated;
grant execute on function public.respond_rdv_invite(uuid, boolean) to authenticated;
grant execute on function public.list_shared_rdv_photos(uuid) to authenticated;
grant execute on function public.can_read_shared_photo(text) to authenticated;

-- PostgREST : recharge le schéma pour exposer tout de suite les nouvelles fonctions.
notify pgrst, 'reload schema';

commit;

-- ---------------------------------------------------------------------
-- Vérification (à lancer ensuite, séparément) : doit renvoyer 1 ligne par
-- compte, avec username vide tant que la personne n'a pas rouvert l'app.
-- select email, username, display_name from public.profiles order by created_at;
-- ---------------------------------------------------------------------
