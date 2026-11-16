// Renders every screen with fake data, in light and dark mode, at phone size.
// Fails on any exception (including layout overflows).
//
// To also write screenshots into test/goldens/ (git-ignored):
//   flutter test test/screens_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seeu/ads/ads.dart';
import 'package:seeu/core/i18n.dart';
import 'package:seeu/data/api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seeu/core/theme.dart';
import 'package:seeu/data/providers.dart';
import 'package:seeu/maps/maps.dart';
import 'package:seeu/domain/dates.dart';
import 'package:seeu/domain/models.dart';
import 'package:seeu/features/auth/login_screen.dart';
import 'package:seeu/features/contacts/contact_detail_screen.dart';
import 'package:seeu/features/contacts/contact_form_screen.dart';
import 'package:seeu/features/contacts/contacts_screen.dart';
import 'package:seeu/features/events/event_preview_screen.dart';
import 'package:seeu/features/history/calendar.dart';
import 'package:seeu/features/settings/moderation_screen.dart';
import 'package:seeu/ui/scaffold.dart';
import 'package:seeu/features/history/history_screen.dart';
import 'package:seeu/features/home/home_screen.dart';
import 'package:seeu/features/home/push_banner.dart';
import 'package:seeu/core/push.dart';
import 'package:seeu/features/rdv/rdv_detail_screen.dart';
import 'package:seeu/features/rdv/rdv_form_screen.dart';
import 'package:seeu/features/settings/settings_screen.dart';

final now = DateTime(2026, 11, 14, 20, 15);
DateTime d(int daysFromNow, [int h = 12, int m = 0]) => DateTime(now.year, now.month, now.day + daysFromNow, h, m);

final me = Profile(id: 'me', email: 'arthur@example.com', displayName: 'Arthur', username: 'arthur', timezone: 'Europe/Brussels');

Contact contact(String id, String name,
        {List<String> categories = const [], int? last = -10, int value = 1, FrequencyUnit unit = FrequencyUnit.months, bool seeSoon = false, String? linked, DateTime? birthday, String? phone}) =>
    Contact(
      id: id,
      userId: 'me',
      name: name,
      categories: categories,
      lastMeetingDate: last == null ? null : d(last),
      frequencyValue: value,
      frequencyUnit: unit,
      nextDueDate: addFrequency(dayOf(d(last ?? -3)), value, unit),
      seeSoon: seeSoon,
      linkedUserId: linked,
      birthday: birthday,
      phone: phone,
      email: phone == null ? null : '$id@example.com',
      notes: phone == null ? null : 'Adore le matcha. Parler de son voyage au Japon.',
    );

final contacts = [
  contact('andrea', 'Andrea', categories: ['Amis', 'Pro'], last: -1, value: 2, unit: FrequencyUnit.weeks, linked: 'u-andrea', birthday: DateTime(2003, 11, 29), phone: '06 12 34 56 78'),
  contact('marie', 'Marie Dupont', categories: ['Famille'], last: -40),
  contact('paul', 'Paul Martin', categories: ['Pro'], last: -25, value: 1, unit: FrequencyUnit.months),
  contact('helene', 'Hélène', categories: ['Amis'], last: -5, seeSoon: true),
  contact('leo', 'Léo Bernard', last: -3, birthday: DateTime(1996, 11, 14), phone: '0470 12 34 56'),
  contact('zoe', 'Zoé', categories: ['Voisins'], last: null, value: 6),
];

ContactLite lite(String id) => contacts.firstWhere((c) => c.id == id).lite;

