import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @languageName.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageName;

  /// No description provided for @and.
  ///
  /// In fr, this message translates to:
  /// **'et'**
  String get and;

  /// No description provided for @andOthers.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{et 1 autre} other{et {n} autres}}'**
  String andOthers(int n);

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get yesterday;

  /// No description provided for @dayAtTime.
  ///
  /// In fr, this message translates to:
  /// **'{day} à {time}'**
  String dayAtTime(String day, String time);

  /// No description provided for @greetingNight.
  ///
  /// In fr, this message translates to:
  /// **'Bonne nuit'**
  String get greetingNight;

  /// No description provided for @greetingMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In fr, this message translates to:
  /// **'Bon après-midi'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get greetingEvening;

  /// No description provided for @nDays.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{0 jour} =1{1 jour} other{{n} jours}}'**
  String nDays(int n);

  /// No description provided for @nWeeks.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 semaine} other{{n} semaines}}'**
  String nWeeks(int n);

  /// No description provided for @nMonths.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 mois} other{{n} mois}}'**
  String nMonths(int n);

  /// No description provided for @nYears.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 an} other{{n} ans}}'**
  String nYears(int n);

  /// No description provided for @nYearsHalf.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 an et demi} other{{n} ans et demi}}'**
  String nYearsHalf(int n);

  /// No description provided for @shortDays.
  ///
  /// In fr, this message translates to:
  /// **'{n} j'**
  String shortDays(int n);

  /// No description provided for @shortWeeks.
  ///
  /// In fr, this message translates to:
  /// **'{n} sem.'**
  String shortWeeks(int n);

  /// No description provided for @shortMonths.
  ///
  /// In fr, this message translates to:
  /// **'{n} mois'**
  String shortMonths(int n);

  /// No description provided for @shortYears.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 an} other{{n} ans}}'**
  String shortYears(int n);

  /// No description provided for @dueOverdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard de {duration}'**
  String dueOverdue(String duration);

  /// No description provided for @dueToday.
  ///
  /// In fr, this message translates to:
  /// **'À revoir aujourd\'hui'**
  String get dueToday;

  /// No description provided for @dueTodayShort.
  ///
  /// In fr, this message translates to:
  /// **'Auj.'**
  String get dueTodayShort;

  /// No description provided for @dueIn.
  ///
  /// In fr, this message translates to:
  /// **'À revoir dans {duration}'**
  String dueIn(String duration);

  /// No description provided for @everyDays.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{tous les jours} other{tous les {n} jours}}'**
  String everyDays(int n);

  /// No description provided for @everyWeeks.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{toutes les semaines} other{toutes les {n} semaines}}'**
  String everyWeeks(int n);

  /// No description provided for @everyMonths.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{tous les mois} other{tous les {n} mois}}'**
  String everyMonths(int n);

  /// No description provided for @everyYears.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{tous les ans} other{tous les {n} ans}}'**
  String everyYears(int n);

  /// No description provided for @unitDays.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{jour} other{jours}}'**
  String unitDays(int n);

  /// No description provided for @unitWeeks.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{semaine} other{semaines}}'**
  String unitWeeks(int n);

  /// No description provided for @unitMonths.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{mois} other{mois}}'**
  String unitMonths(int n);

  /// No description provided for @unitYears.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{an} other{ans}}'**
  String unitYears(int n);

  /// No description provided for @statusPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Planifié'**
  String get statusPlanned;

  /// No description provided for @statusDone.
  ///
  /// In fr, this message translates to:
  /// **'A eu lieu'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get statusCancelled;

  /// No description provided for @rsvpPending.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer'**
  String get rsvpPending;

  /// No description provided for @rsvpAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get rsvpAccepted;

  /// No description provided for @rsvpDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get rsvpDeclined;

  /// No description provided for @withNames.
  ///
  /// In fr, this message translates to:
  /// **'Avec {names}'**
  String withNames(String names);

  /// No description provided for @withNamesMore.
  ///
  /// In fr, this message translates to:
  /// **'Avec {names} et {n} autres'**
  String withNamesMore(String names, int n);

  /// No description provided for @aFriend.
  ///
  /// In fr, this message translates to:
  /// **'Un ami'**
  String get aFriend;

  /// No description provided for @catFamily.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get catFamily;

  /// No description provided for @catFriends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get catFriends;

  /// No description provided for @catWork.
  ///
  /// In fr, this message translates to:
  /// **'Pro'**
  String get catWork;

  /// No description provided for @catOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get catOther;

  /// No description provided for @usernameHint.
  ///
  /// In fr, this message translates to:
  /// **'3 à 20 caractères : lettres minuscules, chiffres, point et tiret bas.'**
  String get usernameHint;

  /// No description provided for @usernameTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {n} caractères.'**
  String usernameTooShort(int n);

  /// No description provided for @usernameBadStart.
  ///
  /// In fr, this message translates to:
  /// **'Doit commencer par une lettre ou un chiffre.'**
  String get usernameBadStart;

  /// No description provided for @errNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Vérifiez votre réseau.'**
  String get errNetwork;

  /// No description provided for @errGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get errGeneric;

  /// No description provided for @errSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée, reconnectez-vous.'**
  String get errSessionExpired;

  /// No description provided for @errForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Action non autorisée.'**
  String get errForbidden;

  /// No description provided for @errUsernameTaken.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom d\'utilisateur est déjà pris.'**
  String get errUsernameTaken;

  /// No description provided for @errUsernameInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur invalide.'**
  String get errUsernameInvalid;

  /// No description provided for @errFriendAlreadyLinked.
  ///
  /// In fr, this message translates to:
  /// **'Cet ami est déjà associé à un autre contact.'**
  String get errFriendAlreadyLinked;

  /// No description provided for @errDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément existe déjà.'**
  String get errDuplicate;

  /// No description provided for @errFileTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop volumineux (10 Mo max).'**
  String get errFileTooLarge;

  /// No description provided for @errBadCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Email ou mot de passe incorrect.'**
  String get errBadCredentials;

  /// No description provided for @errEmailNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez d\'abord votre adresse email (lien reçu par mail).'**
  String get errEmailNotConfirmed;

  /// No description provided for @errEmailTaken.
  ///
  /// In fr, this message translates to:
  /// **'Un compte existe déjà avec cet email.'**
  String get errEmailTaken;

  /// No description provided for @errWeakPassword.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 6 caractères.'**
  String get errWeakPassword;

  /// No description provided for @errRateLimit.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives, réessayez dans quelques minutes.'**
  String get errRateLimit;

  /// No description provided for @errSignupsDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Les inscriptions sont désactivées.'**
  String get errSignupsDisabled;

  /// No description provided for @errInvalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Adresse email invalide.'**
  String get errInvalidEmail;

  /// No description provided for @errSamePassword.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un mot de passe différent de l\'ancien.'**
  String get errSamePassword;

  /// No description provided for @errLinkExpired.
  ///
  /// In fr, this message translates to:
  /// **'Lien invalide ou expiré.'**
  String get errLinkExpired;

  /// No description provided for @errNotFriends.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne ne fait pas partie de vos amis SeeU.'**
  String get errNotFriends;

  /// No description provided for @errNoLongerFriends.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes plus amis sur SeeU.'**
  String get errNoLongerFriends;

  /// No description provided for @errRdvNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous introuvable.'**
  String get errRdvNotFound;

  /// No description provided for @errInviteNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Invitation introuvable.'**
  String get errInviteNotFound;

  /// No description provided for @errRdvGone.
  ///
  /// In fr, this message translates to:
  /// **'Ce rendez-vous n\'existe plus.'**
  String get errRdvGone;

  /// No description provided for @errRdvCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Ce rendez-vous est annulé.'**
  String get errRdvCancelled;

  /// No description provided for @errWaveAlready.
  ///
  /// In fr, this message translates to:
  /// **'Vous lui avez déjà fait signe aujourd\'hui.'**
  String get errWaveAlready;

  /// No description provided for @errAlreadyAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà répondu à cette invitation.'**
  String get errAlreadyAnswered;

  /// No description provided for @errBadAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Réponse invalide.'**
  String get errBadAnswer;

  /// No description provided for @errRequestNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Demande introuvable.'**
  String get errRequestNotFound;

  /// No description provided for @errNotOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Seul l\'organisateur peut faire cela.'**
  String get errNotOrganizer;

  /// No description provided for @errPublicNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore accès aux événements publics.'**
  String get errPublicNotAllowed;

  /// No description provided for @errSlotsClosed.
  ///
  /// In fr, this message translates to:
  /// **'Le choix des créneaux est terminé.'**
  String get errSlotsClosed;

  /// No description provided for @errSlotsNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Les créneaux multiples ne sont pas disponibles pour un événement public.'**
  String get errSlotsNotAllowed;

  /// No description provided for @errEventNotVisible.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement n\'est pas accessible.'**
  String get errEventNotVisible;

  /// No description provided for @errBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible avec cette personne.'**
  String get errBlocked;

  /// No description provided for @errChatReadOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seul l\'organisateur peut publier ici.'**
  String get errChatReadOnly;

  /// No description provided for @errPhotosOrganizerOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seul l\'organisateur peut ajouter des photos.'**
  String get errPhotosOrganizerOnly;

  /// No description provided for @errNotParticipant.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez l\'événement pour participer.'**
  String get errNotParticipant;

  /// No description provided for @errTooManySlots.
  ///
  /// In fr, this message translates to:
  /// **'10 créneaux maximum.'**
  String get errTooManySlots;

  /// No description provided for @errContactsAddedBeforeError.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 contact ajouté avant l\'erreur : {error}} other{{n} contacts ajoutés avant l\'erreur : {error}}}'**
  String errContactsAddedBeforeError(int n, Object error);

  /// No description provided for @errDeleteAccountFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible pour le moment. Réessayez plus tard.'**
  String get errDeleteAccountFailed;

  /// No description provided for @errLinkOtherDevice.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien doit être ouvert sur l\'appareil où vous l\'avez demandé. Ouvrez l\'email sur cet appareil, ou redemandez un lien depuis celui-ci.'**
  String get errLinkOtherDevice;

  /// No description provided for @tabHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tabHome;

  /// No description provided for @tabContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get tabContacts;

  /// No description provided for @tabHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get tabHistory;

  /// No description provided for @tabSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get tabSettings;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clear;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @pickDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get pickDate;

  /// No description provided for @notSeenYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore vu'**
  String get notSeenYet;

  /// No description provided for @seenOn.
  ///
  /// In fr, this message translates to:
  /// **'Vu le {date}'**
  String seenOn(String date);

  /// No description provided for @soonPill.
  ///
  /// In fr, this message translates to:
  /// **'★ Bientôt'**
  String get soonPill;

  /// No description provided for @seeuFriend.
  ///
  /// In fr, this message translates to:
  /// **'Ami SeeU'**
  String get seeuFriend;

  /// No description provided for @freqCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisée'**
  String get freqCustom;

  /// No description provided for @categoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre…'**
  String get categoryOther;

  /// No description provided for @categoryHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Voisins, Sport…'**
  String get categoryHint;

  /// No description provided for @pushChannelName.
  ///
  /// In fr, this message translates to:
  /// **'Rappels SeeU'**
  String get pushChannelName;

  /// No description provided for @pushChannelDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rappels, rendez-vous et activité de vos amis'**
  String get pushChannelDesc;

  /// No description provided for @quickNewRdv.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau rendez-vous'**
  String get quickNewRdv;

  /// No description provided for @quickNewContact.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get quickNewContact;

  /// No description provided for @historyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historyTitle;

  /// No description provided for @historyList.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get historyList;

  /// No description provided for @historyMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get historyMonth;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rencontre pour l\'instant'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les rendez-vous validés ou annulés apparaîtront ici.'**
  String get historyEmptyMessage;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// No description provided for @filterDone.
  ///
  /// In fr, this message translates to:
  /// **'A eu lieu'**
  String get filterDone;

  /// No description provided for @filterCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulés'**
  String get filterCancelled;

  /// No description provided for @historySearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (contact, titre, lieu)'**
  String get historySearchHint;

  /// No description provided for @noResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get noResults;

  /// No description provided for @historyCounts.
  ///
  /// In fr, this message translates to:
  /// **'{nMet, plural, =0{0 rencontre} =1{1 rencontre} other{{nMet} rencontres}} · {nCancelled, plural, =0{0 annulé} =1{1 annulé} other{{nCancelled} annulés}}'**
  String historyCounts(int nMet, int nCancelled);

  /// No description provided for @prevMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois précédent'**
  String get prevMonth;

  /// No description provided for @nextMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois suivant'**
  String get nextMonth;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get loading;

  /// No description provided for @calendarNoneThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rencontre ce mois-ci.'**
  String get calendarNoneThisMonth;

  /// No description provided for @calendarMetInMonth.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 rencontre en {month}} other{{n} rencontres en {month}}}'**
  String calendarMetInMonth(int n, Object month);

  /// No description provided for @calendarDayEvents.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 rendez-vous} other{{n} rendez-vous}}'**
  String calendarDayEvents(int n);

  /// No description provided for @dayNoEvents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rendez-vous ce jour-là'**
  String get dayNoEvents;

  /// No description provided for @dayMetCount.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Aucune rencontre ce jour-là} =1{1 rencontre ce jour-là} other{{n} rencontres ce jour-là}}'**
  String dayMetCount(int n);

  /// No description provided for @rsvpToastAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous accepté'**
  String get rsvpToastAccepted;

  /// No description provided for @rsvpToastDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Invitation refusée'**
  String get rsvpToastDeclined;

  /// No description provided for @rsvpToastPending.
  ///
  /// In fr, this message translates to:
  /// **'Marqué « à confirmer »'**
  String get rsvpToastPending;

  /// No description provided for @rsvpDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get rsvpDecline;

  /// No description provided for @rsvpAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get rsvpAccept;

  /// No description provided for @rsvpMaybe.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer'**
  String get rsvpMaybe;

  /// No description provided for @statusFutureTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce rendez-vous est prévu plus tard'**
  String get statusFutureTitle;

  /// No description provided for @statusFutureMessage.
  ///
  /// In fr, this message translates to:
  /// **'Il est planifié le {when}. Le marquer quand même comme ayant eu lieu ?'**
  String statusFutureMessage(String when);

  /// No description provided for @statusFutureConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Oui, il a eu lieu'**
  String get statusFutureConfirm;

  /// No description provided for @statusToastDone.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous validé'**
  String get statusToastDone;

  /// No description provided for @statusToastDoneReset.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous validé : date de dernière rencontre mise à jour'**
  String get statusToastDoneReset;

  /// No description provided for @statusToastCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous annulé'**
  String get statusToastCancelled;

  /// No description provided for @statusToastPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous remis en planifié'**
  String get statusToastPlanned;

  /// No description provided for @statusSetPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Remettre en planifié'**
  String get statusSetPlanned;

  /// No description provided for @statusSetDone.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme passé'**
  String get statusSetDone;

  /// No description provided for @statusSetCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get statusSetCancelled;

  /// No description provided for @inviteSharesMeetup.
  ///
  /// In fr, this message translates to:
  /// **'{name} partage une rencontre avec vous'**
  String inviteSharesMeetup(String name);

  /// No description provided for @inviteProposes.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous propose un rendez-vous'**
  String inviteProposes(String name);

  /// No description provided for @inviteTentativeHint.
  ///
  /// In fr, this message translates to:
  /// **'Il est déjà dans votre agenda, « à confirmer ». Votre ami n\'est prévenu que si vous acceptez ou refusez.'**
  String get inviteTentativeHint;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @offlineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes hors ligne'**
  String get offlineTitle;

  /// No description provided for @offlineMessage.
  ///
  /// In fr, this message translates to:
  /// **'SeeU a besoin d\'une connexion internet pour fonctionner. Vérifiez votre réseau puis réessayez.'**
  String get offlineMessage;

  /// No description provided for @pageNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Page introuvable'**
  String get pageNotFound;

  /// No description provided for @pageNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette page n\'existe pas ou plus.'**
  String get pageNotFoundMessage;

  /// No description provided for @backHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get backHome;

  /// No description provided for @maybeDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Il a peut-être été supprimé.'**
  String get maybeDeleted;

  /// No description provided for @photoAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get photoAdd;

  /// No description provided for @photoTake.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get photoTake;

  /// No description provided for @photoGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get photoGallery;

  /// No description provided for @photoAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux photos refusé. Autorisez-le dans les réglages du téléphone.'**
  String get photoAccessDenied;

  /// No description provided for @photoEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des photos de vos moments partagés.'**
  String get photoEmpty;

  /// No description provided for @photoDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette photo ?'**
  String get photoDeleteTitle;

  /// No description provided for @irreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est définitive.'**
  String get irreversible;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @photoDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Photo supprimée'**
  String get photoDeleted;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @pushEnabledToast.
  ///
  /// In fr, this message translates to:
  /// **'Notifications activées 🎉'**
  String get pushEnabledToast;

  /// No description provided for @pushBlockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications bloquées'**
  String get pushBlockedTitle;

  /// No description provided for @pushEnableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer les rappels'**
  String get pushEnableTitle;

  /// No description provided for @pushBlockedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez-les dans les réglages de votre téléphone (Notifications → SeeU), ou activez les rappels par email dans les Réglages de l\'app.'**
  String get pushBlockedMessage;

  /// No description provided for @pushEnableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Recevez une notification quand un contact est à recontacter et avant chaque rendez-vous.'**
  String get pushEnableMessage;

  /// No description provided for @openPhoneSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get openPhoneSettings;

  /// No description provided for @seeuSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages SeeU'**
  String get seeuSettings;

  /// No description provided for @enable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get enable;

  /// No description provided for @languageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Langue du téléphone'**
  String get languageSystem;

  /// No description provided for @tagline.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus oublier les personnes qu\'on aimerait revoir.'**
  String get tagline;

  /// No description provided for @configMissing.
  ///
  /// In fr, this message translates to:
  /// **'Configuration manquante : lancez l\'app avec --dart-define-from-file=config/env.json (SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY).'**
  String get configMissing;

  /// No description provided for @errAccountExists.
  ///
  /// In fr, this message translates to:
  /// **'Un compte existe déjà avec cet email. Connectez-vous ou utilisez « Mot de passe oublié ».'**
  String get errAccountExists;

  /// No description provided for @checkMailboxTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre boîte mail'**
  String get checkMailboxTitle;

  /// No description provided for @checkMailboxText.
  ///
  /// In fr, this message translates to:
  /// **'Un lien de confirmation a été envoyé à {email}. Ouvrez-le pour activer votre compte (pensez aux spams).'**
  String checkMailboxText(String email);

  /// No description provided for @magicSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lien envoyé'**
  String get magicSentTitle;

  /// No description provided for @magicSentText.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez le lien reçu à {email} pour vous connecter (pensez aux spams).'**
  String magicSentText(String email);

  /// No description provided for @resetSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Email envoyé'**
  String get resetSentTitle;

  /// No description provided for @resetSentText.
  ///
  /// In fr, this message translates to:
  /// **'Si un compte existe pour {email}, vous recevrez un lien pour choisir un nouveau mot de passe.'**
  String resetSentText(String email);

  /// No description provided for @loginTab.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTab;

  /// No description provided for @signupTab.
  ///
  /// In fr, this message translates to:
  /// **'Inscription'**
  String get signupTab;

  /// No description provided for @magicLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien magique'**
  String get magicLink;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPassword;

  /// No description provided for @magicLinkHelp.
  ///
  /// In fr, this message translates to:
  /// **'Recevez un lien de connexion par email, sans mot de passe.'**
  String get magicLinkHelp;

  /// No description provided for @forgotHelp.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre email : vous recevrez un lien pour choisir un nouveau mot de passe.'**
  String get forgotHelp;

  /// No description provided for @firstNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prénom (nom affiché)'**
  String get firstNameLabel;

  /// No description provided for @nameExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Andrea'**
  String get nameExample;

  /// No description provided for @emailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In fr, this message translates to:
  /// **'vous@exemple.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @passwordMin.
  ///
  /// In fr, this message translates to:
  /// **'6 caractères minimum'**
  String get passwordMin;

  /// No description provided for @hidePassword.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get showPassword;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get createAccount;

  /// No description provided for @getLink.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le lien'**
  String get getLink;

  /// No description provided for @sendLink.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get sendLink;

  /// No description provided for @forgotPasswordQ.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPasswordQ;

  /// No description provided for @getMagicLink.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un lien magique par email'**
  String get getMagicLink;

  /// No description provided for @completeProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Complétez votre profil'**
  String get completeProfileTitle;

  /// No description provided for @completeProfileSub.
  ///
  /// In fr, this message translates to:
  /// **'Vos amis vous retrouveront grâce à votre nom d\'utilisateur.'**
  String get completeProfileSub;

  /// No description provided for @displayName.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché'**
  String get displayName;

  /// No description provided for @displayNameHint.
  ///
  /// In fr, this message translates to:
  /// **'C\'est ce que voient vos amis.'**
  String get displayNameHint;

  /// No description provided for @birthDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get birthDate;

  /// No description provided for @birthDateHint.
  ///
  /// In fr, this message translates to:
  /// **'Facultative. Visible par vos amis uniquement.'**
  String get birthDateHint;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @signedInAs.
  ///
  /// In fr, this message translates to:
  /// **'Connecté avec {email}'**
  String signedInAs(String email);

  /// No description provided for @passwordUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe mis à jour'**
  String get passwordUpdated;

  /// No description provided for @newPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get newPassword;

  /// No description provided for @backToLogin.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get backToLogin;

  /// No description provided for @confirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez le mot de passe'**
  String get confirmPassword;

  /// No description provided for @passwordsDiffer.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe sont différents.'**
  String get passwordsDiffer;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @usernameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur'**
  String get usernameLabel;

  /// No description provided for @usernameAvailable.
  ///
  /// In fr, this message translates to:
  /// **'@{username} est disponible'**
  String usernameAvailable(String username);

  /// No description provided for @usernameCheckFailed.
  ///
  /// In fr, this message translates to:
  /// **'Vérification impossible pour le moment.'**
  String get usernameCheckFailed;

  /// No description provided for @usernamePlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'nom.utilisateur'**
  String get usernamePlaceholder;

  /// No description provided for @nowFriendsWith.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes maintenant amis avec {name}'**
  String nowFriendsWith(String name);

  /// No description provided for @requestDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get requestDeclined;

  /// No description provided for @requestCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée'**
  String get requestCancelled;

  /// No description provided for @contactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @importContacts.
  ///
  /// In fr, this message translates to:
  /// **'Importer des contacts'**
  String get importContacts;

  /// No description provided for @friendsWithoutCard.
  ///
  /// In fr, this message translates to:
  /// **'Amis SeeU sans fiche'**
  String get friendsWithoutCard;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In fr, this message translates to:
  /// **'Essayez une autre recherche.'**
  String get tryAnotherSearch;

  /// No description provided for @groupOverdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get groupOverdue;

  /// No description provided for @groupThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get groupThisWeek;

  /// No description provided for @groupUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'À jour'**
  String get groupUpToDate;

  /// No description provided for @addSeeuFriend.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un ami SeeU'**
  String get addSeeuFriend;

  /// No description provided for @addContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get addContact;

  /// No description provided for @rdvInvitations.
  ///
  /// In fr, this message translates to:
  /// **'Invitations à un rendez-vous'**
  String get rdvInvitations;

  /// No description provided for @friendRequestsReceived.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'ami reçues'**
  String get friendRequestsReceived;

  /// No description provided for @sentYouARequest.
  ///
  /// In fr, this message translates to:
  /// **'Vous a envoyé une demande'**
  String get sentYouARequest;

  /// No description provided for @friendRequestsSent.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'ami envoyées'**
  String get friendRequestsSent;

  /// No description provided for @waitingForAnswer.
  ///
  /// In fr, this message translates to:
  /// **'En attente de sa réponse'**
  String get waitingForAnswer;

  /// No description provided for @noContactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact pour l\'instant'**
  String get noContactsTitle;

  /// No description provided for @noContactsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez les personnes que vous voulez revoir régulièrement. Celles qui sont sur SeeU peuvent devenir vos amis : rendez-vous et photos partagés.'**
  String get noContactsMessage;

  /// No description provided for @importFromPhone.
  ///
  /// In fr, this message translates to:
  /// **'Importer depuis le téléphone'**
  String get importFromPhone;

  /// No description provided for @contactsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (nom, catégorie, notes, @ami)'**
  String get contactsSearchHint;

  /// No description provided for @nContacts.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{0 contact} =1{1 contact} other{{n} contacts}}'**
  String nContacts(int n);

  /// No description provided for @nFriends.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{0 ami} =1{1 ami} other{{n} amis}}'**
  String nFriends(int n);

  /// No description provided for @nOverdue.
  ///
  /// In fr, this message translates to:
  /// **'{n} en retard'**
  String nOverdue(int n);

  /// No description provided for @sortDue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get sortDue;

  /// No description provided for @sortName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get sortName;

  /// No description provided for @notInContactsYet.
  ///
  /// In fr, this message translates to:
  /// **'pas encore dans vos contacts'**
  String get notInContactsYet;

  /// No description provided for @markSeenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vu {name}'**
  String markSeenTitle(String name);

  /// No description provided for @snoozeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reporter {name}'**
  String snoozeTitle(String name);

  /// No description provided for @seeSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'À voir bientôt'**
  String get seeSoonTitle;

  /// No description provided for @seeSoonSub.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez quelqu\'un à revoir sans attendre la fin de sa période. Il restera en tête de liste jusqu\'à votre prochaine rencontre.'**
  String get seeSoonSub;

  /// No description provided for @meetingSaved.
  ///
  /// In fr, this message translates to:
  /// **'Rencontre avec {name} enregistrée'**
  String meetingSaved(String name);

  /// No description provided for @whenDidYouSee.
  ///
  /// In fr, this message translates to:
  /// **'Quand l\'avez-vous vu(e) ?'**
  String get whenDidYouSee;

  /// No description provided for @noteOptional.
  ///
  /// In fr, this message translates to:
  /// **'Une note'**
  String get noteOptional;

  /// No description provided for @noteHint.
  ///
  /// In fr, this message translates to:
  /// **'Un souvenir, un détail à retenir…'**
  String get noteHint;

  /// No description provided for @markSeenHelp.
  ///
  /// In fr, this message translates to:
  /// **'La date de dernière rencontre et la prochaine échéance seront mises à jour automatiquement. La rencontre apparaîtra dans l\'historique.'**
  String get markSeenHelp;

  /// No description provided for @saveMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la rencontre'**
  String get saveMeeting;

  /// No description provided for @snoozedUntil.
  ///
  /// In fr, this message translates to:
  /// **'Rappel reporté au {date}'**
  String snoozedUntil(String date);

  /// No description provided for @remindMeIn.
  ///
  /// In fr, this message translates to:
  /// **'Me le rappeler plus tard, dans :'**
  String get remindMeIn;

  /// No description provided for @orOnDate.
  ///
  /// In fr, this message translates to:
  /// **'Ou à une date précise'**
  String get orOnDate;

  /// No description provided for @snooze.
  ///
  /// In fr, this message translates to:
  /// **'Reporter'**
  String get snooze;

  /// No description provided for @addedToSeeSoon.
  ///
  /// In fr, this message translates to:
  /// **'{name} ajouté(e) à la liste « à voir bientôt »'**
  String addedToSeeSoon(String name);

  /// No description provided for @searchContact.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un contact…'**
  String get searchContact;

  /// No description provided for @allAlreadyInList.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos contacts sont déjà dans la liste.'**
  String get allAlreadyInList;

  /// No description provided for @noMatchingContact.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact ne correspond.'**
  String get noMatchingContact;

  /// No description provided for @ageSuffix.
  ///
  /// In fr, this message translates to:
  /// **'({n} ans)'**
  String ageSuffix(int n);

  /// No description provided for @birthdayToday.
  ///
  /// In fr, this message translates to:
  /// **'C\'est son anniversaire aujourd\'hui !'**
  String get birthdayToday;

  /// No description provided for @birthdayTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire demain'**
  String get birthdayTomorrow;

  /// No description provided for @birthdayInDays.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire dans {n} jours'**
  String birthdayInDays(int n);

  /// No description provided for @contactNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Contact introuvable'**
  String get contactNotFound;

  /// No description provided for @seeMyContacts.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes contacts'**
  String get seeMyContacts;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @removedFromSeeSoon.
  ///
  /// In fr, this message translates to:
  /// **'Retiré de la liste « à voir bientôt »'**
  String get removedFromSeeSoon;

  /// No description provided for @addedToSeeSoonHome.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à la liste « à voir bientôt » de l\'accueil'**
  String get addedToSeeSoonHome;

  /// No description provided for @deleteContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce contact ?'**
  String get deleteContactTitle;

  /// No description provided for @deleteContactMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ses rendez-vous et photos seront aussi supprimés. Cette action est définitive.'**
  String get deleteContactMessage;

  /// No description provided for @contactDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Contact supprimé'**
  String get contactDeleted;

  /// No description provided for @friendPill.
  ///
  /// In fr, this message translates to:
  /// **'Ami SeeU · rendez-vous et photos partageables'**
  String get friendPill;

  /// No description provided for @lastMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Dernière rencontre'**
  String get lastMeeting;

  /// No description provided for @notRecordedYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore notée'**
  String get notRecordedYet;

  /// No description provided for @nextDue.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine échéance'**
  String get nextDue;

  /// No description provided for @snoozedSuffix.
  ///
  /// In fr, this message translates to:
  /// **'(reportée)'**
  String get snoozedSuffix;

  /// No description provided for @frequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence'**
  String get frequency;

  /// No description provided for @planRdv.
  ///
  /// In fr, this message translates to:
  /// **'Planifier un rendez-vous'**
  String get planRdv;

  /// No description provided for @seenToday.
  ///
  /// In fr, this message translates to:
  /// **'Vu aujourd\'hui'**
  String get seenToday;

  /// No description provided for @inSeeSoonRemove.
  ///
  /// In fr, this message translates to:
  /// **'Dans « à voir bientôt » · retirer'**
  String get inSeeSoonRemove;

  /// No description provided for @information.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get information;

  /// No description provided for @bornOn.
  ///
  /// In fr, this message translates to:
  /// **'Né(e) le {date}'**
  String bornOn(String date);

  /// No description provided for @rdvSection.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous'**
  String get rdvSection;

  /// No description provided for @noRdvWithContact.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rendez-vous avec ce contact pour l\'instant.'**
  String get noRdvWithContact;

  /// No description provided for @upcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In fr, this message translates to:
  /// **'Passés'**
  String get past;

  /// No description provided for @gallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get gallery;

  /// No description provided for @deleteContact.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contact'**
  String get deleteContact;

  /// No description provided for @linkToFriend.
  ///
  /// In fr, this message translates to:
  /// **'Associer à un ami SeeU'**
  String get linkToFriend;

  /// No description provided for @linkedToAccount.
  ///
  /// In fr, this message translates to:
  /// **'Associé à un compte SeeU'**
  String get linkedToAccount;

  /// No description provided for @friendCanShare.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez lui envoyer vos rendez-vous et partager les photos.'**
  String get friendCanShare;

  /// No description provided for @wantToMeet.
  ///
  /// In fr, this message translates to:
  /// **'Envie de se voir'**
  String get wantToMeet;

  /// No description provided for @wantToMeetSent.
  ///
  /// In fr, this message translates to:
  /// **'{name} sait que vous aimeriez vous voir 👋'**
  String wantToMeetSent(String name);

  /// No description provided for @manage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer'**
  String get manage;

  /// No description provided for @editContact.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le contact'**
  String get editContact;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire.'**
  String get nameRequired;

  /// No description provided for @frequencyMin.
  ///
  /// In fr, this message translates to:
  /// **'La fréquence doit être d\'au moins 1.'**
  String get frequencyMin;

  /// No description provided for @contactAdded.
  ///
  /// In fr, this message translates to:
  /// **'Contact ajouté'**
  String get contactAdded;

  /// No description provided for @contactUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Contact mis à jour'**
  String get contactUpdated;

  /// No description provided for @newContact.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get newContact;

  /// No description provided for @addTheContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le contact'**
  String get addTheContact;

  /// No description provided for @change.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get change;

  /// No description provided for @remove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get remove;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @nameHintFull.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Marie Dupont'**
  String get nameHintFull;

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @categoriesHint.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif · plusieurs choix possibles'**
  String get categoriesHint;

  /// No description provided for @lastMeetingOptional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif. Sans date, la période démarre aujourd\'hui.'**
  String get lastMeetingOptional;

  /// No description provided for @noMeetingRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de rencontre notée'**
  String get noMeetingRecorded;

  /// No description provided for @nextDueInline.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine échéance : {date}'**
  String nextDueInline(String date);

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 06 12 34 56 78'**
  String get phoneHint;

  /// No description provided for @emailExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex. marie@exemple.com'**
  String get emailExample;

  /// No description provided for @birthday.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire'**
  String get birthday;

  /// No description provided for @notes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @notesHint.
  ///
  /// In fr, this message translates to:
  /// **'Centres d\'intérêt, enfants, dernier sujet abordé…'**
  String get notesHint;

  /// No description provided for @requiredFields.
  ///
  /// In fr, this message translates to:
  /// **'* champs obligatoires'**
  String get requiredFields;

  /// No description provided for @importReadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire vos contacts sur cet appareil.'**
  String get importReadFailed;

  /// No description provided for @importAllThere.
  ///
  /// In fr, this message translates to:
  /// **'Tous ces contacts sont déjà dans SeeU.'**
  String get importAllThere;

  /// No description provided for @importRestTitle.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Le dernier restant d\'un coup} other{Les {n} restants d\'un coup}}'**
  String importRestTitle(int n);

  /// No description provided for @importRestFreq.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence {freq}'**
  String importRestFreq(String freq);

  /// No description provided for @importRestCats.
  ///
  /// In fr, this message translates to:
  /// **'catégories {cats}'**
  String importRestCats(String cats);

  /// No description provided for @importRestLast.
  ///
  /// In fr, this message translates to:
  /// **'dernière rencontre le {date}'**
  String importRestLast(String date);

  /// No description provided for @addAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout ajouter'**
  String get addAll;

  /// No description provided for @ignoreAllFinish.
  ///
  /// In fr, this message translates to:
  /// **'Tout ignorer et terminer'**
  String get ignoreAllFinish;

  /// No description provided for @nImported.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 contact importé} other{{n} contacts importés}}'**
  String nImported(int n);

  /// No description provided for @stepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {n} sur 3'**
  String stepOf(int n);

  /// No description provided for @chooseContacts.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez des contacts'**
  String get chooseContacts;

  /// No description provided for @continueN.
  ///
  /// In fr, this message translates to:
  /// **'Continuer ({n})'**
  String continueN(int n);

  /// No description provided for @ignore.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get ignore;

  /// No description provided for @importN.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Importer 1 contact} other{Importer {n} contacts}}'**
  String importN(int n);

  /// No description provided for @reviewSelection.
  ///
  /// In fr, this message translates to:
  /// **'Revoir la sélection'**
  String get reviewSelection;

  /// No description provided for @fromAddressBook.
  ///
  /// In fr, this message translates to:
  /// **'Depuis votre carnet d\'adresses'**
  String get fromAddressBook;

  /// No description provided for @fromAddressBookHelp.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez les personnes à suivre dans SeeU. Vous réglerez ensuite la fréquence de chacune. Rien n\'est enregistré avant la confirmation finale.'**
  String get fromAddressBookHelp;

  /// No description provided for @accessMyContacts.
  ///
  /// In fr, this message translates to:
  /// **'Accéder à mes contacts'**
  String get accessMyContacts;

  /// No description provided for @contactsAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'SeeU n\'a pas accès à vos contacts. Autorisez-le dans les réglages du téléphone, puis réessayez.'**
  String get contactsAccessDenied;

  /// No description provided for @searchEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher…'**
  String get searchEllipsis;

  /// No description provided for @nChosen.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{0 choisi} =1{1 choisi} other{{n} choisis}}'**
  String nChosen(int n);

  /// No description provided for @deselectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout désélectionner'**
  String get deselectAll;

  /// No description provided for @selectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get selectAll;

  /// No description provided for @contactNofM.
  ///
  /// In fr, this message translates to:
  /// **'Contact {n} sur {nTotal}'**
  String contactNofM(int n, int nTotal);

  /// No description provided for @duplicatesSkipped.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 déjà présent écarté} other{{n} déjà présents écartés}}'**
  String duplicatesSkipped(int n);

  /// No description provided for @optional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif'**
  String get optional;

  /// No description provided for @restAtOnce.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Le dernier restant d\'un coup…} other{Les {n} restants d\'un coup…}}'**
  String restAtOnce(int n);

  /// No description provided for @noneKept.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact retenu.'**
  String get noneKept;

  /// No description provided for @nKept.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 contact retenu} other{{n} contacts retenus}}'**
  String nKept(int n);

  /// No description provided for @nIgnored.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 ignoré} other{{n} ignorés}}'**
  String nIgnored(int n);

  /// No description provided for @removeName.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name}'**
  String removeName(String name);

  /// No description provided for @shareHandleText.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute-moi sur SeeU : @{username}\n{link}'**
  String shareHandleText(String username, String link);

  /// No description provided for @shareAppText.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins-moi sur SeeU, l\'app pour ne plus perdre de vue les gens qu\'on aime : {url}'**
  String shareAppText(String url);

  /// No description provided for @linkFriendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Associer {name}'**
  String linkFriendTitle(String name);

  /// No description provided for @linkFriendSub.
  ///
  /// In fr, this message translates to:
  /// **'Quel contact correspond à cet ami ? C\'est sa période qui sera remise à zéro quand vous validerez un rendez-vous ensemble.'**
  String get linkFriendSub;

  /// No description provided for @linkedFriendToContact.
  ///
  /// In fr, this message translates to:
  /// **'{friend} est associé au contact {contact}'**
  String linkedFriendToContact(String friend, String contact);

  /// No description provided for @createNewContact.
  ///
  /// In fr, this message translates to:
  /// **'Créer un nouveau contact'**
  String get createNewContact;

  /// No description provided for @searchMyContacts.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans mes contacts…'**
  String get searchMyContacts;

  /// No description provided for @alreadyLinked.
  ///
  /// In fr, this message translates to:
  /// **'Déjà associé'**
  String get alreadyLinked;

  /// No description provided for @suggested.
  ///
  /// In fr, this message translates to:
  /// **'Suggéré'**
  String get suggested;

  /// No description provided for @contactUnlinked.
  ///
  /// In fr, this message translates to:
  /// **'Contact dissocié'**
  String get contactUnlinked;

  /// No description provided for @removeFriendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} ?'**
  String removeFriendTitle(String name);

  /// No description provided for @removeFriendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts et rendez-vous existants sont conservés, mais vous ne pourrez plus vous envoyer d\'invitations. Les invitations en attente sont annulées.'**
  String get removeFriendMessage;

  /// No description provided for @friendRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Ami retiré'**
  String get friendRemoved;

  /// No description provided for @proposeRdv.
  ///
  /// In fr, this message translates to:
  /// **'Proposer un rendez-vous'**
  String get proposeRdv;

  /// No description provided for @seeContactName.
  ///
  /// In fr, this message translates to:
  /// **'Voir le contact {name}'**
  String seeContactName(String name);

  /// No description provided for @linkToOtherContact.
  ///
  /// In fr, this message translates to:
  /// **'Associer à un autre contact'**
  String get linkToOtherContact;

  /// No description provided for @unlinkContact.
  ///
  /// In fr, this message translates to:
  /// **'Dissocier du contact'**
  String get unlinkContact;

  /// No description provided for @linkToContact.
  ///
  /// In fr, this message translates to:
  /// **'Associer à un contact'**
  String get linkToContact;

  /// No description provided for @removeFromFriends.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de mes amis'**
  String get removeFromFriends;

  /// No description provided for @linkContactToFriendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Associer {name} à un ami SeeU'**
  String linkContactToFriendTitle(String name);

  /// No description provided for @linkContactToFriendSub.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez lui envoyer vos rendez-vous et partager les photos. Chaque ami ne peut être associé qu\'à un seul contact.'**
  String get linkContactToFriendSub;

  /// No description provided for @linkedContactToFriend.
  ///
  /// In fr, this message translates to:
  /// **'{contact} est associé à {friend}'**
  String linkedContactToFriend(String contact, String friend);

  /// No description provided for @noSeeuFriendsYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore d\'ami SeeU.'**
  String get noSeeuFriendsYet;

  /// No description provided for @addSeeuFriendLong.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un ami SeeU'**
  String get addSeeuFriendLong;

  /// No description provided for @linkedTo.
  ///
  /// In fr, this message translates to:
  /// **'Associé à {name}'**
  String linkedTo(String name);

  /// No description provided for @addFriendSub.
  ///
  /// In fr, this message translates to:
  /// **'Cherchez-le par son nom d\'utilisateur. Entre amis SeeU, vous partagez rendez-vous et photos.'**
  String get addFriendSub;

  /// No description provided for @searchFailed.
  ///
  /// In fr, this message translates to:
  /// **'Recherche impossible'**
  String get searchFailed;

  /// No description provided for @requestSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée à {name}'**
  String requestSentTo(String name);

  /// No description provided for @alreadyInvitedYou.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous avait déjà invité : vous êtes maintenant amis !'**
  String alreadyInvitedYou(String name);

  /// No description provided for @requestAlreadySent.
  ///
  /// In fr, this message translates to:
  /// **'Demande déjà envoyée, en attente de sa réponse.'**
  String get requestAlreadySent;

  /// No description provided for @alreadyFriend.
  ///
  /// In fr, this message translates to:
  /// **'{name} fait déjà partie de vos amis.'**
  String alreadyFriend(String name);

  /// No description provided for @accountGone.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n\'existe plus.'**
  String get accountGone;

  /// No description provided for @yourUsername.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom d\'utilisateur :'**
  String get yourUsername;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @noAccountStartsWith.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte ne commence par {handle}. Vérifiez l\'orthographe, ou invitez cette personne à créer son compte.'**
  String noAccountStartsWith(String handle);

  /// No description provided for @sendAppLink.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien de l\'app'**
  String get sendAppLink;

  /// No description provided for @requestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée'**
  String get requestSent;

  /// No description provided for @alreadyInFriends.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans vos amis'**
  String get alreadyInFriends;

  /// No description provided for @greetingName.
  ///
  /// In fr, this message translates to:
  /// **'{greeting} {name} 👋'**
  String greetingName(String greeting, String name);

  /// No description provided for @greetingAlone.
  ///
  /// In fr, this message translates to:
  /// **'{greeting} 👋'**
  String greetingAlone(String greeting);

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settings;

  /// No description provided for @newRdv.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau rendez-vous'**
  String get newRdv;

  /// No description provided for @invitationsReceived.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Invitation reçue} other{Invitations reçues}}'**
  String invitationsReceived(int n);

  /// No description provided for @statContacts.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{contact} =1{contact} other{contacts}}'**
  String statContacts(int n);

  /// No description provided for @statOverdue.
  ///
  /// In fr, this message translates to:
  /// **'en retard'**
  String get statOverdue;

  /// No description provided for @statUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'rdv à venir'**
  String get statUpcoming;

  /// No description provided for @didTheyHappen.
  ///
  /// In fr, this message translates to:
  /// **'Ont-ils eu lieu ?'**
  String get didTheyHappen;

  /// No description provided for @toReconnect.
  ///
  /// In fr, this message translates to:
  /// **'Garder le contact'**
  String get toReconnect;

  /// No description provided for @seeAllN.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout ({n})'**
  String seeAllN(int n);

  /// No description provided for @addSeeSoon.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter quelqu\'un à voir bientôt'**
  String get addSeeSoon;

  /// No description provided for @allUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'Tout est à jour 🎉'**
  String get allUpToDate;

  /// No description provided for @allUpToDateMessage.
  ///
  /// In fr, this message translates to:
  /// **'Personne à recontacter pour l\'instant. Envie de voir quelqu\'un quand même ? Ajoutez-le avec le bouton +.'**
  String get allUpToDateMessage;

  /// No description provided for @birthdaysThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaires cette semaine'**
  String get birthdaysThisWeek;

  /// No description provided for @inNDays.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{demain} other{dans {n} jours}}'**
  String inNDays(int n);

  /// No description provided for @nYearsOld.
  ///
  /// In fr, this message translates to:
  /// **'{n} ans'**
  String nYearsOld(int n);

  /// No description provided for @nextRdvs.
  ///
  /// In fr, this message translates to:
  /// **'Prochains rendez-vous'**
  String get nextRdvs;

  /// No description provided for @noRdvPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rendez-vous prévu'**
  String get noRdvPlanned;

  /// No description provided for @noRdvPlannedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Planifiez un moment avec quelqu\'un que vous voulez revoir.'**
  String get noRdvPlannedMessage;

  /// No description provided for @plan.
  ///
  /// In fr, this message translates to:
  /// **'Planifier'**
  String get plan;

  /// No description provided for @moreRdvs.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{+ 1 autre rendez-vous planifié} other{+ {n} autres rendez-vous planifiés}}'**
  String moreRdvs(int n);

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur SeeU'**
  String get welcomeTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez les personnes que vous voulez revoir régulièrement, choisissez une fréquence, et laissez l\'app vous rappeler quand il est temps de les recontacter.'**
  String get welcomeMessage;

  /// No description provided for @addFirstContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter mon premier contact'**
  String get addFirstContact;

  /// No description provided for @birthdayOf.
  ///
  /// In fr, this message translates to:
  /// **'🎂 C\'est l\'anniversaire de {name} !'**
  String birthdayOf(String name);

  /// No description provided for @turnsToday.
  ///
  /// In fr, this message translates to:
  /// **'{n} ans aujourd\'hui ·'**
  String turnsToday(int n);

  /// No description provided for @wishThem.
  ///
  /// In fr, this message translates to:
  /// **'Pensez à lui souhaiter.'**
  String get wishThem;

  /// No description provided for @sendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message'**
  String get sendMessage;

  /// No description provided for @seen.
  ///
  /// In fr, this message translates to:
  /// **'Vu'**
  String get seen;

  /// No description provided for @removedFromList.
  ///
  /// In fr, this message translates to:
  /// **'{name} retiré(e) de la liste'**
  String removedFromList(String name);

  /// No description provided for @backToHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get backToHome;

  /// No description provided for @rdvGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous'**
  String get rdvGeneric;

  /// No description provided for @deleteRdvTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce rendez-vous ?'**
  String get deleteRdvTitle;

  /// No description provided for @deleteRdvShared.
  ///
  /// In fr, this message translates to:
  /// **'Il sera supprimé chez vous uniquement (vos amis gardent le leur), et vos photos disparaîtront de la galerie commune. Cette action est définitive.'**
  String get deleteRdvShared;

  /// No description provided for @deleteRdvPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Les photos associées seront supprimées. Cette action est définitive.'**
  String get deleteRdvPrivate;

  /// No description provided for @rdvDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous supprimé'**
  String get rdvDeleted;

  /// No description provided for @didItHappen.
  ///
  /// In fr, this message translates to:
  /// **'Ce rendez-vous a-t-il eu lieu ?'**
  String get didItHappen;

  /// No description provided for @sharedRdvInfo.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous partagé : date, lieu, titre et statut sont les mêmes pour tous. Vos notes restent privées.'**
  String get sharedRdvInfo;

  /// No description provided for @participants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @noParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant.'**
  String get noParticipants;

  /// No description provided for @addToCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au calendrier'**
  String get addToCalendar;

  /// No description provided for @sharedPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos partagées'**
  String get sharedPhotos;

  /// No description provided for @photos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @photosEmptyShared.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des photos de ce moment : tous les participants les verront.'**
  String get photosEmptyShared;

  /// No description provided for @photosEmptyPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des photos de ce moment.'**
  String get photosEmptyPrivate;

  /// No description provided for @deleteRdv.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le rendez-vous'**
  String get deleteRdv;

  /// No description provided for @invitedByFriend.
  ///
  /// In fr, this message translates to:
  /// **'Invitation d\'un ami SeeU'**
  String get invitedByFriend;

  /// No description provided for @proposedBy.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous a proposé ce rendez-vous'**
  String proposedBy(String name);

  /// No description provided for @rsvpPendingHelp.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer : il est dans votre agenda, mais votre ami ne sait pas encore si vous venez.'**
  String get rsvpPendingHelp;

  /// No description provided for @rsvpAcceptedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez accepté. Une fois validé, votre période avec ce contact repart de zéro.'**
  String get rsvpAcceptedHelp;

  /// No description provided for @rsvpDeclinedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez refusé : il n\'apparaît plus dans vos listes.'**
  String get rsvpDeclinedHelp;

  /// No description provided for @sharing.
  ///
  /// In fr, this message translates to:
  /// **'Partage'**
  String get sharing;

  /// No description provided for @sharingHelp.
  ///
  /// In fr, this message translates to:
  /// **'Si votre ami accepte, vous avez tous les deux le rendez-vous. Une fois validé, chacun voit sa période repartir de zéro, et les photos sont communes.'**
  String get sharingHelp;

  /// No description provided for @proposedThisRdv.
  ///
  /// In fr, this message translates to:
  /// **'Vous a proposé ce rendez-vous'**
  String get proposedThisRdv;

  /// No description provided for @friendNotInvited.
  ///
  /// In fr, this message translates to:
  /// **'Ami SeeU · pas encore invité'**
  String get friendNotInvited;

  /// No description provided for @send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get send;

  /// No description provided for @invitationSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée à {name}'**
  String invitationSentTo(String name);

  /// No description provided for @invitationPending.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée · en attente'**
  String get invitationPending;

  /// No description provided for @invitationCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Invitation annulée'**
  String get invitationCancelled;

  /// No description provided for @acceptedShared.
  ///
  /// In fr, this message translates to:
  /// **'A accepté · rendez-vous partagé'**
  String get acceptedShared;

  /// No description provided for @declinedInvitation.
  ///
  /// In fr, this message translates to:
  /// **'A décliné l\'invitation'**
  String get declinedInvitation;

  /// No description provided for @resend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer'**
  String get resend;

  /// No description provided for @editRdv.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le rendez-vous'**
  String get editRdv;

  /// No description provided for @chooseOneContact.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins un contact.'**
  String get chooseOneContact;

  /// No description provided for @rdvUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous mis à jour'**
  String get rdvUpdated;

  /// No description provided for @meetingRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Rencontre enregistrée'**
  String get meetingRecorded;

  /// No description provided for @rdvPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous planifié'**
  String get rdvPlanned;

  /// No description provided for @inviteSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Une invitation n\'a pas pu être envoyée : réessayez depuis le rendez-vous.'**
  String get inviteSendFailed;

  /// No description provided for @invitationsSentN.
  ///
  /// In fr, this message translates to:
  /// **'Invitations envoyées à {n} amis'**
  String invitationsSentN(int n);

  /// No description provided for @titleExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Déjeuner, café, visio…'**
  String get titleExample;

  /// No description provided for @saveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get saveChanges;

  /// No description provided for @planTheRdv.
  ///
  /// In fr, this message translates to:
  /// **'Planifier le rendez-vous'**
  String get planTheRdv;

  /// No description provided for @createContactFirst.
  ///
  /// In fr, this message translates to:
  /// **'Créez d\'abord un contact pour pouvoir planifier un rendez-vous.'**
  String get createContactFirst;

  /// No description provided for @createAContact.
  ///
  /// In fr, this message translates to:
  /// **'Créer un contact'**
  String get createAContact;

  /// No description provided for @date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get time;

  /// No description provided for @titleOptional.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get titleOptional;

  /// No description provided for @placeOptional.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get placeOptional;

  /// No description provided for @placeHint.
  ///
  /// In fr, this message translates to:
  /// **'Café, adresse, visio…'**
  String get placeHint;

  /// No description provided for @notesOptional.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get notesOptional;

  /// No description provided for @notesPrivateHint.
  ///
  /// In fr, this message translates to:
  /// **'Toujours privées, même si le rendez-vous est partagé.'**
  String get notesPrivateHint;

  /// No description provided for @notesRdvHint.
  ///
  /// In fr, this message translates to:
  /// **'Idées de sujets, à ne pas oublier…'**
  String get notesRdvHint;

  /// No description provided for @status.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get status;

  /// No description provided for @statusHintDone.
  ///
  /// In fr, this message translates to:
  /// **'La date de dernière rencontre des participants sera mise à jour.'**
  String get statusHintDone;

  /// No description provided for @statusHintCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Il reste dans l\'historique comme annulé.'**
  String get statusHintCancelled;

  /// No description provided for @statusHintPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Vous recevrez un rappel avant, puis pourrez le valider.'**
  String get statusHintPlanned;

  /// No description provided for @alreadyHappened.
  ///
  /// In fr, this message translates to:
  /// **'Ce rendez-vous a déjà eu lieu'**
  String get alreadyHappened;

  /// No description provided for @alreadyHappenedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Cochez pour noter une rencontre passée : elle va directement dans l\'historique et remet le compteur des participants à zéro.'**
  String get alreadyHappenedHelp;

  /// No description provided for @sendTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer à {names}'**
  String sendTo(String names);

  /// No description provided for @shareOffHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le rendez-vous reste uniquement chez vous. Vous pourrez l\'envoyer plus tard depuis sa fiche.'**
  String get shareOffHelp;

  /// No description provided for @shareDoneHelp.
  ///
  /// In fr, this message translates to:
  /// **'Votre ami recevra cette rencontre : s\'il l\'accepte, sa période est remise à zéro et vous partagez les photos.'**
  String get shareDoneHelp;

  /// No description provided for @sharePlannedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Votre ami reçoit une invitation : s\'il accepte, vous avez tous les deux le rendez-vous et une galerie de photos commune. Vos notes restent privées.'**
  String get sharePlannedHelp;

  /// No description provided for @photosAfterSave.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez ajouter des photos une fois le rendez-vous enregistré.'**
  String get photosAfterSave;

  /// No description provided for @kindDueDigest.
  ///
  /// In fr, this message translates to:
  /// **'Contacts à recontacter'**
  String get kindDueDigest;

  /// No description provided for @kindBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire'**
  String get kindBirthday;

  /// No description provided for @kindRdvReminder.
  ///
  /// In fr, this message translates to:
  /// **'Rappel de rendez-vous'**
  String get kindRdvReminder;

  /// No description provided for @kindRdvFollowup.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de rendez-vous'**
  String get kindRdvFollowup;

  /// No description provided for @kindFriendRequest.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'ami'**
  String get kindFriendRequest;

  /// No description provided for @kindFriendAccept.
  ///
  /// In fr, this message translates to:
  /// **'Ami accepté'**
  String get kindFriendAccept;

  /// No description provided for @kindRdvInvite.
  ///
  /// In fr, this message translates to:
  /// **'Invitation à un rendez-vous'**
  String get kindRdvInvite;

  /// No description provided for @kindRdvResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse à une invitation'**
  String get kindRdvResponse;

  /// No description provided for @kindRdvChange.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous partagé modifié'**
  String get kindRdvChange;

  /// No description provided for @kindWave.
  ///
  /// In fr, this message translates to:
  /// **'Envie de se voir'**
  String get kindWave;

  /// No description provided for @kindTest.
  ///
  /// In fr, this message translates to:
  /// **'Test'**
  String get kindTest;

  /// No description provided for @privacyFooter.
  ///
  /// In fr, this message translates to:
  /// **'SeeU · Vos données restent privées : seuls les rendez-vous que vous envoyez à un ami sont partagés avec lui.'**
  String get privacyFooter;

  /// No description provided for @profileUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour'**
  String get profileUpdated;

  /// No description provided for @profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @yourFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Votre prénom'**
  String get yourFirstName;

  /// No description provided for @birthDateFriendsHint.
  ///
  /// In fr, this message translates to:
  /// **'Visible par vos amis SeeU uniquement : leur fiche à votre nom se remplit toute seule.'**
  String get birthDateFriendsHint;

  /// No description provided for @shareMyHandle.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon @'**
  String get shareMyHandle;

  /// No description provided for @emailNeverShown.
  ///
  /// In fr, this message translates to:
  /// **'Jamais affiché aux autres utilisateurs avant qu\'ils soient vos amis'**
  String get emailNeverShown;

  /// No description provided for @timezone.
  ///
  /// In fr, this message translates to:
  /// **'Fuseau horaire'**
  String get timezone;

  /// No description provided for @timezoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Détecté automatiquement, utilisé pour l\'heure des rappels'**
  String get timezoneHint;

  /// No description provided for @pushDisabledDevice.
  ///
  /// In fr, this message translates to:
  /// **'Notifications désactivées sur cet appareil'**
  String get pushDisabledDevice;

  /// No description provided for @pushEnabledDevice.
  ///
  /// In fr, this message translates to:
  /// **'Notifications activées sur cet appareil'**
  String get pushEnabledDevice;

  /// No description provided for @pushPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée : autorisez les notifications dans les réglages de l\'appareil.'**
  String get pushPermissionDenied;

  /// No description provided for @testSent.
  ///
  /// In fr, this message translates to:
  /// **'Notification de test envoyée'**
  String get testSent;

  /// No description provided for @pushUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Notifications push indisponibles sur cette version ; les rappels partiront par email.'**
  String get pushUnsupported;

  /// No description provided for @pushBlockedSettings.
  ///
  /// In fr, this message translates to:
  /// **'Notifications bloquées : autorisez-les dans les réglages du téléphone.'**
  String get pushBlockedSettings;

  /// No description provided for @pushOnDevice.
  ///
  /// In fr, this message translates to:
  /// **'Activées sur cet appareil'**
  String get pushOnDevice;

  /// No description provided for @disable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get disable;

  /// No description provided for @pushOffDevice.
  ///
  /// In fr, this message translates to:
  /// **'Non activées sur cet appareil'**
  String get pushOffDevice;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels push'**
  String get pushReminders;

  /// No description provided for @pushRemindersSub.
  ///
  /// In fr, this message translates to:
  /// **'Sur tous les appareils où vous les avez activées'**
  String get pushRemindersSub;

  /// No description provided for @emailReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels par email'**
  String get emailReminders;

  /// No description provided for @emailRemindersSub.
  ///
  /// In fr, this message translates to:
  /// **'Utilisés si aucun appareil n\'a les notifications push activées'**
  String get emailRemindersSub;

  /// No description provided for @dailyHour.
  ///
  /// In fr, this message translates to:
  /// **'Heure du rappel quotidien'**
  String get dailyHour;

  /// No description provided for @dailyHourHint.
  ///
  /// In fr, this message translates to:
  /// **'Un seul récapitulatif par jour des contacts à recontacter'**
  String get dailyHourHint;

  /// No description provided for @notifyLead.
  ///
  /// In fr, this message translates to:
  /// **'Prévenir'**
  String get notifyLead;

  /// No description provided for @leadSameDay.
  ///
  /// In fr, this message translates to:
  /// **'Le jour de l\'échéance'**
  String get leadSameDay;

  /// No description provided for @leadDays.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 jour avant} other{{n} jours avant}}'**
  String leadDays(int n);

  /// No description provided for @leadWeeks.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 semaine avant} other{{n} semaines avant}}'**
  String leadWeeks(int n);

  /// No description provided for @rdvReminderLead.
  ///
  /// In fr, this message translates to:
  /// **'Rappel avant un rendez-vous'**
  String get rdvReminderLead;

  /// No description provided for @leadMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{n} minutes avant'**
  String leadMinutes(int n);

  /// No description provided for @leadHours.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 heure avant} other{{n} heures avant}}'**
  String leadHours(int n);

  /// No description provided for @leadEve.
  ///
  /// In fr, this message translates to:
  /// **'La veille (24 h avant)'**
  String get leadEve;

  /// No description provided for @sendTestNotification.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une notification de test'**
  String get sendTestNotification;

  /// No description provided for @lastNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Dernières notifications'**
  String get lastNotifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification envoyée pour l\'instant.'**
  String get noNotificationsYet;

  /// No description provided for @channelNone.
  ///
  /// In fr, this message translates to:
  /// **'aucun'**
  String get channelNone;

  /// No description provided for @application.
  ///
  /// In fr, this message translates to:
  /// **'Application'**
  String get application;

  /// No description provided for @version.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @exportSubject.
  ///
  /// In fr, this message translates to:
  /// **'Export SeeU'**
  String get exportSubject;

  /// No description provided for @data.
  ///
  /// In fr, this message translates to:
  /// **'Données'**
  String get data;

  /// No description provided for @importFromPhoneLong.
  ///
  /// In fr, this message translates to:
  /// **'Importer des contacts du téléphone'**
  String get importFromPhoneLong;

  /// No description provided for @importFromPhoneSub.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le carnet d\'adresses, avec revue contact par contact.'**
  String get importFromPhoneSub;

  /// No description provided for @exportData.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get exportData;

  /// No description provided for @exportDataSub.
  ///
  /// In fr, this message translates to:
  /// **'Profil, contacts, rendez-vous et liste des photos.'**
  String get exportDataSub;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement votre compte ?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos contacts, rendez-vous et photos seront effacés. Cette action est irréversible.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteMyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteMyAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé'**
  String get accountDeleted;

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get account;

  /// No description provided for @changePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get changePassword;

  /// No description provided for @passwordsNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe ne correspondent pas.'**
  String get passwordsNoMatch;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @visPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Privé'**
  String get visPrivate;

  /// No description provided for @visContacts.
  ///
  /// In fr, this message translates to:
  /// **'Entre amis'**
  String get visContacts;

  /// No description provided for @visPublic.
  ///
  /// In fr, this message translates to:
  /// **'Public'**
  String get visPublic;

  /// No description provided for @eventBy.
  ///
  /// In fr, this message translates to:
  /// **'Événement de {name}'**
  String eventBy(String name);

  /// No description provided for @sponsored.
  ///
  /// In fr, this message translates to:
  /// **'Sponsorisé'**
  String get sponsored;

  /// No description provided for @dateToChoose.
  ///
  /// In fr, this message translates to:
  /// **'Date à choisir'**
  String get dateToChoose;

  /// No description provided for @byYou.
  ///
  /// In fr, this message translates to:
  /// **'Par vous'**
  String get byYou;

  /// No description provided for @nGoing.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Personne pour l\'instant} =1{1 participant} other{{n} participants}}'**
  String nGoing(int n);

  /// No description provided for @youreGoing.
  ///
  /// In fr, this message translates to:
  /// **'Vous y allez'**
  String get youreGoing;

  /// No description provided for @homeAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Mon agenda'**
  String get homeAgenda;

  /// No description provided for @homeFriends.
  ///
  /// In fr, this message translates to:
  /// **'Entre amis'**
  String get homeFriends;

  /// No description provided for @homeExplore.
  ///
  /// In fr, this message translates to:
  /// **'Explorer'**
  String get homeExplore;

  /// No description provided for @exploreIntro.
  ///
  /// In fr, this message translates to:
  /// **'Les événements publics à venir : concerts, sorties, rencontres… Rejoignez ceux qui vous tentent.'**
  String get exploreIntro;

  /// No description provided for @friendsFeedIntro.
  ///
  /// In fr, this message translates to:
  /// **'Les événements que vos amis ouvrent à tous leurs amis. Vous pouvez les rejoindre directement.'**
  String get friendsFeedIntro;

  /// No description provided for @exploreEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement public pour l\'instant'**
  String get exploreEmptyTitle;

  /// No description provided for @exploreEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Revenez bientôt : les événements ouverts à tous apparaîtront ici.'**
  String get exploreEmptyMessage;

  /// No description provided for @friendsFeedEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien de prévu entre amis'**
  String get friendsFeedEmptyTitle;

  /// No description provided for @friendsFeedEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Quand un ami crée un événement « Entre amis », il apparaît ici. Lancez le vôtre !'**
  String get friendsFeedEmptyMessage;

  /// No description provided for @createFriendsEvent.
  ///
  /// In fr, this message translates to:
  /// **'Créer un événement entre amis'**
  String get createFriendsEvent;

  /// No description provided for @loadMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get loadMore;

  /// No description provided for @exploreSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (titre, lieu, @organisateur)'**
  String get exploreSearchHint;

  /// No description provided for @slotsAtLeastTwo.
  ///
  /// In fr, this message translates to:
  /// **'Proposez au moins deux créneaux différents.'**
  String get slotsAtLeastTwo;

  /// No description provided for @proposeSlots.
  ///
  /// In fr, this message translates to:
  /// **'Proposer ces créneaux'**
  String get proposeSlots;

  /// No description provided for @whoCanSee.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut le voir ?'**
  String get whoCanSee;

  /// No description provided for @memberEditHint.
  ///
  /// In fr, this message translates to:
  /// **'Vous participez à cet événement : seul l\'organisateur peut changer la date, le lieu ou l\'annuler. Vos notes, vos contacts et le statut restent à vous.'**
  String get memberEditHint;

  /// No description provided for @withWhomOptional.
  ///
  /// In fr, this message translates to:
  /// **'Avec qui ?'**
  String get withWhomOptional;

  /// No description provided for @withWhomHint.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts qui viennent : leur compteur repart de zéro une fois l\'événement passé.'**
  String get withWhomHint;

  /// No description provided for @oneDate.
  ///
  /// In fr, this message translates to:
  /// **'Une date'**
  String get oneDate;

  /// No description provided for @severalSlots.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs créneaux'**
  String get severalSlots;

  /// No description provided for @descriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @descriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Visible par tous ceux qui voient l\'événement.'**
  String get descriptionHint;

  /// No description provided for @descriptionPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Programme, ce qu\'il faut apporter…'**
  String get descriptionPlaceholder;

  /// No description provided for @statusHintCancelledAll.
  ///
  /// In fr, this message translates to:
  /// **'L\'événement est annulé pour tous les participants.'**
  String get statusHintCancelledAll;

  /// No description provided for @shareSlotsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vos amis reçoivent les créneaux et indiquent leurs disponibilités. Vous choisissez ensuite la date.'**
  String get shareSlotsHelp;

  /// No description provided for @contactsBroadcastHint.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos amis SeeU seront prévenus et pourront le rejoindre.'**
  String get contactsBroadcastHint;

  /// No description provided for @publicPhotosHint.
  ///
  /// In fr, this message translates to:
  /// **'Événement public : vous seul pourrez publier des annonces et des photos.'**
  String get publicPhotosHint;

  /// No description provided for @publicReserved.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux organisateurs vérifiés pour l\'instant.'**
  String get publicReserved;

  /// No description provided for @visPrivateHelp.
  ///
  /// In fr, this message translates to:
  /// **'Seulement les amis que vous invitez.'**
  String get visPrivateHelp;

  /// No description provided for @visContactsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos amis SeeU le voient et peuvent le rejoindre.'**
  String get visContactsHelp;

  /// No description provided for @visPublicHelp.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde peut le voir et le rejoindre.'**
  String get visPublicHelp;

  /// No description provided for @slotsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Créneaux proposés'**
  String get slotsLabel;

  /// No description provided for @slotsHint.
  ///
  /// In fr, this message translates to:
  /// **'Chaque participant indique s\'il est disponible ; vous choisissez ensuite le meilleur créneau.'**
  String get slotsHint;

  /// No description provided for @addSlot.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un créneau'**
  String get addSlot;

  /// No description provided for @slotsPollTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quand êtes-vous disponible ?'**
  String get slotsPollTitle;

  /// No description provided for @slotsPollHelp.
  ///
  /// In fr, this message translates to:
  /// **'Pour chaque créneau : ✓ disponible, ? peut-être, ✗ pas disponible.'**
  String get slotsPollHelp;

  /// No description provided for @slotYes.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get slotYes;

  /// No description provided for @slotMaybe.
  ///
  /// In fr, this message translates to:
  /// **'Peut-être'**
  String get slotMaybe;

  /// No description provided for @slotNo.
  ///
  /// In fr, this message translates to:
  /// **'Pas disponible'**
  String get slotNo;

  /// No description provided for @slotMaybeShort.
  ///
  /// In fr, this message translates to:
  /// **'peut-être'**
  String get slotMaybeShort;

  /// No description provided for @slotCounts.
  ///
  /// In fr, this message translates to:
  /// **'{nYes, plural, =0{0 dispo} =1{1 dispo} other{{nYes} dispo}} · {nMaybe} peut-être'**
  String slotCounts(int nYes, int nMaybe);

  /// No description provided for @choose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get choose;

  /// No description provided for @chooseSlotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fixer la date au {when} ?'**
  String chooseSlotTitle(String when);

  /// No description provided for @chooseSlotMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le vote se termine et tous les participants sont prévenus de la date choisie.'**
  String get chooseSlotMessage;

  /// No description provided for @chooseThisSlot.
  ///
  /// In fr, this message translates to:
  /// **'Choisir ce créneau'**
  String get chooseThisSlot;

  /// No description provided for @slotChosen.
  ///
  /// In fr, this message translates to:
  /// **'Date choisie, les participants sont prévenus'**
  String get slotChosen;

  /// No description provided for @slotsNoVotes.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de réponses'**
  String get slotsNoVotes;

  /// No description provided for @bestSlot.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur créneau'**
  String get bestSlot;

  /// No description provided for @bestSlotsTie.
  ///
  /// In fr, this message translates to:
  /// **'Meilleurs créneaux (ex æquo)'**
  String get bestSlotsTie;

  /// No description provided for @slotsWaitOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Vos invités vont indiquer leurs disponibilités. Vous serez prévenu, puis vous choisirez la date.'**
  String get slotsWaitOrganizer;

  /// No description provided for @slotsWaitMember.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez vos disponibilités : l\'organisateur choisira ensuite la date.'**
  String get slotsWaitMember;

  /// No description provided for @slotsOrganizerDecides.
  ///
  /// In fr, this message translates to:
  /// **'L\'organisateur choisira la date définitive.'**
  String get slotsOrganizerDecides;

  /// No description provided for @eventMuted.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de cet événement coupées'**
  String get eventMuted;

  /// No description provided for @eventUnmuted.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de cet événement réactivées'**
  String get eventUnmuted;

  /// No description provided for @personMuted.
  ///
  /// In fr, this message translates to:
  /// **'Événements et messages de {name} masqués'**
  String personMuted(String name);

  /// No description provided for @personUnmuted.
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'est plus masqué(e)'**
  String personUnmuted(String name);

  /// No description provided for @blockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name} ?'**
  String blockTitle(String name);

  /// No description provided for @blockMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne serez plus amis, vous ne verrez plus ses événements ni ses messages, et vous ne pourrez plus vous trouver ni vous inviter. Vous pourrez le débloquer dans les Réglages.'**
  String get blockMessage;

  /// No description provided for @block.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get block;

  /// No description provided for @blocked.
  ///
  /// In fr, this message translates to:
  /// **'{name} est bloqué(e)'**
  String blocked(String name);

  /// No description provided for @mutePerson.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les événements de {name}'**
  String mutePerson(String name);

  /// No description provided for @unmutePerson.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus masquer {name}'**
  String unmutePerson(String name);

  /// No description provided for @blockName.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name}'**
  String blockName(String name);

  /// No description provided for @announcements.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get announcements;

  /// No description provided for @chat.
  ///
  /// In fr, this message translates to:
  /// **'Discussion'**
  String get chat;

  /// No description provided for @announceEmptyOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Publiez des annonces : tous les participants confirmés seront prévenus.'**
  String get announceEmptyOrganizer;

  /// No description provided for @announceEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'annonce de l\'organisateur.'**
  String get announceEmpty;

  /// No description provided for @chatEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de message. Lancez la discussion !'**
  String get chatEmpty;

  /// No description provided for @openAnnouncements.
  ///
  /// In fr, this message translates to:
  /// **'Voir les annonces'**
  String get openAnnouncements;

  /// No description provided for @openChat.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la discussion'**
  String get openChat;

  /// No description provided for @nNew.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 nouveau} other{{n} nouveaux}}'**
  String nNew(int n);

  /// No description provided for @deleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le message'**
  String get deleteMessage;

  /// No description provided for @announceHint.
  ///
  /// In fr, this message translates to:
  /// **'Une annonce pour les participants…'**
  String get announceHint;

  /// No description provided for @messageHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre message…'**
  String get messageHint;

  /// No description provided for @announceReadOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seul l\'organisateur publie ici. Vous êtes prévenu à chaque annonce si vous venez.'**
  String get announceReadOnly;

  /// No description provided for @chatJoinToPost.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez l\'événement pour écrire.'**
  String get chatJoinToPost;

  /// No description provided for @moreActions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'actions'**
  String get moreActions;

  /// No description provided for @muteEvent.
  ///
  /// In fr, this message translates to:
  /// **'Couper les notifications de cet événement'**
  String get muteEvent;

  /// No description provided for @unmuteEvent.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver les notifications de cet événement'**
  String get unmuteEvent;

  /// No description provided for @joinedToast.
  ///
  /// In fr, this message translates to:
  /// **'C\'est noté, vous y allez !'**
  String get joinedToast;

  /// No description provided for @notGoingToast.
  ///
  /// In fr, this message translates to:
  /// **'C\'est noté, vous n\'y allez pas'**
  String get notGoingToast;

  /// No description provided for @organizedBy.
  ///
  /// In fr, this message translates to:
  /// **'Organisé par {name}'**
  String organizedBy(String name);

  /// No description provided for @eventCancelledInfo.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement a été annulé par l\'organisateur.'**
  String get eventCancelledInfo;

  /// No description provided for @joinToVote.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez-le pour indiquer vos disponibilités'**
  String get joinToVote;

  /// No description provided for @areYouComing.
  ///
  /// In fr, this message translates to:
  /// **'Vous venez ?'**
  String get areYouComing;

  /// No description provided for @joinPublicHint.
  ///
  /// In fr, this message translates to:
  /// **'« À confirmer » l\'ajoute à votre agenda sans engagement. Vous recevrez les annonces de l\'organisateur si vous venez.'**
  String get joinPublicHint;

  /// No description provided for @joinFriendsHint.
  ///
  /// In fr, this message translates to:
  /// **'L\'organisateur est prévenu quand vous venez. « À confirmer » l\'ajoute à votre agenda sans engagement.'**
  String get joinFriendsHint;

  /// No description provided for @moderationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Masqués et bloqués'**
  String get moderationTitle;

  /// No description provided for @moderationIntro.
  ///
  /// In fr, this message translates to:
  /// **'Masquer coupe les notifications et retire les événements des fils. Bloquer coupe tout contact avec la personne.'**
  String get moderationIntro;

  /// No description provided for @mutedPeopleAndEvents.
  ///
  /// In fr, this message translates to:
  /// **'Personnes et événements masqués'**
  String get mutedPeopleAndEvents;

  /// No description provided for @nothingMuted.
  ///
  /// In fr, this message translates to:
  /// **'Rien de masqué.'**
  String get nothingMuted;

  /// No description provided for @eventsMuted.
  ///
  /// In fr, this message translates to:
  /// **'événements et messages masqués'**
  String get eventsMuted;

  /// No description provided for @unmute.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get unmute;

  /// No description provided for @blockedPeople.
  ///
  /// In fr, this message translates to:
  /// **'Personnes bloquées'**
  String get blockedPeople;

  /// No description provided for @nobodyBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'est bloqué.'**
  String get nobodyBlocked;

  /// No description provided for @unblock.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer'**
  String get unblock;

  /// No description provided for @unblocked.
  ///
  /// In fr, this message translates to:
  /// **'{name} est débloqué(e)'**
  String unblocked(String name);

  /// No description provided for @unblockHint.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer ne rétablit pas l\'amitié : il faudra renvoyer une demande.'**
  String get unblockHint;

  /// No description provided for @mutedAndBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Masqués et bloqués'**
  String get mutedAndBlocked;

  /// No description provided for @mutedAndBlockedSub.
  ///
  /// In fr, this message translates to:
  /// **'Personnes et événements que vous avez masqués ou bloqués.'**
  String get mutedAndBlockedSub;

  /// No description provided for @leaveEventTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet événement de votre agenda ?'**
  String get leaveEventTitle;

  /// No description provided for @leaveEventMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne participerez plus et vos photos disparaîtront de la galerie commune. Vous pourrez le rejoindre à nouveau s\'il est encore visible.'**
  String get leaveEventMessage;

  /// No description provided for @removeFromAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de mon agenda'**
  String get removeFromAgenda;

  /// No description provided for @myContactsInEvent.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get myContactsInEvent;

  /// No description provided for @photosEmptyPublicMember.
  ///
  /// In fr, this message translates to:
  /// **'L\'organisateur partagera ici les photos de l\'événement.'**
  String get photosEmptyPublicMember;

  /// No description provided for @you.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get you;

  /// No description provided for @organizer.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur'**
  String get organizer;

  /// No description provided for @andNMore.
  ///
  /// In fr, this message translates to:
  /// **'et {n} autres'**
  String andNMore(int n);

  /// No description provided for @kindEventNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel événement entre amis'**
  String get kindEventNew;

  /// No description provided for @kindEventJoin.
  ///
  /// In fr, this message translates to:
  /// **'Participant à votre événement'**
  String get kindEventJoin;

  /// No description provided for @kindEventMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message dans un événement'**
  String get kindEventMessage;

  /// No description provided for @kindEventAnnouncement.
  ///
  /// In fr, this message translates to:
  /// **'Annonce d\'un événement'**
  String get kindEventAnnouncement;

  /// No description provided for @deleteRdvOrganizerPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes l\'organisateur : l\'événement sera annulé pour tous les participants (ils seront prévenus), puis retiré de votre agenda.'**
  String get deleteRdvOrganizerPlanned;

  /// No description provided for @availabilitySaved.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités enregistrées'**
  String get availabilitySaved;

  /// No description provided for @availabilitySentGoing.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités envoyées : vous êtes noté comme participant'**
  String get availabilitySentGoing;

  /// No description provided for @availabilitySentDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez décliné l\'événement, l\'organisateur est prévenu'**
  String get availabilitySentDeclined;

  /// No description provided for @confirmAvailabilityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer vos disponibilités ?'**
  String get confirmAvailabilityTitle;

  /// No description provided for @unansweredAsMaybe.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 créneau sans réponse sera compté « peut-être ».} other{{n} créneaux sans réponse seront comptés « peut-être ».}}'**
  String unansweredAsMaybe(int n);

  /// No description provided for @confirmAndDecline.
  ///
  /// In fr, this message translates to:
  /// **'Décliner l\'événement'**
  String get confirmAndDecline;

  /// No description provided for @confirmAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Valider mes disponibilités'**
  String get confirmAvailability;

  /// No description provided for @leaveWithoutSending.
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans envoyer'**
  String get leaveWithoutSending;

  /// No description provided for @outcomeGoing.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes disponible au moins une fois : vous serez noté comme participant et l\'organisateur sera prévenu.'**
  String get outcomeGoing;

  /// No description provided for @outcomeDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Aucun créneau ne vous convient : l\'événement sera décliné et l\'organisateur prévenu.'**
  String get outcomeDeclined;

  /// No description provided for @outcomeMaybe.
  ///
  /// In fr, this message translates to:
  /// **'Rien de sûr pour l\'instant : l\'événement reste « à confirmer », sans prévenir l\'organisateur.'**
  String get outcomeMaybe;

  /// No description provided for @yourAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse :'**
  String get yourAnswer;

  /// No description provided for @availabilitySent.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités envoyées'**
  String get availabilitySent;

  /// No description provided for @notSentYet.
  ///
  /// In fr, this message translates to:
  /// **'non envoyé'**
  String get notSentYet;

  /// No description provided for @severalSlotsProposed.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs créneaux proposés'**
  String get severalSlotsProposed;

  /// No description provided for @giveAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Indiquer mes disponibilités'**
  String get giveAvailability;

  /// No description provided for @slotsInviteHint.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez l\'événement pour répondre créneau par créneau.'**
  String get slotsInviteHint;

  /// No description provided for @guestsCanInvite.
  ///
  /// In fr, this message translates to:
  /// **'Les invités peuvent inviter leurs amis'**
  String get guestsCanInvite;

  /// No description provided for @guestsCanInviteHelp.
  ///
  /// In fr, this message translates to:
  /// **'Sinon, vous seul pouvez ajouter des participants.'**
  String get guestsCanInviteHelp;

  /// No description provided for @blockContactDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Votre contact « {name} » sera aussi supprimé : plus de rappels pour le revoir.'**
  String blockContactDeleted(String name);

  /// No description provided for @blockedAndDeleted.
  ///
  /// In fr, this message translates to:
  /// **'{name} est bloqué(e) et son contact supprimé'**
  String blockedAndDeleted(String name);

  /// No description provided for @demoAds.
  ///
  /// In fr, this message translates to:
  /// **'Publicités de démonstration'**
  String get demoAds;

  /// No description provided for @demoAdsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Affiche de fausses annonces pour juger de leur intégration (mode développement).'**
  String get demoAdsHelp;

  /// No description provided for @adCta.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus'**
  String get adCta;

  /// No description provided for @earlierMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages précédents'**
  String get earlierMessages;

  /// No description provided for @tagPersonal.
  ///
  /// In fr, this message translates to:
  /// **'(personnel)'**
  String get tagPersonal;

  /// No description provided for @tagShared.
  ///
  /// In fr, this message translates to:
  /// **'(partagée)'**
  String get tagShared;

  /// No description provided for @titleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un titre au rendez-vous'**
  String get titleRequired;

  /// No description provided for @descriptionHintAll.
  ///
  /// In fr, this message translates to:
  /// **'Visible par tous les participants.'**
  String get descriptionHintAll;

  /// No description provided for @editFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la fréquence'**
  String get editFrequency;

  /// No description provided for @frequencySheetSub.
  ///
  /// In fr, this message translates to:
  /// **'À quelle fréquence voulez-vous voir {name} ?'**
  String frequencySheetSub(String name);

  /// No description provided for @frequencyUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence mise à jour'**
  String get frequencyUpdated;

  /// No description provided for @organizedByYou.
  ///
  /// In fr, this message translates to:
  /// **'Organisé par vous'**
  String get organizedByYou;

  /// No description provided for @youAreGuest.
  ///
  /// In fr, this message translates to:
  /// **'Invité'**
  String get youAreGuest;

  /// No description provided for @filterMine.
  ///
  /// In fr, this message translates to:
  /// **'Organisés par vous'**
  String get filterMine;

  /// No description provided for @filterInvited.
  ///
  /// In fr, this message translates to:
  /// **'Invitations'**
  String get filterInvited;

  /// No description provided for @noMineUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rendez-vous organisé par vous.'**
  String get noMineUpcoming;

  /// No description provided for @noInvitedUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Aucune invitation à venir.'**
  String get noInvitedUpcoming;

  /// No description provided for @notOnSeeu.
  ///
  /// In fr, this message translates to:
  /// **'Pas sur SeeU'**
  String get notOnSeeu;

  /// No description provided for @notOnSeeuAddedBy.
  ///
  /// In fr, this message translates to:
  /// **'Pas sur SeeU · ajouté par {name}'**
  String notOnSeeuAddedBy(String name);

  /// No description provided for @memberPending.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer'**
  String get memberPending;

  /// No description provided for @inviteFriend.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get inviteFriend;

  /// No description provided for @peopleLegend.
  ///
  /// In fr, this message translates to:
  /// **'Icône grise : pas de compte SeeU. Seuls les amis SeeU reçoivent l\'invitation, voient le chat et les photos.'**
  String get peopleLegend;

  /// No description provided for @leftEvent.
  ///
  /// In fr, this message translates to:
  /// **'A quitté le rendez-vous'**
  String get leftEvent;

  /// No description provided for @reinvite.
  ///
  /// In fr, this message translates to:
  /// **'Réinviter'**
  String get reinvite;

  /// No description provided for @phaseUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Prévu'**
  String get phaseUpcoming;

  /// No description provided for @phaseNow.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get phaseNow;

  /// No description provided for @phasePast.
  ///
  /// In fr, this message translates to:
  /// **'Passé'**
  String get phasePast;

  /// No description provided for @keepInTouchHelp.
  ///
  /// In fr, this message translates to:
  /// **'Rappels selon la fréquence choisie pour chaque contact. Rien n\'est prévu : planifiez un rendez-vous, ou notez que vous vous êtes vus.'**
  String get keepInTouchHelp;

  /// No description provided for @usernameFixed.
  ///
  /// In fr, this message translates to:
  /// **'Votre identifiant ne peut pas être modifié : c\'est grâce à lui que vos amis vous trouvent.'**
  String get usernameFixed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
