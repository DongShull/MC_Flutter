import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 设置域 API 单例。
final settingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(
    ref.watch(sessionStoreProvider),
    client: ref.watch(mcClientProvider),
  ),
);

/// 设置域 API 封装（统一走 McClient / Channel.general，严格对齐 iOS Endpoints.swift）。
class SettingsApi {
  SettingsApi(this._session, {McClient? client}) : _client = client;

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  // ---- 账号 ----

  /// GET /api/v1/auth/me → SessionView（同时返回原始 JSON 供同步权限快照）。
  Future<({McSession session, Map<String, dynamic> raw})> meWithRaw() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/auth/me',
    );
    return (session: McSession.fromJson(body), raw: body);
  }

  Future<McSession> me() async => (await meWithRaw()).session;

  /// PUT /api/v1/auth/profile：改昵称。
  Future<Map<String, dynamic>> updateProfile(String nickname) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '$_prefix/auth/profile',
        body: {'nickname': nickname},
      );

  /// PUT /api/v1/auth/password：改密码（支持同时注销配对设备）。
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    bool signOutPaired = false,
  }) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '$_prefix/auth/password',
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'sign_out_paired': signOutPaired,
        },
      );

  /// POST /api/v1/auth/avatar（multipart）。
  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final res = await client.postMultipart<dynamic>(
      Channel.general,
      '$_prefix/auth/avatar',
      fileField: 'file',
      filePath: filePath,
    );
    return res is Map
        ? Map<String, dynamic>.from(res)
        : const <String, dynamic>{};
  }

  /// DELETE /api/v1/playback/history?scope=all：清空当前账号播放记录。
  Future<String?> clearPlaybackHistory() async {
    final res = await client.raw<Map<String, dynamic>>(
      Channel.general,
      'DELETE',
      '$_prefix/playback/history',
      query: const {'scope': 'all'},
    );
    final msg = res['message']?.toString().trim();
    return (msg != null && msg.isNotEmpty) ? msg : null;
  }

  // ---- 设备 ----

  /// GET /api/v1/auth/devices?all=…
  Future<List<LoginDevice>> devices({bool all = false}) async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/auth/devices',
      query: {'all': all},
    );
    final list = body is List
        ? body
        : (body is Map
            ? (body['items'] ?? body['devices'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    return list
        .whereType<Map>()
        .map((e) => LoginDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// PATCH /api/v1/auth/devices/{id}：改名。
  Future<void> renameDevice(String id, String name) =>
      client.unwrap<dynamic>(
        Channel.general,
        'PATCH',
        '$_prefix/auth/devices/${Uri.encodeComponent(id)}',
        body: {'name': name},
      );

  /// DELETE /api/v1/auth/devices/{id}：注销。
  Future<void> revokeDevice(String id) => client.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '$_prefix/auth/devices/${Uri.encodeComponent(id)}',
      );

  /// POST /api/v1/auth/devices/cleanup；dryRun=true 只返回「将注销 N 台」预览。
  Future<DeviceCleanupView> cleanupDevices({
    required int inactiveDays,
    bool all = false,
    bool dryRun = false,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/auth/devices/cleanup',
      body: {
        'inactive_days': inactiveDays,
        'all': all,
        'dry_run': dryRun,
      },
    );
    return DeviceCleanupView.fromJson(body);
  }

  // ---- 播放策略 ----

  /// GET /api/v1/playback/policy。
  Future<PlaybackPolicy> playbackPolicy() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/policy',
    );
    return PlaybackPolicy.fromJson(body);
  }

  /// PUT /api/v1/playback/policy。
  Future<PlaybackPolicy> updatePlaybackPolicy(
    Map<String, dynamic> patch,
  ) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '$_prefix/playback/policy',
      body: patch,
    );
    return PlaybackPolicy.fromJson(body);
  }

  // ---- 维护 / 更新 / 存储 ----

  /// GET /api/v1/app/update/pending → 无更新时信封 data 为 null/空。
  Future<PendingUpdate?> pendingUpdate() async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/app/update/pending',
    );
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map.isEmpty) return null;
    final parsed = PendingUpdate.fromJson(map);
    return parsed.hasUpdate ? parsed : null;
  }

  /// GET /api/v1/app/update/status。
  Future<UpdateStatus> updateStatus() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/app/update/status',
    );
    return UpdateStatus.fromJson(body);
  }

  /// POST /api/v1/app/update/check。
  Future<UpdateCheckView> checkUpdate() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/app/update/check',
    );
    return UpdateCheckView.fromJson(body);
  }

  /// POST /api/v1/app/update/apply。
  Future<UpdateProgressView> applyUpdate() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/app/update/apply',
    );
    return UpdateProgressView.fromJson(body);
  }

  /// GET /api/v1/app/update/progress。
  Future<UpdateProgressView> updateProgress() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/app/update/progress',
    );
    return UpdateProgressView.fromJson(body);
  }

  /// POST /api/v1/app/update/model/check。
  Future<ModelUpdateCheckView> checkModelUpdate() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/app/update/model/check',
    );
    return ModelUpdateCheckView.fromJson(body);
  }

  /// POST /api/v1/app/update/model/apply。
  Future<UpdateProgressView> applyModelUpdate() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/app/update/model/apply',
    );
    return UpdateProgressView.fromJson(body);
  }

  /// GET /api/v1/app/update/rollback/options。
  Future<RollbackOptionsView> rollbackOptions() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/app/update/rollback/options',
    );
    return RollbackOptionsView.fromJson(body);
  }

  /// PUT /api/v1/app/update/retention。
  Future<void> setUpdateRetention(int keepVersions) => client.unwrap<dynamic>(
        Channel.general,
        'PUT',
        '$_prefix/app/update/retention',
        body: {'keep_versions': keepVersions},
      );

  /// POST /api/v1/app/update/rollback。
  Future<void> rollbackVersion({
    required String target,
    required bool restoreBackup,
  }) =>
      client.unwrap<dynamic>(
        Channel.general,
        'POST',
        '$_prefix/app/update/rollback',
        body: {
          'target': target,
          'restore_backup': restoreBackup,
        },
      );

  /// POST /api/v1/app/update/last-exit/dismiss。
  Future<void> dismissLastExit() => client.unwrap<dynamic>(
        Channel.general,
        'POST',
        '$_prefix/app/update/last-exit/dismiss',
      );

  /// GET /api/v1/health（重启恢复探测）。
  Future<bool> probeHealth() async {
    try {
      await client.raw<dynamic>(
        Channel.live,
        'GET',
        '$_prefix/health',
        timeout: const Duration(seconds: 3),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/v1/app/restart：重启服务端。
  Future<void> restartApp() => client.unwrap<dynamic>(
        Channel.general,
        'POST',
        '$_prefix/app/restart',
      );

  /// GET /api/v1/app/storage?refresh=… → 存储用量 + 可清理目录。
  Future<StorageState> storage({bool refresh = false}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/app/storage',
      query: refresh ? const {'refresh': true} : null,
    );
    return StorageState.fromJson(body);
  }

  /// POST /api/v1/app/storage/{key}/clean：清理一个登记目录（mode: orphans | all）。
  Future<CleanResult> cleanStorage(String key, {String mode = 'all'}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/app/storage/${Uri.encodeComponent(key)}/clean',
      body: {'mode': mode},
    );
    return CleanResult.fromJson(body);
  }
}