final planned = [
  Rendezvous(id: 'r1', userId: 'me', title: 'Petit matcha bebew', location: 'LLN', appointmentAt: d(0, 19, 30), status: RdvStatus.planifie, contacts: [lite('andrea')]),
  Rendezvous(id: 'r2', userId: 'me', appointmentAt: d(1, 18), status: RdvStatus.planifie, contacts: [lite('marie'), lite('paul')]),
  Rendezvous(id: 'r3', userId: 'me', title: 'Soirée poker', location: 'Bruxelles', appointmentAt: d(4, 21), status: RdvStatus.planifie, eventId: 's',
      event: EventInfo(id: 's', organizerId: 'me', memberCount: 3, goingCount: 2, lat: 50.8467, lng: 4.3525, link: 'https://www.poker-bruxelles.be/soiree'), contacts: [lite('andrea'), lite('leo'), lite('zoe'), lite('paul')]),
  Rendezvous(id: 'r4', userId: 'me', title: 'Brunch', appointmentAt: d(6, 11), status: RdvStatus.planifie, eventId: 't', rsvp: Rsvp.pending,
      event: EventInfo(id: 't', organizerId: 'u-andrea', visibility: EventVisibility.contacts, memberCount: 4, goingCount: 3), contacts: [lite('andrea')]),
  Rendezvous(id: 'r5', userId: 'me', title: 'Week-end au ski', location: 'Chamonix', appointmentAt: d(10, 9), status: RdvStatus.planifie, eventId: 'v',
      event: EventInfo(id: 'v', organizerId: 'me', visibility: EventVisibility.contacts, slotsOpen: true, memberCount: 5, goingCount: 3,
          description: 'On loue un chalet, partage des frais. Dites-moi vos dispos !')),
  Rendezvous(id: 'r6', userId: 'me', title: 'Concert jazz au parc', location: 'Parc de Bruxelles', appointmentAt: d(12, 20), status: RdvStatus.planifie,
      eventId: 'w', rsvp: Rsvp.accepted,
      event: EventInfo(id: 'w', organizerId: 'u-org', visibility: EventVisibility.public, memberCount: 128, goingCount: 120, description: 'Concert gratuit en plein air.')),
];

FeedEvent feedEvent(String id, String title, {String org = 'u-andrea', String orgName = 'Cocsi_bucci', EventVisibility vis = EventVisibility.contacts,
        int days = 3, int going = 4, String? myRdv, Rsvp? myRsvp, bool slots = false, String? location, bool mine = false}) =>
    FeedEvent(
      id: id,
      organizerId: org,
      organizerName: orgName,
      organizerUsername: 'cocsi_bucci',
      visibility: vis,
      title: title,
      location: location,
      description: 'Venez nombreux ! On commence à 19h, apportez de quoi grignoter.',
      appointmentAt: d(days, 19),
      slotsOpen: slots,
      going: going,
      myRdvId: myRdv,
      myRsvp: myRsvp,
      isMine: mine,
      canPost: vis != EventVisibility.public || mine,
    );

final friendsFeed = [
  feedEvent('t', 'Brunch', days: 6, myRdv: 'r4', myRsvp: Rsvp.pending),
  feedEvent('e2', 'Soirée jeux de société', location: 'Chez Tom', orgName: 'Tom', going: 6),
  feedEvent('e3', 'Rando en forêt de Soignes', days: 9, going: 1, slots: true),
  feedEvent('e4', 'Apéro chez moi', org: 'me', orgName: 'Arthur', days: 11, going: 3, myRdv: 'r3', mine: true),
];

final publicFeed = [
  feedEvent('w', 'Concert jazz au parc', vis: EventVisibility.public, orgName: 'Brussels Jazz', days: 12, going: 120, myRdv: 'r6', myRsvp: Rsvp.accepted, location: 'Parc de Bruxelles'),
  feedEvent('p2', 'Marché de Noël solidaire', vis: EventVisibility.public, orgName: 'Asbl Entraide', days: 20, going: 48, location: 'Place Flagey'),
  feedEvent('p3', 'Atelier poterie débutants', vis: EventVisibility.public, orgName: 'Terre & Feu', days: 25, going: 9),
];

final events = {
  for (final e in [...friendsFeed, ...publicFeed]) e.id: e,
  's': feedEvent('s', 'Soirée poker', org: 'me', orgName: 'Arthur', vis: EventVisibility.private, myRdv: 'r3', mine: true),
  'v': feedEvent('v', 'Week-end au ski', org: 'me', orgName: 'Arthur', slots: true, myRdv: 'r5', mine: true),
};

