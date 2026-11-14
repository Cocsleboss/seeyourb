-- =====================================================================
--  SeeYourB — requêtes de consultation (lecture seule, rien n'est modifié)
--
--  Supabase → SQL Editor. L'éditeur n'affiche que le résultat de la
--  DERNIÈRE requête : sélectionne UNE requête à la fois (surligne-la)
--  puis clique "Run" (le bouton exécute uniquement la sélection).
--  Dans le SQL Editor tu es "postgres" : la RLS ne te bloque pas,
--  tu vois les données de tous les utilisateurs.
-- =====================================================================

-- 1) VUE D'ENSEMBLE : nombre de lignes par table
select 'profiles' as "table", count(*) as lignes from public.profiles
union all select 'contacts', count(*) from public.contacts
union all select 'rendezvous', count(*) from public.rendezvous
union all select 'contact_rendezvous', count(*) from public.contact_rendezvous
union all select 'photos', count(*) from public.photos
union all select 'push_subscriptions', count(*) from public.push_subscriptions
union all select 'notifications', count(*) from public.notifications
order by 1;

-- 2) PROFILS : un par utilisateur, avec ses préférences
select id, email, display_name, timezone,
       notify_push, notify_email, daily_hour, due_lead_days,
       rdv_reminder_minutes, last_digest_date, created_at
from public.profiles
order by created_at desc;

-- 3) COMPTES AUTH vs PROFILS (repère un compte sans profil)
select u.id, u.email, u.created_at, u.last_sign_in_at,
       (p.id is not null) as a_un_profil
from auth.users u
left join public.profiles p on p.id = u.id
order by u.created_at desc;

-- 4) RÉSUMÉ PAR UTILISATEUR : contacts, rdv, photos, notifs push
select p.email, p.display_name,
       (select count(*) from public.contacts c where c.user_id = p.id)           as contacts,
       (select count(*) from public.rendezvous r where r.user_id = p.id)         as rendezvous,
       (select count(*) from public.photos ph where ph.user_id = p.id)           as photos,
       (select count(*) from public.push_subscriptions s where s.user_id = p.id) as appareils_push,
       (select count(*) from public.notifications n where n.user_id = p.id)      as notifications
from public.profiles p
order by p.created_at desc;

-- 5) CONTACTS (avec prochaine échéance)
select c.name, p.email as proprietaire, c.category, c.phone, c.email,
       c.last_meeting_date, c.frequency_value, c.frequency_unit,
       c.next_due_date, c.snooze_until, c.created_at
from public.contacts c
join public.profiles p on p.id = c.user_id
order by c.next_due_date;

-- 6) RENDEZ-VOUS
select r.title, p.email as proprietaire, r.appointment_at, r.status,
       r.location, r.reminder_sent, r.followup_sent, r.created_at
from public.rendezvous r
join public.profiles p on p.id = r.user_id
order by r.appointment_at desc;

-- 7) LIENS CONTACT <-> RENDEZ-VOUS
select c.name as contact, r.title as rendezvous, r.appointment_at, r.status
from public.contact_rendezvous cr
join public.contacts c   on c.id = cr.contact_id
join public.rendezvous r on r.id = cr.rendezvous_id
order by r.appointment_at desc;

-- 8) PHOTOS
select ph.id, p.email as proprietaire, c.name as contact,
       ph.storage_path, ph.caption, ph.created_at
from public.photos ph
join public.profiles p on p.id = ph.user_id
left join public.contacts c on c.id = ph.contact_id
order by ph.created_at desc;

-- 9) APPAREILS PUSH (abonnements aux notifications)
select s.id, p.email as proprietaire, s.user_agent, s.created_at
from public.push_subscriptions s
join public.profiles p on p.id = s.user_id
order by s.created_at desc;

-- 10) NOTIFICATIONS (select * : colonnes non détaillées ici)
select * from public.notifications
order by created_at desc
limit 100;

-- 11) CONTACTS EN RETARD (échéance dépassée)
select c.name, p.email as proprietaire, c.next_due_date,
       (current_date - c.next_due_date) as jours_de_retard
from public.contacts c
join public.profiles p on p.id = c.user_id
where c.next_due_date < current_date
order by jours_de_retard desc;

-- 12) LISTE DE TOUTES LES TABLES du schéma public + taille approximative
select relname as "table", n_live_tup as lignes_estimees
from pg_stat_user_tables
where schemaname = 'public'
order by relname;
