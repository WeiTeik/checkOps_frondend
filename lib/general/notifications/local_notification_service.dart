import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalTaskReminder {
  const LocalTaskReminder({
    required this.entryId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.kind,
  });

  final int entryId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final LocalTaskReminderKind kind;
}

enum LocalTaskReminderKind { ready, dueSoon }

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();

  static const enabledStorageKey = 'profile_notifications_enabled';
  static const _channelId = 'checkops_task_reminders';
  static const pushChannelId = 'checkops_push_notifications';
  static const _payloadPrefix = 'checkops-reminder';
  static const _maximumScheduledReminders = 60;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _pushTapController = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  bool _nativePluginUnavailable = false;

  Future<void> initialize() async {
    if (_initialized || _nativePluginUnavailable) {
      return;
    }

    _registerPlatformImplementation();
    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                pushChannelId,
                'CheckOps notifications',
                description: 'Task and workflow updates from CheckOps',
                importance: Importance.high,
              ),
            );
      }
      _initialized = true;
    } on MissingPluginException {
      _nativePluginUnavailable = true;
    }
  }

  Stream<Map<String, dynamic>> get pushNotificationTaps =>
      _pushTapController.stream;

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _pushTapController.add(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // Scheduled reminder payloads use a compact non-JSON format.
    }
  }

  void _registerPlatformImplementation() {
    if (Platform.isAndroid) {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    } else if (Platform.isIOS) {
      IOSFlutterLocalNotificationsPlugin.registerWith();
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) {
      return false;
    }
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> replaceUserReminders({
    required int userId,
    required List<LocalTaskReminder> reminders,
  }) async {
    await initialize();
    if (!_initialized) {
      return;
    }
    await cancelUserReminders(userId);

    final now = DateTime.now();
    final upcoming =
        reminders
            .where((reminder) => reminder.scheduledAt.isAfter(now))
            .toList()
          ..sort(
            (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
          );

    for (final reminder in upcoming.take(_maximumScheduledReminders)) {
      await _plugin.zonedSchedule(
        id: _notificationId(userId, reminder),
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Task reminders',
            channelDescription: 'Reminders for upcoming CheckOps tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload(userId, reminder),
      );
    }
  }

  Future<void> showPushNotification({
    int? id,
    String? title,
    String? body,
    Map<String, dynamic> payload = const {},
  }) async {
    await initialize();
    if (!_initialized ||
        !Platform.isAndroid ||
        (title == null && body == null)) {
      return;
    }

    await _plugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          'CheckOps notifications',
          channelDescription: 'Task and workflow updates from CheckOps',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

  Future<void> cancelUserReminders(int userId) async {
    await initialize();
    if (!_initialized) {
      return;
    }
    final prefix = '$_payloadPrefix:$userId:';
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith(prefix) ?? false) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  int _notificationId(int userId, LocalTaskReminder reminder) {
    const maxId = 0x7fffffff;
    final kindValue = reminder.kind == LocalTaskReminderKind.ready ? 0 : 1;
    return Object.hash(userId, reminder.entryId, kindValue) & maxId;
  }

  String _payload(int userId, LocalTaskReminder reminder) {
    return '$_payloadPrefix:$userId:${reminder.entryId}:${reminder.kind.name}';
  }
}
