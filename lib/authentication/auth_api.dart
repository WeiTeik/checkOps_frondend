import 'dart:convert';
import 'dart:io';

import '../app_config.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message);

  final String message;

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

  final String baseUrl;
  final HttpClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _post('/auth/login', {'email': email, 'password': password});
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
    Map<String, dynamic> payload,
  ) async {
    final request = await _client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));

    final response = await request.close();
    final rawBody = await response.transform(utf8.decoder).join();
    final decoded = rawBody.isEmpty ? <String, dynamic>{} : jsonDecode(rawBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_errorMessage(decoded));
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
