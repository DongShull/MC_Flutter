import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// more 域 API 单例。
final moreApiProvider =
    Provider<MoreApi>((ref) => MoreApi(ref.watch(sessionStoreProvider)));

/// more 域的 API 封装：统一走 McClient（Channel.general），对应 Kotlin McApi.kt
/// 的 auth/me / system/notices / app/update/pending / sessions 段。
class MoreApi {
  MoreApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /auth/me → SessionView。
  Future<Map<String, dynamic>?> me() async {
    try {
      return await client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/auth/me',
      );
    } catch (_) {
      return null;
    }
  }

  /// GET /system/notices → Notice 列表。
  Future<List<McNotice>> notices() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/system/notices',
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(McNotice.fromJson)
        .toList();
  }

  /// POST /system/notices/{id}/dismiss。
  Future<void> dismissNotice(int id) => client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '$_prefix/system/notices/$id/dismiss',
      );

  /// GET /app/update/pending → 无更新返回 null。
  Future<Map<String, dynamic>?> pendingUpdate() async {
    try {
      final body = await client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/app/update/pending',
      );
      return body.isEmpty ? null : body;
    } catch (_) {
      return null;
    }
  }

  /// GET /sessions?limit&offset → 对话会话摘要（分页）。
  Future<List<SessionSummary>> sessions(
      {int limit = 20, int offset = 0}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/sessions',
      query: {'limit': limit, 'offset': offset},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SessionSummary.fromJson)
        .toList();
  }

  /// PATCH /sessions/{id}：改标题。
  Future<void> renameSession(String id, String title) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/sessions/$id',
        body: {'title': title},
      );

  /// DELETE /sessions/{id}。
  Future<void> deleteSession(String id) => client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '$_prefix/sessions/$id',
      );

  /// POST /sessions/{id}/fork：从已有上下文创建独立新会话，返回新会话 id。
  Future<String?> forkSession(String id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/sessions/$id/fork',
    );
    final session = body['session'];
    if (session is Map<String, dynamic>) {
      final newId = session['id'];
      if (newId != null) return newId.toString();
    }
    return body['id']?.toString();
  }
}
