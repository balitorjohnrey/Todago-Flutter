import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class PushNotifications with WidgetsBindingObserver {
  PushNotifications._();

  static final _instance = PushNotifications._();
  static final _endpoint = Uri.parse(
    'https://todago-backend-production.up.railway.app/api/push-devices',
  );
  static const _channel = AndroidNotificationChannel(
    'todago_updates',
    'TodaGo updates',
    description: 'Ride, pickup, message, and account alerts',
    importance: Importance.high,
  );
  static const _icon = 'ic_stat_todago';

  final _local = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _session;
  String? _registeredSession;
  String? _registeredToken;
  Timer? _retry;
  Future<void> _operations = Future.value();

  static Future<void> initialize() => _instance._initialize();

  Future<void> _initialize() async {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb || (!android && !ios)) return;

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      if (android) {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
        FirebaseMessaging.onMessage.listen(_showAndroidBanner);
      } else {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          sound: true,
        );
      }
      _messaging = messaging;
      messaging.onTokenRefresh.listen(
        (_) => _sync(),
        onError: (Object _) => _scheduleRetry(),
      );
      WidgetsBinding.instance.addObserver(this);
      _sync();
    } on FirebaseException catch (error) {
      debugPrint('TodaGo push initialization: ${error.code}');
    } catch (_) {
      debugPrint('TodaGo could not initialize push notifications.');
    }
  }

  static void setSession(String token) {
    _instance._session = token;
    _instance._sync();
  }

  static Future<void> clearSession(Future<String?> Function() readToken) async {
    final instance = _instance;
    if (instance._messaging == null && instance._session == null) return;
    try {
      final token = await readToken();
      if (token == null) return;
      if (instance._session == token) {
        instance._session = null;
        instance._retry?.cancel();
      }
      if (instance._messaging != null) {
        await instance._serialize(() => instance._unregister(token));
      }
    } catch (_) {
      debugPrint('TodaGo could not clear its push registration.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _serialize(Future<void> Function() operation) {
    _operations = _operations.then((_) => operation()).catchError((Object _) {
      debugPrint('TodaGo could not update its push registration.');
    });
    return _operations;
  }

  void _sync() {
    final session = _session;
    final messaging = _messaging;
    if (session == null || messaging == null) return;
    _retry?.cancel();
    unawaited(_serialize(() async {
      if (_session != session) return;
      try {
        final settings = await messaging.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          return;
        }
        final token = await _getToken(messaging);
        if (_session != session) return;
        if (token == null) {
          _scheduleRetry();
          return;
        }
        if (_registeredSession == session && _registeredToken == token) return;

        final registered = await _updateRegistration('PUT', token, session);
        if (!registered) {
          _scheduleRetry();
          return;
        }
        final previous = _registeredToken;
        if (previous != null &&
            previous != token &&
            _registeredSession == session) {
          await _updateRegistration('DELETE', previous, session);
        }
        _registeredSession = session;
        _registeredToken = token;
      } catch (_) {
        _scheduleRetry();
      }
    }));
  }

  void _scheduleRetry() {
    if (_session == null) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 20), _sync);
  }

  Future<String?> _getToken(FirebaseMessaging messaging) async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await messaging.getAPNSToken() == null) {
      return null;
    }
    return messaging.getToken().timeout(const Duration(seconds: 5));
  }

  Future<void> _unregister(String session) async {
    final messaging = _messaging;
    if (messaging == null || _session == session) return;
    try {
      final token = _registeredSession == session
          ? _registeredToken
          : await _getToken(messaging);
      if (token == null) return;
      if (!await _updateRegistration('DELETE', token, session) &&
          _session == null) {
        await messaging.deleteToken().timeout(const Duration(seconds: 5));
      }
    } finally {
      if (_registeredSession == session) {
        _registeredSession = null;
        _registeredToken = null;
      }
    }
  }

  Future<bool> _updateRegistration(
    String method,
    String token,
    String session,
  ) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request(method, _endpoint)
          ..headers['Authorization'] = 'Bearer $session'
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'token': token});
        final response =
            await client.send(request).timeout(const Duration(seconds: 4));
        return response.statusCode == 204;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _showAndroidBanner(RemoteMessage message) async {
    final notification = message.notification;
    if (_session == null || notification == null) return;
    try {
      await _local.show(
        (message.messageId ?? notification.title ?? '').hashCode & 0x7fffffff,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: _icon,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      debugPrint('TodaGo could not display a push notification.');
    }
  }
}
