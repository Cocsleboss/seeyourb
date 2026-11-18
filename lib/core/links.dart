// Shareable links and the destination kept while signing up.
//
//   <SHARE_LINK_BASE>/u/<username>   a profile (website page + app link)
//   <SHARE_LINK_BASE>/e/<event id>   an event
//
// With an https SHARE_LINK_BASE (Android App Links / iOS Universal Links), the
// link opens the app directly when it's installed, else the website. Someone
// not signed in yet is sent to the login / sign-up screen first: the
// destination is remembered (also across an app restart, e.g. while confirming
// the email) and opened once the account is ready.
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

String profileLink(String username) => '${Config.shareLinkBase}/u/${Uri.encodeComponent(username)}';

String eventLink(String eventId) => '${Config.shareLinkBase}/e/$eventId';

/// What a shared link points to.
enum LinkKind { profile, event, friendSearch }

class LinkTarget {
  const LinkTarget(this.kind, this.value);
  final LinkKind kind;

  /// username (profile / search) or event id.
  final String value;

  /// In-app location to open.
  String get location => switch (kind) {
        LinkKind.profile => '/u/${Uri.encodeComponent(value)}',
        LinkKind.event => '/event/$value',
        LinkKind.friendSearch => '/friends?q=${Uri.encodeQueryComponent(value)}',
      };

  static final _username = RegExp(r'^@?[a-z0-9][a-z0-9_.]{2,19}$');
  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// A location coming from a link worth keeping through sign-up (null otherwise).
  static LinkTarget? parse(Uri uri) {
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.length == 2 && seg[0] == 'u') {
      final u = seg[1].toLowerCase();
      return _username.hasMatch(u) ? LinkTarget(LinkKind.profile, u.replaceFirst('@', '')) : null;
    }
    if (seg.length == 2 && (seg[0] == 'e' || seg[0] == 'event')) {
      final id = seg[1].toLowerCase();
      return _uuid.hasMatch(id) ? LinkTarget(LinkKind.event, id) : null;
    }
    if (seg.length == 1 && seg[0] == 'friends') {
      final q = uri.queryParameters['q']?.trim().toLowerCase() ?? '';
      return _username.hasMatch(q) ? LinkTarget(LinkKind.friendSearch, q.replaceFirst('@', '')) : null;
    }
    return null;
  }
}

/// The destination of a link opened before signing in.
abstract final class PendingLink {
  static const _key = 'pending_link';
  static const _atKey = 'pending_link_at';

  /// Older than this, a remembered link is dropped (no surprise weeks later).
  static const maxAge = Duration(days: 2);

  static LinkTarget? _current;
  static LinkTarget? get current => _current;

  /// Reads the destination saved by a previous run (call once at startup).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final at = DateTime.tryParse(prefs.getString(_atKey) ?? '');
      if (raw == null || at == null || DateTime.now().difference(at) > maxAge) {
        await _clearStored(prefs);
        return;
      }
      _current = LinkTarget.parse(Uri.parse(raw));
    } catch (_) {
      _current = null; // storage unavailable: memory only
    }
  }

  static void save(LinkTarget target) {
    _current = target;
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString(_key, target.location);
      await prefs.setString(_atKey, DateTime.now().toIso8601String());
    }).catchError((_) {});
  }

  /// Returns the destination once (and forgets it).
  static LinkTarget? take() {
    final t = _current;
    if (t == null) return null;
    _current = null;
    SharedPreferences.getInstance().then(_clearStored).catchError((_) {});
    return t;
  }

  static Future<void> _clearStored(SharedPreferences prefs) async {
    await prefs.remove(_key);
    await prefs.remove(_atKey);
  }
}
