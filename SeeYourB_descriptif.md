# SeeYourB — descriptif de l'application

## 1. Présentation

SeeYourB est une application web progressive (PWA), installable sur smartphone via "Ajouter à l'écran d'accueil", conçue pour aider les utilisateurs à gérer leurs relations sociales et professionnelles de manière simple et proactive.

L'objectif principal est d'éviter d'oublier les personnes qu'on aimerait revoir, en calculant automatiquement les délais de réconciliation selon une fréquence définie, puis en planifiant des rappels et des rendez-vous.

Chaque utilisateur dispose d'un espace privé et isolé : aucune donnée n'est partagée ou visible entre utilisateurs.

L'application permet de :
- créer un compte personnel sécurisé,
- conserver une liste de contacts,
- définir la fréquence à laquelle on souhaite les revoir,
- enregistrer des rendez-vous avec date, heure et participants,
- recevoir des notifications de rappel (push et/ou email),
- consulter l'historique des rencontres déjà réalisées.

---

## 2. Objectif fonctionnel

SeeYourB répond à un besoin concret : ne plus oublier de recontacter ses proches, amis, collègues ou clients.

Elle transforme la gestion des contacts en un outil de suivi des relations, avec :
- une vue synthétique des personnes à recontacter maintenant ou prochainement,
- un suivi des derniers rendez-vous,
- la planification d'événements ou de rendez-vous,
- la consultation de la liste de contacts et des détails associés à chaque personne (dont galerie photo),
- l'ajout de contacts,
- la recherche rapide d'un contact,
- l'ajout de photos pour les rendez-vous et les contacts,
- la création d'événements avec photos, associés à un ou plusieurs contacts.

---

## 3. Fonctionnalités principales

### 3.1 Compte utilisateur et sécurité

- Création de compte (email + mot de passe, ou lien magique).
- Connexion / déconnexion sécurisée.
- Chaque utilisateur n'a accès qu'à ses propres données (contacts, rendez-vous, photos) — isolation stricte au niveau base de données (Row Level Security), pas seulement au niveau de l'interface.
- Aucune fonctionnalité sociale ou de partage entre utilisateurs : les espaces sont totalement cloisonnés.
- Communications chiffrées (HTTPS) de bout en bout.

### 3.2 Gestion des contacts

L'application permet d'ajouter des contacts avec les informations suivantes :
- nom,
- date de dernière rencontre,
- fréquence de contact (en jours, semaines, mois ou années),
- photo de profil optionnelle.

Chaque contact est ensuite évalué selon sa date de prochaine rencontre calculée automatiquement à partir de la dernière rencontre et de la fréquence définie.

Les actions disponibles sur les contacts comprennent :
- ajout d'un contact,
- recherche rapide dans la liste,
- affichage des détails du contact,
- modification du nom, de la photo et de la fréquence,
- suppression de contact.

### 3.3 Suivi des dates de recontact

Pour chaque contact, l'application calcule une date estimée de prochaine rencontre :
- date de dernière rencontre + fréquence de rappel.

Dans la liste principale, les contacts sont affichés avec un indicateur temporel du type :
- "à revoir dans 3 jours",
- "à revoir dans 2 semaines",
- "à revoir dans 6 mois",
- "en retard de X jours" si l'échéance est dépassée.

**Règle de persistance de l'échéance :** un contact arrivé à échéance reste affiché en tête de liste (avec indicateur "en retard") tant qu'aucun rendez-vous n'a été créé avec lui. Il ne disparaît pas tout seul avec le temps.

Cela permet de prioriser les personnes à recontacter en fonction du délai restant.

### 3.4 Détails d'un contact

La fiche d'un contact affiche :
- le nom,
- la photo,
- la date de dernière rencontre,
- le délai restant (ou le retard) avant le prochain rappel,
- les actions pour modifier les informations ou ajouter un rendez-vous.

Il est également possible d'accéder à une galerie des rendez-vous associés à ce contact.

### 3.5 Ajout de rendez-vous

L'application permet de créer des rendez-vous avec :
- un ou plusieurs contacts,
- une date,
- une heure,
- une photo optionnelle du rendez-vous.

