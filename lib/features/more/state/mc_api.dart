import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/mc_error.dart';
import '../../../core/api/models.dart' as core;
import 'models.dart';

/// more 域 API 单例。
final moreApiProvider =
    Provider<MoreApi>((ref) => MoreApi(ref.watch(mcApiProvider)));

/// more 域 API（P1 薄代理）：方法签名与返回的本域模型不变，调用全部委托给
/// 核心层 [McApi]（类型化端点 + freezed 模型），再经 `toJson/fromJson` 转回
/// 本域模型。本文件不再自建 McClient、不再拼路径、不再手写信封解包。
/// 原先的静默 `catch (_) { return null; }` 改为记日志后返回兜底值
/// （[McErrorLog]，见 P1-core.md 静默 catch 统计）。
class MoreApi {
  MoreApi(this._api);

  final McApi _api;

  /// GET /auth/me → SessionView（失败记日志后返回 null，调用方按未登录处理）。
  Future<Map<String, dynamic>?> me() async {
    try {
      return (await _api.me()).toJson();
    } catch (e) {
      McErrorLog.log(e, context: 'more.me');
      return null;
    }
  }

  /// GET /system/notices → Notice 列表。
  Future<List<McNotice>> notices() async => (await _api.notices())
      .map((e) => McNotice.fromJson(e.toJson()))
      .toList();

  /// POST /system/notices/{id}/dismiss。
  Future<void> dismissNotice(int id) => _api.dismissNotice(id);

  /// GET /app/update/pending → 无更新返回 null。
  /// 服务端无更新时信封 data 为 null：McApi 此时抛 network.empty，
  /// 这里按旧语义（无更新）返回 null，不记错；其它错误记日志后返回 null。
  Future<Map<String, dynamic>?> pendingUpdate() async {
    try {
      return (await _api.pendingUpdate()).toJson();
    } on ApiException catch (e) {
      if (e.code == 'network.empty') return null;
      McErrorLog.log(e, context: 'more.pendingUpdate');
      return null;
    } catch (e) {
      McErrorLog.log(e, context: 'more.pendingUpdate');
      return null;
    }
  }

  /// GET /sessions?limit&offset → 对话会话摘要（分页）。
  Future<List<SessionSummary>> sessions(
      {int limit = 20, int offset = 0}) async {
    final items = await _api.sessions(limit: limit, offset: offset);
    return items.map((e) => SessionSummary.fromJson(e.toJson())).toList();
  }

  /// PATCH /sessions/{id}：改标题。
  Future<void> renameSession(String id, String title) =>
      _api.renameSession(id, body: core.SessionRename(title: title));

  /// DELETE /sessions/{id}。
  Future<void> deleteSession(String id) => _api.deleteSession(id);

  /// POST /sessions/{id}/fork：从已有上下文创建独立新会话，返回新会话 id。
  Future<String?> forkSession(String id) async {
    final transcript = await _api.forkSession(id);
    return transcript.session.id;
  }
}
