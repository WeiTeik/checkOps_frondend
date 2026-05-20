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

  Future<Map<String, dynamic>> getUser({
    required int userId,
    required String accessToken,
  }) async {
    final body = await _request(
      method: 'GET',
      path: '/users/$userId',
      bearerToken: accessToken,
    );
    return _userFrom(body);
  }

  Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String accessToken,
    required String name,
    String? profilePic,
  }) async {
    final body = await _request(
      method: 'PATCH',
      path: '/users/$userId',
      payload: {'name': name, 'profile_pic': ?profilePic},
      bearerToken: accessToken,
    );
    return _userFrom(body);
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
    return _request(
      method: 'POST',
      path: path,
      payload: payload,
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic> payload = const <String, dynamic>{},
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
    final decoded = rawBody.isEmpty ? <String, dynamic>{} : jsonDecode(rawBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_errorMessage(decoded));
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _userFrom(Map<String, dynamic> body) {
    final user = body['user'];
    if (user is Map<String, dynamic>) {
      return user;
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
