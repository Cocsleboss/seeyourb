// Shareable links and the destination kept while signing up.
//
//   <WEBSITE_URL>/@<username>   a public profile (website page, then the app)
//   <WEBSITE_URL>/j/<token>     an invitation link to an event (anyone holding
//                               it may join; the token is random and secret)
//   <WEBSITE_URL>/e/<event id>  a public event (public events are hidden for now)
//
// The website shows the page and opens the app with the same path on the app's
// scheme (seeu://app/@andrea, seeu://app/j/<token>), else offers the stores.
// With App Links / Universal Links verified, the https link opens the app
// directly. Someone not signed in yet is sent to the login / sign-up screen
// first: the destination is remembered (also across an app restart, e.g. while
// confirming the email) and opened once the account is ready.
// Older links (/u/<username>, /friends?q=) are still understood.
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

String profileLink(String username) => '${Config.websiteUrl}/@${Uri.encodeComponent(username)}';
String profileAppLink(String username) => '${Config.appLinkBase}/@${Uri.encodeComponent(username)}';

String eventLink(String eventId) => '${Config.websiteUrl}/e/$eventId';

String eventInviteLink(String token) => '${Config.websiteUrl}/j/$token';
String eventInviteAppLink(String token) => '${Config.appLinkBase}/j/$token';

/// What a shared link points to.
enum LinkKind { profile, event, eventInvite, friendSearch }

class LinkTarget {
  const LinkTarget(this.kind, this.value);
  final LinkKind kind;

  /// username (profile / search), event id, or invitation token.
  final String value;

  /// In-app location to open.
  String get location => switch (kind) {
        LinkKind.profile => '/u/${Uri.encodeComponent(value)}',
        LinkKind.event => '/event/$value',
        LinkKind.eventInvite => '/j/$value',
        LinkKind.friendSearch => '/friends?q=${Uri.encodeQueryComponent(value)}',
      };

  static final _username = RegExp(r'^@?[a-z0-9][a-z0-9_.]{2,19}$');
  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  static final _token = RegExp(r'^[A-Za-z0-9_-]{32,64}$');

  /// A location coming from a link worth keeping through sign-up (null otherwise).
  static LinkTarget? parse(Uri uri) {
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.length == 1 && seg[0].startsWith('@')) {
      final u = seg[0].toLowerCase();
      return _username.hasMatch(u) ? LinkTarget(LinkKind.profile, u.substring(1)) : null;
    }
    if (seg.length == 2 && seg[0] == 'j') {
      return _token.hasMatch(seg[1]) ? LinkTarget(LinkKind.eventInvite, seg[1]) : null;
    }
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
