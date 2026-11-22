import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 通知中心域 API 单例。
final noticeApiProvider = Provider<NoticeApi>((ref) => NoticeApi(
      ref.watch(mcApiProvider),
      ref.watch(sessionStoreProvider),
    ));

/// 通知中心 API（P1 薄代理）：方法签名与返回的本域模型不变，调用全部委托给
/// 核心层 [McApi]（类型化端点 + freezed 模型），再经 `toJson/fromJson` 转回
/// 本域模型。本文件不再自建 McClient、不再拼路径、不再手写信封解包。
/// [notices] 保留旧行为：先 restore 会话再拉取（启动后令牌落盘变化时可接住）。
class NoticeApi {
  NoticeApi(this._api, this._session);

  final McApi _api;
  final SessionStore _session;

  /// GET /system/notices → Notice[]
  Future<List<Notice>> notices() async {
    await _session.restore();
    return (await _api.notices())
        .map((e) => Notice.fromJson(e.toJson()))
        .toList();
  }

  /// POST /system/notices/{id}/dismiss
  Future<void> dismissNotice(int id) => _api.dismissNotice(id);
}
