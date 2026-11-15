// Riverpod providers: session, profile and cached server data.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import 'api.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final apiProvider = Provider<Api>((ref) => Api(ref.watch(supabaseProvider)));

Future<String> deviceTimezone() async {
  try {
    final tz = await FlutterTimezone.getLocalTimezone();
    return tz.identifier;
  } catch (_) {
    return 'Europe/Paris';
  }
}

/// Auth + profile state driving the router (login / complete profile / app).
class SessionController extends ChangeNotifier {
  SessionController(this._sb, this._api) {
    _sub = _sb.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) passwordRecovery = true;
      _onSession(data.session);
    }, onError: (Object e) => debugPrint('auth: $e'));
    _onSession(_sb.auth.currentSession);
  }

  final SupabaseClient _sb;
  final Api _api;
  late final StreamSubscription<AuthState> _sub;

  Session? session;
  Profile? profile;
  bool profileLoading = false;
  Object? profileError;

  /// Opened from a password-reset email: show the "Nouveau mot de passe" screen.
  bool passwordRecovery = false;

  String? get userId => session?.user.id;
  bool get signedIn => session != null;
  bool get needsUsername => signedIn && profile != null && (profile!.username == null || profile!.username!.isEmpty);

  String? _loadedFor;

  void _onSession(Session? s) {
    final changedUser = s?.user.id != session?.user.id;
    session = s;
    if (s == null) {
      profile = null;
      _loadedFor = null;
      passwordRecovery = false;
      notifyListeners();
      return;
    }
    if (changedUser || _loadedFor != s.user.id) {
      reloadProfile();
    } else {
      notifyListeners();
    }
  }

  Future<void> reloadProfile() async {
    final id = session?.user.id;
    if (id == null) return;
    profileLoading = true;
    profileError = null;
    notifyListeners();
    try {
      profile = await _api.ensureProfile(await deviceTimezone());
      _loadedFor = id;
    } catch (e) {
      profileError = e;
    } finally {
      profileLoading = false;
      notifyListeners();
    }
  }

  void setProfile(Profile p) {
    profile = p;
    notifyListeners();
  }

  void endPasswordRecovery() {
    passwordRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final sessionProvider = Provider<SessionController>((ref) {
  final c = SessionController(ref.watch(supabaseProvider), ref.watch(apiProvider));
  ref.onDispose(c.dispose);
  return c;
});

/// Current user id; data providers watch it so they reset on sign-out / user change.
final userIdProvider = NotifierProvider<UserIdNotifier, String?>(UserIdNotifier.new);

class UserIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final session = ref.watch(sessionProvider);
    void listener() {
      if (state != session.userId) state = session.userId;
    }

    session.addListener(listener);
    ref.onDispose(() => session.removeListener(listener));
    return session.userId;
  }
}

/// Profile as a listenable value for widgets.
final profileProvider = NotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends Notifier<Profile?> {
  @override
  Profile? build() {
    final session = ref.watch(sessionProvider);
    void listener() => state = session.profile;
    session.addListener(listener);
    ref.onDispose(() => session.removeListener(listener));
    return session.profile;
  }
}

/* ------------------------------- Data -------------------------------- */

Api _api(Ref ref) {
  ref.watch(userIdProvider);
  return ref.watch(apiProvider);
}

final contactsProvider = FutureProvider<List<Contact>>((ref) => _api(ref).listContacts());

/// One contact from the cached list (null = not found / deleted).
final contactProvider = Provider.family<AsyncValue<Contact?>, String>((ref, id) {
  return ref.watch(contactsProvider).whenData((list) {
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  });
});

final plannedRdvProvider = FutureProvider<List<Rendezvous>>((ref) => _api(ref).listPlannedRdv());
final historyProvider = FutureProvider<List<Rendezvous>>((ref) => _api(ref).listHistory());
final rdvProvider = FutureProvider.family<Rendezvous?, String>((ref, id) => _api(ref).getRdv(id));

/// Validated / cancelled rendezvous of a month (key: first day of the month).
final historyMonthProvider = FutureProvider.family<List<Rendezvous>, DateTime>(
    (ref, month) => _api(ref).listHistoryBetween(month, DateTime(month.year, month.month + 1)));

/// Validated / cancelled rendezvous of one day (key: the day at midnight).
final historyDayProvider = FutureProvider.family<List<Rendezvous>, DateTime>(
    (ref, day) => _api(ref).listHistoryBetween(day, DateTime(day.year, day.month, day.day + 1)));
final contactRdvsProvider = FutureProvider.family<List<Rendezvous>, String>((ref, id) => _api(ref).listRdvForContact(id));
final contactPhotosProvider = FutureProvider.family<List<Photo>, String>((ref, id) => _api(ref).listPhotosForContact(id));
final sharedRdvPhotosProvider = FutureProvider.family<List<Photo>, String>((ref, id) => _api(ref).listSharedPhotosForRdv(id));
final rdvInvitesProvider = FutureProvider.family<List<RdvInvitation>, String>((ref, id) => _api(ref).listInvitesForRdv(id));
final friendsProvider = FutureProvider<List<Friend>>((ref) => _api(ref).listFriends());
final incomingInvitesProvider = FutureProvider<List<IncomingInvite>>((ref) => _api(ref).listIncomingInvites());
final notificationLogProvider = FutureProvider<List<NotificationEntry>>((ref) => _api(ref).listNotifications());

/// Signed URL of a private photo (valid 1 h, cached ~50 min).
final signedUrlProvider = FutureProvider.family<String, String>((ref, path) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 50), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(apiProvider).signedUrl(path);
});

/// Refreshes everything after a mutation (cheap: lists are small, per user).
void refreshData(WidgetRef ref) {
  ref.invalidate(contactsProvider);
  ref.invalidate(plannedRdvProvider);
  ref.invalidate(historyProvider);
  ref.invalidate(historyMonthProvider);
  ref.invalidate(historyDayProvider);
  ref.invalidate(rdvProvider);
  ref.invalidate(contactRdvsProvider);
  ref.invalidate(contactPhotosProvider);
  ref.invalidate(sharedRdvPhotosProvider);
  ref.invalidate(rdvInvitesProvider);
  ref.invalidate(friendsProvider);
  ref.invalidate(incomingInvitesProvider);
}

void refreshDataFromContainer(ProviderContainer c) {
  c.invalidate(contactsProvider);
  c.invalidate(plannedRdvProvider);
  c.invalidate(historyProvider);
  c.invalidate(historyMonthProvider);
  c.invalidate(historyDayProvider);
  c.invalidate(rdvProvider);
  c.invalidate(contactRdvsProvider);
  c.invalidate(contactPhotosProvider);
  c.invalidate(sharedRdvPhotosProvider);
  c.invalidate(rdvInvitesProvider);
  c.invalidate(friendsProvider);
  c.invalidate(incomingInvitesProvider);
  c.invalidate(notificationLogProvider);
}
