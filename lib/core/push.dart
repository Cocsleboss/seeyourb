// Push notifications: Firebase Cloud Messaging (Android + iOS via APNs).
// Firebase is optional at build time: without google-services.json /
// GoogleService-Info.plist the app runs normally, push is just unavailable.
//
// We use FCM registration tokens (getToken/onTokenRefresh), which firebase_messaging 17
// marks deprecated in favour of Installation-ID registration. Tokens still work with
// the FCM HTTP v1 API used by supabase/functions/dispatch; migrate both sides together.
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api.dart';

enum PushPermission { unsupported, notDetermined, granted, denied }

const _channel = AndroidNotificationChannel(
  'seeu_default',
  'Rappels SeeU',
  description: 'Rappels, rendez-vous et activité de vos amis',
  importance: Importance.high,
);

class PushService {
  PushService._();
  static final instance = PushService._();

  bool available = false;
  final _local = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<String>.broadcast();
  final _received = StreamController<void>.broadcast();
  String? _token;
  String? _pendingOpen;
  StreamSubscription<String>? _tokenSub;

  /// Paths to open (notification tapped).
  Stream<String> get onOpen => _opened.stream;

  /// A notification arrived while the app is open (refresh data).
  Stream<void> get onReceived => _received.stream;

  /// Path of the notification that launched the app, consumed once.
  String? takeInitialPath() {
    final p = _pendingOpen;
    _pendingOpen = null;
    return p;
  }

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
    } catch (e) {
      debugPrint('Push disabled (Firebase not configured): $e');
      return;
    }

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) _opened.add(r.payload!);
      },
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);

    final m = FirebaseMessaging.instance;
    // iOS shows foreground notifications itself; Android needs a local notification.
    await m.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen((msg) {
      _received.add(null);
      final n = msg.notification;
      if (n == null || !Platform.isAndroid) return;
      _local.show(
        id: msg.hashCode,
        title: n.title,
        body: n.body,
        payload: msg.data['url'] as String?,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name,
              channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final url = msg.data['url'] as String?;
      if (url != null) _opened.add(url);
    });
    final initial = await m.getInitialMessage();
    _pendingOpen = initial?.data['url'] as String?;
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _pendingOpen ??= launch!.notificationResponse?.payload;
  }

  Future<PushPermission> permission() async {
    if (!available) return PushPermission.unsupported;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return switch (s.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
      AuthorizationStatus.denied => PushPermission.denied,
      _ => PushPermission.notDetermined,
    };
  }

  /// Asks the OS permission (once) then registers this device for the user.
  Future<PushPermission> enable(Api api) async {
    if (!available) return PushPermission.unsupported;
    await FirebaseMessaging.instance.requestPermission();
    final p = await permission();
    if (p == PushPermission.granted) await register(api);
    return p;
  }

  /// Registers the FCM token of this device (no-op without permission).
  Future<void> register(Api api) async {
    if (!available || await permission() != PushPermission.granted) return;
    try {
      if (Platform.isIOS) await FirebaseMessaging.instance.getAPNSToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await api.registerDevice(token, Platform.isIOS ? 'ios' : 'android');
      _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        api.registerDevice(t, Platform.isIOS ? 'ios' : 'android').catchError((_) {});
      });
    } catch (e) {
      debugPrint('push register: $e');
    }
  }

  /// "Désactiver" on this device, and before signing out.
  Future<void> unregister(Api api) async {
    if (!available) return;
    final token = _token ?? await FirebaseMessaging.instance.getToken().catchError((_) => null);
    if (token != null) await api.unregisterDevice(token).catchError((_) {});
    await _tokenSub?.cancel();
    _tokenSub = null;
    _token = null;
    await FirebaseMessaging.instance.deleteToken().catchError((_) {});
  }

  /// Is this device currently registered?
  bool get registered => _token != null;
}
