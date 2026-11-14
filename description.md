# SeeU — Description fonctionnelle complète

Nov 14, 2026 · @dieu

## 1. Le concept

SeeU est une app mobile qui t'empêche de perdre de vue les gens qui comptent. Pour chaque personne, tu choisis à quelle fréquence tu veux la revoir (par exemple « tous les 2 mois »). L'app calcule la prochaine échéance à partir de la dernière rencontre, te prévient quand elle approche, et t'aide à planifier un rendez-vous.

La boucle d'usage tient en quatre temps :

1. J'ajoute un contact avec une fréquence et la date de notre dernière rencontre.
2. L'app me signale quand il est temps de le revoir (accueil + notification).
3. Je planifie un rendez-vous, ou je note simplement « on s'est vus ».
4. La rencontre validée remet le compteur à zéro, et le cycle repart.

Quatre principes à garder en tête en la reconstruisant :

- **Privé par défaut.** Chaque utilisateur a son propre carnet de contacts, invisible des autres. Un contact est une fiche personnelle, pas un compte.
- **Social en option.** Deux utilisateurs peuvent devenir « amis SeeU ». Cela débloque le partage de rendez-vous, une galerie photo commune et un signal « envie de te voir ».
- **Pensée pour une main, sur téléphone.** Barre d'onglets en bas, gros boutons, panneaux qui montent du bas de l'écran pour les actions rapides, thème clair et sombre.
- **Zéro culpabilité.** Le ton est chaleureux, au vouvoiement : « Tout est à jour 🎉 », « Pensez à lui souhaiter ». Un retard s'affiche en rouge, mais on peut toujours reporter.

## 2. Les objets manipulés

L'app repose sur sept objets. Les champs marqués \* sont obligatoires.

### Profil (l'utilisateur lui-même)

| Champ | Détail |
| --- | --- |
| Email \* | Identifiant de connexion. Jamais montré aux autres avant qu'ils soient amis. |
| Nom affiché \* | Prénom ou nom, 60 caractères max. C'est ce que voient les amis. |
| Nom d'utilisateur \* | Unique, affiché avec un « @ » devant. 3 à 20 caractères : minuscules, chiffres, point, tiret bas. Doit commencer par une lettre ou un chiffre. |
| Date de naissance | Facultative. Visible par les amis uniquement. |
| Fuseau horaire | Détecté automatiquement sur l'appareil, sert à l'heure des rappels. |
| Préférences de rappel | Push oui/non, email oui/non, heure du récap quotidien (8h par défaut), délai de prévenance (jour J par défaut), rappel avant rendez-vous (30 min par défaut). |

### Contact (une fiche privée de mon carnet)

| Champ | Détail |
| --- | --- |
| Nom \* | 120 caractères max. |
| Photo | Une photo de profil. Sans photo : avatar coloré avec les initiales. |
| Catégorie | Suggestions : Famille, Amis, Pro, Autre. Saisie libre possible (40 caractères). |
| Dernière rencontre \* | Une date, jamais dans le futur. Aujourd'hui par défaut. |
| Fréquence \* | Un nombre (1 minimum) + une unité : jours, semaines, mois, ans. « 1 mois » par défaut. |
| Prochaine échéance | Calculée : dernière rencontre + fréquence. Jamais saisie à la main. |
| Report | Date facultative qui repousse l'échéance sans toucher à la dernière rencontre. |
| À voir bientôt | Marqueur oui/non posé à la main. S'efface tout seul à la prochaine rencontre. |
| Téléphone, email | Facultatifs. Cliquables depuis la fiche (appel, mail). |
| Anniversaire | Date facultative. |
| Notes | Texte libre. |
| Ami associé | Lien facultatif vers le compte d'un ami SeeU (voir Amis). |

### Rendez-vous

| Champ | Détail |
| --- | --- |
| Participants \* | Un ou plusieurs de mes contacts. |
| Date et heure \* | Peut être passée (on enregistre alors une rencontre déjà faite). |
| Titre | Facultatif, 120 caractères. Sans titre, l'app affiche « Avec Marie, Paul ». |
| Lieu | Facultatif, 200 caractères, texte libre. |
| Notes | Facultatives. Toujours privées, même si le rendez-vous est partagé. |
| Statut | Planifié, A eu lieu, ou Annulé. |
| Photos | Autant qu'on veut, ajoutées après création. |

### Photo

Une image rattachée soit à un contact (sa galerie), soit à un rendez-vous. Elle appartient à celui qui l'a ajoutée : lui seul peut la supprimer.

### Amitié

Un lien entre deux comptes. Il passe par l'état « en attente » (demande envoyée par l'un, reçue par l'autre) puis « acceptée ». Un refus ou une annulation supprime le lien.

### Invitation à un rendez-vous

La proposition d'un de mes rendez-vous à un ami. États : en attente, acceptée, refusée. Quand elle est acceptée, l'ami reçoit sa propre copie du rendez-vous, synchronisée avec la mienne.

