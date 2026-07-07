import '../user_authentication/auth_api.dart';

class _NoUserPayloadValue {
  const _NoUserPayloadValue();
}

const _noUserPayloadValue = _NoUserPayloadValue();

class UserApi {
  UserApi({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  final AuthApi _authApi;

  Future<Map<String, dynamic>> getUser({
    required int userId,
    required String accessToken,
  }) async {
    final body = await _authApi.request(
      method: 'GET',
      path: '/users/$userId',
      bearerToken: accessToken,
    );
    return _userFrom(body);
  }

  Future<List<Map<String, dynamic>>> getUsers({
    required String accessToken,
    String? search,
    List<String> roles = const [],
    bool? active,
  }) async {
    final query = <String, List<String>>{
      if (search != null && search.trim().isNotEmpty) 'search': [search.trim()],
      if (roles.isNotEmpty) 'roles': roles,
      if (active != null) 'active': [active.toString()],
    };
    final path = Uri(
      path: '/users',
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    final body = await _authApi.request(
      method: 'GET',
      path: path,
      bearerToken: accessToken,
    );
    final users = body['users'];
    if (users is List) {
      return users
          .whereType<Map>()
          .map((user) => Map<String, dynamic>.from(user))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createUser({
    required String accessToken,
    required String email,
    required String name,
    required String employeeId,
    required String role,
    int? qcId,
  }) async {
    final body = await _authApi.request(
      method: 'POST',
      path: '/users',
      payload: {
        'email': email,
        'name': name,
        'employee_id': employeeId,
        'role': role,
        'qc_id': ?qcId,
      },
      bearerToken: accessToken,
    );
    return _userFrom(body);
  }

  Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String accessToken,
    String? email,
    String? employeeId,
    String? name,
    String? role,
    String? profilePic,
    Object? qcId = _noUserPayloadValue,
    bool? active,
    bool? isEmailVerified,
  }) async {
    final payload = <String, dynamic>{
      'email': ?email,
      'employee_id': ?employeeId,
      'name': ?name,
      'role': ?role,
      'profile_pic': ?profilePic,
      if (qcId != _noUserPayloadValue) 'qc_id': qcId,
      'active': ?active,
      'is_email_verified': ?isEmailVerified,
    };
    final body = await _authApi.request(
      method: 'PATCH',
      path: '/users/$userId',
      payload: payload,
      bearerToken: accessToken,
    );
    return _userFrom(body);
  }

  Map<String, dynamic> _userFrom(Map<String, dynamic> body) {
    final user = body['user'];
    if (user is Map<String, dynamic>) {
      return user;
    }
    return <String, dynamic>{};
  }
}
