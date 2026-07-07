import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../user_authentication/auth_api.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
    } on Object {
      // Firebase setup is optional until google-services.json is configured.
    }
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final _authApi = AuthApi();
  bool _initialized = false;
  bool _firebaseUnavailable = false;
  String? _accessToken;
  int? _userId;

  bool get isSupported => Platform.isAndroid;

  Future<void> initialize() async {
    if (!isSupported || _initialized || _firebaseUnavailable) {
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerRefreshedToken);
      _initialized = true;
    } on Object {
      _firebaseUnavailable = true;
    }
  }

  Future<void> registerForUser({
    required int userId,
    required String accessToken,
  }) async {
    _userId = userId;
    _accessToken = accessToken;
    if (!isSupported) {
      return;
    }

    await initialize();
    if (!_initialized) {
      return;
    }

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _registerToken(token, accessToken);
  }

  Future<void> setEnabled({
    required int userId,
    required String accessToken,
    required bool enabled,
  }) async {
    if (enabled) {
      await registerForUser(userId: userId, accessToken: accessToken);
      return;
    }
    await unregisterForUser(accessToken: accessToken);
  }

  Future<void> unregisterForUser({required String accessToken}) async {
    if (!isSupported) {
      _accessToken = null;
      _userId = null;
      return;
    }

    await initialize();
    if (!_initialized) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _authApi.request(
        method: 'DELETE',
        path: '/notifications/push-tokens',
        payload: {'token': token},
        bearerToken: accessToken,
      );
    }
    _accessToken = null;
    _userId = null;
  }

  Future<void> _registerRefreshedToken(String token) async {
    final accessToken = _accessToken;
    if (accessToken == null || accessToken.isEmpty || _userId == null) {
      return;
    }
    await _registerToken(token, accessToken);
  }

  Future<void> _registerToken(String token, String accessToken) async {
    await _authApi.request(
      method: 'POST',
      path: '/notifications/push-tokens',
      payload: {'token': token, 'platform': 'android'},
      bearerToken: accessToken,
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) {
      return;
    }

    await LocalNotificationService.instance.showPushNotification(
      title: title ?? 'CheckOps',
      body: body ?? '',
      payload: Map<String, dynamic>.from(message.data),
    );
  }
}
