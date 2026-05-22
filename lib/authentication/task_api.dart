import 'auth_api.dart';

class TaskApi {
  TaskApi({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  final AuthApi _authApi;

  Future<Map<String, dynamic>> createTask({
    required String accessToken,
    required String name,
    required String description,
    required int userId,
    required String location,
    required String recurrenceType,
    required int recurrenceInterval,
    required String? recurrenceUnit,
    required DateTime recurrenceStartAt,
    required int dueInterval,
    required String dueIntervalUnit,
  }) async {
    final body = await _authApi.request(
      method: 'POST',
      path: '/tasks',
      payload: {
        'name': name,
        'description': description,
        'user_id': userId,
        'location': location,
        'recurrence_type': recurrenceType,
        'recurrence_interval': recurrenceInterval,
        'recurrence_unit': recurrenceUnit,
        'recurrence_start_at': recurrenceStartAt.toIso8601String(),
        'due_interval': dueInterval,
        'due_interval_unit': dueIntervalUnit,
        'is_active': true,
      },
      bearerToken: accessToken,
    );
    final task = body['task'];
    if (task is Map<String, dynamic>) {
      return task;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateTask({
    required int taskId,
    required String accessToken,
    required String name,
    required String description,
    required int userId,
    required String location,
    required String recurrenceType,
    required int recurrenceInterval,
    required String? recurrenceUnit,
    required DateTime recurrenceStartAt,
    required int dueInterval,
    required String dueIntervalUnit,
    required bool isActive,
  }) async {
    final body = await _authApi.request(
      method: 'PUT',
      path: '/tasks/$taskId',
      payload: {
        'name': name,
        'description': description,
        'user_id': userId,
        'location': location,
        'recurrence_type': recurrenceType,
        'recurrence_interval': recurrenceInterval,
        'recurrence_unit': recurrenceUnit,
        'recurrence_start_at': recurrenceStartAt.toIso8601String(),
        'due_interval': dueInterval,
        'due_interval_unit': dueIntervalUnit,
        'is_active': isActive,
      },
      bearerToken: accessToken,
    );
    final task = body['task'];
    if (task is Map<String, dynamic>) {
      return task;
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getTasks({
    required String accessToken,
    String? search,
    bool? isActive,
    String? recurrenceType,
  }) async {
    final query = <String, String>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (isActive != null) 'is_active': isActive.toString(),
      if (recurrenceType != null && recurrenceType.isNotEmpty)
        'recurrence_type': recurrenceType,
    };
    final path = Uri(
      path: '/tasks',
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    final body = await _authApi.request(
      method: 'GET',
      path: path,
      bearerToken: accessToken,
    );
    final tasks = body['tasks'];
    if (tasks is List) {
      return tasks
          .whereType<Map>()
          .map((task) => Map<String, dynamic>.from(task))
          .toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> getTaskEntries({
    required int taskId,
    required String accessToken,
    String? status,
    DateTime? dueFrom,
    DateTime? dueTo,
  }) async {
    final query = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (dueFrom != null) 'due_from': dueFrom.toIso8601String(),
      if (dueTo != null) 'due_to': dueTo.toIso8601String(),
    };
    final path = Uri(
      path: '/tasks/$taskId/entries',
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    final body = await _authApi.request(
      method: 'GET',
      path: path,
      bearerToken: accessToken,
    );
    final entries = body['entries'];
    if (entries is List) {
      return entries
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createTaskEntry({
    required int taskId,
    required String accessToken,
    required int userId,
    required DateTime startAt,
    required DateTime dueAt,
  }) async {
    final body = await _authApi.request(
      method: 'POST',
      path: '/tasks/$taskId/entries',
      payload: {
        'user_id': userId,
        'start_at': startAt.toIso8601String(),
        'due_at': dueAt.toIso8601String(),
        'status': 'Pending',
      },
      bearerToken: accessToken,
    );
    final entry = body['entry'];
    if (entry is Map<String, dynamic>) {
      return entry;
    }
    return <String, dynamic>{};
  }
}