### Notification

Chaque rappel envoyé est gardé en journal : type, titre, texte, lien vers l'écran concerné, canal utilisé (push, email, ou aucun), date.

## 3. Navigation générale

L'app a cinq onglets fixes en bas de l'écran, toujours visibles une fois connecté : **Accueil**, **Contacts**, **Amis**, **Historique**, **Réglages**. L'onglet actif prend la couleur de la marque, un bleu indigo.

Les autres écrans s'ouvrent par-dessus, avec une barre du haut portant un titre, une flèche retour à gauche et parfois une action à droite (crayon pour modifier, + pour ajouter).

| Écran | On y arrive depuis |
| --- | --- |
| Connexion / inscription | Ouverture de l'app sans session |
| Nouveau mot de passe | Lien reçu par email |
| Compléter le profil | Automatique si le compte n'a pas de nom d'utilisateur |
| Accueil | Onglet |
| Liste des contacts | Onglet |
| Fiche contact | Une ligne de contact, n'importe où |
| Nouveau contact / Modifier le contact | Bouton + de la liste, crayon de la fiche |
| Import de contacts | Icône carnet de la liste, ou Réglages |
| Nouveau rendez-vous / Modifier | Bouton flottant + de l'accueil, bouton « Planifier », crayon de la fiche |
| Fiche rendez-vous | Une ligne de rendez-vous, n'importe où, ou une notification |
| Amis | Onglet |
| Historique | Onglet |
| Réglages | Onglet, ou roue crantée en haut de l'accueil |
| Hors connexion | Automatique sans réseau |

Trois composants reviennent partout :

- **Panneau bas** : une feuille qui monte du bas de l'écran pour une action rapide (noter une rencontre, reporter, confirmer une suppression). On la ferme en tapant à côté.
- **Message éclair** : un bandeau bref qui confirme chaque action (« Contact supprimé ») ou signale une erreur.
- **État vide** : quand une liste est vide, une icône, un titre, une phrase d'explication et un bouton pour démarrer.

Pendant un chargement, les listes affichent des lignes grises animées. En cas d'erreur de chargement, une carte rouge affiche le message et un bouton « Réessayer ».

## 4. Les écrans, un par un

### 4.1 Connexion et inscription

Un seul écran, avec le logo, le nom SeeU et le slogan « Ne plus oublier les personnes qu'on aimerait revoir. ». Un sélecteur à deux positions bascule entre **Connexion** et **Inscription**.

