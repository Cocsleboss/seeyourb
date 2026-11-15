// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get and => 'and';

  @override
  String andOthers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'and $n others',
      one: 'and 1 other',
    );
    return '$_temp0';
  }

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String dayAtTime(String day, String time) {
    return '$day at $time';
  }

  @override
  String get greetingNight => 'Good night';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String nDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String nWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String nMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String nYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String nYearsHalf(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n and a half years',
      one: 'a year and a half',
    );
    return '$_temp0';
  }

  @override
  String shortDays(int n) {
    return '${n}d';
  }

  @override
  String shortWeeks(int n) {
    return '${n}w';
  }

  @override
  String shortMonths(int n) {
    return '${n}mo';
  }

  @override
  String shortYears(int n) {
    return '${n}y';
  }

  @override
  String dueOverdue(String duration) {
    return 'Overdue by $duration';
  }

  @override
  String get dueToday => 'Catch up today';

  @override
  String get dueTodayShort => 'Today';

  @override
  String dueIn(String duration) {
    return 'Catch up in $duration';
  }

  @override
  String everyDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'every $n days',
      one: 'every day',
    );
    return '$_temp0';
  }

  @override
  String everyWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'every $n weeks',
      one: 'every week',
    );
    return '$_temp0';
  }

  @override
  String everyMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'every $n months',
      one: 'every month',
    );
    return '$_temp0';
  }

  @override
  String everyYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'every $n years',
      one: 'every year',
    );
    return '$_temp0';
  }

  @override
  String unitDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'years',
      one: 'year',
    );
    return '$_temp0';
  }

  @override
  String get statusPlanned => 'Planned';

  @override
  String get statusDone => 'Happened';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get rsvpPending => 'Maybe';

  @override
  String get rsvpAccepted => 'Going';

  @override
  String get rsvpDeclined => 'Declined';

  @override
  String withNames(String names) {
    return 'With $names';
  }

  @override
  String withNamesMore(String names, int n) {
    return 'With $names and $n others';
  }

  @override
  String get aFriend => 'A friend';

  @override
  String get catFamily => 'Family';

  @override
  String get catFriends => 'Friends';

  @override
  String get catWork => 'Work';

  @override
  String get catOther => 'Other';

  @override
  String get usernameHint =>
      '3 to 20 characters: lowercase letters, digits, dot and underscore.';

  @override
  String usernameTooShort(int n) {
    return 'At least $n characters.';
  }

  @override
  String get usernameBadStart => 'Must start with a letter or a digit.';

  @override
  String get errNetwork => 'No connection. Check your network.';

  @override
  String get errGeneric => 'Something went wrong.';

  @override
  String get errSessionExpired => 'Session expired, please sign in again.';

  @override
  String get errForbidden => 'Action not allowed.';

  @override
  String get errUsernameTaken => 'This username is already taken.';

  @override
  String get errUsernameInvalid => 'Invalid username.';

  @override
  String get errFriendAlreadyLinked =>
      'This friend is already linked to another contact.';

  @override
  String get errDuplicate => 'This already exists.';

  @override
  String get errFileTooLarge => 'File too large (10 MB max).';

  @override
  String get errBadCredentials => 'Wrong email or password.';

  @override
  String get errEmailNotConfirmed =>
      'Please confirm your email address first (link sent by email).';

  @override
  String get errEmailTaken => 'An account already exists with this email.';

  @override
  String get errWeakPassword =>
      'The password must be at least 6 characters long.';

  @override
  String get errRateLimit => 'Too many attempts, try again in a few minutes.';

  @override
  String get errSignupsDisabled => 'Sign-ups are disabled.';

  @override
  String get errInvalidEmail => 'Invalid email address.';

  @override
  String get errSamePassword => 'Choose a password different from the old one.';

  @override
  String get errLinkExpired => 'Invalid or expired link.';

  @override
  String get errNotFriends => 'This person is not one of your SeeU friends.';

  @override
  String get errNoLongerFriends => 'You are no longer friends on SeeU.';

  @override
  String get errRdvNotFound => 'Event not found.';

  @override
  String get errInviteNotFound => 'Invitation not found.';

  @override
  String get errRdvGone => 'This event no longer exists.';

  @override
  String get errRdvCancelled => 'This event is cancelled.';

  @override
  String get errWaveAlready => 'You already waved at them today.';

  @override
  String get errAlreadyAnswered => 'You already answered this invitation.';

  @override
  String get errBadAnswer => 'Invalid answer.';

  @override
  String get errRequestNotFound => 'Request not found.';

  @override
  String get errNotOrganizer => 'Only the organizer can do this.';

  @override
  String get errPublicNotAllowed =>
      'You don\'t have access to public events yet.';

  @override
  String get errSlotsClosed => 'Timeslot voting is closed.';

  @override
  String get errSlotsNotAllowed =>
      'Multiple timeslots aren\'t available for public events.';

  @override
  String get errEventNotVisible => 'This event isn\'t available.';

  @override
  String get errBlocked => 'This action isn\'t possible with this person.';

  @override
  String get errChatReadOnly => 'Only the organizer can post here.';

  @override
  String get errPhotosOrganizerOnly => 'Only the organizer can add photos.';

  @override
  String get errNotParticipant => 'Join the event to take part.';

  @override
  String get errTooManySlots => '10 timeslots maximum.';

  @override
  String errContactsAddedBeforeError(int n, Object error) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts added before the error: $error',
      one: '1 contact added before the error: $error',
    );
    return '$_temp0';
  }

  @override
  String get errDeleteAccountFailed =>
      'Can\'t delete the account right now. Try again later.';

  @override
  String get errLinkOtherDevice =>
      'This link must be opened on the device where you requested it. Open the email on that device, or request a new link from this one.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabHistory => 'History';

  @override
  String get tabSettings => 'Settings';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get add => 'Add';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get notSeenYet => 'Not seen yet';

  @override
  String seenOn(String date) {
    return 'Seen on $date';
  }

  @override
  String get soonPill => '★ Soon';

  @override
  String get seeuFriend => 'SeeU friend';

  @override
  String get freqCustom => 'Custom';

  @override
  String get categoryOther => 'Other…';

  @override
  String get categoryHint => 'E.g. Neighbours, Sport…';

  @override
  String get pushChannelName => 'SeeU reminders';

  @override
  String get pushChannelDesc => 'Reminders, events and your friends\' activity';

  @override
  String get quickNewRdv => 'New event';

  @override
  String get quickNewContact => 'New contact';

  @override
  String get historyTitle => 'History';

  @override
  String get historyList => 'List';

  @override
  String get historyMonth => 'Month';

  @override
  String get historyEmptyTitle => 'No meetups yet';

  @override
  String get historyEmptyMessage =>
      'Events that happened or were cancelled will show up here.';

  @override
  String get filterAll => 'All';

  @override
  String get filterDone => 'Happened';

  @override
  String get filterCancelled => 'Cancelled';

  @override
  String get historySearchHint => 'Search (contact, title, place)';

  @override
  String get noResults => 'No results';

  @override
  String historyCounts(int nMet, int nCancelled) {
    String _temp0 = intl.Intl.pluralLogic(
      nMet,
      locale: localeName,
      other: '$nMet meetups',
      one: '1 meetup',
    );
    return '$_temp0 · $nCancelled cancelled';
  }

  @override
  String get prevMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get loading => 'Loading…';

  @override
  String get calendarNoneThisMonth => 'No meetups this month.';

  @override
  String calendarMetInMonth(int n, Object month) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n meetups in $month',
      one: '1 meetup in $month',
    );
    return '$_temp0';
  }

  @override
  String calendarDayEvents(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get dayNoEvents => 'No events that day';

  @override
  String dayMetCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n meetups that day',
      one: '1 meetup that day',
      zero: 'No meetups that day',
    );
    return '$_temp0';
  }

  @override
  String get rsvpToastAccepted => 'Invitation accepted';

  @override
  String get rsvpToastDeclined => 'Invitation declined';

  @override
  String get rsvpToastPending => 'Marked as “maybe”';

  @override
  String get rsvpDecline => 'Decline';

  @override
  String get rsvpAccept => 'Accept';

  @override
  String get rsvpMaybe => 'Maybe';

  @override
  String get statusFutureTitle => 'This event is planned for later';

  @override
  String statusFutureMessage(String when) {
    return 'It is planned for $when. Mark it as happened anyway?';
  }

  @override
  String get statusFutureConfirm => 'Yes, it happened';

  @override
  String get statusToastDone => 'Event confirmed';

  @override
  String get statusToastDoneReset =>
      'Event confirmed: last meetup date updated';

  @override
  String get statusToastCancelled => 'Event cancelled';

  @override
  String get statusToastPlanned => 'Event set back to planned';

  @override
  String get statusSetPlanned => 'Set back to planned';

  @override
  String get statusSetDone => 'Happened';

  @override
  String get statusSetCancelled => 'Cancelled';

  @override
  String inviteSharesMeetup(String name) {
    return '$name shared a meetup with you';
  }

  @override
  String inviteProposes(String name) {
    return '$name invites you to an event';
  }

  @override
  String get inviteTentativeHint =>
      'It\'s already in your agenda as “maybe”. Your friend is only notified if you accept or decline.';

  @override
  String get signOut => 'Sign out';

  @override
  String get offlineTitle => 'You\'re offline';

  @override
  String get offlineMessage =>
      'SeeU needs an internet connection. Check your network and try again.';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get pageNotFoundMessage => 'This page doesn\'t exist (anymore).';

  @override
  String get backHome => 'Back to home';

  @override
  String get maybeDeleted => 'It may have been deleted.';

  @override
  String get photoAdd => 'Add a photo';

  @override
  String get photoTake => 'Take a photo';

  @override
  String get photoGallery => 'Choose from gallery';

  @override
  String get photoAccessDenied =>
      'Photo access denied. Allow it in your phone settings.';

  @override
  String get photoEmpty => 'Add photos of your shared moments.';

  @override
  String get photoDeleteTitle => 'Delete this photo?';

  @override
  String get irreversible => 'This can\'t be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get photoDeleted => 'Photo deleted';

  @override
  String get close => 'Close';

  @override
  String get pushEnabledToast => 'Notifications enabled 🎉';

  @override
  String get pushBlockedTitle => 'Notifications blocked';

  @override
  String get pushEnableTitle => 'Turn on reminders';

  @override
  String get pushBlockedMessage =>
      'Allow them in your phone settings (Notifications → SeeU), or turn on email reminders in the app Settings.';

  @override
  String get pushEnableMessage =>
      'Get notified when it\'s time to catch up with someone and before each event.';

  @override
  String get openPhoneSettings => 'Open settings';

  @override
  String get seeuSettings => 'SeeU settings';

  @override
  String get enable => 'Turn on';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'Phone language';

  @override
  String get tagline =>
      'Never lose touch with the people you want to see again.';

  @override
  String get configMissing =>
      'Missing configuration: run the app with --dart-define-from-file=config/env.json (SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY).';

  @override
  String get errAccountExists =>
      'An account already exists with this email. Sign in or use “Forgot password”.';

  @override
  String get checkMailboxTitle => 'Check your inbox';

  @override
  String checkMailboxText(String email) {
    return 'A confirmation link was sent to $email. Open it to activate your account (check your spam folder).';
  }

  @override
  String get magicSentTitle => 'Link sent';

  @override
  String magicSentText(String email) {
    return 'Open the link sent to $email to sign in (check your spam folder).';
  }

  @override
  String get resetSentTitle => 'Email sent';

  @override
  String resetSentText(String email) {
    return 'If an account exists for $email, you\'ll receive a link to choose a new password.';
  }

  @override
  String get loginTab => 'Sign in';

  @override
  String get signupTab => 'Sign up';

  @override
  String get magicLink => 'Magic link';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get magicLinkHelp =>
      'Get a sign-in link by email, no password needed.';

  @override
  String get forgotHelp =>
      'Enter your email: you\'ll receive a link to choose a new password.';

  @override
  String get firstNameLabel => 'First name (display name)';

  @override
  String get nameExample => 'E.g. Andrea';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordMin => 'At least 6 characters';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create my account';

  @override
  String get getLink => 'Get the link';

  @override
  String get sendLink => 'Send the link';

  @override
  String get forgotPasswordQ => 'Forgot password?';

  @override
  String get getMagicLink => 'Get a magic link by email';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileSub =>
      'Your friends will find you with your username.';

  @override
  String get displayName => 'Display name';

  @override
  String get displayNameHint => 'This is what your friends see.';

  @override
  String get birthDate => 'Date of birth';

  @override
  String get birthDateHint => 'Optional. Only visible to your friends.';

  @override
  String get continueLabel => 'Continue';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get passwordUpdated => 'Password updated';

  @override
  String get newPassword => 'New password';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get confirmPassword => 'Confirm the password';

  @override
  String get passwordsDiffer => 'The passwords don\'t match.';

  @override
  String get save => 'Save';

  @override
  String get usernameLabel => 'Username';

  @override
  String usernameAvailable(String username) {
    return '@$username is available';
  }

  @override
  String get usernameCheckFailed => 'Can\'t check right now.';

  @override
  String get usernamePlaceholder => 'user.name';

  @override
  String nowFriendsWith(String name) {
    return 'You\'re now friends with $name';
  }

  @override
  String get requestDeclined => 'Request declined';

  @override
  String get requestCancelled => 'Request cancelled';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get importContacts => 'Import contacts';

  @override
  String get friendsWithoutCard => 'SeeU friends without a contact card';

  @override
  String get tryAnotherSearch => 'Try another search.';

  @override
  String get groupOverdue => 'Overdue';

  @override
  String get groupThisWeek => 'This week';

  @override
  String get groupUpToDate => 'Up to date';

  @override
  String get addSeeuFriend => 'Add a SeeU friend';

  @override
  String get addContact => 'Add a contact';

  @override
  String get rdvInvitations => 'Event invitations';

  @override
  String get friendRequestsReceived => 'Friend requests received';

  @override
  String get sentYouARequest => 'Sent you a request';

  @override
  String get friendRequestsSent => 'Friend requests sent';

  @override
  String get waitingForAnswer => 'Waiting for their answer';

  @override
  String get noContactsTitle => 'No contacts yet';

  @override
  String get noContactsMessage =>
      'Add the people you want to see regularly. Those on SeeU can become your friends: shared events and photos.';

  @override
  String get importFromPhone => 'Import from phone';

  @override
  String get contactsSearchHint => 'Search (name, category, notes, @friend)';

  @override
  String nContacts(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts',
      one: '1 contact',
    );
    return '$_temp0';
  }

  @override
  String nFriends(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n friends',
      one: '1 friend',
    );
    return '$_temp0';
  }

  @override
  String nOverdue(int n) {
    return '$n overdue';
  }

  @override
  String get sortDue => 'Due date';

  @override
  String get sortName => 'Name';

  @override
  String get notInContactsYet => 'not in your contacts yet';

  @override
  String markSeenTitle(String name) {
    return 'Saw $name';
  }

  @override
  String snoozeTitle(String name) {
    return 'Snooze $name';
  }

  @override
  String get seeSoonTitle => 'See soon';

  @override
  String get seeSoonSub =>
      'Pick someone to see without waiting for the end of their period. They\'ll stay at the top of the list until you meet.';

  @override
  String meetingSaved(String name) {
    return 'Meetup with $name saved';
  }

  @override
  String get whenDidYouSee => 'When did you see them?';

  @override
  String get noteOptional => 'A note';

  @override
  String get noteHint => 'A memory, a detail to remember…';

  @override
  String get markSeenHelp =>
      'The last meetup date and the next due date will update automatically. The meetup will show up in the history.';

  @override
  String get saveMeeting => 'Save the meetup';

  @override
  String snoozedUntil(String date) {
    return 'Reminder snoozed until $date';
  }

  @override
  String get remindMeIn => 'Remind me later, in:';

  @override
  String get orOnDate => 'Or on a specific date';

  @override
  String get snooze => 'Snooze';

  @override
  String addedToSeeSoon(String name) {
    return '$name added to the “see soon” list';
  }

  @override
  String get searchContact => 'Search a contact…';

  @override
  String get allAlreadyInList => 'All your contacts are already in the list.';

  @override
  String get noMatchingContact => 'No matching contact.';

  @override
  String ageSuffix(int n) {
    return '($n years old)';
  }

  @override
  String get birthdayToday => 'It\'s their birthday today!';

  @override
  String get birthdayTomorrow => 'Birthday tomorrow';

  @override
  String birthdayInDays(int n) {
    return 'Birthday in $n days';
  }

  @override
  String get contactNotFound => 'Contact not found';

  @override
  String get seeMyContacts => 'See my contacts';

  @override
  String get edit => 'Edit';

  @override
  String get removedFromSeeSoon => 'Removed from the “see soon” list';

  @override
  String get addedToSeeSoonHome => 'Added to the “see soon” list on Home';

  @override
  String get deleteContactTitle => 'Delete this contact?';

  @override
  String get deleteContactMessage =>
      'Their events and photos will be deleted too. This can\'t be undone.';

  @override
  String get contactDeleted => 'Contact deleted';

  @override
  String get friendPill => 'SeeU friend · events and photos can be shared';

  @override
  String get lastMeeting => 'Last meetup';

  @override
  String get notRecordedYet => 'Not recorded yet';

  @override
  String get nextDue => 'Next due date';

  @override
  String get snoozedSuffix => '(snoozed)';

  @override
  String get frequency => 'Frequency';

  @override
  String get planRdv => 'Plan an event';

  @override
  String get seenToday => 'Seen today';

  @override
  String get inSeeSoonRemove => 'In “see soon” · remove';

  @override
  String get information => 'Details';

  @override
  String bornOn(String date) {
    return 'Born on $date';
  }

  @override
  String get rdvSection => 'Events';

  @override
  String get noRdvWithContact => 'No events with this contact yet.';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get gallery => 'Gallery';

  @override
  String get deleteContact => 'Delete contact';

  @override
  String get linkToFriend => 'Link to a SeeU friend';

  @override
  String get linkedToAccount => 'Linked to a SeeU account';

  @override
  String get friendCanShare =>
      'You can send them your events and share photos.';

  @override
  String get wantToMeet => 'Let\'s meet';

  @override
  String wantToMeetSent(String name) {
    return '$name knows you\'d like to meet 👋';
  }

  @override
  String get manage => 'Manage';

  @override
  String get editContact => 'Edit contact';

  @override
  String get nameRequired => 'The name is required.';

  @override
  String get frequencyMin => 'The frequency must be at least 1.';

  @override
  String get contactAdded => 'Contact added';

  @override
  String get contactUpdated => 'Contact updated';

  @override
  String get newContact => 'New contact';

  @override
  String get addTheContact => 'Add contact';

  @override
  String get change => 'Change';

  @override
  String get remove => 'Remove';

  @override
  String get name => 'Name';

  @override
  String get nameHintFull => 'E.g. Mary Smith';

  @override
  String get categories => 'Categories';

  @override
  String get categoriesHint => 'Optional · you can pick several';

  @override
  String get lastMeetingOptional =>
      'Optional. Without a date, the period starts today.';

  @override
  String get noMeetingRecorded => 'No meetup recorded yet';

  @override
  String nextDueInline(String date) {
    return 'Next due date: $date';
  }

  @override
  String get phone => 'Phone';

  @override
  String get phoneHint => 'E.g. +1 555 123 4567';

  @override
  String get emailExample => 'E.g. mary@example.com';

  @override
  String get birthday => 'Birthday';

  @override
  String get notes => 'Notes';

  @override
  String get notesHint => 'Interests, kids, last topic you talked about…';

  @override
  String get requiredFields => '* required fields';

  @override
  String get importReadFailed => 'Can\'t read your contacts on this device.';

  @override
  String get importAllThere => 'All these contacts are already in SeeU.';

  @override
  String importRestTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'The remaining $n at once',
      one: 'The last one at once',
    );
    return '$_temp0';
  }

  @override
  String importRestFreq(String freq) {
    return 'Frequency $freq';
  }

  @override
  String importRestCats(String cats) {
    return 'categories $cats';
  }

  @override
  String importRestLast(String date) {
    return 'last meetup on $date';
  }

  @override
  String get addAll => 'Add all';

  @override
  String get ignoreAllFinish => 'Skip all and finish';

  @override
  String nImported(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts imported',
      one: '1 contact imported',
    );
    return '$_temp0';
  }

  @override
  String stepOf(int n) {
    return 'Step $n of 3';
  }

  @override
  String get chooseContacts => 'Choose contacts';

  @override
  String continueN(int n) {
    return 'Continue ($n)';
  }

  @override
  String get ignore => 'Skip';

  @override
  String importN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Import $n contacts',
      one: 'Import 1 contact',
    );
    return '$_temp0';
  }

  @override
  String get reviewSelection => 'Review the selection';

  @override
  String get fromAddressBook => 'From your address book';

  @override
  String get fromAddressBookHelp =>
      'Choose the people to follow in SeeU. You\'ll then set how often for each. Nothing is saved before the final confirmation.';

  @override
  String get accessMyContacts => 'Access my contacts';

  @override
  String get contactsAccessDenied =>
      'SeeU can\'t access your contacts. Allow it in your phone settings, then try again.';

  @override
  String get searchEllipsis => 'Search…';

  @override
  String nChosen(int n) {
    return '$n selected';
  }

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get selectAll => 'Select all';

  @override
  String contactNofM(int n, int nTotal) {
    return 'Contact $n of $nTotal';
  }

  @override
  String duplicatesSkipped(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n already there, skipped',
      one: '1 already there, skipped',
    );
    return '$_temp0';
  }

  @override
  String get optional => 'Optional';

  @override
  String restAtOnce(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'The remaining $n at once…',
      one: 'The last one at once…',
    );
    return '$_temp0';
  }

  @override
  String get noneKept => 'No contact kept.';

  @override
  String nKept(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contacts kept',
      one: '1 contact kept',
    );
    return '$_temp0';
  }

  @override
  String nIgnored(int n) {
    return '$n skipped';
  }

  @override
  String removeName(String name) {
    return 'Remove $name';
  }

  @override
  String shareHandleText(String username, String link) {
    return 'Add me on SeeU: @$username\n$link';
  }

  @override
  String shareAppText(String url) {
    return 'Join me on SeeU, the app to never lose touch with the people you love: $url';
  }

  @override
  String linkFriendTitle(String name) {
    return 'Link $name';
  }

  @override
  String get linkFriendSub =>
      'Which contact is this friend? Their period resets when you confirm an event together.';

  @override
  String linkedFriendToContact(String friend, String contact) {
    return '$friend is linked to the contact $contact';
  }

  @override
  String get createNewContact => 'Create a new contact';

  @override
  String get searchMyContacts => 'Search my contacts…';

  @override
  String get alreadyLinked => 'Already linked';

  @override
  String get suggested => 'Suggested';

  @override
  String get contactUnlinked => 'Contact unlinked';

  @override
  String removeFriendTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeFriendMessage =>
      'Your existing contacts and events are kept, but you won\'t be able to invite each other anymore. Pending invitations are cancelled.';

  @override
  String get friendRemoved => 'Friend removed';

  @override
  String get proposeRdv => 'Suggest an event';

  @override
  String seeContactName(String name) {
    return 'See the contact $name';
  }

  @override
  String get linkToOtherContact => 'Link to another contact';

  @override
  String get unlinkContact => 'Unlink from contact';

  @override
  String get linkToContact => 'Link to a contact';

  @override
  String get removeFromFriends => 'Remove from friends';

  @override
  String linkContactToFriendTitle(String name) {
    return 'Link $name to a SeeU friend';
  }

  @override
  String get linkContactToFriendSub =>
      'You\'ll be able to send them your events and share photos. Each friend can only be linked to one contact.';

  @override
  String linkedContactToFriend(String contact, String friend) {
    return '$contact is linked to $friend';
  }

  @override
  String get noSeeuFriendsYet => 'You don\'t have any SeeU friends yet.';

  @override
  String get addSeeuFriendLong => 'Add a SeeU friend';

  @override
  String linkedTo(String name) {
    return 'Linked to $name';
  }

  @override
  String get addFriendSub =>
      'Search by username. SeeU friends share events and photos.';

  @override
  String get searchFailed => 'Search failed';

  @override
  String requestSentTo(String name) {
    return 'Request sent to $name';
  }

  @override
  String alreadyInvitedYou(String name) {
    return '$name had already invited you: you\'re now friends!';
  }

  @override
  String get requestAlreadySent =>
      'Request already sent, waiting for their answer.';

  @override
  String alreadyFriend(String name) {
    return '$name is already your friend.';
  }

  @override
  String get accountGone => 'This account no longer exists.';

  @override
  String get yourUsername => 'Your username:';

  @override
  String get share => 'Share';

  @override
  String noAccountStartsWith(String handle) {
    return 'No account starts with $handle. Check the spelling, or invite this person to create an account.';
  }

  @override
  String get sendAppLink => 'Send the app link';

  @override
  String get requestSent => 'Request sent';

  @override
  String get alreadyInFriends => 'Already your friend';

  @override
  String greetingName(String greeting, String name) {
    return '$greeting $name 👋';
  }

  @override
  String greetingAlone(String greeting) {
    return '$greeting 👋';
  }

  @override
  String get settings => 'Settings';

  @override
  String get newRdv => 'New event';

  @override
  String invitationsReceived(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Invitations',
      one: 'Invitation',
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
    );
    return '$_temp0';
  }

  @override
  String get statOverdue => 'overdue';

  @override
  String get statUpcoming => 'upcoming';

  @override
  String get didTheyHappen => 'Did they happen?';

  @override
  String get toReconnect => 'Time to catch up';

  @override
  String seeAllN(int n) {
    return 'See all ($n)';
  }

  @override
  String get addSeeSoon => 'Add someone to see soon';

  @override
  String get allUpToDate => 'All caught up 🎉';

  @override
  String get allUpToDateMessage =>
      'Nobody to catch up with right now. Want to see someone anyway? Add them with the + button.';

  @override
  String get birthdaysThisWeek => 'Birthdays this week';

  @override
  String inNDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'in $n days',
      one: 'tomorrow',
    );
    return '$_temp0';
  }

  @override
  String nYearsOld(int n) {
    return '$n years old';
  }

  @override
  String get nextRdvs => 'Upcoming events';

  @override
  String get noRdvPlanned => 'No events planned';

  @override
  String get noRdvPlannedMessage =>
      'Plan a moment with someone you want to see again.';

  @override
  String get plan => 'Plan';

  @override
  String moreRdvs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '+ $n more planned events',
      one: '+ 1 more planned event',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Welcome to SeeU';

  @override
  String get welcomeMessage =>
      'Add the people you want to see regularly, pick a frequency, and let the app remind you when it\'s time to catch up.';

  @override
  String get addFirstContact => 'Add my first contact';

  @override
  String birthdayOf(String name) {
    return '🎂 It\'s $name\'s birthday!';
  }

  @override
  String turnsToday(int n) {
    return 'Turns $n today ·';
  }

  @override
  String get wishThem => 'Remember to wish them.';

  @override
  String get sendMessage => 'Send a message';

  @override
  String get seen => 'Seen';

  @override
  String removedFromList(String name) {
    return '$name removed from the list';
  }

  @override
  String get backToHome => 'Back to home';

  @override
  String get rdvGeneric => 'Event';

  @override
  String get deleteRdvTitle => 'Delete this event?';

  @override
  String get deleteRdvShared =>
      'It will only be deleted for you (your friends keep theirs), and your photos will disappear from the shared gallery. This can\'t be undone.';

  @override
  String get deleteRdvPrivate =>
      'Its photos will be deleted. This can\'t be undone.';

  @override
  String get rdvDeleted => 'Event deleted';

  @override
  String get didItHappen => 'Did this event happen?';

  @override
  String get sharedRdvInfo =>
      'Shared event: date, place, title and status are the same for everyone. Your notes stay private.';

  @override
  String get participants => 'Participants';

  @override
  String get noParticipants => 'No participants.';

  @override
  String get addToCalendar => 'Add to calendar';

  @override
  String get sharedPhotos => 'Shared photos';

  @override
  String get photos => 'Photos';

  @override
  String get photosEmptyShared =>
      'Add photos of this moment: every participant will see them.';

  @override
  String get photosEmptyPrivate => 'Add photos of this moment.';

  @override
  String get deleteRdv => 'Delete event';

  @override
  String get invitedByFriend => 'Invitation from a SeeU friend';

  @override
  String proposedBy(String name) {
    return '$name invited you to this event';
  }

  @override
  String get rsvpPendingHelp =>
      'Maybe: it\'s in your agenda, but your friend doesn\'t know yet whether you\'re coming.';

  @override
  String get rsvpAcceptedHelp =>
      'You accepted. Once confirmed, your period with this contact starts over.';

  @override
  String get rsvpDeclinedHelp =>
      'You declined: it no longer shows in your lists.';

  @override
  String get sharing => 'Sharing';

  @override
  String get sharingHelp =>
      'If your friend accepts, you both have the event. Once confirmed, each of your periods starts over, and photos are shared.';

  @override
  String get proposedThisRdv => 'Invited you to this event';

  @override
  String get friendNotInvited => 'SeeU friend · not invited yet';

  @override
  String get send => 'Send';

  @override
  String invitationSentTo(String name) {
    return 'Invitation sent to $name';
  }

  @override
  String get invitationPending => 'Invitation sent · pending';

  @override
  String get invitationCancelled => 'Invitation cancelled';

  @override
  String get acceptedShared => 'Accepted · shared event';

  @override
  String get declinedInvitation => 'Declined the invitation';

  @override
  String get resend => 'Resend';

  @override
  String get editRdv => 'Edit event';

  @override
  String get chooseOneContact => 'Choose at least one contact.';

  @override
  String get rdvUpdated => 'Event updated';

  @override
  String get meetingRecorded => 'Meetup saved';

  @override
  String get rdvPlanned => 'Event planned';

  @override
  String get inviteSendFailed =>
      'An invitation couldn\'t be sent: try again from the event.';

  @override
  String invitationsSentN(int n) {
    return 'Invitations sent to $n friends';
  }

  @override
  String get titleExample => 'E.g. Lunch, coffee, video call…';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get planTheRdv => 'Plan the event';

  @override
  String get createContactFirst => 'Create a contact first to plan an event.';

  @override
  String get createAContact => 'Create a contact';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get titleOptional => 'Title';

  @override
  String get placeOptional => 'Place';

  @override
  String get placeHint => 'Café, address, video call…';

  @override
  String get notesOptional => 'Notes';

  @override
  String get notesPrivateHint => 'Always private, even if the event is shared.';

  @override
  String get notesRdvHint => 'Topics, things not to forget…';

  @override
  String get status => 'Status';

  @override
  String get statusHintDone =>
      'The participants\' last meetup date will be updated.';

  @override
  String get statusHintCancelled => 'It stays in the history as cancelled.';

  @override
  String get statusHintPlanned =>
      'You\'ll get a reminder before, then you can confirm it.';

  @override
  String get alreadyHappened => 'This event already happened';

  @override
  String get alreadyHappenedHelp =>
      'Check to record a past meetup: it goes straight to the history and resets the participants\' counter.';

  @override
  String sendTo(String names) {
    return 'Send to $names';
  }

  @override
  String get shareOffHelp =>
      'The event stays with you only. You can send it later from its page.';

  @override
  String get shareDoneHelp =>
      'Your friend will receive this meetup: if they accept, their period resets and you share photos.';

  @override
  String get sharePlannedHelp =>
      'Your friend gets an invitation: if they accept, you both have the event and a shared photo gallery. Your notes stay private.';

  @override
  String get photosAfterSave => 'You can add photos once the event is saved.';

  @override
  String get kindDueDigest => 'Contacts to catch up with';

  @override
  String get kindBirthday => 'Birthday';

  @override
  String get kindRdvReminder => 'Event reminder';

  @override
  String get kindRdvFollowup => 'Event follow-up';

  @override
  String get kindFriendRequest => 'Friend request';

  @override
  String get kindFriendAccept => 'Friend accepted';

  @override
  String get kindRdvInvite => 'Event invitation';

  @override
  String get kindRdvResponse => 'Invitation answer';

  @override
  String get kindRdvChange => 'Shared event changed';

  @override
  String get kindWave => 'Let\'s meet';

  @override
  String get kindTest => 'Test';

  @override
  String get privacyFooter =>
      'SeeU · Your data stays private: only the events you send to a friend are shared with them.';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profile => 'Profile';

  @override
  String get yourFirstName => 'Your first name';

  @override
  String get birthDateFriendsHint =>
      'Only visible to your SeeU friends: their contact card for you fills itself in.';

  @override
  String get shareMyHandle => 'Share my @';

  @override
  String get emailNeverShown =>
      'Never shown to other users before they\'re your friends';

  @override
  String get timezone => 'Time zone';

  @override
  String get timezoneHint => 'Detected automatically, used for reminder times';

  @override
  String get pushDisabledDevice => 'Notifications turned off on this device';

  @override
  String get pushEnabledDevice => 'Notifications turned on on this device';

  @override
  String get pushPermissionDenied =>
      'Permission denied: allow notifications in the device settings.';

  @override
  String get testSent => 'Test notification sent';

  @override
  String get pushUnsupported =>
      'Push notifications aren\'t available on this version; reminders will go by email.';

  @override
  String get pushBlockedSettings =>
      'Notifications blocked: allow them in your phone settings.';

  @override
  String get pushOnDevice => 'On for this device';

  @override
  String get disable => 'Turn off';

  @override
  String get pushOffDevice => 'Off on this device';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushReminders => 'Push reminders';

  @override
  String get pushRemindersSub => 'On every device where you turned them on';

  @override
  String get emailReminders => 'Email reminders';

  @override
  String get emailRemindersSub =>
      'Used when no device has push notifications on';

  @override
  String get dailyHour => 'Daily reminder time';

  @override
  String get dailyHourHint =>
      'A single daily summary of contacts to catch up with';

  @override
  String get notifyLead => 'Notify';

  @override
  String get leadSameDay => 'On the due date';

  @override
  String leadDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String leadWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks before',
      one: '1 week before',
    );
    return '$_temp0';
  }

  @override
  String get rdvReminderLead => 'Reminder before an event';

  @override
  String leadMinutes(int n) {
    return '$n minutes before';
  }

  @override
  String leadHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String get leadEve => 'The day before (24 h)';

  @override
  String get sendTestNotification => 'Send a test notification';

  @override
  String get lastNotifications => 'Latest notifications';

  @override
  String get noNotificationsYet => 'No notifications sent yet.';

  @override
  String get channelNone => 'none';

  @override
  String get application => 'App';

  @override
  String get version => 'Version';

  @override
  String get exportSubject => 'SeeU export';

  @override
  String get data => 'Data';

  @override
  String get importFromPhoneLong => 'Import contacts from the phone';

  @override
  String get importFromPhoneSub =>
      'From your address book, reviewing each contact.';

  @override
  String get exportData => 'Export my data';

  @override
  String get exportDataSub =>
      'Profile, contacts, events and the list of photos.';

  @override
  String get deleteAccountTitle => 'Permanently delete your account?';

  @override
  String get deleteAccountMessage =>
      'All your contacts, events and photos will be erased. This can\'t be undone.';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get account => 'Account';

  @override
  String get changePassword => 'Change password';

  @override
  String get passwordsNoMatch => 'The passwords don\'t match.';

  @override
  String get confirm => 'Confirm';

  @override
  String get visPrivate => 'Private';

  @override
  String get visContacts => 'Friends';

  @override
  String get visPublic => 'Public';

  @override
  String eventBy(String name) {
    return '$name\'s event';
  }

  @override
  String get sponsored => 'Sponsored';

  @override
  String get dateToChoose => 'Date to be chosen';

  @override
  String get byYou => 'By you';

  @override
  String nGoing(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n going',
      one: '1 going',
      zero: 'Nobody yet',
    );
    return '$_temp0';
  }

  @override
  String get youreGoing => 'You\'re going';

  @override
  String get homeAgenda => 'My agenda';

  @override
  String get homeFriends => 'Friends';

  @override
  String get homeExplore => 'Explore';

  @override
  String get exploreIntro =>
      'Upcoming public events: concerts, outings, meetups… Join the ones you like.';

  @override
  String get friendsFeedIntro =>
      'Events your friends open to all their friends. You can join them directly.';

  @override
  String get exploreEmptyTitle => 'No public events yet';

  @override
  String get exploreEmptyMessage =>
      'Come back soon: events open to everyone will show up here.';

  @override
  String get friendsFeedEmptyTitle => 'Nothing planned with friends';

  @override
  String get friendsFeedEmptyMessage =>
      'When a friend creates a “Friends” event, it shows up here. Start your own!';

  @override
  String get createFriendsEvent => 'Create a friends event';

  @override
  String get loadMore => 'Load more';

  @override
  String get exploreSearchHint => 'Search (title, place, @organizer)';

  @override
  String get slotsAtLeastTwo => 'Suggest at least two different timeslots.';

  @override
  String get proposeSlots => 'Suggest these timeslots';

  @override
  String get whoCanSee => 'Who can see it?';

  @override
  String get memberEditHint =>
      'You\'re taking part in this event: only the organizer can change the date or place, or cancel it. Your notes, contacts and status are yours.';

  @override
  String get withWhomOptional => 'With whom?';

  @override
  String get withWhomHint =>
      'Your contacts who are coming: their counter starts over once the event has happened.';

  @override
  String get oneDate => 'One date';

  @override
  String get severalSlots => 'Several timeslots';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionHint => 'Visible to everyone who can see the event.';

  @override
  String get descriptionPlaceholder => 'Plan, what to bring…';

  @override
  String get statusHintCancelledAll =>
      'The event is cancelled for every participant.';

  @override
  String get shareSlotsHelp =>
      'Your friends get the timeslots and share their availability. You then pick the date.';

  @override
  String get contactsBroadcastHint =>
      'All your SeeU friends will be notified and can join.';

  @override
  String get publicPhotosHint =>
      'Public event: only you can post announcements and photos.';

  @override
  String get publicReserved => 'Only for verified organizers for now.';

  @override
  String get visPrivateHelp => 'Only the friends you invite.';

  @override
  String get visContactsHelp => 'All your SeeU friends see it and can join.';

  @override
  String get visPublicHelp => 'Anyone can see and join it.';

  @override
  String get slotsLabel => 'Suggested timeslots';

  @override
  String get slotsHint =>
      'Each participant says if they\'re available; then you pick the best timeslot.';

  @override
  String get addSlot => 'Add a timeslot';

  @override
  String get slotsPollTitle => 'When are you available?';

  @override
  String get slotsPollHelp =>
      'For each timeslot: ✓ available, ? maybe, ✗ not available.';

  @override
  String get slotYes => 'Available';

  @override
  String get slotMaybe => 'Maybe';

  @override
  String get slotNo => 'Not available';

  @override
  String get slotMaybeShort => 'maybe';

  @override
  String slotCounts(int nYes, int nMaybe) {
    return '$nYes available · $nMaybe maybe';
  }

  @override
  String get choose => 'Choose';

  @override
  String chooseSlotTitle(String when) {
    return 'Set the date to $when?';
  }

  @override
  String get chooseSlotMessage =>
      'Voting ends and every participant is told the chosen date.';

  @override
  String get chooseThisSlot => 'Choose this timeslot';

  @override
  String get slotChosen => 'Date set, participants have been notified';

  @override
  String get slotsNoVotes => 'No answers yet';

  @override
  String get bestSlot => 'Best timeslot';

  @override
  String get bestSlotsTie => 'Best timeslots (tied)';

  @override
  String get slotsWaitOrganizer =>
      'Your guests will share their availability. Then you pick the date.';

  @override
  String get slotsWaitMember =>
      'Share your availability: the organizer will then pick the date.';

  @override
  String get slotsOrganizerDecides => 'The organizer will pick the final date.';

  @override
  String get eventMuted => 'Notifications for this event muted';

  @override
  String get eventUnmuted => 'Notifications for this event turned back on';

  @override
  String personMuted(String name) {
    return '$name\'s events and messages muted';
  }

  @override
  String personUnmuted(String name) {
    return '$name is no longer muted';
  }

  @override
  String blockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockMessage =>
      'You\'ll no longer be friends, you won\'t see each other\'s events or messages, and you won\'t be able to find or invite each other. You can unblock them in Settings.';

  @override
  String get block => 'Block';

  @override
  String blocked(String name) {
    return '$name is blocked';
  }

  @override
  String mutePerson(String name) {
    return 'Mute $name\'s events';
  }

  @override
  String unmutePerson(String name) {
    return 'Unmute $name';
  }

  @override
  String blockName(String name) {
    return 'Block $name';
  }

  @override
  String get announcements => 'Announcements';

  @override
  String get chat => 'Chat';

  @override
  String get announceEmptyOrganizer =>
      'Post announcements: every confirmed participant will be notified.';

  @override
  String get announceEmpty => 'No announcement from the organizer yet.';

  @override
  String get chatEmpty => 'No messages yet. Start the conversation!';

  @override
  String get openAnnouncements => 'See announcements';

  @override
  String get openChat => 'Open the chat';

  @override
  String nNew(int n) {
    return '$n new';
  }

  @override
  String get deleteMessage => 'Delete message';

  @override
  String get announceHint => 'An announcement for participants…';

  @override
  String get messageHint => 'Your message…';

  @override
  String get announceReadOnly =>
      'Only the organizer posts here. You\'re notified of each announcement if you\'re going.';

  @override
  String get chatJoinToPost => 'Join the event to write.';

  @override
  String get moreActions => 'More actions';

  @override
  String get muteEvent => 'Mute this event';

  @override
  String get unmuteEvent => 'Unmute this event';

  @override
  String get joinedToast => 'Great, you\'re going!';

  @override
  String get notGoingToast => 'Got it, you\'re not going';

  @override
  String organizedBy(String name) {
    return 'Organized by $name';
  }

  @override
  String get eventCancelledInfo => 'This event was cancelled by the organizer.';

  @override
  String get joinToVote => 'Join it to share your availability';

  @override
  String get areYouComing => 'Are you coming?';

  @override
  String get joinPublicHint =>
      '“Maybe” adds it to your agenda without commitment. You\'ll get the organizer\'s announcements if you\'re going.';

  @override
  String get joinFriendsHint =>
      'The organizer is notified when you\'re going. “Maybe” adds it to your agenda without commitment.';

  @override
  String get moderationTitle => 'Muted and blocked';

  @override
  String get moderationIntro =>
      'Muting turns off notifications and hides events from the feeds. Blocking cuts all contact with the person.';

  @override
  String get mutedPeopleAndEvents => 'Muted people and events';

  @override
  String get nothingMuted => 'Nothing muted.';

  @override
  String get eventsMuted => 'events and messages muted';

  @override
  String get unmute => 'Unmute';

  @override
  String get blockedPeople => 'Blocked people';

  @override
  String get nobodyBlocked => 'Nobody is blocked.';

  @override
  String get unblock => 'Unblock';

  @override
  String unblocked(String name) {
    return '$name is unblocked';
  }

  @override
  String get unblockHint =>
      'Unblocking doesn\'t restore the friendship: you\'ll need to send a new request.';

  @override
  String get mutedAndBlocked => 'Muted and blocked';

  @override
  String get mutedAndBlockedSub => 'People and events you muted or blocked.';

  @override
  String get leaveEventTitle => 'Remove this event from your agenda?';

  @override
  String get leaveEventMessage =>
      'You\'ll no longer take part and your photos will disappear from the shared gallery. You can join again if it\'s still visible.';

  @override
  String get removeFromAgenda => 'Remove from my agenda';

  @override
  String get myContactsInEvent => 'My contacts';

  @override
  String get photosEmptyPublicMember =>
      'The organizer will share the event\'s photos here.';

  @override
  String get you => 'You';

  @override
  String get organizer => 'Organizer';

  @override
  String andNMore(int n) {
    return 'and $n more';
  }

  @override
  String get kindEventNew => 'New friends event';

  @override
  String get kindEventJoin => 'Someone joined your event';

  @override
  String get kindEventMessage => 'Event message';

  @override
  String get kindEventAnnouncement => 'Event announcement';

  @override
  String get deleteRdvOrganizerPlanned =>
      'You\'re the organizer: the event will be cancelled for every participant (they\'ll be notified), then removed from your agenda.';

  @override
  String get availabilitySaved => 'Availability saved';

  @override
  String get availabilitySentGoing =>
      'Availability sent: you\'re marked as going';

  @override
  String get availabilitySentDeclined =>
      'You declined the event, the organizer has been notified';

  @override
  String get confirmAvailabilityTitle => 'Send your availability?';

  @override
  String unansweredAsMaybe(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n timeslots without an answer will count as “maybe”.',
      one: '1 timeslot without an answer will count as “maybe”.',
    );
    return '$_temp0';
  }

  @override
  String get confirmAndDecline => 'Decline the event';

  @override
  String get confirmAvailability => 'Confirm my availability';

  @override
  String get leaveWithoutSending => 'Leave without sending';

  @override
  String get outcomeGoing =>
      'You\'re available at least once: you\'ll be marked as going and the organizer will be notified.';

  @override
  String get outcomeDeclined =>
      'No timeslot works for you: the event will be declined and the organizer notified.';

  @override
  String get outcomeMaybe =>
      'Nothing certain yet: the event stays “maybe”, without notifying the organizer.';

  @override
  String get yourAnswer => 'Your answer:';

  @override
  String get availabilitySent => 'Availability sent';

  @override
  String get notSentYet => 'not sent';

  @override
  String get severalSlotsProposed => 'Several timeslots suggested';

  @override
  String get giveAvailability => 'Share my availability';

  @override
  String get slotsInviteHint => 'Open the event to answer slot by slot.';

  @override
  String get guestsCanInvite => 'Guests can invite their friends';

  @override
  String get guestsCanInviteHelp => 'Otherwise only you can add participants.';

  @override
  String blockContactDeleted(String name) {
    return 'Your contact “$name” will be deleted too: no more catch-up reminders.';
  }

  @override
  String blockedAndDeleted(String name) {
    return '$name is blocked and their contact deleted';
  }

  @override
  String get demoAds => 'Demo ads';

  @override
  String get demoAdsHelp =>
      'Shows fake ads to judge how they fit (development mode).';

  @override
  String get adCta => 'Learn more';

  @override
  String get earlierMessages => 'Earlier messages';

  @override
  String get tagPersonal => '(personal)';

  @override
  String get tagShared => '(shared)';

  @override
  String get titleRequired => 'Give the event a title';

  @override
  String get descriptionHintAll => 'Visible to every participant.';

  @override
  String get editFrequency => 'Change frequency';

  @override
  String frequencySheetSub(String name) {
    return 'How often do you want to see $name?';
  }

  @override
  String get frequencyUpdated => 'Frequency updated';

  @override
  String get organizedByYou => 'Organized by you';

  @override
  String get youAreGuest => 'Guest';

  @override
  String get filterMine => 'Organized by you';

  @override
  String get filterInvited => 'Invitations';

  @override
  String get noMineUpcoming => 'No events organized by you.';

  @override
  String get noInvitedUpcoming => 'No upcoming invitations.';

  @override
  String get notOnSeeu => 'Not on SeeU';

  @override
  String notOnSeeuAddedBy(String name) {
    return 'Not on SeeU · added by $name';
  }

  @override
  String get memberPending => 'To be confirmed';

  @override
  String get inviteFriend => 'Invite';

  @override
  String get peopleLegend =>
      'Grey icon: no SeeU account. Only SeeU friends get the invitation and see the chat and photos.';
}