Les rendez-vous peuvent être ajoutés :
- depuis l'écran d'accueil,
- depuis la fiche détaillée d'un contact.

Une fois créés, ils sont enregistrés en base de données et visibles dans la liste des rendez-vous à venir.

### 3.6 Cycle de vie d'un rendez-vous

Un rendez-vous, une fois créé, reste actif (visible, modifiable) jusqu'à ce que l'utilisateur le fasse basculer dans l'un des deux états suivants :

- **Validé / terminé** : le rendez-vous a eu lieu. La date de dernière rencontre de chaque contact associé est alors mise à jour automatiquement avec la date du rendez-vous, ce qui recalcule immédiatement sa prochaine échéance. Le contact sort de l'état "en retard" ou "à revoir".
- **Annulé** : le rendez-vous n'a pas eu lieu. Aucune mise à jour de la date de dernière rencontre n'est effectuée ; le contact reste en attente et continue d'apparaître comme à recontacter.

Chaque rendez-vous peut par ailleurs être :
- consulté,
- modifié (date, heure, participants),
- supprimé,
- associé à des photos.

### 3.7 Historique des rendez-vous

Un écran d'historique permet de visualiser les rendez-vous marqués comme validés ou annulés.

Cette vue est utile pour :
- garder une trace des rencontres passées,
- revoir les événements importants,
- se rappeler des derniers contacts effectués.

### 3.8 Notifications de rappel

Le système de notification repose sur deux canaux complémentaires :

- **Notifications push (canal principal)** : via l'API Web Push, nativement supportée par les PWA installées sur l'écran d'accueil (Android/Chrome de longue date, iOS à partir de la version 16.4). L'utilisateur autorise les notifications lors de l'installation ou depuis les réglages.
- **Notifications par email (canal de secours)** : utilisées si l'utilisateur n'a pas autorisé les notifications push, ou n'a pas encore installé l'application sur son écran d'accueil.

Une alerte est envoyée avant l'échéance d'un rendez-vous planifié, ainsi que pour signaler qu'un contact arrive à échéance de recontact.

### 3.9 Recherche et filtres

La liste des contacts peut être filtrée par nom via une barre de recherche.

Cela permet de trouver rapidement un contact sans parcourir toute la liste.

### 3.10 Galerie des rendez-vous

Pour chaque contact, il est possible d'accéder à une galerie visuelle qui rassemble les rendez-vous associés, avec les photos éventuellement ajoutées.

Cette fonction permet de garder une trace des souvenirs ou des moments partagés.

---

## 4. Interface et navigation

L'application est structurée autour de :
- un écran de connexion / inscription,
- un écran d'accueil,
- une page de contacts,
- une page détaillée par contact,
- une page d'historique,
- une navigation par barre inférieure (adaptée mobile).

L'écran d'accueil présente :
- les prochains contacts à revoir (et ceux en retard),
- la liste des rendez-vous à venir,
- le bouton d'ajout de rendez-vous.

---

## 5. Stack technique

SeeYourB est une PWA construite avec les technologies suivantes :

- **Frontend** : framework web (React/Next.js ou équivalent), avec manifest PWA et service worker pour l'installation sur écran d'accueil et le fonctionnement hors-ligne partiel.
- **Backend / base de données** : Supabase (Postgres géré) — choisi pour son plan gratuit, son authentification intégrée et sa Row Level Security qui garantit l'isolation stricte des données par utilisateur au niveau base de données.
- **Authentification** : Supabase Auth (email/mot de passe ou lien magique), gestion des sessions via JWT — aucune logique de mot de passe codée manuellement.
- **Stockage des photos** : Supabase Storage, avec règles d'accès équivalentes (RLS) pour que chaque utilisateur n'accède qu'à ses propres fichiers.
- **Notifications push** : Web Push API (protocole standard, clés VAPID).
- **Notifications email** : service d'envoi transactionnel (ex. Resend ou équivalent, offre gratuite disponible).
- **Hébergement frontend** : Vercel ou Netlify (plan gratuit, HTTPS automatique, déploiement continu depuis GitHub).