- **Connexion** : email, mot de passe (avec un œil pour l'afficher), bouton « Se connecter ». Deux liens dessous : « Mot de passe oublié ? » et « Recevoir un lien magique par email ».
- **Inscription** : prénom (facultatif), nom d'utilisateur (obligatoire), email, mot de passe de 6 caractères minimum. Le bouton « Créer mon compte » reste grisé tant qu'un champ est invalide. Selon le cas, l'utilisateur entre directement dans l'app ou voit « Vérifiez votre boîte mail » et doit ouvrir le lien de confirmation.
- **Lien magique** : on saisit seulement son email et on reçoit un lien qui connecte sans mot de passe. Le compte est créé s'il n'existait pas.
- **Mot de passe oublié** : on saisit son email. Le message de confirmation est volontairement neutre (« Si un compte existe pour… ») pour ne pas révéler qui est inscrit.
- **Nouveau mot de passe** : écran ouvert par le lien reçu. Deux champs qui doivent être identiques, 6 caractères minimum. Si le lien est périmé : « Lien invalide ou expiré ».

Les erreurs s'affichent dans un encart rouge sous le formulaire, en français clair (« Un compte existe déjà avec cet email », identifiants incorrects, etc.).

**Le champ nom d'utilisateur** est réutilisé à trois endroits (inscription, compléter le profil, réglages). Il affiche un « @ » fixe à gauche et nettoie la saisie pendant la frappe : tout passe en minuscules, les accents et caractères interdits sont retirés. Environ un tiers de seconde après la dernière touche, il vérifie si le nom est libre et affiche un indicateur à droite : roue qui tourne, coche verte avec « @marie est disponible », ou croix rouge avec « Ce nom d'utilisateur est déjà pris. ».

### 4.2 Compléter le profil

Un compte sans nom d'utilisateur (créé par lien magique, par exemple) ne peut pas entrer dans l'app. À la place de n'importe quel écran, il voit « Complétez votre profil » : nom d'utilisateur (pré-rempli avec une suggestion tirée du prénom ou de l'email), nom affiché, date de naissance facultative, bouton « Continuer ». En bas : « Connecté avec… » et un lien pour se déconnecter.

### 4.3 Accueil

C'est le tableau de bord. De haut en bas :

1. **En-tête.** Une salutation selon l'heure, suivie du prénom et d'un 👋 : « Bonne nuit » avant 5h, « Bonjour » avant midi, « Bon après-midi » avant 18h, « Bonsoir » ensuite. Dessous, la date du jour (« Samedi 14 novembre »). À droite, une roue crantée vers les réglages.
2. **Bandeau notifications.** Tant que les notifications ne sont pas activées, un encart propose de le faire (« Activer les rappels »). On peut le fermer ; il revient 7 jours plus tard. Si elles sont bloquées dans le téléphone, il explique comment les réautoriser.
3. **Invitations reçues.** Une carte par rendez-vous proposé par un ami, avec « Refuser » et « Accepter » (détail en 4.10).
4. **Anniversaires du jour.** Une carte rose par contact concerné : « 🎂 C'est l'anniversaire de Marie ! », « 30 ans aujourd'hui · Pensez à lui souhaiter. ». Deux boutons : « Envoyer un message » (ouvre un SMS, seulement si le contact a un numéro) et « Planifier ».
5. **Trois compteurs** côte à côte : nombre de contacts, nombre en retard (en rouge s'il y en a), nombre de rendez-vous à venir. Les deux premiers mènent à la liste des contacts.
6. **À confirmer.** Les rendez-vous planifiés dont l'heure est passée depuis plus de 30 minutes. Chacun porte deux boutons : « A eu lieu » et « Annulé ».
7. **À recontacter.** Le cœur de l'écran, détaillé juste après.
8. **Anniversaires cette semaine.** Les anniversaires dans 1 à 7 jours : nom, puis « demain » ou « dans 4 jours · 31 ans ».
9. **Prochains rendez-vous.** Les 10 prochains, regroupés par jour (« Aujourd'hui », « Demain », « Mercredi 18 novembre »). S'il y en a plus : « + 3 autres rendez-vous planifiés ».
10. **Bouton flottant +** en bas à droite, au-dessus des onglets : nouveau rendez-vous.

**La liste « À recontacter ».** Elle contient les contacts en retard, ceux à revoir aujourd'hui, ceux à revoir dans les 7 jours, et ceux marqués « à voir bientôt ». Les marqués passent en tête, puis viennent les autres du plus en retard au moins urgent. Elle montre 8 contacts au maximum, avec un lien « Voir tout (12) » au-delà.

Chaque ligne montre l'avatar, le nom, « Vu le 12 sept. 2026 · tous les 2 mois », et une pastille colorée (ou une pastille violette « ★ Bientôt » pour les marqués). Sous chaque ligne, trois boutons :

- **Planifier** : ouvre le formulaire de rendez-vous avec ce contact déjà sélectionné.
- **Vu** : ouvre le panneau « on s'est vus ».
- **Reporter** : ouvre le panneau de report. Pour un contact présent uniquement parce qu'il est marqué « bientôt », ce bouton devient **Retirer**.

Un petit + dans le titre de la section ouvre le panneau « À voir bientôt » pour ajouter quelqu'un à la main. Quand la liste est vide, une carte verte dit « Tout est à jour 🎉 ».

**Premier lancement.** Sans aucun contact, l'accueil n'affiche qu'une carte « Bienvenue sur SeeU » avec le bouton « Ajouter mon premier contact ».

### 4.4 Les trois panneaux d'action rapide

- **« Vu Marie ».** Une date (aujourd'hui par défaut, jamais dans le futur), une note facultative, un bouton « Enregistrer la rencontre ». Cela crée un rendez-vous déjà validé à cette date, visible dans l'historique, et remet le compteur du contact à zéro.
- **« Reporter Marie ».** Quatre boutons : 3 jours, 1 semaine, 2 semaines, 1 mois. Ou une date précise à choisir, pas avant aujourd'hui. Confirmation : « Rappel reporté au 21 nov. 2026 ».
- **« À voir bientôt ».** Une recherche et la liste des contacts qui ne sont pas déjà dans « À recontacter ». Un tap ajoute le contact en tête de liste jusqu'à la prochaine rencontre.

### 4.5 Liste des contacts

Barre du haut : une icône carnet (import) et un bouton rond + (nouveau contact). Puis :

- Un champ de recherche qui filtre en direct sur le nom, la catégorie et les notes, sans tenir compte des accents ni des majuscules.
- Une rangée de pastilles : « Tous », puis une par catégorie réellement utilisée. Un tap filtre, un second tap retire le filtre.
- Une ligne de résumé « 24 contacts · 3 en retard » et, à droite, une bascule de tri **Échéance / Nom**.

Triée par échéance, la liste est découpée en trois groupes avec leur compteur : « En retard », « Cette semaine » (aujourd'hui et les 7 jours suivants), « À jour ». Triée par nom, c'est une seule liste alphabétique. Chaque ligne a la même forme que sur l'accueil et ouvre la fiche.

État vide : « Aucun contact pour l'instant » avec deux boutons, « Ajouter un contact » et « Importer depuis le téléphone ». Recherche sans résultat : « Aucun résultat ».

### 4.6 Fiche contact

Barre du haut : le nom, retour vers la liste, crayon pour modifier. Puis :

1. **En-tête centré** : grand avatar, nom, pastille de catégorie. Si le contact est associé à un ami : une pastille « Ami SeeU · rendez-vous et photos partageables ». Si son anniversaire tombe dans les 30 jours : « Anniversaire dans 12 jours (31 ans) ».
2. **Carte de suivi** : la pastille d'échéance en version longue (« En retard de 3 jours »), puis trois lignes : dernière rencontre, prochaine échéance (avec la mention « reportée » le cas échéant), fréquence (« tous les 2 mois »).
3. **Actions** : « Planifier un rendez-vous » (bouton principal), « Vu aujourd'hui », « Reporter », et « À voir bientôt » qui fonctionne comme un interrupteur.
4. **Informations** (si renseignées) : téléphone (lance l'appel), email (ouvre un mail), date de naissance, notes.
5. **Rendez-vous** avec ce contact, séparés en « À venir » et « Passés ». Les passés affichent leur statut.
6. **Galerie** : une grille de vignettes carrées, 3 par ligne, avec un bouton « Ajouter ». Elle réunit les photos ajoutées sur la fiche et celles de tous les rendez-vous avec ce contact, y compris celles postées par l'ami sur un rendez-vous partagé.
7. **Supprimer le contact**, en rouge tout en bas. Confirmation : « Ses rendez-vous et photos seront aussi supprimés. Cette action est définitive. »

**Visionneuse photo.** Un tap sur une vignette ouvre la photo en plein écran sur fond noir, avec des flèches précédente / suivante, une croix pour fermer, et une corbeille visible seulement sur ses propres photos. Pendant un envoi, une vignette grise animée tient la place de la photo.

### 4.7 Nouveau contact / Modifier le contact

Un seul formulaire pour les deux cas, dans cet ordre : photo (avatar + « Ajouter une photo », puis « Changer » et « Retirer »), nom, catégorie, dernière rencontre, fréquence, téléphone, email, anniversaire, notes.

- **Catégorie** : quatre pastilles (Famille, Amis, Pro, Autre) plus « Autre… » qui ouvre un champ libre. Retaper la pastille active la désélectionne.
- **Fréquence** : sept pastilles (1 semaine, 2 semaines, 1 mois, 2 mois, 3 mois, 6 mois, 1 an) plus « Personnalisée » qui ouvre un nombre et une unité.
- Sous la fréquence, un encart se met à jour en direct : « tous les 2 mois · Prochaine échéance : mardi 12 janvier 2027 ».
- **Validation** : « Le nom est obligatoire. », « La fréquence doit être d'au moins 1. », « Adresse email invalide. ». Les dates de rencontre et d'anniversaire ne peuvent pas être futures.

Après enregistrement, on arrive sur la fiche du contact, avec le message « Contact ajouté » ou « Contact mis à jour ».

### 4.8 Import de contacts

Un parcours en trois étapes, annoncées en sous-titre (« Étape 2 sur 3 »). Rien n'est enregistré avant la confirmation finale.

1. **Source.** L'utilisateur choisit des personnes dans le carnet d'adresses de son téléphone, ou ouvre un fichier de contacts exporté (format vCard). L'app en retient le nom, le téléphone, l'email, l'anniversaire et les notes. Elle écarte toute seule les personnes déjà présentes et les doublons, en comparant le nom, l'email, et les 9 derniers chiffres du numéro.
2. **Revue, une fiche à la fois.** Une barre de progression et « Contact 3 sur 40 ». Pour chaque personne : fréquence, catégorie, date de dernière rencontre, puis « Ignorer » ou « Ajouter ». Les choix faits sur une fiche pré-remplissent la suivante. La flèche retour revient à la fiche précédente. Un lien « Les 38 restants d'un coup… » propose « Tout ajouter » avec les réglages courants ou « Tout ignorer et terminer ».
3. **Confirmation.** La liste des contacts retenus, chacun retirable d'une croix, le nombre d'ignorés, puis « Importer 12 contacts » ou « Revoir la sélection ».

Dans la version actuelle, l'iPhone ne laisse pas l'app lire le carnet directement : l'écran affiche donc un guide pas à pas pour exporter ses contacts en fichier. Dans une app native, cette étape se résume à demander l'autorisation d'accéder aux contacts.

### 4.9 Nouveau rendez-vous / Modifier le rendez-vous

Le formulaire, dans l'ordre :

1. **Participants** (obligatoire). Les contacts choisis apparaissent en pastilles retirables d'une croix. Dessous, une recherche et une liste défilante de tous les contacts, chacun avec une case à cocher. Si on arrive depuis un bouton « Planifier », le contact est déjà coché. Sans aucun contact : « Créez d'abord un contact ».
2. **Date** et **heure**, pré-remplies au prochain quart d'heure.
3. **Titre** facultatif. Le texte d'exemple reprend les participants : « Avec Marie, Paul ».
4. **Lieu** et **notes**, facultatifs.
5. **Interrupteur « Ce rendez-vous a déjà eu lieu ».** Il se coche tout seul dès que la date choisie est passée, tant que l'utilisateur ne l'a pas touché. Coché, le rendez-vous est enregistré directement comme rencontre validée. Décoché, il est planifié.
6. **Interrupteur « Envoyer à Marie ».** Visible seulement si un participant est associé à un ami SeeU, et activé par défaut. Il envoie une invitation à l'ami dès l'enregistrement.

Le bouton final s'appelle « Planifier le rendez-vous » ou « Enregistrer la rencontre » selon l'interrupteur 5. Erreurs possibles : « Choisissez au moins un contact. » et « Indiquez la date et l'heure. ». Après enregistrement, on arrive sur la fiche du rendez-vous.

En modification, les deux interrupteurs disparaissent : le statut se change depuis la fiche, et le partage aussi.

### 4.10 Fiche rendez-vous

Barre du haut : le titre (ou « Avec Marie, Paul » ; au-delà de trois personnes, « Avec Marie, Paul et 2 autres »), retour, crayon. Puis :

1. **Bandeau ambre « Ce rendez-vous a-t-il eu lieu ? »** si le rendez-vous est planifié et que son heure est passée depuis plus de 30 minutes. Il porte les boutons « A eu lieu » et « Annulé ».
2. **Carte principale** : pastille de statut, jour relatif (« Demain »), date complète, heure, lieu (un tap ouvre l'app de cartes sur cette adresse), notes. Si le rendez-vous est partagé : « date, lieu, titre et statut sont les mêmes pour tous. Vos notes restent privées. »
3. **Participants** : chaque ligne ouvre la fiche du contact.
4. **Partage** : visible seulement si un participant est associé à un ami. Une ligne par ami, avec son état et le bouton correspondant (tableau ci-dessous).
5. **Boutons de statut**, puis « Ajouter au calendrier » pour un rendez-vous planifié. Ce bouton exporte un événement d'une heure vers le calendrier du téléphone, avec titre, lieu, participants et une alarme 30 minutes avant.
6. **Photos** : même grille et même visionneuse que sur la fiche contact. Sur un rendez-vous partagé, la section s'appelle « Photos partagées » et mélange les photos de tous les participants.
7. **Supprimer le rendez-vous.** Sur un rendez-vous partagé, la confirmation précise qu'il n'est supprimé que chez soi et que ses propres photos quittent la galerie commune.

| État du partage avec un ami | Texte affiché | Bouton |
| --- | --- | --- |
| Jamais invité | Ami SeeU · pas encore invité | Envoyer |
| Invitation en attente | Invitation envoyée · en attente | Annuler |
| Acceptée | A accepté · rendez-vous partagé | aucun |
| Refusée | A décliné l'invitation | Renvoyer |
| C'est lui qui m'a invité | Vous a proposé ce rendez-vous | aucun |

**Boutons de statut.** Un rendez-vous planifié propose « A eu lieu » (vert) et « Annulé ». Si on tape « A eu lieu » alors que la date est encore future, l'app demande confirmation : « Ce rendez-vous est prévu plus tard. Le marquer quand même comme ayant eu lieu ? ». Un rendez-vous validé ou annulé ne propose qu'un bouton discret : « Remettre en planifié ».

### 4.11 Amis

L'onglet social, sous-titré « Partagez rendez-vous et photos avec d'autres utilisateurs ». De haut en bas :

1. **Ajouter un ami.** Un champ de recherche avec « @ ». À partir de 2 caractères, l'app cherche les comptes dont le nom d'utilisateur commence par la saisie (8 résultats au plus), un tiers de seconde après la dernière touche. Chaque résultat montre le nom affiché, le @, et selon le cas un bouton « Ajouter », un bouton « Accepter » (il m'a déjà envoyé une demande), ou une simple mention « Demande envoyée » / « Déjà dans vos amis ». Sans résultat : un bouton « Envoyer le lien de l'app » pour inviter la personne.
2. **Mon nom d'utilisateur** et un bouton « Partager ». Il ouvre le partage du téléphone avec le texte « Ajoute-moi sur SeeU : @andrea » et un lien. Ce lien ouvre l'app sur cet onglet, recherche déjà remplie.
3. **Invitations à un rendez-vous** reçues (les mêmes cartes que sur l'accueil).
4. **Demandes reçues** : pour chacune, « Refuser » et « Accepter ».
5. **Mes amis (n)** : la liste des amis acceptés. Sous-titre : le @ et, s'il y en a un, « Associé au contact Marie ». Un ami sans contact associé affiche un bouton « Associer à un contact ».
6. **Demandes envoyées** : « En attente de sa réponse », avec « Annuler ».

**Une carte d'invitation à un rendez-vous** affiche « Marie vous propose un rendez-vous » (ou « partage une rencontre avec vous » si elle a déjà eu lieu), le titre, le jour et l'heure, le lieu, puis « Refuser » et « Accepter ». Accepter ajoute le rendez-vous chez moi et m'emmène sur sa fiche.

**Associer un ami à un contact.** Le panneau s'ouvre tout seul juste après avoir accepté une demande. Il explique : « Quel contact correspond à cet ami ? C'est sa période qui sera remise à zéro quand vous validerez un rendez-vous ensemble. ». Il propose « Créer un nouveau contact » (formulaire pré-rempli avec le nom et l'email de l'ami) ou de choisir dans ses contacts. Ceux qui ont le même email ou le même prénom montent en tête avec une étiquette « Suggéré ». Un ami ne peut être associé qu'à un seul contact.

**Panneau d'un ami** (tap sur une ligne de « Mes amis ») :

- **Envie de se voir** : envoie un signe à l'ami, une fois par jour au maximum (voir les règles en section 5).
- **Proposer un rendez-vous** : ouvre le formulaire avec son contact pré-sélectionné.
- **Voir le contact**, **Associer à un autre contact**, **Dissocier du contact**.
- **Retirer de mes amis**, en rouge, avec confirmation : les contacts et rendez-vous existants sont conservés, les invitations en attente sont annulées.

### 4.12 Historique

Tous les rendez-vous validés ou annulés, du plus récent au plus ancien (200 au maximum).

- Un filtre à trois positions : **Tous / A eu lieu / Annulés**.
- Une recherche sur le nom d'un participant, le titre ou le lieu.
- Un résumé : « 42 rencontres · 3 annulés ».
- La liste, regroupée par mois (« Novembre 2026 (4) »).

Chaque ligne de rendez-vous, ici comme ailleurs, montre : un pavé avec le jour et le mois, le titre, une ligne « Hier · 18:30 · lieu · nombre de photos », les avatars des participants empilés (3 au plus), et la pastille de statut.

### 4.13 Réglages

Cinq blocs :

1. **Profil.** Nom affiché, nom d'utilisateur, date de naissance, bouton « Enregistrer » (actif seulement s'il y a un changement valide), bouton « Partager mon @ ». En lecture seule : l'email et le fuseau horaire détecté.
2. **Notifications.** L'état des notifications sur cet appareil avec un bouton Activer / Désactiver, puis deux interrupteurs généraux (rappels push, rappels par email). Trois listes de choix : l'heure du récap quotidien (de 0h à 23h), quand prévenir (le jour de l'échéance, 1, 3, 7 ou 14 jours avant), et le rappel avant un rendez-vous (15, 30, 60, 120 minutes ou la veille). Un bouton « Envoyer une notification de test ». Enfin, la liste des 10 dernières notifications envoyées : titre, texte, type, date, et le canal utilisé.
3. **Application.** Le numéro de version. La version actuelle affiche aussi une aide pour installer l'app sur l'écran d'accueil, inutile pour une app native.
4. **Données.** « Importer des contacts du téléphone » et « Exporter mes données » : un fichier contenant le profil, les contacts, les rendez-vous et la liste des photos.
5. **Compte.** « Changer le mot de passe » (panneau avec deux champs), « Se déconnecter », et « Supprimer mon compte » en rouge. La suppression efface définitivement contacts, rendez-vous et photos, après confirmation.

Chaque réglage de notification est enregistré dès qu'on le touche, sans bouton de validation.

### 4.14 Écrans de secours

- **Hors connexion** : « Vous êtes hors ligne », une phrase d'explication, un bouton « Réessayer ». L'app a besoin du réseau pour fonctionner.
- **Page introuvable** et **erreur inattendue** : un message court et un bouton de retour.
- **Contact ou rendez-vous introuvable** : « Il a peut-être été supprimé. », avec un bouton vers la liste ou l'accueil.

## 5. Les règles de fonctionnement

### 5.1 Calcul de l'échéance

La prochaine échéance vaut la date de dernière rencontre plus la fréquence, en calendrier réel : le 31 janvier + 1 mois donne le 28 février. Si un report existe et tombe après cette date, c'est le report qui compte.

L'état d'un contact dépend du nombre de jours entre aujourd'hui et cette échéance :

| Jours restants | État | Couleur | Texte long | Texte court |
| --- | --- | --- | --- | --- |
| Négatif | En retard | Rouge | En retard de 3 jours | -3 j |
| 0 | Aujourd'hui | Orange | À revoir aujourd'hui | Auj. |
| 1 à 7 | Bientôt | Ambre | À revoir dans 5 jours | 5 j |
| 8 et plus | À jour | Vert | À revoir dans 2 mois | 2 mois |

Les durées sont arrondies pour rester lisibles : en jours jusqu'à 13, en semaines jusqu'à 59 jours, en mois jusqu'à 349 jours (2 mois au minimum), puis en années, avec le cas particulier « 1 an et demi ».

La fréquence se lit « tous les jours », « toutes les semaines », « tous les mois », « tous les ans », ou avec un nombre : « toutes les 3 semaines », « tous les 2 mois ».

### 5.2 Ce qui remet le compteur à zéro

- **Valider un rendez-vous** (ou enregistrer une rencontre passée) met la date de dernière rencontre de chaque participant au jour du rendez-vous. Cette date n'est jamais reculée : si une rencontre plus récente existe déjà, elle est conservée.
- **Quand la dernière rencontre ou la fréquence change**, un nouveau cycle commence : le report est effacé et le contact pourra de nouveau être signalé dans un rappel.
- **Quand la dernière rencontre change**, le marqueur « à voir bientôt » est retiré.
- **Remettre un rendez-vous en « planifié »** ne recule pas la date de dernière rencontre.

### 5.3 Cycle de vie d'un rendez-vous

Un rendez-vous naît « Planifié » ou directement « A eu lieu ». Planifié, il peut passer à « A eu lieu » ou « Annulé », et dans les deux cas revenir à « Planifié ».

- Un rendez-vous planifié dont l'heure est passée depuis plus de 30 minutes est « à confirmer » : il remonte sur l'accueil et sa fiche affiche le bandeau ambre.
- Si on change sa date, les rappels déjà envoyés repartent : l'utilisateur sera prévenu de nouveau.
- Supprimer un contact supprime aussi ses rendez-vous et ses photos.

### 5.4 Anniversaires

L'app calcule le prochain anniversaire et l'âge atteint. L'âge n'est affiché que s'il est plausible (entre 1 et 119 ans). Une personne née un 29 février est fêtée le 28 les années non bissextiles.

Quand un ami renseigne sa date de naissance dans son profil, elle remplit automatiquement la fiche contact qui lui est associée chez ses amis, sauf s'ils y avaient saisi une autre date.

### 5.5 Amitiés

- On ajoute quelqu'un uniquement par son nom d'utilisateur. La recherche ne révèle jamais l'email.
- Si j'envoie une demande à quelqu'un qui m'en avait déjà envoyé une, nous devenons amis immédiatement.
- Refuser ou annuler une demande la supprime, sans laisser de trace.
- L'email d'un ami n'est visible qu'une fois l'amitié acceptée.
- Un contact ne peut être associé qu'à un ami accepté, et un ami à un seul contact.
- Retirer un ami conserve mes contacts et mes rendez-vous, mais dissocie le contact et annule les invitations en attente.

### 5.6 Rendez-vous partagé, pas à pas

1. Andrea crée un rendez-vous avec son contact « Marie », associé au compte de Marie, et lui envoie une invitation. C'est impossible si le rendez-vous est annulé.
2. Marie reçoit une notification et voit une carte d'invitation sur son accueil et dans l'onglet Amis.
3. Si Marie accepte, elle obtient sa propre copie du rendez-vous, rattachée à son contact associé à Andrea. Si elle n'en a pas, l'app le crée toute seule : nom et email d'Andrea, fréquence d'un mois, dernière rencontre aujourd'hui.
4. À partir de là, quatre informations restent identiques chez les deux : **statut, date et heure, titre, lieu**. Toute modification par l'un s'applique chez l'autre, qui reçoit une notification. Les **notes** restent privées, et chacun garde sa propre liste de participants.
5. Quand l'un des deux marque « A eu lieu », le rendez-vous est validé chez les deux. Chacun voit alors son propre compteur repartir de zéro avec son propre contact.
6. Les photos forment une galerie commune : chacun voit celles de l'autre, mais ne peut supprimer que les siennes.
7. Supprimer le rendez-vous ne le supprime que chez soi.

Une invitation refusée peut être renvoyée. Une invitation en attente peut être annulée par son auteur. On peut aussi partager une rencontre déjà passée : en l'acceptant, l'ami voit son compteur remis à zéro tout de suite.

### 5.7 « Envie de se voir »

Un signe envoyé à un ami, limité à un par ami et par 24 heures. L'ami reçoit une notification « 👋 Andrea aimerait vous voir ». Chez lui, le contact associé à Andrea est marqué « à voir bientôt » et remonte donc en tête de son accueil. S'il n'a pas de contact associé, seule la notification part.

### 5.8 Photos

- Chaque photo est réduite avant l'envoi : 1600 pixels au plus sur le grand côté, compression d'environ 80 %.
- Les photos sont privées. Seuls leur propriétaire et les participants d'un rendez-vous partagé peuvent les voir.
- On peut en sélectionner plusieurs d'un coup ; elles sont envoyées l'une après l'autre.

### 5.9 Recherche

Toutes les recherches ignorent les majuscules et les accents (« helene » trouve « Hélène ») et cherchent n'importe où dans le texte, pas seulement au début. Seule exception : la recherche d'utilisateurs, qui part du début du nom d'utilisateur.

## 6. Notifications et rappels

L'app envoie dix types de notifications. Un tap sur une notification ouvre directement l'écran concerné.

| Type | Quand | Titre (exemple) | Ouvre |
| --- | --- | --- | --- |
| Récap quotidien | Une fois par jour, à l'heure choisie | « Marie est à recontacter » ou « 4 contacts à recontacter » | Accueil |
| Anniversaire | Le jour J, avec le récap | « 🎂 C'est l'anniversaire de Marie ! » | Contacts |
| Rappel de rendez-vous | Avant le rendez-vous, selon le délai choisi | « Rendez-vous avec Marie dans 30 min » | Fiche rendez-vous |
| Suivi de rendez-vous | 2 heures après un rendez-vous resté « planifié » | « Votre rendez-vous avec Marie a-t-il eu lieu ? » | Fiche rendez-vous |
| Demande d'ami | À la réception | « Andrea (@andrea) vous a ajouté sur SeeU » | Amis |
| Ami accepté | Quand l'autre accepte | « Marie a accepté votre demande » | Amis |
| Invitation à un rendez-vous | À la réception | « Andrea vous propose un rendez-vous » | Amis |
| Réponse à une invitation | Quand l'ami répond | « Marie a accepté votre rendez-vous ✅ » ou « a décliné » | Fiche rendez-vous |
| Rendez-vous partagé modifié | Quand l'ami déplace, confirme, annule ou replanifie | « Marie a déplacé votre rendez-vous » | Fiche rendez-vous |
| Envie de se voir | À la réception | « 👋 Andrea aimerait vous voir » | Fiche contact |

**Le récap quotidien** liste les contacts dont l'échéance tombe aujourd'hui ou avant, ou dans le délai de prévenance choisi (jusqu'à 14 jours avant). Son texte cite 5 noms au plus : « Marie (en retard de 3 j), Paul (aujourd'hui), Léa (dans 2 j) et 2 autres · 6 en retard au total ». Un contact n'est signalé qu'une seule fois par cycle : il ne revient pas chaque matin tant qu'on ne l'a ni revu ni reporté.

**Le rappel de rendez-vous** précise le jour, l'heure et le lieu dans son texte. Son titre s'adapte : « maintenant », « dans 30 min », ou « à 18:30 » au-delà d'une heure et demie.

**Canal d'envoi.** La notification part d'abord en push sur tous les appareils de l'utilisateur. Si aucun appareil ne peut la recevoir et que les emails sont autorisés, elle part par email, avec le même titre, le même texte et un bouton vers l'app. Chaque envoi est noté dans le journal visible en réglages.

**Heure locale.** Toutes les heures de rappel suivent le fuseau horaire de l'utilisateur, mis à jour à chaque ouverture de l'app. Les rappels sont vérifiés toutes les 10 minutes environ : c'est leur précision.

**Raccourcis.** Un appui long sur l'icône de l'app propose « Nouveau rendez-vous » et « Nouveau contact ».

## 7. Identité visuelle et ton

**Couleurs.** La couleur de marque est un bleu indigo (#4F46E5) : boutons principaux, onglet actif, liens, bouton flottant. Sa version très claire (#EEF2FF) sert de fond aux encarts d'information. Le fond de l'app est un gris très clair, les cartes sont blanches.

| Couleur | Signification |
| --- | --- |
| Rouge | En retard, erreur, action destructive |
| Orange | À revoir aujourd'hui |
| Ambre | À revoir cette semaine, rendez-vous à confirmer |
| Vert | À jour, succès, « A eu lieu » |
| Rose | Anniversaires |
| Violet | Marqueur « à voir bientôt » |
| Indigo clair | Rendez-vous planifié, contenu lié aux amis |
| Gris | Rendez-vous annulé, éléments secondaires |

**Thème sombre.** L'app suit automatiquement le réglage clair / sombre du téléphone. Chaque couleur a sa variante sombre.

**Formes.** Police système du téléphone. Cartes aux coins très arrondis avec une ombre légère. Pastilles en forme de pilule. Boutons arrondis en trois tailles et six styles : principal (indigo plein), secondaire (gris), contour, discret (texte seul), succès (vert), danger (rouge). Un bouton en cours d'action affiche une roue et se désactive.

**Avatars.** Ronds. Avec une photo si le contact en a une, sinon les initiales (première lettre du prénom et du nom, ou les deux premières lettres d'un nom unique) sur un fond pastel. La couleur est tirée du nom parmi dix teintes, donc toujours la même pour une même personne.

**Mouvements.** Les panneaux glissent depuis le bas en un cinquième de seconde environ. Les boutons se rétractent légèrement au toucher. Les messages éclair sont verts pour un succès, rouges pour une erreur, sombres pour une information.

**Ton des textes.** Vouvoiement, phrases courtes, quelques emojis bien placés (👋, 🎉, 🎂, ✅). Les formulaires donnent toujours un exemple dans le champ (« Ex. Marie Dupont », « Café, adresse, visio… »). Chaque action destructive est confirmée et rappelle qu'elle est définitive.

**Dates et heures.** Format 24 heures. Les dates s'écrivent « 12 nov. 2026 » en version courte et « mercredi 12 novembre 2026 » en version longue. Les jours proches deviennent « Aujourd'hui », « Demain », « Hier ».
