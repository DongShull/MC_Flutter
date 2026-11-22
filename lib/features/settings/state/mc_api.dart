import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/models.dart' as core;
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 设置域 API 单例。
final settingsApiProvider = Provider<SettingsApi>((ref) => SettingsApi(
      ref.watch(mcApiProvider),
      ref.watch(mcClientProvider),
      ref.watch(sessionStoreProvider),
    ));

/// 设置域 API（P1 薄代理）：方法签名与返回的本域模型不变，调用全部委托给
/// 核心层 [McApi]（类型化端点 + freezed 模型），再经 `toJson/fromJson` 转回
/// 本域模型。本文件不再自建 McClient、不再拼路径、不再手写信封解包。
/// 例外（保持旧语义）：[updatePlaybackPolicy] 的补丁 map 必须原样发
/// （typed round-trip 会丢未知键/补 null），故仍走 [McClient] 直发。
class SettingsApi {
  SettingsApi(this._api, this._client, this._session);

  final McApi _api;
  final McClient _client;
  final SessionStore _session;

  /// 当前服务器基址（给「网页托管」分区拼浏览器 URL 用）。
  String get origin => _session.baseUrl ?? '';

  // ---- 账号 ----

  /// GET /auth/me → SessionView。
  Future<McSession> me() async =>
      McSession.fromJson((await _api.me()).toJson());

  /// PUT /auth/profile：改昵称。
  Future<void> updateProfile(String nickname) => _api.updateProfile(
      body: core.UpdateProfileRequest(nickname: nickname));

  /// PUT /auth/password：改密码（signOutPaired 固定 false，同安卓）。
  Future<void> changePassword(
          {required String oldPassword, required String newPassword}) =>
      _api.changePassword(
          body: core.ChangePasswordRequest(
              oldPassword: oldPassword,
              newPassword: newPassword,
              signOutPaired: false));

  /// POST /auth/avatar（multipart，对齐 Kotlin McApi.uploadAvatar）。
  Future<void> uploadAvatar(String filePath) =>
      _api.uploadAvatar(filePath: filePath);

  // ---- 设备 ----

  /// GET /auth/devices?all=…；all=true 时连其他用户的播放器一起看（超管）。
  Future<List<LoginDevice>> devices({bool all = false}) async =>
      (await _api.devices(all: all))
          .map((e) => LoginDevice.fromJson(e.toJson()))
          .toList();

  /// PATCH /auth/devices/{id}：改名。
  Future<void> renameDevice(String id, String name) =>
      _api.renameDevice(id, body: core.DeviceRenameRequest(name: name));

  /// DELETE /auth/devices/{id}：注销。
  Future<void> revokeDevice(String id) => _api.revokeDevice(id);

  /// POST /auth/devices/cleanup；dryRun=true 只返回「将注销 N 台」预览。
  Future<DeviceCleanupView> cleanupDevices(
      {required int inactiveDays, bool dryRun = false}) async {
    final result = await _api.cleanupDevices(
        body: core.DeviceCleanupRequest(
            inactiveDays: inactiveDays, all: false, dryRun: dryRun));
    return DeviceCleanupView.fromJson(result.toJson());
  }

  // ---- 播放策略 ----

  /// GET /playback/policy。
  Future<PlaybackPolicy> playbackPolicy() async =>
      PlaybackPolicy.fromJson((await _api.playbackPolicy()).toJson());

  /// PUT /playback/policy（意愿开关全量补丁）。
  /// 不走 McApi 的类型化方法：调用方给的是任意补丁 map，原样发；
  /// typed round-trip 会丢未知键并给缺失开关补 null。
  Future<void> updatePlaybackPolicy(Map<String, dynamic> patch) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/playback/policy',
        body: patch,
      );

  // ---- 维护 ----

  /// GET /app/update/pending → 无更新时信封 data 为 null。
  /// McApi 此时抛 network.empty；按旧语义（旧代码把信封整体当默认模型解析）
  /// 返回默认 PendingUpdate，不抛错——MaintenanceController 用 Future.wait
  /// 并行拉三项，一项抛错会拖垮整页。
  Future<PendingUpdate> pendingUpdate() async {
    try {
      return PendingUpdate.fromJson((await _api.pendingUpdate()).toJson());
    } on ApiException catch (e) {
      if (e.code == 'network.empty') return const PendingUpdate();
      rethrow;
    }
  }

  /// GET /app/update/status。
  Future<UpdateStatus> updateStatus() async =>
      UpdateStatus.fromJson((await _api.updateStatus()).toJson());

  /// POST /app/restart：重启服务端。
  Future<void> restartApp() => _api.restartApp();

  /// GET /app/storage → 存储用量 + 可清理目录。
  Future<StorageState> storage() async =>
      StorageState.fromJson((await _api.storageState()).toJson());

  /// POST /app/storage/{key}/clean：清理一个登记目录。
  Future<CleanResult> cleanStorage(String key) async =>
      CleanResult.fromJson((await _api.cleanStorage(key)).toJson());
}
