// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageName => 'Français';

  @override
  String get and => 'et';

  @override
  String andOthers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'et $n autres',
      one: 'et 1 autre',
    );
    return '$_temp0';
  }

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get yesterday => 'Hier';

  @override
  String dayAtTime(String day, String time) {
    return '$day à $time';
  }

  @override
  String get greetingNight => 'Bonne nuit';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String nDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n jours',
      one: '1 jour',
      zero: '0 jour',
    );
    return '$_temp0';
  }

  @override
  String nWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String nMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n mois',
      one: '1 mois',
    );
    return '$_temp0';
  }

  @override
  String nYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String nYearsHalf(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ans et demi',
      one: '1 an et demi',
    );
    return '$_temp0';
  }

  @override
  String shortDays(int n) {
    return '$n j';
  }

  @override
  String shortWeeks(int n) {
    return '$n sem.';
  }

  @override
  String shortMonths(int n) {
    return '$n mois';
  }

  @override
  String shortYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String dueOverdue(String duration) {
    return 'En retard de $duration';
  }

  @override
  String get dueToday => 'À revoir aujourd\'hui';

  @override
  String get dueTodayShort => 'Auj.';

  @override
  String dueIn(String duration) {
    return 'À revoir dans $duration';
  }

  @override
  String everyDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'tous les $n jours',
      one: 'tous les jours',
    );
    return '$_temp0';
  }

  @override
  String everyWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'toutes les $n semaines',
      one: 'toutes les semaines',
    );
    return '$_temp0';
  }

  @override
  String everyMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'tous les $n mois',
      one: 'tous les mois',
    );
    return '$_temp0';
  }

  @override
  String everyYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'tous les $n ans',
      one: 'tous les ans',
    );
    return '$_temp0';
  }

  @override
  String unitDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'jours',
      one: 'jour',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'semaines',
      one: 'semaine',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'mois',
      one: 'mois',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'ans',
      one: 'an',
    );
    return '$_temp0';
  }

  @override
  String get statusPlanned => 'Planifié';

  @override
  String get statusDone => 'A eu lieu';

  @override
  String get statusCancelled => 'Annulé';

  @override
  String get rsvpPending => 'À confirmer';

  @override
  String get rsvpAccepted => 'Accepté';

  @override
  String get rsvpDeclined => 'Refusé';

  @override
  String withNames(String names) {
    return 'Avec $names';
  }

  @override
  String withNamesMore(String names, int n) {
    return 'Avec $names et $n autres';
  }

  @override
  String get aFriend => 'Un ami';

  @override
  String get catFamily => 'Famille';

  @override
  String get catFriends => 'Amis';

  @override
  String get catWork => 'Pro';

  @override
  String get catOther => 'Autre';

  @override
  String get usernameHint =>
      '3 à 20 caractères : lettres minuscules, chiffres, point et tiret bas.';

  @override
  String usernameTooShort(int n) {
    return 'Au moins $n caractères.';
  }

  @override
  String get usernameBadStart => 'Doit commencer par une lettre ou un chiffre.';

  @override
  String get errNetwork => 'Pas de connexion. Vérifiez votre réseau.';

  @override
  String get errGeneric => 'Une erreur est survenue.';

  @override
  String get errSessionExpired => 'Session expirée, reconnectez-vous.';

  @override
  String get errForbidden => 'Action non autorisée.';

  @override
  String get errUsernameTaken => 'Ce nom d\'utilisateur est déjà pris.';

  @override
  String get errUsernameInvalid => 'Nom d\'utilisateur invalide.';

  @override
  String get errFriendAlreadyLinked =>
      'Cet ami est déjà associé à un autre contact.';

  @override
  String get errDuplicate => 'Cet élément existe déjà.';

  @override
  String get errFileTooLarge => 'Fichier trop volumineux (10 Mo max).';

  @override
  String get errBadCredentials => 'Email ou mot de passe incorrect.';

  @override
  String get errEmailNotConfirmed =>
      'Confirmez d\'abord votre adresse email (lien reçu par mail).';

  @override
  String get errEmailTaken => 'Un compte existe déjà avec cet email.';

  @override
  String get errWeakPassword =>
      'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get errRateLimit =>
      'Trop de tentatives, réessayez dans quelques minutes.';

  @override
  String get errSignupsDisabled => 'Les inscriptions sont désactivées.';

  @override
  String get errInvalidEmail => 'Adresse email invalide.';

  @override
  String get errSamePassword =>
      'Choisissez un mot de passe différent de l\'ancien.';

  @override
  String get errLinkExpired => 'Lien invalide ou expiré.';

  @override
  String get errNotFriends =>
      'Cette personne ne fait pas partie de vos amis SeeU.';

  @override
  String get errNoLongerFriends => 'Vous n\'êtes plus amis sur SeeU.';

  @override
  String get errRdvNotFound => 'Rendez-vous introuvable.';

  @override
  String get errInviteNotFound => 'Invitation introuvable.';

  @override
  String get errRdvGone => 'Ce rendez-vous n\'existe plus.';

  @override
  String get errRdvCancelled => 'Ce rendez-vous est annulé.';

  @override
  String get errWaveAlready => 'Vous lui avez déjà fait signe aujourd\'hui.';

  @override
  String get errAlreadyAnswered => 'Vous avez déjà répondu à cette invitation.';

  @override
  String get errBadAnswer => 'Réponse invalide.';

  @override
  String get errRequestNotFound => 'Demande introuvable.';

  @override
  String get errNotOrganizer => 'Seul l\'organisateur peut faire cela.';

  @override
  String get errPublicNotAllowed =>
      'Vous n\'avez pas encore accès aux événements publics.';

  @override
  String get errSlotsClosed => 'Le choix des créneaux est terminé.';

  @override
  String get errSlotsNotAllowed =>
      'Les créneaux multiples ne sont pas disponibles pour un événement public.';

  @override
  String get errEventNotVisible => 'Cet événement n\'est pas accessible.';

  @override
  String get errBlocked => 'Action impossible avec cette personne.';

  @override
  String get errChatReadOnly => 'Seul l\'organisateur peut publier ici.';

  @override
  String get errPhotosOrganizerOnly =>
      'Seul l\'organisateur peut ajouter des photos.';

  @override
  String get errNotParticipant => 'Rejoignez l\'événement pour participer.';

  @override
  String get errTooManySlots => '10 créneaux maximum.';

  @override
  String errContactsAddedBeforeError(int n, Object error) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts ajoutés avant l\'erreur : $error',
      one: '1 contact ajouté avant l\'erreur : $error',
    );
    return '$_temp0';
  }

  @override
  String get errDeleteAccountFailed =>
      'Suppression impossible pour le moment. Réessayez plus tard.';

  @override
  String get errLinkOtherDevice =>
      'Ce lien doit être ouvert sur l\'appareil où vous l\'avez demandé. Ouvrez l\'email sur cet appareil, ou redemandez un lien depuis celui-ci.';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabHistory => 'Historique';

  @override
  String get tabSettings => 'Réglages';

  @override
  String get back => 'Retour';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get clear => 'Effacer';

  @override
  String get add => 'Ajouter';

  @override
  String get pickDate => 'Choisir une date';

  @override
  String get notSeenYet => 'Pas encore vu';

  @override
  String seenOn(String date) {
    return 'Vu le $date';
  }

  @override
  String get soonPill => '★ Bientôt';

  @override
  String get seeuFriend => 'Ami SeeU';

  @override
  String get freqCustom => 'Personnalisée';

  @override
  String get categoryOther => 'Autre…';

  @override
  String get categoryHint => 'Ex. Voisins, Sport…';

  @override
  String get pushChannelName => 'Rappels SeeU';

  @override
  String get pushChannelDesc => 'Rappels, rendez-vous et activité de vos amis';

  @override
  String get quickNewRdv => 'Nouveau rendez-vous';

  @override
  String get quickNewContact => 'Nouveau contact';

  @override
  String get historyTitle => 'Historique';

  @override
  String get historyList => 'Liste';

  @override
  String get historyMonth => 'Mois';

  @override
  String get historyEmptyTitle => 'Aucune rencontre pour l\'instant';

  @override
  String get historyEmptyMessage =>
      'Les rendez-vous validés ou annulés apparaîtront ici.';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterDone => 'A eu lieu';

  @override
  String get filterCancelled => 'Annulés';

  @override
  String get historySearchHint => 'Rechercher (contact, titre, lieu)';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String historyCounts(int nMet, int nCancelled) {
    String _temp0 = intl.Intl.pluralLogic(
      nMet,
      locale: localeName,
      other: '$nMet rencontres',
      one: '1 rencontre',
      zero: '0 rencontre',
    );
    String _temp1 = intl.Intl.pluralLogic(
      nCancelled,
      locale: localeName,
      other: '$nCancelled annulés',
      one: '1 annulé',
      zero: '0 annulé',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get prevMonth => 'Mois précédent';

  @override
  String get nextMonth => 'Mois suivant';

  @override
  String get loading => 'Chargement…';

  @override
  String get calendarNoneThisMonth => 'Aucune rencontre ce mois-ci.';

  @override
  String calendarMetInMonth(int n, Object month) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rencontres en $month',
      one: '1 rencontre en $month',
    );
    return '$_temp0';
  }

  @override
  String calendarDayEvents(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rendez-vous',
      one: '1 rendez-vous',
    );
    return '$_temp0';
  }

  @override
  String get dayNoEvents => 'Aucun rendez-vous ce jour-là';

  @override
  String dayMetCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rencontres ce jour-là',
      one: '1 rencontre ce jour-là',
      zero: 'Aucune rencontre ce jour-là',
    );
    return '$_temp0';
  }

  @override
  String get rsvpToastAccepted => 'Rendez-vous accepté';

  @override
  String get rsvpToastDeclined => 'Invitation refusée';

  @override
  String get rsvpToastPending => 'Marqué « à confirmer »';

  @override
  String get rsvpDecline => 'Refuser';

  @override
  String get rsvpAccept => 'Accepter';

  @override
  String get rsvpMaybe => 'À confirmer';

  @override
  String get statusFutureTitle => 'Ce rendez-vous est prévu plus tard';

  @override
  String statusFutureMessage(String when) {
    return 'Il est planifié le $when. Le marquer quand même comme ayant eu lieu ?';
  }

  @override
  String get statusFutureConfirm => 'Oui, il a eu lieu';

  @override
  String get statusToastDone => 'Rendez-vous validé';

  @override
  String get statusToastDoneReset =>
      'Rendez-vous validé : date de dernière rencontre mise à jour';

  @override
  String get statusToastCancelled => 'Rendez-vous annulé';

  @override
  String get statusToastPlanned => 'Rendez-vous remis en planifié';

  @override
  String get statusSetPlanned => 'Remettre en planifié';

  @override
  String get statusSetDone => 'Marquer comme passé';

  @override
  String get statusSetCancelled => 'Annuler';

  @override
  String inviteSharesMeetup(String name) {
    return '$name partage une rencontre avec vous';
  }

  @override
  String inviteProposes(String name) {
    return '$name vous propose un rendez-vous';
  }

  @override
  String get inviteTentativeHint =>
      'Il est déjà dans votre agenda, « à confirmer ». Votre ami n\'est prévenu que si vous acceptez ou refusez.';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get offlineTitle => 'Vous êtes hors ligne';

  @override
  String get offlineMessage =>
      'SeeU a besoin d\'une connexion internet pour fonctionner. Vérifiez votre réseau puis réessayez.';

  @override
  String get pageNotFound => 'Page introuvable';

  @override
  String get pageNotFoundMessage => 'Cette page n\'existe pas ou plus.';

  @override
  String get backHome => 'Retour à l\'accueil';

  @override
  String get maybeDeleted => 'Il a peut-être été supprimé.';

  @override
  String get photoAdd => 'Ajouter une photo';

  @override
  String get photoTake => 'Prendre une photo';

  @override
  String get photoGallery => 'Choisir dans la galerie';

  @override
  String get photoAccessDenied =>
      'Accès aux photos refusé. Autorisez-le dans les réglages du téléphone.';

  @override
  String get photoEmpty => 'Ajoutez des photos de vos moments partagés.';

  @override
  String get photoDeleteTitle => 'Supprimer cette photo ?';

  @override
  String get irreversible => 'Cette action est définitive.';

  @override
  String get delete => 'Supprimer';

  @override
  String get photoDeleted => 'Photo supprimée';

  @override
  String get close => 'Fermer';

  @override
  String get pushEnabledToast => 'Notifications activées 🎉';

  @override
  String get pushBlockedTitle => 'Notifications bloquées';

  @override
  String get pushEnableTitle => 'Activer les rappels';

  @override
  String get pushBlockedMessage =>
      'Autorisez-les dans les réglages de votre téléphone (Notifications → SeeU), ou activez les rappels par email dans les Réglages de l\'app.';

  @override
  String get pushEnableMessage =>
      'Recevez une notification quand un contact est à recontacter et avant chaque rendez-vous.';

  @override
  String get openPhoneSettings => 'Ouvrir les réglages';

  @override
  String get seeuSettings => 'Réglages SeeU';

  @override
  String get enable => 'Activer';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSystem => 'Langue du téléphone';

  @override
  String get tagline => 'Ne plus oublier les personnes qu\'on aimerait revoir.';

  @override
  String get configMissing =>
      'Configuration manquante : lancez l\'app avec --dart-define-from-file=config/env.json (SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY).';

  @override
  String get errAccountExists =>
      'Un compte existe déjà avec cet email. Connectez-vous ou utilisez « Mot de passe oublié ».';

  @override
  String get checkMailboxTitle => 'Vérifiez votre boîte mail';

  @override
  String checkMailboxText(String email) {
    return 'Un lien de confirmation a été envoyé à $email. Ouvrez-le pour activer votre compte (pensez aux spams).';
  }

  @override
  String get magicSentTitle => 'Lien envoyé';

  @override
  String magicSentText(String email) {
    return 'Ouvrez le lien reçu à $email pour vous connecter (pensez aux spams).';
  }

  @override
  String get resetSentTitle => 'Email envoyé';

  @override
  String resetSentText(String email) {
    return 'Si un compte existe pour $email, vous recevrez un lien pour choisir un nouveau mot de passe.';
  }

  @override
  String get loginTab => 'Connexion';

  @override
  String get signupTab => 'Inscription';

  @override
  String get magicLink => 'Lien magique';

  @override
  String get forgotPassword => 'Mot de passe oublié';

  @override
  String get magicLinkHelp =>
      'Recevez un lien de connexion par email, sans mot de passe.';

  @override
  String get forgotHelp =>
      'Indiquez votre email : vous recevrez un lien pour choisir un nouveau mot de passe.';

  @override
  String get firstNameLabel => 'Prénom (nom affiché)';

  @override
  String get nameExample => 'Ex. Andrea';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'vous@exemple.com';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordMin => '6 caractères minimum';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createAccount => 'Créer mon compte';

  @override
  String get getLink => 'Recevoir le lien';

  @override
  String get sendLink => 'Envoyer le lien';

  @override
  String get forgotPasswordQ => 'Mot de passe oublié ?';

  @override
  String get getMagicLink => 'Recevoir un lien magique par email';

  @override
  String get completeProfileTitle => 'Complétez votre profil';

  @override
  String get completeProfileSub =>
      'Vos amis vous retrouveront grâce à votre nom d\'utilisateur.';

  @override
  String get displayName => 'Nom affiché';

  @override
  String get displayNameHint => 'C\'est ce que voient vos amis.';

  @override
  String get birthDate => 'Date de naissance';

  @override
  String get birthDateHint => 'Facultative. Visible par vos amis uniquement.';

  @override
  String get continueLabel => 'Continuer';

  @override
  String signedInAs(String email) {
    return 'Connecté avec $email';
  }

  @override
  String get passwordUpdated => 'Mot de passe mis à jour';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get backToLogin => 'Retour à la connexion';

  @override
  String get confirmPassword => 'Confirmez le mot de passe';

  @override
  String get passwordsDiffer => 'Les deux mots de passe sont différents.';

  @override
  String get save => 'Enregistrer';

  @override
  String get usernameLabel => 'Nom d\'utilisateur';

  @override
  String usernameAvailable(String username) {
    return '@$username est disponible';
  }

  @override
  String get usernameCheckFailed => 'Vérification impossible pour le moment.';

  @override
  String get usernamePlaceholder => 'nom.utilisateur';

  @override
  String nowFriendsWith(String name) {
    return 'Vous êtes maintenant amis avec $name';
  }

  @override
  String get requestDeclined => 'Demande refusée';

  @override
  String get requestCancelled => 'Demande annulée';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get importContacts => 'Importer des contacts';

  @override
  String get friendsWithoutCard => 'Amis SeeU sans fiche';

  @override
  String get tryAnotherSearch => 'Essayez une autre recherche.';

  @override
  String get groupOverdue => 'En retard';

  @override
  String get groupThisWeek => 'Cette semaine';

  @override
  String get groupUpToDate => 'À jour';

  @override
  String get addSeeuFriend => 'Ajouter un ami SeeU';

  @override
  String get addContact => 'Ajouter un contact';

  @override
  String get rdvInvitations => 'Invitations à un rendez-vous';

  @override
  String get friendRequestsReceived => 'Demandes d\'ami reçues';

  @override
  String get sentYouARequest => 'Vous a envoyé une demande';

  @override
  String get friendRequestsSent => 'Demandes d\'ami envoyées';

  @override
  String get waitingForAnswer => 'En attente';

  @override
  String get noContactsTitle => 'Aucun contact pour l\'instant';

  @override
  String get noContactsMessage =>
      'Ajoutez les personnes que vous voulez revoir régulièrement. Celles qui sont sur SeeU peuvent devenir vos amis : rendez-vous et photos partagés.';

  @override
  String get importFromPhone => 'Importer depuis le téléphone';

  @override
  String get contactsSearchHint => 'Rechercher (nom, catégorie, notes, @ami)';

  @override
  String nContacts(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts',
      one: '1 contact',
      zero: '0 contact',
    );
    return '$_temp0';
  }

  @override
  String nFriends(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n amis',
      one: '1 ami',
      zero: '0 ami',
    );
    return '$_temp0';
  }

  @override
  String nOverdue(int n) {
    return '$n en retard';
  }

  @override
  String get sortDue => 'Échéance';

  @override
  String get sortName => 'Nom';

  @override
  String get notInContactsYet => 'pas encore dans vos contacts';

  @override
  String markSeenTitle(String name) {
    return 'Vu $name';
  }

  @override
  String snoozeTitle(String name) {
    return 'Reporter $name';
  }

  @override
  String get seeSoonTitle => 'À voir bientôt';

  @override
  String get seeSoonSub =>
      'Choisissez quelqu\'un à revoir sans attendre la fin de sa période. Il restera en tête de liste jusqu\'à votre prochaine rencontre.';

  @override
  String meetingSaved(String name) {
    return 'Rencontre avec $name enregistrée';
  }

  @override
  String get whenDidYouSee => 'Quand l\'avez-vous vu(e) ?';

  @override
  String get noteOptional => 'Une note';

  @override
  String get noteHint => 'Un souvenir, un détail à retenir…';

  @override
  String get markSeenHelp =>
      'La date de dernière rencontre et la prochaine échéance seront mises à jour automatiquement. La rencontre apparaîtra dans l\'historique.';

  @override
  String get saveMeeting => 'Enregistrer la rencontre';

  @override
  String snoozedUntil(String date) {
    return 'Rappel reporté au $date';
  }

  @override
  String get remindMeIn => 'Me le rappeler plus tard, dans :';

  @override
  String get orOnDate => 'Ou à une date précise';

  @override
  String get snooze => 'Reporter';

  @override
  String addedToSeeSoon(String name) {
    return '$name ajouté(e) à la liste « à voir bientôt »';
  }

  @override
  String get searchContact => 'Rechercher un contact…';

  @override
  String get allAlreadyInList => 'Tous vos contacts sont déjà dans la liste.';

  @override
  String get noMatchingContact => 'Aucun contact ne correspond.';

  @override
  String ageSuffix(int n) {
    return '($n ans)';
  }

  @override
  String get birthdayToday => 'C\'est son anniversaire aujourd\'hui !';

  @override
  String get birthdayTomorrow => 'Anniversaire demain';

  @override
  String birthdayInDays(int n) {
    return 'Anniversaire dans $n jours';
  }

  @override
  String get contactNotFound => 'Contact introuvable';

  @override
  String get seeMyContacts => 'Voir mes contacts';

  @override
  String get edit => 'Modifier';

  @override
  String get removedFromSeeSoon => 'Retiré de la liste « à voir bientôt »';

  @override
  String get addedToSeeSoonHome =>
      'Ajouté à la liste « à voir bientôt » de l\'accueil';

  @override
  String get deleteContactTitle => 'Supprimer ce contact ?';

  @override
  String get deleteContactMessage =>
      'Ses rendez-vous et photos seront aussi supprimés. Cette action est définitive.';

  @override
  String get contactDeleted => 'Contact supprimé';

  @override
  String get friendPill => 'Ami SeeU · rendez-vous et photos partageables';

  @override
  String get lastMeeting => 'Dernière rencontre';

  @override
  String get notRecordedYet => 'Pas encore notée';

  @override
  String get nextDue => 'Prochaine échéance';

  @override
  String get snoozedSuffix => '(reportée)';

  @override
  String get frequency => 'Fréquence';

  @override
  String get planRdv => 'Planifier un rendez-vous';

  @override
  String get seenToday => 'Vu aujourd\'hui';

  @override
  String get inSeeSoonRemove => 'Dans « à voir bientôt » · retirer';

  @override
  String get information => 'Informations';

  @override
  String bornOn(String date) {
    return 'Né(e) le $date';
  }

  @override
  String get rdvSection => 'Rendez-vous';

  @override
  String get noRdvWithContact =>
      'Aucun rendez-vous avec ce contact pour l\'instant.';

  @override
  String get upcoming => 'À venir';

  @override
  String get past => 'Passés';

  @override
  String get gallery => 'Galerie';

  @override
  String get deleteContact => 'Supprimer le contact';

  @override
  String get linkToFriend => 'Associer à un ami SeeU';

  @override
  String get linkedToAccount => 'Associé à un compte SeeU';

  @override
  String get friendCanShare =>
      'Vous pouvez lui envoyer vos rendez-vous et partager les photos.';

  @override
  String get wantToMeet => 'Envie de se voir';

  @override
  String wantToMeetSent(String name) {
    return '$name sait que vous aimeriez vous voir 👋';
  }

  @override
  String get manage => 'Gérer';

  @override
  String get editContact => 'Modifier le contact';

  @override
  String get nameRequired => 'Le nom est obligatoire.';

  @override
  String get frequencyMin => 'La fréquence doit être d\'au moins 1.';

  @override
  String get contactAdded => 'Contact ajouté';

  @override
  String get contactUpdated => 'Contact mis à jour';

  @override
  String get newContact => 'Nouveau contact';

  @override
  String get addTheContact => 'Ajouter le contact';

  @override
  String get change => 'Changer';

  @override
  String get remove => 'Retirer';

  @override
  String get name => 'Nom';

  @override
  String get nameHintFull => 'Ex. Marie Dupont';

  @override
  String get categories => 'Catégories';

  @override
  String get categoriesHint => 'Facultatif · plusieurs choix possibles';

  @override
  String get lastMeetingOptional =>
      'Facultatif. Sans date, la période démarre aujourd\'hui.';

  @override
  String get noMeetingRecorded => 'Pas encore de rencontre notée';

  @override
  String nextDueInline(String date) {
    return 'Prochaine échéance : $date';
  }

  @override
  String get phone => 'Téléphone';

  @override
  String get phoneHint => 'Ex. 06 12 34 56 78';

  @override
  String get emailExample => 'Ex. marie@exemple.com';

  @override
  String get birthday => 'Anniversaire';

  @override
  String get notes => 'Notes';

  @override
  String get notesHint => 'Centres d\'intérêt, enfants, dernier sujet abordé…';

  @override
  String get requiredFields => '* champs obligatoires';

  @override
  String get importReadFailed =>
      'Impossible de lire vos contacts sur cet appareil.';

  @override
  String get importAllThere => 'Tous ces contacts sont déjà dans SeeU.';

  @override
  String importRestTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Les $n restants d\'un coup',
      one: 'Le dernier restant d\'un coup',
    );
    return '$_temp0';
  }

  @override
  String importRestFreq(String freq) {
    return 'Fréquence $freq';
  }

  @override
  String importRestCats(String cats) {
    return 'catégories $cats';
  }

  @override
  String importRestLast(String date) {
    return 'dernière rencontre le $date';
  }

  @override
  String get addAll => 'Tout ajouter';

  @override
  String get ignoreAllFinish => 'Tout ignorer et terminer';

  @override
  String nImported(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts importés',
      one: '1 contact importé',
    );
    return '$_temp0';
  }

  @override
  String stepOf(int n) {
    return 'Étape $n sur 3';
  }

  @override
  String get chooseContacts => 'Choisissez des contacts';

  @override
  String continueN(int n) {
    return 'Continuer ($n)';
  }

  @override
  String get ignore => 'Ignorer';

  @override
  String importN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Importer $n contacts',
      one: 'Importer 1 contact',
    );
    return '$_temp0';
  }

  @override
  String get reviewSelection => 'Revoir la sélection';

  @override
  String get fromAddressBook => 'Depuis votre carnet d\'adresses';

  @override
  String get fromAddressBookHelp =>
      'Choisissez les personnes à suivre dans SeeU. Vous réglerez ensuite la fréquence de chacune. Rien n\'est enregistré avant la confirmation finale.';

  @override
  String get accessMyContacts => 'Accéder à mes contacts';

  @override
  String get contactsAccessDenied =>
      'SeeU n\'a pas accès à vos contacts. Autorisez-le dans les réglages du téléphone, puis réessayez.';

  @override
  String get searchEllipsis => 'Rechercher…';

  @override
  String nChosen(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n choisis',
      one: '1 choisi',
      zero: '0 choisi',
    );
    return '$_temp0';
  }

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String contactNofM(int n, int nTotal) {
    return 'Contact $n sur $nTotal';
  }

  @override
  String duplicatesSkipped(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n déjà présents écartés',
      one: '1 déjà présent écarté',
    );
    return '$_temp0';
  }

  @override
  String get optional => 'Facultatif';

  @override
  String restAtOnce(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Les $n restants d\'un coup…',
      one: 'Le dernier restant d\'un coup…',
    );
    return '$_temp0';
  }

  @override
  String get noneKept => 'Aucun contact retenu.';

  @override
  String nKept(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts retenus',
      one: '1 contact retenu',
    );
    return '$_temp0';
  }

  @override
  String nIgnored(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ignorés',
      one: '1 ignoré',
    );
    return '$_temp0';
  }

  @override
  String removeName(String name) {
    return 'Retirer $name';
  }

  @override
  String shareHandleText(String username, String link) {
    return 'Ajoute-moi sur SeeU : @$username\n$link';
  }

  @override
  String shareAppText(String url) {
    return 'Rejoins-moi sur SeeU, l\'app pour ne plus perdre de vue les gens qu\'on aime : $url';
  }

  @override
  String linkFriendTitle(String name) {
    return 'Associer $name';
  }

  @override
  String get linkFriendSub =>
      'Quel contact correspond à cet ami ? C\'est sa période qui sera remise à zéro quand vous validerez un rendez-vous ensemble.';

  @override
  String linkedFriendToContact(String friend, String contact) {
    return '$friend est associé au contact $contact';
  }

  @override
  String get createNewContact => 'Créer un nouveau contact';

  @override
  String get searchMyContacts => 'Rechercher dans mes contacts…';

  @override
  String get alreadyLinked => 'Déjà associé';

  @override
  String get suggested => 'Suggéré';

  @override
  String get contactUnlinked => 'Contact dissocié';

  @override
  String removeFriendTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get removeFriendMessage =>
      'Vos contacts et rendez-vous existants sont conservés, mais vous ne pourrez plus vous envoyer d\'invitations. Les invitations en attente sont annulées.';

  @override
  String get friendRemoved => 'Ami retiré';

  @override
  String get proposeRdv => 'Proposer un rendez-vous';

  @override
  String seeContactName(String name) {
    return 'Voir le contact $name';
  }

  @override
  String get linkToOtherContact => 'Associer à un autre contact';

  @override
  String get unlinkContact => 'Dissocier du contact';

  @override
  String get linkToContact => 'Associer à un contact';

  @override
  String get removeFromFriends => 'Retirer de mes amis';

  @override
  String linkContactToFriendTitle(String name) {
    return 'Associer $name à un ami SeeU';
  }

  @override
  String get linkContactToFriendSub =>
      'Vous pourrez lui envoyer vos rendez-vous et partager les photos. Chaque ami ne peut être associé qu\'à un seul contact.';

  @override
  String linkedContactToFriend(String contact, String friend) {
    return '$contact est associé à $friend';
  }

  @override
  String get noSeeuFriendsYet => 'Vous n\'avez pas encore d\'ami SeeU.';

  @override
  String get addSeeuFriendLong => 'Ajouter un ami SeeU';

  @override
  String linkedTo(String name) {
    return 'Associé à $name';
  }

  @override
  String get addFriendSub =>
      'Cherchez-le par son nom d\'utilisateur. Entre amis SeeU, vous partagez rendez-vous et photos.';

  @override
  String get searchFailed => 'Recherche impossible';

  @override
  String requestSentTo(String name) {
    return 'Demande envoyée à $name';
  }

  @override
  String alreadyInvitedYou(String name) {
    return '$name vous avait déjà invité : vous êtes maintenant amis !';
  }

  @override
  String get requestAlreadySent =>
      'Demande déjà envoyée, en attente de sa réponse.';

  @override
  String alreadyFriend(String name) {
    return '$name fait déjà partie de vos amis.';
  }

  @override
  String get accountGone => 'Ce compte n\'existe plus.';

  @override
  String get yourUsername => 'Votre nom d\'utilisateur :';

  @override
  String get share => 'Partager';

  @override
  String noAccountStartsWith(String handle) {
    return 'Aucun compte ne commence par $handle. Vérifiez l\'orthographe, ou invitez cette personne à créer son compte.';
  }

  @override
  String get sendAppLink => 'Envoyer le lien de l\'app';

  @override
  String get requestSent => 'Demande envoyée';

  @override
  String get alreadyInFriends => 'Déjà dans vos amis';

  @override
  String greetingName(String greeting, String name) {
    return '$greeting $name 👋';
  }

  @override
  String greetingAlone(String greeting) {
    return '$greeting 👋';
  }

  @override
  String get settings => 'Réglages';

  @override
  String get newRdv => 'Nouveau rendez-vous';

  @override
  String invitationsReceived(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Invitations reçues',
      one: 'Invitation reçue',
    );
    return '$_temp0';
  }

  @override
  String statContacts(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'contacts',
      one: 'contact',
      zero: 'contact',
    );
    return '$_temp0';
  }

  @override
  String get statOverdue => 'en retard';

  @override
  String get statUpcoming => 'rdv à venir';

  @override
  String get didTheyHappen => 'Ont-ils eu lieu ?';

  @override
  String get toReconnect => 'Garder le contact';

  @override
  String seeAllN(int n) {
    return 'Voir tout ($n)';
  }

  @override
  String get addSeeSoon => 'Ajouter quelqu\'un à voir bientôt';

  @override
  String get allUpToDate => 'Tout est à jour 🎉';

  @override
  String get allUpToDateMessage =>
      'Personne à recontacter pour l\'instant. Envie de voir quelqu\'un quand même ? Ajoutez-le avec le bouton +.';

  @override
  String get birthdaysThisWeek => 'Anniversaires cette semaine';

  @override
  String inNDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'dans $n jours',
      one: 'demain',
    );
    return '$_temp0';
  }

  @override
  String nYearsOld(int n) {
    return '$n ans';
  }

  @override
  String get nextRdvs => 'Prochains rendez-vous';

  @override
  String get noRdvPlanned => 'Aucun rendez-vous prévu';

  @override
  String get noRdvPlannedMessage =>
      'Planifiez un moment avec quelqu\'un que vous voulez revoir.';

  @override
  String get plan => 'Planifier';

  @override
  String moreRdvs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '+ $n autres rendez-vous planifiés',
      one: '+ 1 autre rendez-vous planifié',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Bienvenue sur SeeU';

  @override
  String get welcomeMessage =>
      'Ajoutez les personnes que vous voulez revoir régulièrement, choisissez une fréquence, et laissez l\'app vous rappeler quand il est temps de les recontacter.';

  @override
  String get addFirstContact => 'Ajouter mon premier contact';

  @override
  String birthdayOf(String name) {
    return '🎂 C\'est l\'anniversaire de $name !';
  }

  @override
  String turnsToday(int n) {
    return '$n ans aujourd\'hui ·';
  }

  @override
  String get wishThem => 'Pensez à lui souhaiter.';

  @override
  String get sendMessage => 'Envoyer un message';

  @override
  String get seen => 'Vu';

  @override
  String removedFromList(String name) {
    return '$name retiré(e) de la liste';
  }

  @override
  String get backToHome => 'Retour à l\'accueil';

  @override
  String get rdvGeneric => 'Rendez-vous';

  @override
  String get deleteRdvTitle => 'Supprimer ce rendez-vous ?';

  @override
  String get deleteRdvShared =>
      'Il sera supprimé chez vous uniquement (vos amis gardent le leur), et vos photos disparaîtront de la galerie commune. Cette action est définitive.';

  @override
  String get deleteRdvPrivate =>
      'Les photos associées seront supprimées. Cette action est définitive.';

  @override
  String get rdvDeleted => 'Rendez-vous supprimé';

  @override
  String get didItHappen => 'Ce rendez-vous a-t-il eu lieu ?';

  @override
  String get sharedRdvInfo =>
      'Rendez-vous partagé : date, lieu, titre et statut sont les mêmes pour tous. Vos notes restent privées.';

  @override
  String get participants => 'Participants';

  @override
  String get noParticipants => 'Aucun participant.';

  @override
  String get addToCalendar => 'Ajouter au calendrier';

  @override
  String get sharedPhotos => 'Photos partagées';

  @override
  String get photos => 'Photos';

  @override
  String get photosEmptyShared =>
      'Ajoutez des photos de ce moment : tous les participants les verront.';

  @override
  String get photosEmptyPrivate => 'Ajoutez des photos de ce moment.';

  @override
  String get deleteRdv => 'Supprimer le rendez-vous';

  @override
  String get invitedByFriend => 'Invitation d\'un ami SeeU';

  @override
  String proposedBy(String name) {
    return '$name vous a proposé ce rendez-vous';
  }

  @override
  String get rsvpPendingHelp =>
      'À confirmer : il est dans votre agenda, mais votre ami ne sait pas encore si vous venez.';

  @override
  String get rsvpAcceptedHelp =>
      'Vous avez accepté. Une fois validé, votre période avec ce contact repart de zéro.';

  @override
  String get rsvpDeclinedHelp =>
      'Vous avez refusé : il n\'apparaît plus dans vos listes.';

  @override
  String get sharing => 'Partage';

  @override
  String get sharingHelp =>
      'Si votre ami accepte, vous avez tous les deux le rendez-vous. Une fois validé, chacun voit sa période repartir de zéro, et les photos sont communes.';

  @override
  String get proposedThisRdv => 'Vous a proposé ce rendez-vous';

  @override
  String get friendNotInvited => 'Ami SeeU · pas encore invité';

  @override
  String get send => 'Envoyer';

  @override
  String invitationSentTo(String name) {
    return 'Invitation envoyée à $name';
  }

  @override
  String get invitationPending => 'Invitation envoyée · en attente';

  @override
  String get invitationCancelled => 'Invitation annulée';

  @override
  String get acceptedShared => 'A accepté · rendez-vous partagé';

  @override
  String get declinedInvitation => 'A décliné l\'invitation';

  @override
  String get resend => 'Renvoyer';

  @override
  String get editRdv => 'Modifier le rendez-vous';

  @override
  String get chooseOneContact => 'Choisissez au moins un contact.';

  @override
  String get rdvUpdated => 'Rendez-vous mis à jour';

  @override
  String get meetingRecorded => 'Rencontre enregistrée';

  @override
  String get rdvPlanned => 'Rendez-vous planifié';

  @override
  String get inviteSendFailed =>
      'Une invitation n\'a pas pu être envoyée : réessayez depuis le rendez-vous.';

  @override
  String invitationsSentN(int n) {
    return 'Invitations envoyées à $n amis';
  }

  @override
  String get titleExample => 'Ex. Déjeuner, café, visio…';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get planTheRdv => 'Planifier le rendez-vous';

  @override
  String get createContactFirst =>
      'Créez d\'abord un contact pour pouvoir planifier un rendez-vous.';

  @override
  String get createAContact => 'Créer un contact';

  @override
  String get date => 'Date';

  @override
  String get time => 'Heure';

  @override
  String get titleOptional => 'Titre';

  @override
  String get placeOptional => 'Lieu';

  @override
  String get placeHint => 'Café, adresse, visio…';

  @override
  String get notesOptional => 'Notes';

  @override
  String get notesPrivateHint =>
      'Toujours privées, même si le rendez-vous est partagé.';

  @override
  String get notesRdvHint => 'Idées de sujets, à ne pas oublier…';

  @override
  String get status => 'Statut';

  @override
  String get statusHintDone =>
      'La date de dernière rencontre des participants sera mise à jour.';

  @override
  String get statusHintCancelled => 'Il reste dans l\'historique comme annulé.';

  @override
  String get statusHintPlanned =>
      'Vous recevrez un rappel avant, puis pourrez le valider.';

  @override
  String get alreadyHappened => 'Ce rendez-vous a déjà eu lieu';

  @override
  String get alreadyHappenedHelp =>
      'Cochez pour noter une rencontre passée : elle va directement dans l\'historique et remet le compteur des participants à zéro.';

  @override
  String sendTo(String names) {
    return 'Envoyer à $names';
  }

  @override
  String get shareOffHelp =>
      'Le rendez-vous reste uniquement chez vous. Vous pourrez l\'envoyer plus tard depuis sa fiche.';

  @override
  String get shareDoneHelp =>
      'Votre ami recevra cette rencontre : s\'il l\'accepte, sa période est remise à zéro et vous partagez les photos.';

  @override
  String get sharePlannedHelp =>
      'Votre ami reçoit une invitation : s\'il accepte, vous avez tous les deux le rendez-vous et une galerie de photos commune. Vos notes restent privées.';

  @override
  String get photosAfterSave =>
      'Vous pourrez ajouter des photos une fois le rendez-vous enregistré.';

  @override
  String get kindDueDigest => 'Contacts à recontacter';

  @override
  String get kindBirthday => 'Anniversaire';

  @override
  String get kindRdvReminder => 'Rappel de rendez-vous';

  @override
  String get kindRdvFollowup => 'Suivi de rendez-vous';

  @override
  String get kindFriendRequest => 'Demande d\'ami';

  @override
  String get kindFriendAccept => 'Ami accepté';

  @override
  String get kindRdvInvite => 'Invitation à un rendez-vous';

  @override
  String get kindRdvResponse => 'Réponse à une invitation';

  @override
  String get kindRdvChange => 'Rendez-vous partagé modifié';

  @override
  String get kindWave => 'Envie de se voir';

  @override
  String get kindTest => 'Test';

  @override
  String get privacyFooter =>
      'SeeU · Vos données restent privées : seuls les rendez-vous que vous envoyez à un ami sont partagés avec lui.';

  @override
  String get profileUpdated => 'Profil mis à jour';

  @override
  String get profile => 'Profil';

  @override
  String get yourFirstName => 'Votre prénom';

  @override
  String get birthDateFriendsHint =>
      'Visible par vos amis SeeU uniquement : leur fiche à votre nom se remplit toute seule.';

  @override
  String get shareMyHandle => 'Partager mon @';

  @override
  String get emailNeverShown =>
      'Jamais affiché aux autres utilisateurs avant qu\'ils soient vos amis';

  @override
  String get timezone => 'Fuseau horaire';

  @override
  String get timezoneHint =>
      'Détecté automatiquement, utilisé pour l\'heure des rappels';

  @override
  String get pushDisabledDevice => 'Notifications désactivées sur cet appareil';

  @override
  String get pushEnabledDevice => 'Notifications activées sur cet appareil';

  @override
  String get pushPermissionDenied =>
      'Permission refusée : autorisez les notifications dans les réglages de l\'appareil.';

  @override
  String get testSent => 'Notification de test envoyée';

  @override
  String get pushUnsupported =>
      'Notifications push indisponibles sur cette version ; les rappels partiront par email.';

  @override
  String get pushBlockedSettings =>
      'Notifications bloquées : autorisez-les dans les réglages du téléphone.';

  @override
  String get pushOnDevice => 'Activées sur cet appareil';

  @override
  String get disable => 'Désactiver';

  @override
  String get pushOffDevice => 'Non activées sur cet appareil';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushReminders => 'Rappels push';

  @override
  String get pushRemindersSub =>
      'Sur tous les appareils où vous les avez activées';

  @override
  String get emailReminders => 'Rappels par email';

  @override
  String get emailRemindersSub =>
      'Utilisés si aucun appareil n\'a les notifications push activées';

  @override
  String get dailyHour => 'Heure du rappel quotidien';

  @override
  String get dailyHourHint =>
      'Un seul récapitulatif par jour des contacts à recontacter';

  @override
  String get notifyLead => 'Prévenir';

  @override
  String get leadSameDay => 'Le jour de l\'échéance';

  @override
  String leadDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n jours avant',
      one: '1 jour avant',
    );
    return '$_temp0';
  }

  @override
  String leadWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n semaines avant',
      one: '1 semaine avant',
    );
    return '$_temp0';
  }

  @override
  String get rdvReminderLead => 'Rappel avant un rendez-vous';

  @override
  String leadMinutes(int n) {
    return '$n minutes avant';
  }

  @override
  String leadHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n heures avant',
      one: '1 heure avant',
    );
    return '$_temp0';
  }

  @override
  String get leadEve => 'La veille (24 h avant)';

  @override
  String get sendTestNotification => 'Envoyer une notification de test';

  @override
  String get lastNotifications => 'Dernières notifications';

  @override
  String get noNotificationsYet =>
      'Aucune notification envoyée pour l\'instant.';

  @override
  String get channelNone => 'aucun';

  @override
  String get application => 'Application';

  @override
  String get version => 'Version';

  @override
  String get exportSubject => 'Export SeeU';

  @override
  String get data => 'Données';

  @override
  String get importFromPhoneLong => 'Importer des contacts du téléphone';

  @override
  String get importFromPhoneSub =>
      'Depuis le carnet d\'adresses, avec revue contact par contact.';

  @override
  String get exportData => 'Exporter mes données';

  @override
  String get exportDataSub =>
      'Profil, contacts, rendez-vous et liste des photos.';

  @override
  String get deleteAccountTitle => 'Supprimer définitivement votre compte ?';

  @override
  String get deleteAccountMessage =>
      'Tous vos contacts, rendez-vous et photos seront effacés. Cette action est irréversible.';

  @override
  String get deleteMyAccount => 'Supprimer mon compte';

  @override
  String get accountDeleted => 'Compte supprimé';

  @override
  String get account => 'Compte';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get passwordsNoMatch => 'Les deux mots de passe ne correspondent pas.';

  @override
  String get confirm => 'Confirmer';

  @override
  String get visPrivate => 'Privé';

  @override
  String get visContacts => 'Entre amis';

  @override
  String get visPublic => 'Public';

  @override
  String eventBy(String name) {
    return 'Événement de $name';
  }

  @override
  String get sponsored => 'Sponsorisé';

  @override
  String get dateToChoose => 'Date à confirmer';

  @override
  String get byYou => 'Par vous';

  @override
  String nGoing(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n participants',
      one: '1 participant',
      zero: 'Personne pour l\'instant',
    );
    return '$_temp0';
  }

  @override
  String get youreGoing => 'Vous y allez';

  @override
  String get homeAgenda => 'Mon agenda';

  @override
  String get homeFriends => 'Entre amis';

  @override
  String get homeExplore => 'Explorer';

  @override
  String get exploreIntro =>
      'Les événements publics à venir : concerts, sorties, rencontres… Rejoignez ceux qui vous tentent.';

  @override
  String get friendsFeedIntro =>
      'Les événements que vos amis ouvrent à tous leurs amis. Vous pouvez les rejoindre directement.';

  @override
  String get exploreEmptyTitle => 'Aucun événement public pour l\'instant';

  @override
  String get exploreEmptyMessage =>
      'Revenez bientôt : les événements ouverts à tous apparaîtront ici.';

  @override
  String get friendsFeedEmptyTitle => 'Rien de prévu entre amis';

  @override
  String get friendsFeedEmptyMessage =>
      'Quand un ami crée un événement « Entre amis », il apparaît ici. Lancez le vôtre !';

  @override
  String get createFriendsEvent => 'Créer un événement entre amis';

  @override
  String get loadMore => 'Voir plus';

  @override
  String get exploreSearchHint => 'Rechercher (titre, lieu, @organisateur)';

  @override
  String get slotsAtLeastTwo => 'Proposez au moins deux créneaux différents.';

  @override
  String get proposeSlots => 'Proposer ces créneaux';

  @override
  String get whoCanSee => 'Qui peut le voir ?';

  @override
  String get memberEditHint =>
      'Vous participez à cet événement : seul l\'organisateur peut changer la date, le lieu ou l\'annuler. Vos notes, vos contacts et le statut restent à vous.';

  @override
  String get withWhomOptional => 'Avec qui ?';

  @override
  String get withWhomHint =>
      'Vos contacts qui viennent : leur compteur repart de zéro une fois l\'événement passé.';

  @override
  String get oneDate => 'Une date';

  @override
  String get severalSlots => 'Plusieurs créneaux';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionHint =>
      'Visible par tous ceux qui voient l\'événement.';

  @override
  String get descriptionPlaceholder => 'Programme, ce qu\'il faut apporter…';

  @override
  String get statusHintCancelledAll =>
      'L\'événement est annulé pour tous les participants.';

  @override
  String get shareSlotsHelp =>
      'Vos amis reçoivent les créneaux et indiquent leurs disponibilités. Vous choisissez ensuite la date.';

  @override
  String get contactsBroadcastHint =>
      'Tous vos amis SeeU seront prévenus et pourront le rejoindre.';

  @override
  String get publicPhotosHint =>
      'Événement public : vous seul pourrez publier des annonces et des photos.';

  @override
  String get publicReserved =>
      'Réservé aux organisateurs vérifiés pour l\'instant.';

  @override
  String get visPrivateHelp =>
      'Par défaut. Seulement les personnes que vous invitez ; jamais sur votre profil ni dans Explorer.';

  @override
  String get visContactsHelp =>
      'Tous vos amis SeeU le voient et peuvent le rejoindre.';

  @override
  String get visPublicHelp =>
      'Tout le monde peut le voir et le rejoindre sans invitation, y compris depuis votre profil public.';

  @override
  String get slotsLabel => 'Créneaux proposés';

  @override
  String get slotsHint =>
      'Chaque participant indique s\'il est disponible ; vous choisissez ensuite le meilleur créneau.';

  @override
  String get addSlot => 'Ajouter un créneau';

  @override
  String get slotsPollTitle => 'Quand êtes-vous disponible ?';

  @override
  String get slotsPollHelp =>
      'Pour chaque créneau : ✓ disponible, ? peut-être, ✗ pas disponible.';

  @override
  String get slotYes => 'Disponible';

  @override
  String get slotMaybe => 'Peut-être';

  @override
  String get slotNo => 'Pas disponible';

  @override
  String get slotMaybeShort => 'peut-être';

  @override
  String slotCounts(int nYes, int nMaybe) {
    String _temp0 = intl.Intl.pluralLogic(
      nYes,
      locale: localeName,
      other: '$nYes dispo',
      one: '1 dispo',
      zero: '0 dispo',
    );
    return '$_temp0 · $nMaybe peut-être';
  }

  @override
  String get choose => 'Choisir';

  @override
  String chooseSlotTitle(String when) {
    return 'Fixer la date au $when ?';
  }

  @override
  String get chooseSlotMessage =>
      'Le vote se termine et tous les participants sont prévenus de la date choisie.';

  @override
  String get chooseThisSlot => 'Choisir ce créneau';

  @override
  String get slotChosen => 'Date choisie, les participants sont prévenus';

  @override
  String get slotsNoVotes => 'Pas encore de réponses';

  @override
  String get bestSlot => 'Meilleur créneau';

  @override
  String get bestSlotsTie => 'Meilleurs créneaux (ex æquo)';

  @override
  String get slotsWaitOrganizer =>
      'Vos invités vont indiquer leurs disponibilités. Vous serez prévenu, puis vous choisirez la date.';

  @override
  String get slotsWaitMember =>
      'Indiquez vos disponibilités : l\'organisateur choisira ensuite la date.';

  @override
  String get slotsOrganizerDecides =>
      'L\'organisateur choisira la date définitive.';

  @override
  String get eventMuted => 'Notifications de cet événement coupées';

  @override
  String get eventUnmuted => 'Notifications de cet événement réactivées';

  @override
  String personMuted(String name) {
    return 'Événements et messages de $name masqués';
  }

  @override
  String personUnmuted(String name) {
    return '$name n\'est plus masqué(e)';
  }

  @override
  String blockTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get blockMessage =>
      'Vous ne serez plus amis, vous ne verrez plus ses événements ni ses messages, et vous ne pourrez plus vous trouver ni vous inviter. Vous pourrez le débloquer dans les Réglages.';

  @override
  String get block => 'Bloquer';

  @override
  String blocked(String name) {
    return '$name est bloqué(e)';
  }

  @override
  String mutePerson(String name) {
    return 'Masquer les événements de $name';
  }

  @override
  String unmutePerson(String name) {
    return 'Ne plus masquer $name';
  }

  @override
  String blockName(String name) {
    return 'Bloquer $name';
  }

  @override
  String get announcements => 'Annonces';

  @override
  String get chat => 'Discussion';

  @override
  String get announceEmptyOrganizer =>
      'Publiez des annonces : tous les participants confirmés seront prévenus.';

  @override
  String get announceEmpty => 'Pas encore d\'annonce de l\'organisateur.';

  @override
  String get chatEmpty => 'Pas encore de message. Lancez la discussion !';

  @override
  String get openAnnouncements => 'Voir les annonces';

  @override
  String get openChat => 'Ouvrir la discussion';

  @override
  String nNew(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nouveaux',
      one: '1 nouveau',
    );
    return '$_temp0';
  }

  @override
  String get deleteMessage => 'Supprimer le message';

  @override
  String get announceHint => 'Une annonce pour les participants…';

  @override
  String get messageHint => 'Votre message…';

  @override
  String get announceReadOnly =>
      'Seul l\'organisateur publie ici. Vous êtes prévenu à chaque annonce si vous venez.';

  @override
  String get chatJoinToPost => 'Rejoignez l\'événement pour écrire.';

  @override
  String get moreActions => 'Plus d\'actions';

  @override
  String get muteEvent => 'Couper les notifications de cet événement';

  @override
  String get unmuteEvent => 'Réactiver les notifications de cet événement';

  @override
  String get joinedToast => 'C\'est noté, vous y allez !';

  @override
  String get notGoingToast => 'C\'est noté, vous n\'y allez pas';

  @override
  String organizedBy(String name) {
    return 'Organisé par $name';
  }

  @override
  String get eventCancelledInfo =>
      'Cet événement a été annulé par l\'organisateur.';

  @override
  String get joinToVote => 'Rejoignez-le pour indiquer vos disponibilités';

  @override
  String get areYouComing => 'Vous venez ?';

  @override
  String get joinPublicHint =>
      '« À confirmer » l\'ajoute à votre agenda sans engagement. Vous recevrez les annonces de l\'organisateur si vous venez.';

  @override
  String get joinFriendsHint =>
      'L\'organisateur est prévenu quand vous venez. « À confirmer » l\'ajoute à votre agenda sans engagement.';

  @override
  String get moderationTitle => 'Masqués et bloqués';

  @override
  String get moderationIntro =>
      'Masquer coupe les notifications et retire les événements des fils. Bloquer coupe tout contact avec la personne.';

  @override
  String get mutedPeopleAndEvents => 'Personnes et événements masqués';

  @override
  String get nothingMuted => 'Rien de masqué.';

  @override
  String get eventsMuted => 'événements et messages masqués';

  @override
  String get unmute => 'Réactiver';

  @override
  String get blockedPeople => 'Personnes bloquées';

  @override
  String get nobodyBlocked => 'Personne n\'est bloqué.';

  @override
  String get unblock => 'Débloquer';

  @override
  String unblocked(String name) {
    return '$name est débloqué(e)';
  }

  @override
  String get unblockHint =>
      'Débloquer ne rétablit pas l\'amitié : il faudra renvoyer une demande.';

  @override
  String get mutedAndBlocked => 'Masqués et bloqués';

  @override
  String get mutedAndBlockedSub =>
      'Personnes et événements que vous avez masqués ou bloqués.';

  @override
  String get leaveEventTitle => 'Retirer cet événement de votre agenda ?';

  @override
  String get leaveEventMessage =>
      'Vous ne participerez plus et vos photos disparaîtront de la galerie commune. Vous pourrez le rejoindre à nouveau s\'il est encore visible.';

  @override
  String get removeFromAgenda => 'Retirer de mon agenda';

  @override
  String get myContactsInEvent => 'Mes contacts';

  @override
  String get photosEmptyPublicMember =>
      'L\'organisateur partagera ici les photos de l\'événement.';

  @override
  String get you => 'Vous';

  @override
  String get organizer => 'Organisateur';

  @override
  String andNMore(int n) {
    return 'et $n autres';
  }

  @override
  String get kindEventNew => 'Nouvel événement entre amis';

  @override
  String get kindEventJoin => 'Participant à votre événement';

  @override
  String get kindEventMessage => 'Message dans un événement';

  @override
  String get kindEventAnnouncement => 'Annonce d\'un événement';

  @override
  String get deleteRdvOrganizerPlanned =>
      'Vous êtes l\'organisateur : l\'événement sera annulé pour tous les participants (ils seront prévenus), puis retiré de votre agenda.';

  @override
  String get availabilitySaved => 'Disponibilités enregistrées';

  @override
  String get availabilitySentGoing =>
      'Disponibilités envoyées : vous êtes noté comme participant';

  @override
  String get availabilitySentDeclined =>
      'Vous avez décliné l\'événement, l\'organisateur est prévenu';

  @override
  String get confirmAvailabilityTitle => 'Envoyer vos disponibilités ?';

  @override
  String unansweredAsMaybe(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n créneaux sans réponse seront comptés « peut-être ».',
      one: '1 créneau sans réponse sera compté « peut-être ».',
    );
    return '$_temp0';
  }

  @override
  String get confirmAndDecline => 'Décliner l\'événement';

  @override
  String get confirmAvailability => 'Valider mes disponibilités';

  @override
  String get leaveWithoutSending => 'Quitter sans envoyer';

  @override
  String get outcomeGoing =>
      'Vous êtes disponible au moins une fois : vous serez noté comme participant et l\'organisateur sera prévenu.';

  @override
  String get outcomeDeclined =>
      'Aucun créneau ne vous convient : l\'événement sera décliné et l\'organisateur prévenu.';

  @override
  String get outcomeMaybe =>
      'Rien de sûr pour l\'instant : l\'événement reste « à confirmer », sans prévenir l\'organisateur.';

  @override
  String get yourAnswer => 'Votre réponse :';

  @override
  String get availabilitySent => 'Disponibilités envoyées';

  @override
  String get notSentYet => 'non envoyé';

  @override
  String get severalSlotsProposed => 'Plusieurs créneaux proposés';

  @override
  String get giveAvailability => 'Indiquer mes disponibilités';

  @override
  String get slotsInviteHint =>
      'Ouvrez l\'événement pour répondre créneau par créneau.';

  @override
  String get guestsCanInvite => 'Les invités peuvent inviter leurs amis';

  @override
  String get guestsCanInviteHelp =>
      'Sinon, vous seul pouvez ajouter des participants.';

  @override
  String blockContactDeleted(String name) {
    return 'Votre contact « $name » sera aussi supprimé : plus de rappels pour le revoir.';
  }

  @override
  String blockedAndDeleted(String name) {
    return '$name est bloqué(e) et son contact supprimé';
  }

  @override
  String get demoAds => 'Publicités de démonstration';

  @override
  String get demoAdsHelp =>
      'Affiche de fausses annonces pour juger de leur intégration (mode développement).';

  @override
  String get adCta => 'En savoir plus';

  @override
  String get earlierMessages => 'Messages précédents';

  @override
  String get tagPersonal => '(personnel)';

  @override
  String get tagShared => '(partagée)';

  @override
  String get titleRequired => 'Donnez un titre au rendez-vous';

  @override
  String get descriptionHintAll => 'Visible par tous les participants.';

  @override
  String get editFrequency => 'Modifier la fréquence';

  @override
  String frequencySheetSub(String name) {
    return 'À quelle fréquence voulez-vous voir $name ?';
  }

  @override
  String get frequencyUpdated => 'Fréquence mise à jour';

  @override
  String get organizedByYou => 'Organisé par vous';

  @override
  String get youAreGuest => 'Invité';

  @override
  String get filterMine => 'Organisés par vous';

  @override
  String get filterInvited => 'Invitations';

  @override
  String get noMineUpcoming => 'Aucun rendez-vous organisé par vous.';

  @override
  String get noInvitedUpcoming => 'Aucune invitation à venir.';

  @override
  String get notOnSeeu => 'Pas sur SeeU';

  @override
  String notOnSeeuAddedBy(String name) {
    return 'Pas sur SeeU · ajouté par $name';
  }

  @override
  String get memberPending => 'À confirmer';

  @override
  String get inviteFriend => 'Inviter';

  @override
  String get peopleLegend =>
      'Icône grise : pas de compte SeeU. Seuls les amis SeeU reçoivent l\'invitation, voient le chat et les photos.';

  @override
  String get leftEvent => 'A quitté le rendez-vous';

  @override
  String get reinvite => 'Réinviter';

  @override
  String get phaseUpcoming => 'Prévu';

  @override
  String get phaseNow => 'En cours';

  @override
  String get phasePast => 'Passé';

  @override
  String get keepInTouchHelp =>
      'Rappels selon la fréquence choisie pour chaque contact. Rien n\'est prévu : planifiez un rendez-vous, ou notez que vous vous êtes vus.';

  @override
  String get usernameFixed =>
      'Votre identifiant ne peut pas être modifié : c\'est grâce à lui que vos amis vous trouvent.';

  @override
  String get slotsPollHelpOrganizer =>
      'Vous avez proposé ces créneaux : vous êtes compté comme disponible sur chacun. Voici les réponses des participants.';

  @override
  String get slotNoAnswerYet => 'Pas encore de réponse';

  @override
  String slotYesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n disponibles',
      one: '1 disponible',
    );
    return '$_temp0';
  }

  @override
  String slotMaybeCount(int n) {
    return '$n peut-être';
  }

  @override
  String slotNoCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pas dispo',
      one: '1 pas dispo',
    );
    return '$_temp0';
  }

  @override
  String get slotsOrganizerOnlyFree =>
      'Proposez uniquement des créneaux où vous êtes disponible : vous êtes compté comme disponible sur chacun.';

  @override
  String findContactOnSeeu(String name) {
    return '$name sur SeeU';
  }

  @override
  String findContactOnSeeuSub(String name) {
    return 'Cherchez son @identifiant : une fois la demande acceptée, la fiche de $name est liée et ses rendez-vous à venir avec vous sont partagés.';
  }

  @override
  String get friendRequestPending => 'Demande d\'ami SeeU envoyée · en attente';

  @override
  String friendRequestPendingHelp(String name) {
    return 'Dès que $name accepte, sa fiche est liée et vos rendez-vous à venir sont partagés.';
  }

  @override
  String get cancelRequest => 'Annuler la demande';

  @override
  String get findOnSeeu => 'Pas encore ami : chercher son @identifiant';

  @override
  String get avatarHint =>
      'Visible par vos amis et les participants de vos rendez-vous.';

  @override
  String get avatarUpdated => 'Photo de profil mise à jour';

  @override
  String get avatarRemoved => 'Photo de profil retirée';

  @override
  String get errBadLink =>
      'Ce lien n\'est pas valide (ex. : www.exemple.be ou exemple.com/page).';

  @override
  String get linkLabel => 'Lien';

  @override
  String get linkHint => 'Billetterie, menu, page de l\'événement…';

  @override
  String get placeSearchHint => 'Bar, restaurant, adresse… ou texte libre';

  @override
  String get placeFreeTextHint =>
      'Pas dans la liste ? Gardez simplement votre texte.';

  @override
  String get placeSearchFailed =>
      'Recherche de lieux indisponible : votre texte sera gardé tel quel.';

  @override
  String get openInMaps => 'Itinéraire';

  @override
  String get historyMap => 'Carte';

  @override
  String get historyMapEmpty =>
      'Les rendez-vous dont le lieu a été choisi dans la recherche apparaîtront ici.';

  @override
  String get openEvent => 'Voir le rendez-vous';

  @override
  String get welcomeFriendsTitle => 'Vos amis SeeU';

  @override
  String welcomeFriendsMessage(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Vous avez $n amis SeeU sans fiche contact : associez-les pour que SeeU vous rappelle de les voir.',
      one: 'Vous avez 1 ami SeeU sans fiche contact : associez-le pour que SeeU vous rappelle de le voir.',
    );
    return '$_temp0';
  }

  @override
  String get quickHowOften => 'À quelle fréquence ?';

  @override
  String get quickCategory => 'Catégorie';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get associate => 'Associer';

  @override
  String friendNowContact(String name) {
    return '$name est maintenant dans vos contacts';
  }

  @override
  String get contactLinkHint =>
      'Facultatif. Lié à son compte SeeU, vous pourrez partager rendez-vous et photos.';

  @override
  String get contactLinkSheetSub =>
      'Un de vos amis SeeU, ou cherchez son @identifiant : la demande d\'ami partira à l\'enregistrement.';

  @override
  String get orFindByUsername => 'Pas encore ami ? Cherchez son @identifiant';

  @override
  String get requestSentOnSave => 'demande envoyée à l\'enregistrement';

  @override
  String get clearField => 'Effacer';

  @override
  String get placeAtMine => 'Chez moi';

  @override
  String get placeVideo => 'En visio';

  @override
  String get placeTbd => 'Lieu à définir';

  @override
  String placeUseText(String text) {
    return 'Utiliser « $text »';
  }

  @override
  String get placeUseTextSub => 'Tel quel, sans adresse ni carte';

  @override
  String get requestAlreadySentLinked =>
      'demande déjà envoyée : elle sera liée à ce contact';

  @override
  String get requestReceivedAcceptOnSave =>
      'vous a envoyé une demande : acceptée à l\'enregistrement';

  @override
  String get requestPendingShort => 'Demande envoyée';

  @override
  String get requestReceivedShort => 'Vous a demandé';

  @override
  String get seeuFriendShort => 'Ami SeeU';

  @override
  String get prevWeek => 'Semaine précédente';

  @override
  String get nextWeek => 'Semaine suivante';

  @override
  String get calendarMonth => 'Mois';

  @override
  String get calendarWeek => 'Semaine';

  @override
  String get nothingThatDay => 'Rien de prévu ce jour-là.';

  @override
  String nEventsHere(int n) {
    return '$n rendez-vous ici';
  }

  @override
  String get tabLink => 'Lier';

  @override
  String get tabCreate => 'Créer';

  @override
  String get noContactToLink => 'Aucun contact libre à lier : créez-en un.';

  @override
  String get searchContactToLink => 'Chercher un de mes contacts…';

  @override
  String get noSuggestionSearch =>
      'Pas de suggestion : cherchez le contact à lier.';

  @override
  String get link => 'Lier';

  @override
  String get fullForm => 'Formulaire';

  @override
  String get createContactShort => 'Créer';

  @override
  String get friendsToAssociate => 'Amis SeeU à associer';

  @override
  String get friendsToAssociateHelp =>
      'Liez chacun à un de vos contacts, ou créez-lui une fiche : SeeU vous rappellera de le voir, et vous partagerez rendez-vous et photos.';

  @override
  String get friendVsContactTitle => 'Contact ou ami SeeU ?';

  @override
  String get helpContactTitle => 'Contact';

  @override
  String get helpContactText =>
      'Une fiche privée, rien que pour vous : à quelle fréquence vous voulez voir la personne, vos notes, ses infos. Elle n\'a pas besoin de SeeU.';

  @override
  String get helpFriendTitle => 'Ami SeeU';

  @override
  String get helpFriendText =>
      'Une personne qui a SeeU et avec qui vous êtes amis (via son @identifiant) : vous pouvez l\'inviter, partager rendez-vous, discussions et photos. Repérable à l\'icône 🤝.';

  @override
  String get helpLinkTitle => 'Les deux, liés';

  @override
  String get helpLinkText =>
      'Liez la fiche d\'un contact à son compte SeeU : vous gardez vos rappels et notes, et vos rendez-vous avec lui sont partagés.';

  @override
  String contactFromFriendBanner(String name) {
    return 'Fiche liée à votre ami SeeU $name : vous partagerez rendez-vous et photos, et sa photo de profil est utilisée.';
  }

  @override
  String get manageContacts => 'Gérer mes contacts';

  @override
  String get quickBirthday => 'Anniversaire';

  @override
  String get optionalShort => 'Facultatif';

  @override
  String get toFixTitle => 'À fixer';

  @override
  String get toFixHelp =>
      'Date pas encore choisie : répondez aux créneaux, l\'organisateur fixe ensuite la date.';

  @override
  String answeredCount(int n, int nTotal) {
    return '$n/$nTotal ont répondu';
  }

  @override
  String get bestShort => 'Meilleur :';

  @override
  String yourTurnToAnswer(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'À vous de répondre · $n créneaux',
      one: 'À vous de répondre · 1 créneau',
    );
    return '$_temp0';
  }

  @override
  String availabilitySentShort(int nYes, int nMaybe) {
    return 'Dispos envoyées · $nYes oui, $nMaybe peut-être';
  }

  @override
  String nSlots(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n créneaux',
      one: '1 créneau',
    );
    return '$_temp0';
  }

  @override
  String get proposedSlotsThatDay => 'Créneaux proposés ce jour';

  @override
  String get youProposed => 'Proposé par vous';

  @override
  String get notAnswered => 'Pas répondu';

  @override
  String heldDayWarning(String title, String time) {
    return 'Vous êtes disponible ce jour-là pour un créneau de « $title » ($time), dont la date n\'est pas encore fixée.';
  }

  @override
  String get legendFixed => 'date fixée';

  @override
  String get legendProposed => 'créneau proposé (date à choisir)';

  @override
  String get waitingForOrganizer =>
      'En attente de l\'organisateur pour fixer la date';

  @override
  String get waitingForAnswers => 'En attente des réponses';

  @override
  String get yourTurnToChoose => 'À vous de choisir la date';

  @override
  String get yourAnswerShort => 'Votre réponse :';

  @override
  String dateConfirmedBy(String name) {
    return 'Date à confirmer par $name';
  }

  @override
  String get dateYouSet => 'Vous fixez la date';

  @override
  String get proposedSlot => 'Créneau proposé';

  @override
  String get keyboardDone => 'OK';

  @override
  String get messageShort => 'Message';

  @override
  String get addPeople => 'Ajouter des personnes';

  @override
  String get addPeopleSub => 'Parmi vos contacts';

  @override
  String get addPeopleHelp =>
      'Vos amis SeeU reçoivent une invitation. Les autres apparaissent aux participants avec la mention « Pas sur SeeU ».';

  @override
  String addNPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ajouter $n personnes',
      one: 'Ajouter 1 personne',
    );
    return '$_temp0';
  }

  @override
  String peopleAdded(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n personnes ajoutées',
      one: '1 personne ajoutée',
    );
    return '$_temp0';
  }

  @override
  String get myNotes => 'Mes notes';

  @override
  String get notesOnlyYou =>
      'Visibles par vous seul, même si le rendez-vous est partagé.';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get noReminder => 'Pas de rappel récurrent';

  @override
  String get noReminderShort => 'Sans rappel';

  @override
  String get freqNever => 'Aucun rappel';

  @override
  String get noReminderHelp =>
      'Pas de rappel : ce contact n\'apparaîtra jamais dans « Garder le contact ».';

  @override
  String get addAsFriend => 'Ajouter en ami SeeU';

  @override
  String get friendRequestSentShort => 'Demande envoyée';

  @override
  String get publicProfileTitle => 'Profil public et partage';

  @override
  String get publicProfileRowSub =>
      'Votre lien, ce que les autres voient, vos événements publics';

  @override
  String get myProfileLink => 'Votre lien de profil';

  @override
  String get myProfileLinkHelp =>
      'Partagez-le sur Instagram, WhatsApp, Messenger… Il ouvre votre profil dans SeeU, ou propose d\'installer l\'app.';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get linkCopied => 'Lien copié';

  @override
  String get showQrCode => 'QR code';

  @override
  String get qrCodeTitle => 'Votre QR code SeeU';

  @override
  String get qrCodeHelp =>
      'Faites-le scanner : votre profil s\'ouvre, prêt à vous ajouter en ami.';

  @override
  String shareProfileText(String username, String link) {
    return 'Retrouvez-moi sur SeeU : @$username\n$link';
  }

  @override
  String get shareMyProfile => 'Partager mon profil';

  @override
  String get publicProfileToggle => 'Profil public';

  @override
  String get publicProfileToggleSub =>
      'Une page web, visible par tous ceux qui ont le lien, avec seulement les informations choisies ci-dessous.';

  @override
  String get publicProfileOffInfo =>
      'Désactivé : votre lien ouvre toujours SeeU, mais il n\'y a pas de page publique.';

  @override
  String get publicFieldsTitle => 'Informations visibles';

  @override
  String get publicFieldAvatar => 'Photo de profil';

  @override
  String get publicFieldName => 'Nom affiché';

  @override
  String get publicFieldCity => 'Ville de résidence';

  @override
  String get publicFieldBio => 'Bio';

  @override
  String get publicFieldsHelp =>
      'Votre @pseudo est toujours visible : c\'est l\'adresse de la page. Votre e-mail et vos contacts ne le sont jamais.';

  @override
  String get publicEventsTitle => 'Événements affichés';

  @override
  String get publicEventsNone => 'Aucun';

  @override
  String get publicEventsSelected => 'Choisis';

  @override
  String get publicEventsAll => 'Tous';

  @override
  String get publicEventsHelp =>
      'Seulement des événements publics (organisés ou rejoints). Les événements privés ou entre amis n\'apparaissent jamais.';

  @override
  String get publicEventsPick => 'Événements à afficher';

  @override
  String get noPublicEventsYet =>
      'Aucun événement public à venir, organisé ou rejoint.';

  @override
  String get inAppVisibilityTitle => 'Dans l\'app';

  @override
  String get inAppVisibilityHelp =>
      'Les membres SeeU voient toujours votre nom, votre @pseudo et votre photo (comme dans la recherche). Vos amis voient aussi votre bio et vos événements « Entre amis ».';

  @override
  String get friendsSeeCity => 'Mes amis voient ma ville';

  @override
  String get friendsSeeCitySub =>
      'Pour vous suggérer l\'un à l\'autre quand vous passez dans la ville de l\'autre.';

  @override
  String get previewMyProfile => 'Voir mon profil';

  @override
  String get cityLabel => 'Ville de résidence';

  @override
  String get cityHint => 'Rechercher une ville';

  @override
  String get cityHelp => 'Sert à vous suggérer qui voir quand vous voyagez.';

  @override
  String get bioLabel => 'Bio';

  @override
  String get bioHint => 'Quelques mots sur vous';

  @override
  String get contactCityLabel => 'Ville';

  @override
  String get contactCityHelp =>
      'Là où cette personne habite : SeeU vous le rappellera quand vous irez par là.';

  @override
  String livesIn(String city) {
    return 'Habite à $city';
  }

  @override
  String get userProfileTitle => 'Profil';

  @override
  String get profileNotFound => 'Profil introuvable';

  @override
  String get profileNotFoundMessage =>
      'Ce profil n\'existe pas ou n\'est plus disponible.';

  @override
  String get requestSentButton => 'Demande envoyée';

  @override
  String get acceptRequest => 'Accepter sa demande';

  @override
  String get alreadyFriends => 'Vous êtes amis sur SeeU';

  @override
  String get addToMyContacts => 'Ajouter à mes contacts';

  @override
  String get seeContactCard => 'Voir sa fiche contact';

  @override
  String mutualFriends(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n amis en commun',
      one: '1 ami en commun',
    );
    return '$_temp0';
  }

  @override
  String get theirEvents => 'Prochains événements';

  @override
  String get noVisibleEvents => 'Aucun événement visible pour l\'instant.';

  @override
  String get thisIsYou => 'C\'est votre profil, tel que vos amis le voient.';

  @override
  String get editMyProfile => 'Modifier';

  @override
  String get seeSeeuProfile => 'Voir son profil SeeU';

  @override
  String get roleOrganizer => 'Organise';

  @override
  String get roleGoing => 'Participe';

  @override
  String get report => 'Signaler';

  @override
  String reportPerson(String name) {
    return 'Signaler $name';
  }

  @override
  String get reportEvent => 'Signaler l\'événement';

  @override
  String get reportMessage => 'Signaler ce message';

  @override
  String get reportPhoto => 'Signaler cette photo';

  @override
  String get reportSub =>
      'Votre signalement reste anonyme : la personne ne saura pas que c\'est vous.';

  @override
  String get reportReason => 'Motif';

  @override
  String get reasonSpam => 'Spam ou publicité';

  @override
  String get reasonHarassment => 'Harcèlement ou intimidation';

  @override
  String get reasonInappropriate => 'Contenu inapproprié';

  @override
  String get reasonFakeProfile => 'Faux profil';

  @override
  String get reasonOther => 'Autre';

  @override
  String get reportComment => 'Commentaire (facultatif)';

  @override
  String get reportCommentHint => 'Ce qui s\'est passé, en quelques mots';

  @override
  String get reportAlsoBlock => 'Bloquer aussi cette personne';

  @override
  String get sendReport => 'Envoyer le signalement';

  @override
  String get reportSent => 'Merci, notre équipe va examiner ce signalement.';

  @override
  String get bannedTitle => 'Compte suspendu';

  @override
  String get bannedMessage =>
      'Ce compte SeeU a été suspendu pour non-respect des règles d\'utilisation. Il ne peut plus être utilisé.';

  @override
  String get bannedHelp =>
      'Si vous pensez qu\'il s\'agit d\'une erreur, contactez le support SeeU.';

  @override
  String get errAccountBanned => 'Ce compte a été suspendu.';

  @override
  String get errForbiddenField => 'Ce champ ne peut pas être modifié.';

  @override
  String get errTooManyReports =>
      'Trop de signalements aujourd\'hui. Réessayez demain.';

  @override
  String get errReportTarget =>
      'Ce contenu n\'existe plus ou n\'est plus visible.';

  @override
  String get errReportSelf => 'Vous ne pouvez pas vous signaler vous-même.';

  @override
  String pendingProfileBanner(String username) {
    return 'Créez votre compte (ou connectez-vous) pour retrouver @$username sur SeeU.';
  }

  @override
  String get pendingEventBanner =>
      'Créez votre compte (ou connectez-vous) pour voir cet événement.';

  @override
  String get travelCardTitle => 'Vous pourriez les voir sur place';

  @override
  String get travelCardSub =>
      'Ils habitent près de ce lieu, loin de chez vous.';

  @override
  String travelRow(String city, String km) {
    return '$city · $km km';
  }

  @override
  String travelFormHint(String name, String city) {
    return '$name habite à $city : vous pourriez vous voir pendant votre séjour.';
  }

  @override
  String travelFormHintMany(String name, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n autres personnes',
      one: '1 autre personne',
    );
    return '$name et $_temp0 habitent dans le coin : de quoi se voir pendant votre séjour.';
  }

  @override
  String get travelSetCity =>
      'Ajoutez votre ville de résidence (Réglages → Profil) pour savoir qui vous pourriez voir en voyage.';

  @override
  String get notifyTravel => 'Suggestions en voyage';

  @override
  String get notifyTravelSub =>
      'Quelques jours avant un événement loin de chez vous : qui habite sur place.';

  @override
  String get kindTravelNearby => 'Suggestion en voyage';

  @override
  String get showOnProfile => 'Afficher sur mon profil public';

  @override
  String get showOnProfileSub =>
      'Visible sur votre page publique (événements affichés : « Choisis »).';

  @override
  String get showOnProfileSubOff =>
      'Votre profil public n\'affiche pas d\'événements pour l\'instant : Réglages → Profil public et partage.';

  @override
  String get showOnProfileSubAll =>
      'Tous vos événements publics sont déjà affichés sur votre profil public.';

  @override
  String get shareEvent => 'Partager l\'événement';

  @override
  String shareEventText(String title, String link) {
    return '$title sur SeeU\n$link';
  }

  @override
  String get shareEventFriendsHint =>
      'Le lien s\'ouvre pour vos amis SeeU (événement « Entre amis »).';
}
