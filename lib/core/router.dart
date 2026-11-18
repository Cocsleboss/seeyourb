// Navigation: 5 tabs in a stateful shell, detail screens pushed on top.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../ui/feedback.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/contacts/contact_detail_screen.dart';
import '../features/contacts/contact_form_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/contacts/import_screen.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../features/events/event_preview_screen.dart';
import '../features/events/join_link_screen.dart';
import '../features/history/calendar.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/misc/fallback_screens.dart';
import '../features/profile/public_profile_settings_screen.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/rdv/rdv_detail_screen.dart';
import '../features/rdv/rdv_form_screen.dart';
import '../features/settings/moderation_screen.dart';
import '../features/settings/settings_screen.dart';
import 'links.dart';


const _publicPaths = {'/login', '/reset-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    // Auth email links (seeu://auth-callback?code=…) are handled by Supabase itself.
    if (path.isEmpty || path == '/auth-callback') return '/';
    // Profile links: https://<site>/@andrea (and seeu://app/@andrea) → /u/andrea
    if (path.startsWith('/@') && !path.substring(2).contains('/')) {
      return '/u/${Uri.encodeComponent(Uri.decodeComponent(path.substring(2)).toLowerCase())}';
    }
    // A shared link (profile, event, friend search) opened before signing in:
    // remembered, opened once the account is ready (sign-up included).
    if (!session.signedIn && !session.passwordRecovery && !_publicPaths.contains(path)) {
      final target = LinkTarget.parse(state.uri);
      if (target != null) PendingLink.save(target);
      return '/login';
    }
    // Friends now live in the Contacts tab ("/friends?q=andrea" comes from older shared links and notifications).
    if (path == '/friends') {
      final q = state.uri.queryParameters['q'];
      return q == null || q.isEmpty ? '/contacts' : '/contacts?ami=${Uri.encodeQueryComponent(q)}';
    }
    if (session.passwordRecovery) return path == '/reset-password' ? null : '/reset-password';
    if (!session.signedIn) return _publicPaths.contains(path) ? null : '/login';
    if (session.isBanned) return path == '/banned' ? null : '/banned';
    if (session.profile == null) return path == '/splash' ? null : '/splash';
    if (session.needsUsername) return path == '/complete-profile' ? null : '/complete-profile';
    const waiting = {'/', '/splash', '/complete-profile', '/banned'};
    if (_publicPaths.contains(path) || waiting.contains(path)) {
      final pending = PendingLink.take();
      if (pending != null) return pending.location;
      if (path != '/') return '/';
    }
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
      GoRoute(path: '/banned', builder: (_, _) => const BannedScreen()),
      StatefulShellRoute.indexedStack(
        // One outer Scaffold: the four tabs' own Scaffolds become nested, so a
        // toast is shown once (it was shown in every tab kept alive, which
        // crashed with "multiple heroes share the same tag").
        builder: (context, state, shell) => Scaffold(resizeToAvoidBottomInset: false, body: shell),
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
      GoRoute(path: '/rdv/:id', pageBuilder: (_, s) => page(s, RdvDetailScreen(id: s.pathParameters['id']!, openShare: s.uri.queryParameters['share'] == '1'))),
      GoRoute(path: '/rdv/:id/edit', pageBuilder: (_, s) => page(s, RdvFormScreen(editId: s.pathParameters['id']))),
      // chat notifications: the chat is on the event page
      GoRoute(path: '/rdv/:id/chat', pageBuilder: (_, s) => page(s, RdvDetailScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/event/:id', pageBuilder: (_, s) => page(s, EventPreviewScreen(id: s.pathParameters['id']!))),
      // Shared links: https://<site>/e/<id> (event) and /u/<username> (profile)
      GoRoute(path: '/e/:id', redirect: (_, s) => '/event/${s.pathParameters['id']}'),
      // Invitation link to an event: https://<site>/j/<token> or seeu://app/j/<token>
      GoRoute(path: '/j/:token', pageBuilder: (_, s) => page(s, JoinLinkScreen(token: s.pathParameters['token']!))),
      GoRoute(path: '/u/:username', pageBuilder: (_, s) => page(s, UserProfileScreen(username: s.pathParameters['username']!))),
      GoRoute(path: '/settings/public-profile', pageBuilder: (_, s) => page(s, const PublicProfileSettingsScreen())),
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
