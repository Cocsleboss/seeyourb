# SeeYourB

**Ne plus oublier les personnes qu'on aimerait revoir.**

SeeYourB est une application web progressive (PWA) : on l'ouvre dans le navigateur, on l'ajoute à l'écran d'accueil de son iPhone ou Android, et elle se comporte comme une vraie app (icône, plein écran, notifications push).

Chaque utilisateur crée un compte et dispose d'un espace strictement privé (isolation au niveau base de données, *Row Level Security*).

## Fonctionnalités

- **Contacts** : nom, photo, catégorie (Famille, Amis, Pro…), téléphone, email, anniversaire, notes, date de dernière rencontre et **fréquence souhaitée** (ex. tous les 2 mois).
- **Import des contacts du téléphone** : sélecteur natif (Chrome Android, Safari iOS) ou fichier vCard (.vcf) pour tout importer d'un coup ; l'app passe ensuite chaque personne en revue (fréquence, catégorie, ajouter / ignorer) et écarte celles déjà présentes.
- **Échéances automatiques** : l'app calcule quand revoir chaque personne et affiche « en retard de 3 jours », « à revoir dans 2 semaines »… Un contact en retard reste en tête de liste tant qu'aucune rencontre n'est enregistrée.
- **Rendez-vous** : un ou plusieurs contacts, date, heure, lieu, notes, photos. Cycle de vie : *planifié* → *a eu lieu* (met à jour automatiquement la date de dernière rencontre des participants) ou *annulé*.
- **Actions rapides** : « Vu aujourd'hui » (enregistre une rencontre passée en 2 secondes), « Reporter » (repousse le rappel), « Planifier ».
- **Historique** des rencontres, **galerie photo** par contact et par rendez-vous.
- **Notifications** : push (iPhone, Android, desktop) avec repli email :
  - récapitulatif quotidien des contacts à recontacter (heure au choix), 
  - rappel avant chaque rendez-vous (30 min par défaut, réglable),
  - « Ce rendez-vous a-t-il eu lieu ? » quelques heures après un rendez-vous non confirmé,
  - anniversaires.
- **Ajout au calendrier** (.ics), **export JSON** de ses données, suppression de compte, mode sombre, fonctionnement partiel hors ligne.

## Stack

Next.js 15 (App Router) · TypeScript · Tailwind CSS · Supabase (Postgres, Auth, Storage, pg_cron) · Web Push (VAPID) · Vercel. Coût : 0 € dans les limites des offres gratuites.

---

## Mise en ligne ce soir (≈ 20 minutes)