Coût d'infrastructure : nul tant que l'usage reste dans les limites des plans gratuits (largement suffisant pour un usage personnel et un petit groupe d'utilisateurs).

### 5.1 Sécurité

- HTTPS imposé sur l'ensemble de l'application.
- Isolation des données par utilisateur via Row Level Security au niveau de la base de données (et non uniquement via des vérifications côté application).
- Mots de passe et sessions gérés exclusivement par le fournisseur d'authentification (hashing, tokens, expiration/refresh) — aucune implémentation maison.
- Variables sensibles (clés API, clés VAPID) stockées en variables d'environnement, jamais dans le code source.
- Aucune donnée partagée ou accessible entre comptes utilisateurs.

### 5.2 Calcul des échéances et planification des notifications

**Principe général :** la première échéance de chaque contact est saisie manuellement (date de dernière rencontre + fréquence souhaitée). Les échéances suivantes sont recalculées automatiquement à chaque fois qu'un rendez-vous avec ce contact est validé, en prenant la date du rendez-vous comme nouvelle référence.

**Calcul de l'échéance (`next_due_date`) :** implémenté comme une colonne calculée (*generated column*) directement en base de données, à partir de `last_meeting_date` et de la fréquence définie. Aucune logique de calcul côté application : la valeur est toujours juste et à jour.

**Mise à jour automatique à la validation d'un rendez-vous :** un trigger côté base de données se déclenche lorsqu'un rendez-vous passe au statut "validé". Il met à jour la date de dernière rencontre de chaque contact associé avec la date du rendez-vous, ce qui recalcule immédiatement (et automatiquement, via la colonne calculée) la nouvelle échéance.

**Deux tâches planifiées (`pg_cron`, natif chez Supabase, gratuit) tournent en tâche de fond :**

1. **Tâche quotidienne** (ex. 8h du matin) : recherche les contacts dont l'échéance est atteinte ou dépassée et qui n'ont pas encore été notifiés pour ce cycle, puis déclenche l'envoi d'une notification. Le flag de notification est réinitialisé automatiquement dès que la date de dernière rencontre change (nouveau rendez-vous validé), évitant les notifications répétées pour le même retard.
2. **Tâche fréquente** (toutes les 5 à 10 minutes) : recherche les rendez-vous planifiés dont l'heure tombe dans les 35 prochaines minutes et dont le rappel n'a pas encore été envoyé, puis déclenche l'envoi d'une notification environ 30 minutes avant.

Ces deux tâches planifiées appellent une Edge Function (hébergée gratuitement, jusqu'à 500 000 appels/mois inclus) qui gère l'envoi effectif : notification push (Web Push, clés VAPID) en priorité, email en secours si l'utilisateur n'a pas activé les notifications push.

Cette architecture ne nécessite aucun serveur à maintenir soi-même et reste entièrement gratuite dans les limites d'usage d'un groupe restreint d'utilisateurs.

### 5.3 Schéma de base de données (PostgreSQL / Supabase)

> Point de vigilance critique : chaque table doit avoir la Row Level Security explicitement activée (`ENABLE ROW LEVEL SECURITY`). Sans cela, une table reste accessible via la clé publique (`anon key`), visible dans le code frontend — c'est la faille la plus fréquente sur ce type d'architecture.

```sql
-- Extensions nécessaires
create extension if not exists pgcrypto;
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Types énumérés
create type frequency_unit as enum ('days', 'weeks', 'months', 'years');
create type rdv_status as enum ('planifie', 'valide', 'annule');

-- ============ CONTACTS ============
create table contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  photo_url text,
  last_meeting_date date not null,
  frequency_value integer not null check (frequency_value > 0),
  frequency_unit frequency_unit not null,
  next_due_date date generated always as (
    (last_meeting_date + (frequency_value || ' ' || frequency_unit)::interval)::date
  ) stored,
  notified_current_cycle boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_contacts_user on contacts(user_id);
create index idx_contacts_next_due on contacts(next_due_date);

-- ============ RENDEZ-VOUS ============
create table rendezvous (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  appointment_at timestamptz not null,
  status rdv_status not null default 'planifie',
  reminder_sent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_rdv_user on rendezvous(user_id);
create index idx_rdv_appointment_at on rendezvous(appointment_at);
create index idx_rdv_status_reminder on rendezvous(status, reminder_sent);

-- ============ LIAISON CONTACTS <-> RENDEZ-VOUS (many-to-many) ============
create table contact_rendezvous (
  contact_id uuid not null references contacts(id) on delete cascade,
  rendezvous_id uuid not null references rendezvous(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (contact_id, rendezvous_id)
);

create index idx_cr_user on contact_rendezvous(user_id);

-- ============ PHOTOS (galerie contacts et rendez-vous) ============
create table photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid references contacts(id) on delete cascade,
  rendezvous_id uuid references rendezvous(id) on delete cascade,
  storage_path text not null,
  created_at timestamptz not null default now(),
  check (contact_id is not null or rendezvous_id is not null)
);

create index idx_photos_user on photos(user_id);

-- ============ ROW LEVEL SECURITY — obligatoire, table par table ============
alter table contacts enable row level security;
alter table rendezvous enable row level security;
alter table contact_rendezvous enable row level security;
alter table photos enable row level security;

create policy "contacts_own" on contacts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "rdv_own" on rendezvous
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "cr_own" on contact_rendezvous
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "photos_own" on photos
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============ TRIGGER : validation d'un rdv -> mise à jour des contacts ============
create or replace function fn_update_contacts_on_rdv_validated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'valide' and old.status is distinct from 'valide' then
    update contacts
    set last_meeting_date = new.appointment_at::date,
        notified_current_cycle = false,
        updated_at = now()
    where id in (
      select contact_id from contact_rendezvous where rendezvous_id = new.id
    );
  end if;
  return new;
end;
$$;

create trigger trg_rdv_validated
after update on rendezvous
for each row
execute function fn_update_contacts_on_rdv_validated();

-- ============ TÂCHES PLANIFIÉES (pg_cron) ============
-- Vérification quotidienne des échéances de contacts (8h)
select cron.schedule(
  'daily-contact-due-check',
  '0 8 * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/notify-due-contacts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <service_role_key>',
      'Content-Type', 'application/json'
    )
  );
  $$
);

-- Vérification des rdv à venir toutes les 10 minutes (rappel 30 min avant)
select cron.schedule(
  'rdv-reminder-check',
  '*/10 * * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/notify-upcoming-rdv',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <service_role_key>',
      'Content-Type', 'application/json'
    )
  );
  $$
);
```

**Notes d'implémentation :**
- Les Edge Functions appelées par `pg_cron` utilisent la `service_role_key` (jamais exposée côté client) pour contourner volontairement la RLS, puisqu'elles doivent traiter les données de tous les utilisateurs.
- `contact_rendezvous` porte son propre `user_id` (plutôt que de le déduire par jointure) afin de simplifier et d'accélérer la policy RLS.
- L'affichage du statut "en retard" côté frontend se fait en comparant `next_due_date` à la date du jour au moment du rendu — cette comparaison n'est pas stockée en base, elle est recalculée à chaque affichage.

---

## 6. Cas d'usage typiques

- Un utilisateur veut revoir son meilleur ami tous les 2 mois. Il ajoute son contact avec une fréquence de 60 jours.
- Il reçoit un rappel automatique (push ou email) pour organiser un moment avec lui.
- Il ajoute un rendez-vous avec plusieurs amis et ajoute une photo prise lors de la rencontre.
- Il marque le rendez-vous comme validé : la date de dernière rencontre du contact se met à jour automatiquement, et son échéance est recalculée.
- Il peut retrouver plus tard les photos et les détails associés à chaque relation dans l'historique.

---

## 7. Valeur ajoutée

SeeYourB se distingue par son approche pratique et relationnelle :
- elle ne se limite pas à une simple liste de contacts,
- elle aide activement à maintenir les liens sociaux,
- elle automatise la mémoire des rendez-vous et des recontacts,
- elle favorise la régularité dans les relations personnelles et professionnelles,
- elle est accessible depuis n'importe quel navigateur, installable comme une app, sans passer par les stores mobiles,
- chaque utilisateur bénéficie d'un espace privé et sécurisé, indépendant des autres.

En résumé, c'est une application de gestion des liens humains, pensée pour aider à garder des contacts, organiser des retrouvailles et ne plus oublier les personnes importantes — accessible à tous, sans friction d'installation ni coût d'infrastructure.
