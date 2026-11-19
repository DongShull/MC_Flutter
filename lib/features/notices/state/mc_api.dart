import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 通知中心域 API 单例。
final noticeApiProvider =
    Provider<NoticeApi>((ref) => NoticeApi(ref.watch(sessionStoreProvider)));

/// 通知中心 API：统一走 McClient（Channel.general），
/// 对应 Kotlin McApi.kt 的 GET system/notices / POST system/notices/{id}/dismiss。
class NoticeApi {
  NoticeApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /system/notices → Notice[]
  Future<List<Notice>> notices() async {
    await _session.restore();
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/system/notices',
    );
    return body
        .whereType<Map>()
        .map((e) => Notice.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /system/notices/{id}/dismiss
  Future<void> dismissNotice(int id) async {
    await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'POST', '$_prefix/system/notices/$id/dismiss',
    );
  }
}