Il vous faut deux comptes gratuits : [supabase.com](https://supabase.com) et [vercel.com](https://vercel.com). Node.js 20+ sur votre Mac pour générer les clés (déjà installé si `node -v` répond).

### 1. Créer le projet Supabase

1. Supabase → **New project** (région *West EU (Paris)* ou *Frankfurt*). Notez le mot de passe de la base (il ne sert pas à l'app, mais gardez-le).
2. Attendez que le projet soit prêt (1-2 min).
3. **SQL Editor** → **New query** → collez tout le contenu de [`supabase/schema.sql`](supabase/schema.sql) → **Run**. Il doit afficher *Success*. Ce script crée les tables, la sécurité (RLS), les triggers et le bucket photos. Il peut être relancé sans risque.
4. **Authentication → Sign In / Providers → Email** : désactivez **Confirm email** (recommandé ce soir : sinon chaque inscription attend un email, et Supabase limite à quelques emails par heure sans serveur SMTP personnalisé). Enregistrez.
5. **Project Settings → API** : copiez
   - *Project URL* → `NEXT_PUBLIC_SUPABASE_URL`
   - *anon public* → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - *service_role* (cliquez *Reveal*) → `SUPABASE_SERVICE_ROLE_KEY` — **secret, jamais dans le code ni côté client**.

### 2. Générer les clés de notification

Dans le dossier du projet :

```bash
npm install
npm run vapid            # affiche NEXT_PUBLIC_VAPID_PUBLIC_KEY et VAPID_PRIVATE_KEY
openssl rand -hex 32     # → CRON_SECRET (un secret partagé entre Supabase et l'app)
```

### 3. Déployer sur Vercel

**Option A — sans GitHub (le plus rapide)**

```bash
npm i -g vercel
vercel login
vercel --prod
```

Acceptez les valeurs par défaut (projet Next.js détecté). Le premier déploiement échouera peut-être au démarrage tant que les variables ne sont pas définies : ajoutez-les dans **Vercel → votre projet → Settings → Environment Variables** (environnement *Production*), puis relancez `vercel --prod`.

**Option B — avec GitHub (déploiement continu)**

```bash
git add .
git commit -m "SeeYourB"
# créez un dépôt sur github.com puis :
git remote add origin https://github.com/VOTRE-COMPTE/seeyourb.git
git push -u origin main
```

Vercel → **Add New Project** → importez le dépôt → ajoutez les variables d'environnement → **Deploy**.

**Variables d'environnement (Vercel → Settings → Environment Variables)**

| Variable | Valeur | Obligatoire |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL Supabase | oui |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | clé *anon public* | oui |
| `SUPABASE_SERVICE_ROLE_KEY` | clé *service_role* | oui |
| `NEXT_PUBLIC_VAPID_PUBLIC_KEY` | sortie de `npm run vapid` | oui (push) |
| `VAPID_PRIVATE_KEY` | sortie de `npm run vapid` | oui (push) |
| `VAPID_SUBJECT` | `mailto:votre@email.com` | oui (push) |
| `CRON_SECRET` | sortie de `openssl rand -hex 32` | oui (rappels) |
| `NEXT_PUBLIC_APP_URL` | `https://votre-app.vercel.app` (sans `/` final) | conseillé |
| `BREVO_API_KEY` | clé API Brevo | optionnel (email) |
| `RESEND_API_KEY` | clé API Resend | optionnel (email) |
| `EMAIL_FROM` | `SeeYourB <votre@email.com>` | si email |

Après chaque modification des variables, **redéployez** (Vercel → Deployments → ⋯ → Redeploy, ou `vercel --prod`).

### 4. Autoriser l'URL de l'app dans Supabase

**Authentication → URL Configuration** :
- *Site URL* : `https://votre-app.vercel.app`
- *Redirect URLs* : ajoutez `https://votre-app.vercel.app/auth/callback` (et `http://localhost:3000/auth/callback` pour le développement).

Sans cela, les liens magiques et la réinitialisation de mot de passe ne reviendront pas vers l'app.

### 5. Activer les rappels automatiques (cron)

Supabase → **SQL Editor** → collez [`supabase/cron.sql`](supabase/cron.sql) en remplaçant :
- `VOTRE-APP.vercel.app` par votre domaine Vercel,
- `VOTRE_CRON_SECRET` par la valeur de `CRON_SECRET`.

→ **Run**. Toutes les 10 minutes, Supabase appelle `https://votre-app/api/cron/tick`, qui envoie les rappels dus. Vérification :

```sql
select jobname, schedule, active from cron.job;
select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;
select status_code, content::text from net._http_response order by id desc limit 5;   -- doit afficher 200 et {"ok":true,...}
```

> Alternative sans pg_cron : créez une tâche gratuite sur [cron-job.org](https://cron-job.org) qui appelle `https://votre-app/api/cron/tick` toutes les 10 minutes avec l'en-tête `Authorization: Bearer VOTRE_CRON_SECRET`. Le fichier `vercel.json` ajoute aussi un appel quotidien de secours (Vercel Cron, 07:00 UTC) ; il utilise automatiquement `CRON_SECRET`.

### 6. Email de secours (optionnel, 5 minutes)

Si un utilisateur n'a pas activé les notifications push, l'app lui envoie les rappels par email. Deux fournisseurs gratuits :

- **Brevo** (recommandé ce soir) : créez un compte sur [brevo.com](https://www.brevo.com), **Senders & IP → Add a sender** et validez votre adresse email, puis **SMTP & API → API Keys → Generate**. Variables : `BREVO_API_KEY` et `EMAIL_FROM="SeeYourB <votre@email.com>"` (300 emails/jour).
- **Resend** : [resend.com](https://resend.com) → API key. Attention, sans domaine vérifié, Resend n'envoie qu'à votre propre adresse. Variables : `RESEND_API_KEY` et `EMAIL_FROM`.

Redéployez après avoir ajouté les variables.

### 7. Sur l'iPhone

1. Ouvrez `https://votre-app.vercel.app` dans **Safari**, créez votre compte.
2. Touchez **Partager** (le carré avec la flèche) → **Sur l'écran d'accueil** → **Ajouter**.
3. Ouvrez SeeYourB **depuis l'icône** (indispensable pour les notifications sur iOS, version 16.4 minimum).
4. **Réglages → Notifications → Activer**, puis **Envoyer une notification de test**.

Sur Android (Chrome) : menu ⋮ → **Installer l'application** (ou acceptez la bannière), puis activez les notifications dans Réglages.

---

## Développement local

```bash
cp .env.example .env.local     # remplissez les valeurs
npm install
npm run dev                    # http://localhost:3000
npm run typecheck              # vérification TypeScript
npm run build                  # build de production
```

Le service worker et les notifications push fonctionnent sur `http://localhost` (contexte sécurisé). Pour tester le cron localement :

```bash
curl -H "Authorization: Bearer VOTRE_CRON_SECRET" http://localhost:3000/api/cron/tick
```

## Comment ça marche

- **Échéance** : `next_due_date` est une colonne calculée en base (`last_meeting_date` + fréquence). « En retard » = `next_due_date` < aujourd'hui, recalculé à l'affichage. Un **report** (`snooze_until`) décale le rappel sans changer la fréquence.
- **Validation d'un rendez-vous** : un trigger SQL met `last_meeting_date` = date du rendez-vous (jamais en arrière) pour chaque participant, ce qui recalcule l'échéance et réarme la notification du cycle. « Vu aujourd'hui » crée simplement un rendez-vous déjà validé.
- **Notifications** : `/api/cron/tick` (appelé toutes les 10 min) traite trois choses : rappels avant rendez-vous, suivi après rendez-vous non confirmé, récapitulatif quotidien par utilisateur (à l'heure choisie, dans son fuseau horaire) + anniversaires. Chaque envoi est d'abord « réclamé » en base (flags `reminder_sent`, `followup_sent`, `last_digest_date`, `notified_current_cycle`) : aucun doublon même si deux exécutions se chevauchent. Envoi push sur tous les appareils abonnés ; si aucun n'accepte, email de secours.
- **Sécurité** : RLS activée sur chaque table et sur le bucket de stockage (`<user_id>/…`). Auth, mots de passe et sessions gérés par Supabase. La clé `service_role` n'est utilisée que dans les routes serveur (`/api/cron/tick`, `/api/push/*`, `/api/account/delete`), jamais exposée au navigateur. Le cron est protégé par `CRON_SECRET`.

## Importer les contacts du téléphone

Contacts → icône carnet (en haut) ou Réglages → Données → *Importer des contacts du téléphone*. Trois étapes : choisir la source, passer chaque contact en revue (fréquence, catégorie, dernière rencontre, **Ajouter** / **Ignorer**, ou « les restants d'un coup »), confirmer. Rien n'est enregistré avant la confirmation ; les contacts déjà présents (même nom, numéro ou email) sont écartés.

- **Sélecteur natif** (`navigator.contacts`, API Contact Picker) : disponible dans Chrome sur Android et Safari sur iPhone. Le bouton n'apparaît que si le navigateur le propose ; il peut manquer dans l'app installée sur l'écran d'accueil iOS → ouvrir SeeYourB dans Safari pour cette opération, ou passer par un fichier.
- **Fichier .vcf** (vCard 2.1 / 3.0 / 4.0, un ou plusieurs fichiers) : marche partout et permet d'importer tout le carnet. iPhone : icloud.com → Contacts → tout sélectionner → ⚙ → *Exporter vCard* (ou, fiche par fiche, *Partager le contact* → *Enregistrer dans Fichiers*). Android : app Contacts → *Exporter*. Google : contacts.google.com → *Exporter* → vCard. Champs repris : nom, téléphone, email, anniversaire, organisation / titre / note. Les photos ne sont pas importées.
- Une PWA n'a jamais d'accès permanent au carnet d'adresses : il s'agit d'un import ponctuel, pas d'une synchronisation en continu. Code : `lib/contact-import.ts`, `lib/vcard.ts`, `app/(app)/contacts/import/`.

## Structure du projet

```
app/
  (app)/              pages protégées : accueil, contacts, rdv, historique, réglages
  login/, auth/       connexion, callback OAuth/magic link, réinitialisation
  api/                cron, push, ics, export, suppression de compte, diagnostic
components/           UI partagée (ui/), contacts/, rdv/, settings/, PWA
lib/                  types, accès données (data.ts), dates, photos, notifications (serveur)
supabase/             schema.sql (à exécuter une fois), cron.sql
public/sw.js          service worker (push + cache)
scripts/              génération des icônes et des clés VAPID
```

## Dépannage

| Symptôme | Cause probable / solution |
|---|---|
| Page de login : « Configuration manquante » | Variables `NEXT_PUBLIC_SUPABASE_*` absentes sur Vercel → ajoutez-les puis redéployez. |
| Inscription : « Vérifiez votre boîte mail » mais rien n'arrive | *Confirm email* est activé dans Supabase et le quota d'emails gratuit est atteint. Désactivez *Confirm email* (étape 1.4) ou configurez un SMTP dans Supabase → Authentication → SMTP Settings. |
| Pas de bouton « Activer » les notifications sur iPhone | L'app doit être ouverte **depuis l'icône de l'écran d'accueil** (iOS 16.4+), pas depuis Safari. |
| Pas de bouton « Choisir dans mes contacts » | Le navigateur ne propose pas l'API Contact Picker (desktop, Firefox, app iOS installée sur l'écran d'accueil…). Ouvrez l'app dans Safari (iPhone) ou Chrome (Android), ou importez un fichier .vcf. |
| Notification de test : « Aucun canal disponible » | Push : aucun appareil abonné ou clés VAPID absentes (voir Réglages → Diagnostic). Email : configurez Brevo/Resend. |
| Les rappels n'arrivent jamais | Le cron n'est pas installé : exécutez `supabase/cron.sql` avec la bonne URL et le bon secret, puis vérifiez `cron.job_run_details` et `net._http_response` (doit renvoyer 200). |
| Upload de photo refusé | Fichier > 10 Mo ou bucket non créé : relancez `schema.sql`. |
| Erreur « row-level security » | Un utilisateur tente d'accéder à des données qui ne sont pas les siennes : comportement attendu. |

## Scripts

- `npm run dev` / `npm run build` / `npm run start`
- `npm run typecheck` — TypeScript strict
- `npm run vapid` — génère les clés Web Push
- `npm run icons` — régénère les icônes PNG à partir du logo vectoriel (`scripts/gen-icons.mjs`)
