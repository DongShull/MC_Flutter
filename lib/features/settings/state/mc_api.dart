import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 设置域 API 单例。
final settingsApiProvider =
    Provider<SettingsApi>((ref) => SettingsApi(ref.watch(sessionStoreProvider)));

/// 设置域的 API 封装：统一走 McClient（Channel.general），对应 Kotlin McApi.kt
/// 的 auth / playback-policy / app-maintenance 段。
class SettingsApi {
  SettingsApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// 当前服务器基址（给「网页托管」分区拼浏览器 URL 用）。
  String get origin => _session.baseUrl ?? '';

  // ---- 账号 ----

  /// GET /auth/me → SessionView。
  Future<McSession> me() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/auth/me',
    );
    return McSession.fromJson(body);
  }

  /// PUT /auth/profile：改昵称。
  Future<void> updateProfile(String nickname) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general, 'PUT', '$_prefix/auth/profile',
        body: {'nickname': nickname},
      );

  /// PUT /auth/password：改密码（signOutPaired 固定 false，同安卓）。
  Future<void> changePassword(
          {required String oldPassword, required String newPassword}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general, 'PUT', '$_prefix/auth/password',
        body: {
          'oldPassword': oldPassword,
          'old_password': oldPassword,
          'newPassword': newPassword,
          'new_password': newPassword,
          'signOutPaired': false,
          'sign_out_paired': false,
        },
      );

  // TODO(avatar): POST /auth/avatar 需要 multipart 上传，McClient 暂不支持。

  // ---- 设备 ----

  /// GET /auth/devices?all=…；all=true 时连其他用户的播放器一起看（超管）。
  Future<List<LoginDevice>> devices({bool all = false}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/auth/devices',
      query: {'all': all},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LoginDevice.fromJson)
        .toList();
  }

  /// PATCH /auth/devices/{id}：改名。
  Future<void> renameDevice(String id, String name) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general, 'PATCH', '$_prefix/auth/devices/$id',
        body: {'name': name},
      );

  /// DELETE /auth/devices/{id}：注销。
  Future<void> revokeDevice(String id) => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'DELETE', '$_prefix/auth/devices/$id',
      );

  /// POST /auth/devices/cleanup；dryRun=true 只返回「将注销 N 台」预览。
  Future<DeviceCleanupView> cleanupDevices(
      {required int inactiveDays, bool dryRun = false}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'POST', '$_prefix/auth/devices/cleanup',
      body: {
        'inactiveDays': inactiveDays,
        'inactive_days': inactiveDays,
        'all': false,
        'dryRun': dryRun,
        'dry_run': dryRun,
      },
    );
    return DeviceCleanupView.fromJson(body);
  }

  // ---- 播放策略 ----

  /// GET /playback/policy。
  Future<PlaybackPolicy> playbackPolicy() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/playback/policy',
    );
    return PlaybackPolicy.fromJson(body);
  }

  /// PUT /playback/policy（意愿开关全量补丁）。
  Future<void> updatePlaybackPolicy(Map<String, dynamic> patch) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general, 'PUT', '$_prefix/playback/policy',
        body: patch,
      );

  // ---- 维护 ----

  /// GET /app/update/pending → 无更新时信封 data 为 null。
  Future<PendingUpdate?> pendingUpdate() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/app/update/pending',
    );
    return body.isEmpty ? null : PendingUpdate.fromJson(body);
  }

  /// GET /app/update/status。
  Future<UpdateStatus> updateStatus() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/app/update/status',
    );
    return UpdateStatus.fromJson(body);
  }

  /// POST /app/restart：重启服务端。
  Future<void> restartApp() => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/app/restart',
      );

  /// GET /app/storage → 存储用量 + 可清理目录。
  Future<StorageState> storage() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/app/storage',
    );
    return StorageState.fromJson(body);
  }

  /// POST /app/storage/{key}/clean：清理一个登记目录。
  Future<CleanResult> cleanStorage(String key) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'POST', '$_prefix/app/storage/$key/clean',
    );
    return CleanResult.fromJson(body);
  }
}
