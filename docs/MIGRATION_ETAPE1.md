# SeeU : mise à jour de la base Supabase (étape 1)

Ce guide met à jour le projet Supabase qui tourne déjà, sans rien effacer.
La mise à jour ajoute les signalements, les bannissements et les statistiques admin,
les profils publics partageables, la ville de résidence et les suggestions en voyage.

- **Durée :** une quinzaine de minutes.
- **Projet concerné :** celui dont l'adresse est `https://klqzmegiydmwtmxfguvl.supabase.co`
  (Project Settings → General → Reference ID `klqzmegiydmwtmxfguvl`).
- **Données :** rien n'est supprimé. Les anciennes versions de l'app continuent de marcher
  après la mise à jour. La nouvelle version de l'app, elle, a besoin de cette mise à jour.
- **Sans risque à relancer :** chaque fichier peut être exécuté une deuxième fois sans dégât.
  Si une exécution s'arrête au milieu, corrige ce qui bloque et relance le même fichier.

Les fichiers cités sont dans le dossier `supabase/` du dépôt (branche `flutter`), ou dans
le zip que je t'ai envoyé, qui reprend la même arborescence.

## 1. Voir ce qui manque

Dashboard → **SQL Editor** → **New query**, colle cette requête puis **Run** :

```sql
select m.migration, case when m.applied then 'déjà appliquée' else 'À APPLIQUER' end as etat
from (values
  ('20261120000008_profiles_places_friends', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'avatar_path')),
  ('20261120000009_no_emails',               exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'avatars_select_own')),
  ('20261121000010_event_status',            exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'events' and column_name = 'check_sent')),
  ('20261122000011_no_reminder',             exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid where t.typname = 'frequency_unit' and e.enumlabel = 'never')),
  ('20261123000012_moderation',              to_regclass('public.reports') is not null),
  ('20261123000013_public_profiles',         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'public_profile')),
  ('20261123000014_travel_hints',            exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'contacts' and column_name = 'lat'))
) as m(migration, applied)
order by m.migration;
```

Tu obtiens 7 lignes. Normalement, 0012, 0013 et 0014 sont « À APPLIQUER », et sans doute
aussi 0010 et 0011. **Si 0008 ou 0009 est « À APPLIQUER », arrête-toi et préviens-moi :**
la base est alors plus ancienne que prévu.

## 2. Appliquer les migrations manquantes

### Option A : SQL Editor (le plus simple)

Pour chaque ligne « À APPLIQUER », **dans l'ordre du tableau** :

1. SQL Editor → **New query**.
2. Ouvre le fichier `supabase/migrations/<nom de la ligne>.sql` et colle **tout** son contenu.
3. **Run**. Le résultat attendu est « Success. No rows returned ».

Un fichier par requête : ne colle pas plusieurs fichiers ensemble.
Si une erreur s'affiche, envoie-moi le message exact.

### Option B : CLI Supabase (si tu l'as déjà utilisée pour ce projet)

Depuis le dossier qui contient `supabase/` :

```sh
supabase login
supabase link --project-ref klqzmegiydmwtmxfguvl
supabase migration list     # colonne Remote : ce que la CLI croit déjà appliqué
supabase db push            # liste les migrations à envoyer, puis demande confirmation
```

Avant de confirmer, compare la liste proposée avec le tableau de l'étape 1.
Si elle contient des migrations déjà appliquées (par exemple `20261115000001_init`, parce que
l'ancien déploiement avait été collé dans le SQL Editor), réponds **non**. Marque-les ensuite
comme appliquées, une version par migration déjà présente, puis relance `supabase db push` :

```sh
supabase migration repair --status applied 20261115000001 20261115000002   # etc.
```

## 3. Vérifier

Dans le SQL Editor :

```sql
select
  (select array_to_string(rolconfig, ', ') from pg_roles where rolname = 'authenticator') as hook_bannissement,
  (select string_agg(jobname, ', ' order by jobname) from cron.job
    where jobname in ('seeu-event-checks', 'seeu-purge-sessions', 'seeu-travel-hints')) as nouvelles_taches,
  public.get_public_profile('personne_qui_nexiste_pas') is null as rpc_publique_ok;
```

| Colonne | Résultat attendu |
| --- | --- |
| `hook_bannissement` | contient `pgrst.db_pre_request=public.seeu_pre_request` |
| `nouvelles_taches` | `seeu-event-checks, seeu-purge-sessions, seeu-travel-hints` |
| `rpc_publique_ok` | `true` |

Si `hook_bannissement` ne contient pas `seeu_pre_request`, exécute ceci puis revérifie :

```sql
alter role authenticator set pgrst.db_pre_request = 'public.seeu_pre_request';
notify pgrst, 'reload config';
```

## 4. Redéployer la fonction `dispatch`

Elle contient les textes des nouvelles notifications. Les secrets déjà en place
(`DISPATCH_SECRET`, `FCM_SERVICE_ACCOUNT`) ne changent pas.

Avec la CLI, depuis le dossier qui contient `supabase/` :

```sh
supabase functions deploy dispatch --no-verify-jwt --project-ref klqzmegiydmwtmxfguvl
```

Sans la CLI : Dashboard → **Edge Functions** → `dispatch` → onglet du code, si ton dashboard
permet de l'éditer. Remplace le contenu de `templates.ts` par celui de
`supabase/functions/dispatch/templates.ts`, puis déploie. La vérification du JWT doit rester
**désactivée** pour cette fonction, sinon plus aucune notification ne part.

Contrôle : Edge Functions → `dispatch` → **Logs**. La base l'appelle chaque minute, et
aucune erreur ne doit apparaître.

## 5. Nommer le premier admin

Remplace `PSEUDO_SEEU` par le pseudo de l'app, sans le @ :

```sql
insert into public.admins (user_id, note)
select id, 'premier admin' from public.profiles where username = 'PSEUDO_SEEU';

select p.username from public.admins a join public.profiles p on p.id = a.user_id;
```

La deuxième requête doit afficher le pseudo. Personne d'autre n'a accès à cette table.

## 6. En cas de problème

- **Toutes les requêtes de l'app échouent juste après la migration :** retire le contrôle des
  comptes bannis, puis préviens-moi.
  ```sql
  alter role authenticator reset pgrst.db_pre_request;
  notify pgrst, 'reload config';
  ```
- **Une migration affiche une erreur :** envoie-moi le message. Tu peux relancer le fichier
  une fois le problème réglé.
- Il n'y a rien d'autre à annuler : les autres changements ne font qu'ajouter des colonnes,
  des tables et des fonctions.

## Récapitulatif

- [ ] 1. Requête de détection lancée
- [ ] 2. Migrations « À APPLIQUER » exécutées dans l'ordre
- [ ] 3. Les trois vérifications sont bonnes
- [ ] 4. `dispatch` redéployée, logs sans erreur
- [ ] 5. Premier admin ajouté
- [ ] Prévenir que c'est fait : la nouvelle version de l'app peut alors être installée
