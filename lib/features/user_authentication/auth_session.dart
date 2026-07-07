import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../dashboard_reporting/home_page.dart';
import '../notifications/push_notification_service.dart';
import 'auth_api.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.role,
    required this.displayName,
    required this.email,
    required this.employeeId,
    required this.userId,
    this.profilePic,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final UserRole role;
  final String displayName;
  final String email;
  final String employeeId;
  final int userId;
  final String? profilePic;

  bool get hasValidAccessToken {
    return accessTokenExpiresAt.isAfter(
      DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
  }

  bool get hasValidRefreshToken {
    return refreshTokenExpiresAt.isAfter(DateTime.now().toUtc());
  }

  Map<String, String> toStorage() {
    return {
      _AuthSessionStore.accessTokenKey: accessToken,
      _AuthSessionStore.refreshTokenKey: refreshToken,
      _AuthSessionStore.accessExpiresAtKey: accessTokenExpiresAt
          .toUtc()
          .toIso8601String(),
      _AuthSessionStore.refreshExpiresAtKey: refreshTokenExpiresAt
          .toUtc()
          .toIso8601String(),
      _AuthSessionStore.roleKey: role.name,
      _AuthSessionStore.displayNameKey: displayName,
      _AuthSessionStore.emailKey: email,
      _AuthSessionStore.employeeIdKey: employeeId,
      _AuthSessionStore.userIdKey: userId.toString(),
    };
  }

  static AuthSession? fromLoginResponse(Map<String, dynamic> response) {
    final accessToken = response['access_token']?.toString();
    final refreshToken = response['refresh_token']?.toString();
    final accessExpiresAt = _parseDate(response['access_token_expires_at']);
    final refreshExpiresAt = _parseDate(response['refresh_token_expires_at']);
    final user = response['user'] as Map<String, dynamic>?;
    final userId = _parseInt(user?['id'] ?? response['id']);

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        accessExpiresAt == null ||
        refreshExpiresAt == null ||
        userId == null) {
      return null;
    }

    final email = user?['email']?.toString();
    final employeeId =
        user?['employee_id']?.toString() ??
        user?['employeeId']?.toString() ??
        user?['id']?.toString() ??
        response['employee_id']?.toString() ??
        response['employeeId']?.toString() ??
        response['id']?.toString();
    final profilePic =
        user?['profile_pic']?.toString() ??
        user?['profilePic']?.toString() ??
        response['profile_pic']?.toString() ??
        response['profilePic']?.toString();
    final displayName =
        user?['name']?.toString() ?? response['name']?.toString() ?? email;
    if (displayName == null ||
        displayName.isEmpty ||
        email == null ||
        email.isEmpty) {
      return null;
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessExpiresAt,
      refreshTokenExpiresAt: refreshExpiresAt,
      role: userRoleFromValue(
        user?['role'] ??
            user?['user_role'] ??
            user?['type'] ??
            response['role'] ??
            response['user_role'] ??
            response['type'],
      ),
      displayName: displayName,
      email: email,
      employeeId: employeeId ?? '',
      userId: userId,
      profilePic: profilePic,
    );
  }

  static AuthSession? fromStorage(Map<String, String> values) {
    final accessToken = values[_AuthSessionStore.accessTokenKey];
    final refreshToken = values[_AuthSessionStore.refreshTokenKey];
    final accessExpiresAt = _parseDate(
      values[_AuthSessionStore.accessExpiresAtKey],
    );
    final refreshExpiresAt = _parseDate(
      values[_AuthSessionStore.refreshExpiresAtKey],
    );
    final displayName = values[_AuthSessionStore.displayNameKey];
    final email = values[_AuthSessionStore.emailKey];
    final employeeId = values[_AuthSessionStore.employeeIdKey];
    final userId = _parseInt(values[_AuthSessionStore.userIdKey]);

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        accessExpiresAt == null ||
        refreshExpiresAt == null ||
        displayName == null ||
        displayName.isEmpty ||
        email == null ||
        email.isEmpty ||
        userId == null) {
      return null;
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessExpiresAt,
      refreshTokenExpiresAt: refreshExpiresAt,
      role: userRoleFromValue(values[_AuthSessionStore.roleKey]),
      displayName: displayName,
      email: email,
      employeeId: employeeId ?? '',
      userId: userId,
    );
  }

  AuthSession copyWith({
    String? displayName,
    String? email,
    String? employeeId,
    UserRole? role,
    String? profilePic,
  }) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      userId: userId,
      profilePic: profilePic ?? this.profilePic,
    );
  }

  static DateTime? _parseDate(Object? value) {
    final rawValue = value?.toString();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue)?.toUtc();
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class AuthSessionManager {
  AuthSessionManager({AuthApi? authApi, FlutterSecureStorage? storage})
    : _authApi = authApi ?? AuthApi(),
      _store = _AuthSessionStore(storage ?? const FlutterSecureStorage()) {
    AuthApi.accessTokenProvider = () => _session?.accessToken;
    AuthApi.unauthorizedTokenHandler = _refreshAfterUnauthorized;
  }

  final AuthApi _authApi;
  final _AuthSessionStore _store;
  AuthSession? _session;
  bool _shouldPersistSession = false;
  Future<AuthSession?>? _refreshInFlight;

  AuthSession? get session => _session;

  Future<AuthSession?> restore() async {
    final AuthSession? storedSession;
    try {
      storedSession = await _store.read();
    } on Object {
      return null;
    }

    if (storedSession == null) {
      return null;
    }

    if (storedSession.hasValidAccessToken) {
      _session = storedSession;
      _shouldPersistSession = true;
      unawaited(
        PushNotificationService.instance.registerForUser(
          userId: storedSession.userId,
          accessToken: storedSession.accessToken,
        ),
      );
      return storedSession;
    }

    if (!storedSession.hasValidRefreshToken) {
      await clear();
      return null;
    }

    try {
      _session = storedSession;
      _shouldPersistSession = true;
      final refreshedSession = await _refreshSession(storedSession);
      if (refreshedSession == null) {
        await clear();
        return null;
      }
      return refreshedSession;
    } on AuthApiException {
      await clear();
      return null;
    }
  }

  Future<void> saveAfterLogin({
    required AuthSession session,
    required bool rememberMe,
  }) async {
    _session = session;
    _shouldPersistSession = rememberMe;
    unawaited(
      PushNotificationService.instance.registerForUser(
        userId: session.userId,
        accessToken: session.accessToken,
      ),
    );
    if (rememberMe) {
      await _store.write(session);
      return;
    }
    await _store.clear();
  }

  Future<void> remember(AuthSession session) async {
    _session = session;
    _shouldPersistSession = true;
    await _store.write(session);
  }

  Future<String?> _refreshAfterUnauthorized(String expiredAccessToken) async {
    final currentSession = _session;
    if (currentSession == null) {
      return null;
    }

    if (currentSession.accessToken != expiredAccessToken) {
      return currentSession.accessToken;
    }

    if (!currentSession.hasValidRefreshToken) {
      await clear();
      return null;
    }

    final refreshedSession = await (_refreshInFlight ??= _refreshSession(
      currentSession,
    ));
    _refreshInFlight = null;
    return refreshedSession?.accessToken;
  }

  Future<AuthSession?> _refreshSession(AuthSession session) async {
    try {
      final response = await _authApi.refresh(
        refreshToken: session.refreshToken,
      );
      final refreshedSession = AuthSession.fromLoginResponse(response);
      if (refreshedSession == null) {
        await clear();
        return null;
      }
      await _saveRefreshedSession(refreshedSession);
      return refreshedSession;
    } on AuthApiException {
      await clear();
      return null;
    }
  }

  Future<void> _saveRefreshedSession(AuthSession session) async {
    _session = session;
    unawaited(
      PushNotificationService.instance.registerForUser(
        userId: session.userId,
        accessToken: session.accessToken,
      ),
    );
    if (_shouldPersistSession) {
      await _store.write(session);
    }
  }

  Future<void> updateCachedProfile({
    required String displayName,
    required String email,
    required String employeeId,
    required UserRole role,
    String? profilePic,
  }) async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }
    final updatedSession = currentSession.copyWith(
      displayName: displayName,
      email: email,
      employeeId: employeeId,
      role: role,
      profilePic: profilePic,
    );
    _session = updatedSession;
    if (_shouldPersistSession) {
      await _store.write(updatedSession);
    }
  }

  Future<void> logout() async {
    final accessToken = _session?.accessToken;
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await PushNotificationService.instance.unregisterForUser(
          accessToken: accessToken,
        );
        await _authApi.logout(accessToken: accessToken);
      }
    } on Object {
      // Local logout should still complete if the server session is already gone.
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    _session = null;
    _shouldPersistSession = false;
    await _store.clear();
  }
}

class _AuthSessionStore {
  _AuthSessionStore(this._storage);

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const accessExpiresAtKey = 'access_token_expires_at';
  static const refreshExpiresAtKey = 'refresh_token_expires_at';
  static const roleKey = 'role';
  static const displayNameKey = 'display_name';
  static const emailKey = 'email';
  static const employeeIdKey = 'employee_id';
  static const userIdKey = 'user_id';

  static const _allKeys = [
    accessTokenKey,
    refreshTokenKey,
    accessExpiresAtKey,
    refreshExpiresAtKey,
    roleKey,
    displayNameKey,
    emailKey,
    employeeIdKey,
    userIdKey,
  ];

  final FlutterSecureStorage _storage;

  Future<AuthSession?> read() async {
    final values = <String, String>{};
    for (final key in _allKeys) {
      final value = await _storage.read(key: key);
      if (value != null) {
        values[key] = value;
      }
    }
    return AuthSession.fromStorage(values);
  }

  Future<void> write(AuthSession session) async {
    for (final entry in session.toStorage().entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }

  Future<void> clear() async {
    for (final key in _allKeys) {
      await _storage.delete(key: key);
    }
  }
}
