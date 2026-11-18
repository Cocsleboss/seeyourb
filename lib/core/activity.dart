// Activity for the admin statistics (sessions, daily / weekly / monthly actives,
// people online now): touch_session() at launch, when the app comes back to
// the foreground, then every few minutes while it stays open. Nothing about
// what the user does is sent, only "the app is open". Failures are ignored.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/api.dart';
import 'errors.dart';

class ActivityTracker {
  ActivityTracker._();
  static final instance = ActivityTracker._();

  /// Under the server's 5-minute "online now" window, well above its 1-minute throttle.
  static const heartbeat = Duration(minutes: 4);

  Api? _api;
  Timer? _timer;
  String? _version;

  /// Signed in with a profile: start (or restart) tracking for this account.
  void start(Api api) {
    _api = api;
    _touch();
    _timer?.cancel();
    _timer = Timer.periodic(heartbeat, (_) => _touch());
  }

  /// Signed out.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _api = null;
  }

  void resumed() {
    if (_api == null) return;
    _touch();
    _timer?.cancel();
    _timer = Timer.periodic(heartbeat, (_) => _touch());
  }

  /// In the background: no heartbeat (the session ends 30 min later on the server).
  void paused() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _touch() async {
    final api = _api;
    if (api == null) return;
    try {
      _version ??= (await PackageInfo.fromPlatform()).version;
      final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'));
      await api.touchSession(platform, _version ?? '');
    } catch (e) {
      // suspended account: show it; otherwise (offline, function not deployed yet)
      // it's statistics only, never the user's problem
      if (isBannedError(e)) accountBanned.value = true;
    }
  }
}
