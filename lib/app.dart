import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import 'core/push.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'features/misc/fallback_screens.dart';
import 'ui/feedback.dart';

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});

class SeeUApp extends ConsumerStatefulWidget {
  const SeeUApp({super.key});
  @override
  ConsumerState<SeeUApp> createState() => _SeeUAppState();
}

class _SeeUAppState extends ConsumerState<SeeUApp> {
  final _subs = <StreamSubscription<dynamic>>[];
  late final AppLifecycleListener _lifecycle;
  String? _registeredFor;

  @override
  void initState() {
    super.initState();
    final push = PushService.instance;
    _subs.add(push.onOpen.listen(_open));
    _subs.add(push.onReceived.listen((_) => _refresh()));
    _lifecycle = AppLifecycleListener(onResume: _refresh);

    const QuickActions()
      ..initialize((type) => _open(type == 'new_contact' ? '/contacts/new' : '/rdv/new'))
      ..setShortcutItems(const [
        ShortcutItem(type: 'new_rdv', localizedTitle: 'Nouveau rendez-vous'),
        ShortcutItem(type: 'new_contact', localizedTitle: 'Nouveau contact'),
      ]).catchError((_) {});

    final session = ref.read(sessionProvider);
    session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onSession();
      final initial = push.takeInitialPath();
      if (initial != null) _open(initial);
    });
  }

  /// Registers this device for push once signed in (if the user already allowed it).
  void _onSession() {
    final session = ref.read(sessionProvider);
    final uid = session.profile != null ? session.userId : null;
    if (uid != null && uid != _registeredFor) {
      _registeredFor = uid;
      PushService.instance.register(ref.read(apiProvider));
    } else if (uid == null) {
      _registeredFor = null;
    }
  }

  void _refresh() {
    if (ref.read(sessionProvider).signedIn) refreshDataFromContainer(ProviderScope.containerOf(context, listen: false));
  }

  void _open(String path) {
    if (!ref.read(sessionProvider).signedIn) return;
    _refresh();
    openAppPath(ref.read(routerProvider), path);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    ref.read(sessionProvider).removeListener(_onSession);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final online = ref.watch(connectivityProvider).value ?? true;
    return MaterialApp.router(
      title: 'SeeU',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      theme: buildTheme(AppColors.light),
      darkTheme: buildTheme(AppColors.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => online
          ? child!
          : OfflineScreen(onRetry: () => ref.invalidate(connectivityProvider)),
    );
  }
}
