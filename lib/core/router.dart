// Navigation: 5 tabs in a stateful shell, detail screens pushed on top.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/contacts/contact_detail_screen.dart';
import '../features/contacts/contact_form_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/contacts/import_screen.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../features/events/chat.dart';
import '../features/events/event_preview_screen.dart';
import '../features/history/calendar.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/misc/fallback_screens.dart';
import '../features/rdv/rdv_detail_screen.dart';
import '../features/rdv/rdv_form_screen.dart';
import '../features/settings/moderation_screen.dart';
import '../features/settings/settings_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

const _publicPaths = {'/login', '/reset-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    // Auth email links (seeu://auth-callback?code=…) are handled by Supabase itself.
    if (path.isEmpty || path == '/auth-callback') return '/';
    // Friends now live in the Contacts tab ("/friends?q=andrea" comes from shared links and notifications).
    if (path == '/friends') {
      final q = state.uri.queryParameters['q'];
      return q == null || q.isEmpty ? '/contacts' : '/contacts?ami=${Uri.encodeQueryComponent(q)}';
    }
    if (session.passwordRecovery) return path == '/reset-password' ? null : '/reset-password';
    if (!session.signedIn) return _publicPaths.contains(path) ? null : '/login';
    if (session.profile == null) return path == '/splash' ? null : '/splash';
    if (session.needsUsername) return path == '/complete-profile' ? null : '/complete-profile';
    if (_publicPaths.contains(path) || path == '/splash' || path == '/complete-profile') return '/';
    return null;
  }

  Page<void> page(GoRouterState state, Widget child) => MaterialPage(key: state.pageKey, child: child);

  GoRoute tab(String path, Widget child) => GoRoute(path: path, pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: child));

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: session,
    redirect: redirect,
    errorBuilder: (_, _) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/reset-password', builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(path: '/complete-profile', builder: (_, _) => const CompleteProfileScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [tab('/', const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/contacts',
              pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: ContactsScreen(friendQuery: s.uri.queryParameters['ami'])),
            ),
          ]),
          StatefulShellBranch(routes: [tab('/history', const HistoryScreen())]),
          StatefulShellBranch(routes: [tab('/settings', const SettingsScreen())]),
        ],
      ),
      GoRoute(path: '/contacts/new', pageBuilder: (_, s) => page(s, ContactFormScreen(prefill: s.extra as ContactPrefill?))),
      GoRoute(path: '/contacts/import', pageBuilder: (_, s) => page(s, const ImportScreen())),
      GoRoute(path: '/contacts/:id', pageBuilder: (_, s) => page(s, ContactDetailScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/contacts/:id/edit', pageBuilder: (_, s) => page(s, ContactFormScreen(editId: s.pathParameters['id']))),
      GoRoute(
        path: '/history/day/:date',
        pageBuilder: (_, s) => page(s, DayReviewScreen(day: parseDay(s.pathParameters['date']!))),
      ),
      GoRoute(
        path: '/rdv/new',
        pageBuilder: (_, s) => page(
            s,
            RdvFormScreen(
              preselectContactId: s.uri.queryParameters['contact'],
              initialVisibility: s.uri.queryParameters['vis'] == null ? null : EventVisibility.parse(s.uri.queryParameters['vis']),
            )),
      ),
      GoRoute(path: '/rdv/:id', pageBuilder: (_, s) => page(s, RdvDetailScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/rdv/:id/edit', pageBuilder: (_, s) => page(s, RdvFormScreen(editId: s.pathParameters['id']))),
      GoRoute(path: '/rdv/:id/chat', pageBuilder: (_, s) => page(s, ChatScreen(rdvId: s.pathParameters['id']!))),
      GoRoute(path: '/event/:id', pageBuilder: (_, s) => page(s, EventPreviewScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/settings/moderation', pageBuilder: (_, s) => page(s, const ModerationScreen())),
    ],
  );
});

/// Opens a path coming from a notification or a deep link.
void openAppPath(GoRouter router, String? url) {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final path = uri.path.isEmpty ? '/' : uri.path;
  const tabs = {'/', '/contacts', '/friends', '/history', '/settings'}; // /friends redirects to /contacts
  final location = uri.hasQuery ? '$path?${uri.query}' : path;
  if (tabs.contains(path)) {
    router.go(location);
  } else {
    router.push(location);
  }
}
