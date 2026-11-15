// Renders every screen with fake data, in light and dark mode, at phone size.
// Fails on any exception (including layout overflows).
//
// To also write screenshots into test/goldens/ (git-ignored):
//   flutter test test/screens_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seeu/core/theme.dart';
import 'package:seeu/data/providers.dart';
import 'package:seeu/domain/dates.dart';
import 'package:seeu/domain/models.dart';
import 'package:seeu/features/auth/login_screen.dart';
import 'package:seeu/features/contacts/contact_detail_screen.dart';
import 'package:seeu/features/contacts/contact_form_screen.dart';
import 'package:seeu/features/contacts/contacts_screen.dart';
import 'package:seeu/features/friends/friends_screen.dart';
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
        {String? category, int last = -10, int value = 1, FrequencyUnit unit = FrequencyUnit.months, bool seeSoon = false, String? linked, DateTime? birthday, String? phone}) =>
    Contact(
      id: id,
      userId: 'me',
      name: name,
      category: category,
      lastMeetingDate: d(last),
      frequencyValue: value,
      frequencyUnit: unit,
      nextDueDate: addFrequency(dayOf(d(last)), value, unit),
      seeSoon: seeSoon,
      linkedUserId: linked,
      birthday: birthday,
      phone: phone,
      email: phone == null ? null : '$id@example.com',
      notes: phone == null ? null : 'Adore le matcha. Parler de son voyage au Japon.',
    );

final contacts = [
  contact('andrea', 'Andrea', category: 'Amis', last: -1, value: 2, unit: FrequencyUnit.weeks, linked: 'u-andrea', birthday: DateTime(2003, 11, 29), phone: '06 12 34 56 78'),
  contact('marie', 'Marie Dupont', category: 'Famille', last: -40),
  contact('paul', 'Paul Martin', category: 'Pro', last: -25, value: 1, unit: FrequencyUnit.months),
  contact('helene', 'Hélène', category: 'Amis', last: -5, seeSoon: true),
  contact('leo', 'Léo Bernard', last: -3, birthday: DateTime(1996, 11, 14), phone: '0470 12 34 56'),
  contact('zoe', 'Zoé', category: 'Voisins', last: -200, value: 6),
];

ContactLite lite(String id) => contacts.firstWhere((c) => c.id == id).lite;

final planned = [
  Rendezvous(id: 'r1', userId: 'me', title: 'Petit matcha bebew', location: 'LLN', appointmentAt: d(0, 19, 30), status: RdvStatus.planifie, contacts: [lite('andrea')]),
  Rendezvous(id: 'r2', userId: 'me', appointmentAt: d(1, 18), status: RdvStatus.planifie, contacts: [lite('marie'), lite('paul')]),
  Rendezvous(id: 'r3', userId: 'me', title: 'Soirée poker', location: 'Bruxelles', appointmentAt: d(4, 21), status: RdvStatus.planifie, shareId: 's', contacts: [lite('andrea'), lite('leo'), lite('zoe'), lite('paul')]),
];

final history = [
  Rendezvous(id: 'h1', userId: 'me', title: 'Petit date', appointmentAt: d(-1, 13, 15), status: RdvStatus.valide, contacts: [lite('andrea')]),
  Rendezvous(id: 'h2', userId: 'me', title: 'Poulet frit', location: 'Chez toi', appointmentAt: d(-3, 18), status: RdvStatus.annule, contacts: [lite('andrea')]),
  Rendezvous(id: 'h3', userId: 'me', appointmentAt: d(-35, 12), status: RdvStatus.valide, contacts: [lite('marie'), lite('helene')]),
];

final friends = [
  Friend(friendshipId: 'f1', userId: 'u-andrea', username: 'cocsi_bucci', displayName: 'Cocsi_bucci', accepted: true, incoming: false),
  Friend(friendshipId: 'f2', userId: 'u-bob', username: 'bob', displayName: 'Bob', accepted: false, incoming: true),
  Friend(friendshipId: 'f3', userId: 'u-lea', username: 'lea.m', displayName: 'Léa', accepted: false, incoming: false),
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

Widget app(String location, Brightness brightness, List<RouteBase> extra) {
  Widget tab(Widget w) => w;
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/', builder: (_, _) => tab(const HomeScreen())),
    GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen()),
    GoRoute(path: '/friends', builder: (_, _) => const FriendsScreen()),
    GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/contacts/new', builder: (_, _) => const ContactFormScreen()),
    GoRoute(path: '/contacts/:id', builder: (_, s) => ContactDetailScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/contacts/:id/edit', builder: (_, s) => ContactFormScreen(editId: s.pathParameters['id'])),
    GoRoute(path: '/rdv/new', builder: (_, s) => RdvFormScreen(preselectContactId: s.uri.queryParameters['contact'])),
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
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(colors),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'fr_FR';
    await initializeDateFormatting('fr_FR');
    PackageInfo.setMockInitialValues(
        appName: 'SeeU', packageName: 'com.seeuapp.seeu', version: '1.0.0', buildNumber: '1', buildSignature: '', installerStore: null);
    await loadFonts();
  });
  setUp(() => clock = () => now);
  tearDown(() => clock = DateTime.now);

  const screens = {
    'home': '/',
    'contacts': '/contacts',
    'contact_detail': '/contacts/andrea',
    'contact_form': '/contacts/new',
    'rdv_form': '/rdv/new?contact=andrea',
    'rdv_detail': '/rdv/r3',
    'friends': '/friends',
    'history': '/history',
    'settings': '/settings',
    'login': '/login',
  };

  for (final brightness in Brightness.values) {
    for (final MapEntry(key: name, value: location) in screens.entries) {
      testWidgets('$name ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(location, brightness, const []));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        if (autoUpdateGoldenFiles) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${brightness.name}.png'));
        }
      });
    }
  }
}
