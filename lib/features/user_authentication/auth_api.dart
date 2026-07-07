import 'dart:convert';
import 'dart:io';

import '../../app_config.dart';

typedef AccessTokenProvider = String? Function();
typedef UnauthorizedTokenHandler =
    Future<String?> Function(String expiredAccessToken);

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({String? baseUrl, HttpClient? client})
    : baseUrl = (baseUrl ?? AppConfig.apiHostname).replaceAll(
        RegExp(r'/$'),
        '',
      ),
      _client = client ?? HttpClient();

  static AccessTokenProvider? accessTokenProvider;
  static UnauthorizedTokenHandler? unauthorizedTokenHandler;

  final String baseUrl;
  final HttpClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> refresh({required String refreshToken}) {
    return _post('/auth/refresh', {'refresh_token': refreshToken});
  }

  Future<String> logout({required String accessToken}) async {
    final body = await _post(
      '/auth/logout',
      const <String, dynamic>{},
      bearerToken: accessToken,
    );
    return _messageFrom(body);
  }

  Future<String> requestPasswordReset(String email) async {
    final body = await _post('/auth/password/request-reset', {'email': email});
    return _messageFrom(body);
  }

  Future<String> resendPasswordReset(String email) async {
    final body = await _post('/auth/password/resend-reset', {'email': email});
    return _messageFrom(body);
  }

  Future<String> resendActivation(String email) async {
    final body = await _post('/auth/email/resend-activation', {'email': email});
    return _messageFrom(body);
  }

  Future<Map<String, dynamic>> validateLink({
    required String email,
    required String token,
    required String type,
  }) {
    return _post('/auth/validate-link', {
      'email': email,
      'token': token,
      'type': type,
    });
  }

  Future<String> setPasswordFromActivation({
    required String email,
    required String otp,
    required String token,
    required String password,
  }) async {
    final body = await _post('/auth/email/set-password', {
      'email': email,
      'otp': otp,
      'token': token,
      'password': password,
    });
    return _messageFrom(body);
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String token,
    required String password,
  }) async {
    final body = await _post('/auth/password/reset', {
      'email': email,
      'otp': otp,
      'token': token,
      'password': password,
    });
    return _messageFrom(body);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    String? bearerToken,
  }) async {
    return request(
      method: 'POST',
      path: path,
      payload: payload,
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? bearerToken,
  }) async {
    final effectiveBearerToken = bearerToken == null
        ? null
        : accessTokenProvider?.call() ?? bearerToken;
    final response = await _sendRequest(
      method: method,
      path: path,
      payload: payload,
      bearerToken: effectiveBearerToken,
    );

    if (response.statusCode == HttpStatus.unauthorized &&
        effectiveBearerToken != null &&
        effectiveBearerToken.isNotEmpty) {
      final nextBearerToken = await unauthorizedTokenHandler?.call(
        effectiveBearerToken,
      );
      if (nextBearerToken != null && nextBearerToken.isNotEmpty) {
        final retryResponse = await _sendRequest(
          method: method,
          path: path,
          payload: payload,
          bearerToken: nextBearerToken,
        );
        return _decodeResponse(retryResponse);
      }
    }

    return _decodeResponse(response);
  }

  Future<_AuthApiResponse> _sendRequest({
    required String method,
    required String path,
    required Map<String, dynamic> payload,
    String? bearerToken,
  }) async {
    final request = await _client.openUrl(method, Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    if (bearerToken != null && bearerToken.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $bearerToken',
      );
    }
    if (method != 'GET') {
      request.write(jsonEncode(payload));
    }

    final response = await request.close();
    final rawBody = await response.transform(utf8.decoder).join();
    return _AuthApiResponse(statusCode: response.statusCode, body: rawBody);
  }

  Map<String, dynamic> _decodeResponse(_AuthApiResponse response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        _errorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  String _messageFrom(Map<String, dynamic> body) {
    return body['message']?.toString() ?? 'Done.';
  }

  String _errorMessage(Object decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        return detail.first.toString();
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

class _AuthApiResponse {
  const _AuthApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
