// Riverpod providers: session, profile and cached server data.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../core/i18n.dart';
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
    accountBanned.addListener(_onBanned);
    _onSession(_sb.auth.currentSession);
  }

  void _onBanned() {
    if (accountBanned.value && signedIn && !banned) {
      banned = true;
      notifyListeners();
    }
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

  /// The server refused this account (suspended by a moderator).
  bool banned = false;
  bool get isBanned => signedIn && (banned || profile?.bannedAt != null);

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
      banned = false;
      accountBanned.value = false;
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
      profile = await _api.ensureProfile(await deviceTimezone(), currentLanguage);
      _loadedFor = id;
    } catch (e) {
      profileError = e;
      if (isBannedError(e)) banned = true;
    } finally {
      profileLoading = false;
      notifyListeners();
    }
  }

  /// The app language changed: notifications follow.
  Future<void> syncLanguage(String lang) async {
    final p = profile;
    if (p == null || p.locale == lang) return;
    try {
      profile = await _api.updateProfile({'locale': lang});
      notifyListeners();
    } catch (_) {
      // retried at next launch by ensureProfile
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
    accountBanned.removeListener(_onBanned);
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
/// One event of my agenda. Shown at once from the lists already loaded (agenda,
/// history, a contact's events), then refreshed from the server.
final rdvProvider = StreamProvider.family<Rendezvous?, String>((ref, id) async* {
  Rendezvous? cached;
  for (final list in [ref.read(plannedRdvProvider).value, ref.read(historyProvider).value]) {
    cached ??= list?.where((r) => r.id == id).firstOrNull;
  }
  if (cached != null) yield cached;
  yield await _api(ref).getRdv(id);
});

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

/// Feeds of the home sections: 'contacts' and 'public' (first page; search in Explorer).
final feedProvider = FutureProvider.family<List<FeedEvent>, ({String scope, String query})>(
    (ref, k) => _api(ref).listFeed(k.scope, query: k.query));
final eventProvider = FutureProvider.family<FeedEvent?, String>((ref, id) => _api(ref).getEvent(id));
final participantsProvider = FutureProvider.family<List<Participant>, String>((ref, id) => _api(ref).listParticipants(id));
final eventGuestsProvider = FutureProvider.family<List<EventGuest>, String>((ref, id) => _api(ref).listGuests(id));
final slotsProvider = FutureProvider.family<List<EventSlot>, String>((ref, id) => _api(ref).listSlots(id));
final chatPreviewProvider = FutureProvider.family<List<ChatMessage>, String>((ref, id) => _api(ref).listMessages(id, limit: 3));
final canCreatePublicProvider = FutureProvider<bool>((ref) => _api(ref).canCreatePublicEvents().catchError((_) => false));
final mutesProvider = FutureProvider<List<MuteEntry>>((ref) => _api(ref).listMutes());
final blockedProvider = FutureProvider<List<BlockedUser>>((ref) => _api(ref).listBlocked());

/// Someone's profile page (/u/:username); null = not found / not visible to me.
final userProfileProvider = FutureProvider.family<UserProfile?, String>((ref, username) => _api(ref).getUserProfile(username));

/// A SeeU friend's city, as they share it with their friends (null: none, or
/// not shared). Shown on my card for them instead of a city I'd type.
final friendCityProvider = FutureProvider.family<String?, String>((ref, userId) async {
  final friends = await ref.watch(friendsProvider.future);
  final username = friends.where((f) => f.userId == userId && f.accepted).firstOrNull?.username;
  if (username == null) return null;
  final profile = await ref.watch(userProfileProvider(username).future);
  return profile?.cityLabel;
});

/// "You could see them while there": people living near a place far from my home.
final peopleNearProvider = FutureProvider.family<List<NearbyPerson>, ({double lat, double lng, String? eventId})>(
    (ref, k) => _api(ref).peopleNear(k.lat, k.lng, eventId: k.eventId));

/// Signed URL of a private photo (valid 1 h, cached ~50 min).
final signedUrlProvider = FutureProvider.family<String, String>((ref, path) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 50), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(apiProvider).signedUrl(path);
});

/// Refreshes everything after a mutation (cheap: lists are small, per user).
/// Profile pictures, fetched in batches: every avatar shown in the same frame
/// costs one request. Value: public URL, or null (no picture).
class AvatarBatcher {
  AvatarBatcher(this._api);
  final Api _api;
  final _waiting = <String, Completer<String?>>{};
  Timer? _timer;

  Future<String?> get(String userId) {
    final existing = _waiting[userId];
    if (existing != null) return existing.future;
    final c = Completer<String?>();
    _waiting[userId] = c;
    _timer ??= Timer(const Duration(milliseconds: 30), _flush);
    return c.future;
  }

  Future<void> _flush() async {
    _timer = null;
    final batch = Map.of(_waiting);
    _waiting.clear();
    try {
      final urls = await _api.profileAvatars(batch.keys.toList());
      batch.forEach((id, c) => c.complete(urls[id]));
    } catch (_) {
      batch.forEach((_, c) => c.complete(null)); // initials instead; never an error state
    }
  }
}

final avatarBatcherProvider = Provider<AvatarBatcher>((ref) => AvatarBatcher(ref.watch(apiProvider)));
final avatarUrlProvider = FutureProvider.family<String?, String>((ref, userId) => ref.watch(avatarBatcherProvider).get(userId));

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
  ref.invalidate(feedProvider);
  ref.invalidate(eventProvider);
  ref.invalidate(participantsProvider);
  ref.invalidate(eventGuestsProvider);
  ref.invalidate(slotsProvider);
  ref.invalidate(chatPreviewProvider);
  ref.invalidate(mutesProvider);
  ref.invalidate(blockedProvider);
  ref.invalidate(avatarUrlProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(peopleNearProvider);
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
  c.invalidate(feedProvider);
  c.invalidate(eventProvider);
  c.invalidate(participantsProvider);
  c.invalidate(eventGuestsProvider);
  c.invalidate(slotsProvider);
  c.invalidate(chatPreviewProvider);
  c.invalidate(userProfileProvider);
  c.invalidate(peopleNearProvider);
}