final participants = [
  Participant(userId: 'me', name: 'Arthur', username: 'arthur', role: 'organizer'),
  Participant(userId: 'u-andrea', name: 'Cocsi_bucci', username: 'cocsi_bucci', role: 'accepted', isFriend: true),
  Participant(userId: 'u-tom', name: 'Tom', username: 'tom', role: 'accepted', isFriend: true),
  Participant(userId: 'u-lea', name: 'Léa', username: 'lea.m', role: 'pending'),
];

final slots = [
  EventSlot(id: 'sl1', startsAt: d(10, 9), yes: 2, maybe: 1, no: 1, myAnswer: SlotAnswer.yes, yesNames: ['Arthur', 'Tom'], maybeNames: ['Léa']),
  EventSlot(id: 'sl2', startsAt: d(17, 9), yes: 4, maybe: 0, no: 0, myAnswer: SlotAnswer.yes, yesNames: ['Arthur', 'Cocsi_bucci', 'Tom', 'Léa']),
  EventSlot(id: 'sl3', startsAt: d(24, 9), yes: 1, maybe: 2, no: 1, myAnswer: SlotAnswer.maybe, yesNames: ['Tom'], maybeNames: ['Arthur', 'Léa']),
];

final messages = [
  ChatMessage(id: 'm3', userId: 'u-tom', authorName: 'Tom', body: 'Je peux prendre 3 personnes en voiture 🚗', createdAt: d(0, 18, 2)),
  ChatMessage(id: 'm2', userId: 'me', authorName: 'Arthur', body: 'Top, je réserve le chalet ce soir', createdAt: d(0, 17, 40)),
  ChatMessage(id: 'm1', userId: 'u-andrea', authorName: 'Cocsi_bucci', body: 'Le 2e week-end me va parfaitement !', createdAt: d(0, 17, 31)),
];

/// Server calls made by widgets themselves (the event chat), answered locally.
class _FakeApi extends Api {
  _FakeApi() : super(SupabaseClient('http://localhost', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)));
  @override
  Future<List<ChatMessage>> listMessages(String eventId, {DateTime? before, int limit = 50}) async => before == null ? messages : const [];
  @override
  void Function() watchMessages(String eventId, void Function(Map<String, dynamic> row) onInsert, void Function(String id) onDelete) => () {};
  @override
  Future<void> markChatRead(String rdvId) async {}
  @override
  Future<Map<String, String>> profileAvatars(List<String> ids) async => const {};
}

/// Created once outside the tests (the client starts timers).
late final Api fakeApi;

class _Ads extends AdsDemo {
  @override
  bool build() => true;
}

class _Section extends HomeSectionNotifier {
  _Section(this.initial);
  final HomeSection initial;
  @override
  HomeSection build() => initial;
}

final history = [
  Rendezvous(id: 'h1', userId: 'me', title: 'Petit date', appointmentAt: d(-1, 13, 15), status: RdvStatus.valide, contacts: [lite('andrea')]),
  Rendezvous(id: 'h2', userId: 'me', title: 'Poulet frit', location: 'Chez toi', appointmentAt: d(-3, 18), status: RdvStatus.annule, contacts: [lite('andrea')]),
  Rendezvous(id: 'h3', userId: 'me', appointmentAt: d(-35, 12), status: RdvStatus.valide, contacts: [lite('marie'), lite('helene')]),
];

final friends = [
  Friend(friendshipId: 'f1', userId: 'u-andrea', username: 'cocsi_bucci', displayName: 'Cocsi_bucci', accepted: true, incoming: false),
  Friend(friendshipId: 'f2', userId: 'u-bob', username: 'bob', displayName: 'Bob', accepted: false, incoming: true),
  Friend(friendshipId: 'f3', userId: 'u-lea', username: 'lea.m', displayName: 'Léa', accepted: false, incoming: false),
  Friend(friendshipId: 'f4', userId: 'u-tom', username: 'tom', displayName: 'Tom', accepted: true, incoming: false),
];

