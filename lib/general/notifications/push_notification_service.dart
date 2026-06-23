import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../authentication/auth_api.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  static const _storage = FlutterSecureStorage();

  final _authApi = AuthApi();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<Map<String, dynamic>>? _localTapSubscription;
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _pendingNotificationTap;
  String? _accessToken;
  bool _initialized = false;
  bool _unavailable = false;

  Future<void> initialize() async {
    if (_initialized || _unavailable || !Platform.isAndroid) {
      // iOS placeholder: initialize FCM here after APNs is configured.
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        LocalNotificationService.instance.showPushNotification(
          id: message.messageId?.hashCode,
          title: message.notification?.title,
          body: message.notification?.body,
          payload: message.data,
        );
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _emitNotificationTap(message.data),
      );
      _localTapSubscription = LocalNotificationService
          .instance
          .pushNotificationTaps
          .listen(_emitNotificationTap);
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _emitNotificationTap(initialMessage.data);
      }
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((token) {
            final accessToken = _accessToken;
            if (accessToken != null) {
              _registerToken(accessToken: accessToken, token: token);
            }
          });
      _initialized = true;
    } on Object {
      _unavailable = true;
    }
  }

  Stream<Map<String, dynamic>> get notificationTaps =>
      _notificationTapController.stream;

  Map<String, dynamic>? takePendingNotificationTap() {
    final pending = _pendingNotificationTap;
    _pendingNotificationTap = null;
    return pending;
  }

  void _emitNotificationTap(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return;
    }
    final payload = Map<String, dynamic>.from(data);
    if (!_notificationTapController.hasListener) {
      _pendingNotificationTap = payload;
    }
    _notificationTapController.add(payload);
  }

  Future<void> registerForSession(String accessToken) async {
    if (!Platform.isAndroid) {
      return;
    }

    await initialize();
    if (!_initialized) {
      return;
    }
    _accessToken = accessToken;
    final enabled = await _storage.read(
      key: LocalNotificationService.enabledStorageKey,
    );
    if (enabled == 'false') {
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(accessToken: accessToken, token: token);
      }
    } on Object {
      // Push setup is best-effort and must not block authentication.
    }
  }

  Future<void> setEnabled({
    required String accessToken,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (enabled) {
      await registerForSession(accessToken);
      return;
    }

    await unregisterForSession(accessToken);
  }

  Future<void> unregisterForSession(String accessToken) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _authApi
            .request(
              method: 'DELETE',
              path: '/notifications/push-devices',
              payload: {'token': token, 'platform': 'android'},
              bearerToken: accessToken,
            )
            .timeout(const Duration(seconds: 5));
      }
    } on Object {
      // Logout and notification settings should still complete offline.
    } finally {
      _accessToken = null;
    }
  }

  Future<void> _registerToken({
    required String accessToken,
    required String token,
  }) async {
    try {
      await _authApi
          .request(
            method: 'POST',
            path: '/notifications/push-devices',
            payload: {'token': token, 'platform': 'android'},
            bearerToken: accessToken,
          )
          .timeout(const Duration(seconds: 5));
    } on Object {
      // The token refresh stream or the next login will retry registration.
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _localTapSubscription?.cancel();
    await _notificationTapController.close();
  }
}
