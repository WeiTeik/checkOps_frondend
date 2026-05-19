import 'dart:async';

import 'package:flutter/services.dart';

class AuthDeepLink {
  AuthDeepLink({
    required this.flow,
    required this.email,
    required this.otp,
    required this.token,
  });

  final String flow;
  final String email;
  final String otp;
  final String token;

  bool get isActivation => flow == 'activation';
  bool get isPasswordReset => flow == 'password_reset';
}

class DeepLinkService {
  DeepLinkService._();

  static const _channel = MethodChannel('checkops/deep_links');
  static const _events = EventChannel('checkops/deep_links/events');

  static Future<AuthDeepLink?> initialAuthLink() async {
    final link = await _channel.invokeMethod<String>('getInitialLink');
    return parseAuthLink(link);
  }

  static Stream<AuthDeepLink> authLinks() {
    return _events.receiveBroadcastStream().map((value) {
      return parseAuthLink(value?.toString());
    }).where((link) => link != null).cast<AuthDeepLink>();
  }

  static AuthDeepLink? parseAuthLink(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'smartchecklist') {
      return null;
    }

    final route = uri.host.isNotEmpty
        ? uri.host
        : uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : '';
    final flow = switch (route) {
      'activate-account' => 'activation',
      'reset-password' => 'password_reset',
      _ => null,
    };

    final email = uri.queryParameters['email'] ?? '';
    final otp = uri.queryParameters['otp'] ?? '';
    final token = uri.queryParameters['token'] ?? '';

    if (flow == null || email.isEmpty || otp.isEmpty || token.isEmpty) {
      return null;
    }

    return AuthDeepLink(
      flow: flow,
      email: email,
      otp: otp,
      token: token,
    );
  }
}