final invites = [
  IncomingInvite(id: 'i1', rdvId: 'x', fromUser: 'u-andrea', fromName: 'Cocsi_bucci', title: 'Soirée poker', location: 'Bruxelles', appointmentAt: d(20, 1, 15), rdvStatus: RdvStatus.planifie),
];

class _Profile extends ProfileNotifier {
  @override
  Profile? build() => me;
}

class _UserId extends UserIdNotifier {
  @override
  String? build() => 'me';
}

Future<void> loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/flutter/flutter';
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    final file = File('$dir/$f');
    if (file.existsSync()) roboto.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await roboto.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  await lucide.load();
}

Widget app(String location, Brightness brightness, List<RouteBase> extra, {List overrides = const []}) {
  Widget tab(Widget w) => w;
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/', builder: (_, _) => tab(const HomeScreen())),
    GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen()),
    GoRoute(
      path: '/history-calendar',
      builder: (_, _) => const AppScaffold(title: 'Historique', body: SingleChildScrollView(padding: EdgeInsets.all(16), child: HistoryCalendar())),
    ),
    GoRoute(path: '/history/day/:date', builder: (_, s) => DayReviewScreen(day: parseDay(s.pathParameters['date']!))),
    GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/contacts/new', builder: (_, _) => const ContactFormScreen()),
    GoRoute(path: '/contacts/:id', builder: (_, s) => ContactDetailScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/contacts/:id/edit', builder: (_, s) => ContactFormScreen(editId: s.pathParameters['id'])),
    GoRoute(
        path: '/rdv/new',
        builder: (_, s) => RdvFormScreen(
            preselectContactId: s.uri.queryParameters['contact'],
            initialVisibility: s.uri.queryParameters['vis'] == null ? null : EventVisibility.parse(s.uri.queryParameters['vis']))),
    GoRoute(path: '/rdv/:id/edit', builder: (_, s) => RdvFormScreen(editId: s.pathParameters['id'])),
    GoRoute(path: '/event/:id', builder: (_, s) => EventPreviewScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/settings/moderation', builder: (_, _) => const ModerationScreen()),
    GoRoute(path: '/rdv/:id', builder: (_, s) => RdvDetailScreen(id: s.pathParameters['id']!)),
    ...extra,
  ]);
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(_Profile.new),
      userIdProvider.overrideWith(_UserId.new),
      contactsProvider.overrideWith((ref) async => contacts),
      plannedRdvProvider.overrideWith((ref) async => planned),
      historyProvider.overrideWith((ref) async => history),
      historyMonthProvider.overrideWith((ref, month) async => history.where((r) => r.appointmentAt.month == month.month).toList()),
      historyDayProvider.overrideWith((ref, day) async => history.where((r) => dayOf(r.appointmentAt) == day).toList()),
      friendsProvider.overrideWith((ref) async => friends),
      incomingInvitesProvider.overrideWith((ref) async => invites),
      notificationLogProvider.overrideWith((ref) async => [
            NotificationEntry(id: 'n', kind: 'due_digest', title: 'Marie est à recontacter', body: 'Marie (en retard de 9 j)', channel: 'push', createdAt: d(0, 8)),
          ]),
      pushPermissionProvider.overrideWith((ref) async => PushPermission.notDetermined),
      rdvProvider.overrideWith((ref, id) async => [...planned, ...history].where((r) => r.id == id).firstOrNull),
      contactRdvsProvider.overrideWith((ref, id) async => [...planned, ...history].where((r) => r.contacts.any((c) => c.id == id)).toList()),
      contactPhotosProvider.overrideWith((ref, id) async => const <Photo>[]),
      sharedRdvPhotosProvider.overrideWith((ref, id) async => const <Photo>[]),
      rdvInvitesProvider.overrideWith((ref, id) async => const <RdvInvitation>[]),
      feedProvider.overrideWith((ref, k) async => k.scope == 'public' ? publicFeed : friendsFeed),
      eventProvider.overrideWith((ref, id) async => events[id]),
      participantsProvider.overrideWith((ref, id) async => participants),
      eventGuestsProvider.overrideWith((ref, id) async => [EventGuest(name: 'Mamie Jo', addedBy: 'u-andrea', addedByName: 'Cocsi_bucci')]),
      slotsProvider.overrideWith((ref, id) async => slots),
      chatPreviewProvider.overrideWith((ref, id) async => messages),
      canCreatePublicProvider.overrideWith((ref) async => false),
      mutesProvider.overrideWith((ref) async => [
            MuteEntry(id: 'mu1', targetUser: 'u-x', userName: 'Max', username: 'max'),
            MuteEntry(id: 'mu2', eventId: 'p2', eventTitle: 'Marché de Noël solidaire', eventAt: d(20, 19)),
          ]),
      blockedProvider.overrideWith((ref) async => [BlockedUser(userId: 'u-y', name: 'Spammeur', username: 'spam42')]),
      avatarUrlProvider.overrideWith((ref, id) async => null),
      mapsEnabledProvider.overrideWithValue(false),
      apiProvider.overrideWithValue(fakeApi),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(colors),
      locale: Locale(currentLanguage),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    fakeApi = _FakeApi();
    PackageInfo.setMockInitialValues(
        appName: 'SeeU', packageName: 'com.seeuapp.mobile', version: '1.0.0', buildNumber: '1', buildSignature: '', installerStore: null);
    await loadFonts();
  });
  setUp(() => clock = () => now);
  tearDown(() => clock = DateTime.now);

  List section(HomeSection v) => [homeSectionProvider.overrideWith(() => _Section(v))];
  final screens = <String, (String, List)>{
    'home': ('/', const []),
    'home_friends': ('/', section(HomeSection.friends)),
    'home_explore': ('/', section(HomeSection.explore)),
    'home_explore_ads_tall': ('/', [...section(HomeSection.explore), adsDemoProvider.overrideWith(() => _Ads())]),
    'home_ads': ('/', [adsDemoProvider.overrideWith(() => _Ads())]),
    'event_preview_ads': ('/event/p2', [adsDemoProvider.overrideWith(() => _Ads())]),
    'contacts': ('/contacts', const []),
    'contacts_tall': ('/contacts', const []),
    'contact_detail': ('/contacts/andrea', const []),
    'contact_form': ('/contacts/new', const []),
    'rdv_form': ('/rdv/new?contact=andrea', const []),
    'rdv_form_slots': ('/rdv/r5/edit', const []),
    'rdv_form_tall': ('/rdv/new?contact=andrea', const []),
    'rdv_form_public': ('/rdv/new?vis=public', const []),
    'rdv_detail': ('/rdv/r3', const []),
    'rdv_slots': ('/rdv/r5', const []),
    'rdv_slots_tall': ('/rdv/r5', const []),
    'rdv_detail_tall': ('/rdv/r3', const []),
    'home_ads_tall': ('/', [adsDemoProvider.overrideWith(() => _Ads())]),
    'rdv_public': ('/rdv/r6', const []),
    'event_preview': ('/event/e2', const []),
    'event_preview_public': ('/event/p2', const []),
    'contacts_friend_link': ('/contacts?ami=tom', const []),
    'calendar': ('/history-calendar', const []),
    'day_review': ('/history/day/2026-11-13', const []),
    'rdv_tentative': ('/rdv/r4', const []),
    'history': ('/history', const []),
    'settings': ('/settings', const []),
    'moderation': ('/settings/moderation', const []),
    'login': ('/login', const []),
  };

  // French in light + dark, English in light (catches longer strings overflowing).
  for (final (lang, brightness) in [('fr', Brightness.light), ('fr', Brightness.dark), ('en', Brightness.light)]) {
    for (final MapEntry(key: name, value: (location, overrides)) in screens.entries) {
      testWidgets('$name ${brightness.name} $lang', (tester) async {
        applyLanguage(lang);
        tester.view.physicalSize = Size(1170, name.endsWith('_tall') ? 7200 : 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(location, brightness, const [], overrides: overrides));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        if (autoUpdateGoldenFiles) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${brightness.name}${lang == 'fr' ? '' : '_$lang'}.png'));
        }
      });
    }
  }
}
