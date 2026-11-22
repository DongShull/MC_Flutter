import 'mc_client.dart';
import 'models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_providers.dart';

/// 类型化服务端 API：方法/路径/参数对照安卓端 Retrofit 接口
/// `apps/android/app/.../core/api/McApi.kt`（283 个）与生成版
/// `apps/android-core/network/.../generated/McApi.kt` 独有的 26 个，
/// 共 309 个端点，由生成脚本机械转写。
///
/// - 路径相对 origin：`/api/v1/<path>`（`/health` 亦然，见服务端挂载）。
/// - 响应模型：`models.dart` 的 freezed 模型（字段源自 Kotlin data class）；
///   未建模的载荷返回 `Map<String, dynamic>` / `List<Map<String, dynamic>>`，
///   待 P2 逐步提升为模型。`@Body` 同理：已建模的请求用模型，其余用 Map。
/// - 通道：默认 [Channel.general]；`playback/*` 走 [Channel.live]。
/// - 播放器实现不在此：播放会话/进度等端点只暴露调用面（P1-player 负责实现）。

/// 全 App 唯一的 [McApi]（经 [mcClientProvider] 共享会话/McClient）。
final mcApiProvider = Provider<McApi>((ref) => McApi(ref.watch(mcClientProvider)));

class McApi {
  McApi(this._client);

  final McClient _client;

  static const _prefix = '/api/v1';

  // ── health ──

  /// `GET /api/v1/health`（Kotlin `health`，retrofit）。
  Future<HealthView> health() async {
    final res = await _client.get(Channel.general, '$_prefix/health');
    final data = res.data ?? {};
    return HealthView.fromJson(data);
  }

  // ── auth ──

  /// `GET /api/v1/auth/bootstrap`（Kotlin `bootstrapStatus`，retrofit）。
  Future<BootstrapStatus> bootstrapStatus() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/auth/bootstrap');
    return BootstrapStatus.fromJson(data);
  }

  /// `POST /api/v1/auth/bootstrap`（Kotlin `bootstrapCreate`，retrofit）。
  Future<SessionView> bootstrapCreate({required CreateAdminRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/auth/bootstrap', body: body.toJson());
    return SessionView.fromJson(data);
  }

  /// `POST /api/v1/auth/device/login`（Kotlin `deviceLogin`，retrofit）。
  Future<DeviceLoginView> deviceLogin({required DeviceLoginRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/auth/device/login', body: body.toJson());
    return DeviceLoginView.fromJson(data);
  }

  /// `GET /api/v1/auth/me`（Kotlin `me`，retrofit）。
  Future<SessionView> me() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/auth/me');
    return SessionView.fromJson(data);
  }

  /// `PUT /api/v1/auth/profile`（Kotlin `updateProfile`，retrofit）。
  Future<SessionView> updateProfile({required UpdateProfileRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/auth/profile', body: body.toJson());
    return SessionView.fromJson(data);
  }

  /// `PUT /api/v1/auth/password`（Kotlin `changePassword`，retrofit）。
  Future<SessionView> changePassword({required ChangePasswordRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/auth/password', body: body.toJson());
    return SessionView.fromJson(data);
  }

  /// `POST /api/v1/auth/avatar`（Kotlin `uploadAvatar`，retrofit）。
  Future<dynamic> uploadAvatar({required String filePath}) async {
    await _client.postMultipart<dynamic>(Channel.general, '$_prefix/auth/avatar', fileField: 'file', filePath: filePath);
  }

  /// `GET /api/v1/auth/devices`（Kotlin `devices`，retrofit）。
  Future<List<LoginDevice>> devices({bool? all}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/auth/devices', query: {if (all != null) 'all': all});
    return items.whereType<Map<String, dynamic>>().map(LoginDevice.fromJson).toList();
  }

  /// `POST /api/v1/auth/devices/cleanup`（Kotlin `cleanupDevices`，retrofit）。
  Future<DeviceCleanupView> cleanupDevices({required DeviceCleanupRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/auth/devices/cleanup', body: body.toJson());
    return DeviceCleanupView.fromJson(data);
  }

  /// `PATCH /api/v1/auth/devices/{deviceId}`（Kotlin `renameDevice`，retrofit）。
  Future<dynamic> renameDevice(String deviceId, {required DeviceRenameRequest body}) async {
    return _client.unwrapDynamic(Channel.general, 'PATCH', '$_prefix/auth/devices/$deviceId', body: body.toJson());
  }

  /// `DELETE /api/v1/auth/devices/{deviceId}`（Kotlin `revokeDevice`，retrofit）。
  Future<dynamic> revokeDevice(String deviceId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/auth/devices/$deviceId');
  }

  /// `GET /api/v1/auth/devices/requests/{userCode}`（Kotlin `deviceRequest`，retrofit）。
  Future<DeviceRequestView> deviceRequest(String userCode) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/auth/devices/requests/$userCode');
    return DeviceRequestView.fromJson(data);
  }

  /// `POST /api/v1/auth/devices/requests/{userCode}/approve`（Kotlin `approveDeviceRequest`，retrofit）。
  Future<dynamic> approveDeviceRequest(String userCode) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/auth/devices/requests/$userCode/approve');
  }

  /// `POST /api/v1/auth/devices/requests/{userCode}/deny`（Kotlin `denyDeviceRequest`，retrofit）。
  Future<dynamic> denyDeviceRequest(String userCode) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/auth/devices/requests/$userCode/deny');
  }

  /// `DELETE /api/v1/auth/devices/current`（Kotlin `logoutCurrentDevice`，retrofit）。
  Future<dynamic> logoutCurrentDevice() async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/auth/devices/current');
  }

  /// `POST /api/v1/auth/device/authorize`（Kotlin `authDeviceAuthorize`，generated）。
  Future<DeviceAuthorizeView> authDeviceAuthorize({required DeviceAuthorizeRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/auth/device/authorize', body: body.toJson());
    return DeviceAuthorizeView.fromJson(data);
  }

  /// `POST /api/v1/auth/device/token`（Kotlin `authDeviceToken`，generated）。
  Future<Map<String, dynamic>> authDeviceToken({required DeviceTokenRequest body}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'POST', '$_prefix/auth/device/token', body: body.toJson());
  }

  // ── app ──

  /// `GET /api/v1/app/update/pending`（Kotlin `pendingUpdate`，retrofit）。
  Future<PendingUpdate> pendingUpdate() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/update/pending');
    return PendingUpdate.fromJson(data);
  }

  /// `GET /api/v1/app/update/status`（Kotlin `updateStatus`，retrofit）。
  Future<UpdateStatus> updateStatus() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/update/status');
    return UpdateStatus.fromJson(data);
  }

  /// `POST /api/v1/app/update/check`（Kotlin `checkUpdate`，retrofit）。
  Future<UpdateCheck> checkUpdate() async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/app/update/check');
    return UpdateCheck.fromJson(data);
  }

  /// `POST /api/v1/app/update/last-exit/dismiss`（Kotlin `dismissLastAbnormalExit`，retrofit）。
  Future<dynamic> dismissLastAbnormalExit() async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/app/update/last-exit/dismiss');
  }

  /// `POST /api/v1/app/update/apply`（Kotlin `applyUpdate`，retrofit）。
  Future<UpdateProgress> applyUpdate() async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/app/update/apply');
    return UpdateProgress.fromJson(data);
  }

  /// `GET /api/v1/app/update/progress`（Kotlin `updateProgress`，retrofit）。
  Future<UpdateProgress> updateProgress() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/update/progress');
    return UpdateProgress.fromJson(data);
  }

  /// `GET /api/v1/app/update/rollback/options`（Kotlin `rollbackOptions`，retrofit）。
  Future<RollbackOptions> rollbackOptions() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/update/rollback/options');
    return RollbackOptions.fromJson(data);
  }

  /// `POST /api/v1/app/update/rollback`（Kotlin `rollbackTo`，retrofit）。
  Future<dynamic> rollbackTo({required RollbackRequest body}) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/app/update/rollback', body: body.toJson());
  }

  /// `PUT /api/v1/app/update/retention`（Kotlin `saveUpdateRetention`，retrofit）。
  Future<dynamic> saveUpdateRetention({required RetentionRequest body}) async {
    return _client.unwrapDynamic(Channel.general, 'PUT', '$_prefix/app/update/retention', body: body.toJson());
  }

  /// `GET /api/v1/app/update/github-token`（Kotlin `githubToken`，retrofit）。
  Future<GithubToken> githubToken() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/update/github-token');
    return GithubToken.fromJson(data);
  }

  /// `PUT /api/v1/app/update/github-token`（Kotlin `saveGithubToken`，retrofit）。
  Future<GithubToken> saveGithubToken({required GithubTokenPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/app/update/github-token', body: body.toJson());
    return GithubToken.fromJson(data);
  }

  /// `POST /api/v1/app/update/model/check`（Kotlin `checkModelUpdate`，retrofit）。
  Future<ModelUpdateCheck> checkModelUpdate() async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/app/update/model/check');
    return ModelUpdateCheck.fromJson(data);
  }

  /// `POST /api/v1/app/update/model/apply`（Kotlin `applyModelUpdate`，retrofit）。
  Future<UpdateProgress> applyModelUpdate() async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/app/update/model/apply');
    return UpdateProgress.fromJson(data);
  }

  /// `POST /api/v1/app/restart`（Kotlin `restartApp`，retrofit）。
  Future<dynamic> restartApp() async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/app/restart');
  }

  /// `GET /api/v1/app/storage`（Kotlin `storageState`，retrofit）。
  Future<StorageState> storageState() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/storage');
    return StorageState.fromJson(data);
  }

  /// `POST /api/v1/app/storage/{key}/clean`（Kotlin `cleanStorage`，retrofit）。
  Future<CleanResult> cleanStorage(String key) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/app/storage/$key/clean');
    return CleanResult.fromJson(data);
  }

  /// `GET /api/v1/app/config`（Kotlin `appConfigShow`，retrofit）。
  Future<AppConfig> appConfigShow() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/config');
    return AppConfig.fromJson(data);
  }

  /// `PUT /api/v1/app/config`（Kotlin `appConfigSave`，retrofit）。
  Future<AppConfig> appConfigSave({required AppConfigPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/app/config', body: body.toJson());
    return AppConfig.fromJson(data);
  }

  /// `PUT /api/v1/app/port`（Kotlin `appPortSave`，retrofit）。
  Future<AppConfig> appPortSave({required WebPortPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/app/port', body: body.toJson());
    return AppConfig.fromJson(data);
  }

  /// `GET /api/v1/app/clients/{product}/latest`（Kotlin `appClientsLatest`，generated）。
  Future<ClientReleaseView> appClientsLatest(String product, {bool? refresh}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/app/clients/$product/latest', query: {if (refresh != null) 'refresh': refresh});
    return ClientReleaseView.fromJson(data);
  }

  // ── offline ──

  /// `GET /api/v1/offline/manifest`（Kotlin `offlineManifest`，retrofit）。
  Future<OfflineManifest> offlineManifest({int? fileId}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/offline/manifest', query: {if (fileId != null) 'file_id': fileId});
    return OfflineManifest.fromJson(data);
  }

  /// `POST /api/v1/offline/profiles`（Kotlin `offlineProfiles`，retrofit）。
  Future<OfflineProfilesView> offlineProfiles({required OfflineProfilesRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/offline/profiles', body: body.toJson());
    return OfflineProfilesView.fromJson(data);
  }

  /// `POST /api/v1/offline/exports`（Kotlin `offlineExportCreate`，retrofit）。
  Future<OfflineExport> offlineExportCreate({required OfflineExportRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/offline/exports', body: body.toJson());
    return OfflineExport.fromJson(data);
  }

  /// `GET /api/v1/offline/exports/{exportId}`（Kotlin `offlineExportGet`，retrofit）。
  Future<OfflineExport> offlineExportGet(String exportId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/offline/exports/$exportId');
    return OfflineExport.fromJson(data);
  }

  /// `DELETE /api/v1/offline/exports/{exportId}`（Kotlin `offlineExportRelease`，retrofit）。
  Future<Map<String, dynamic>> offlineExportRelease(String exportId) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'DELETE', '$_prefix/offline/exports/$exportId');
  }

  // ── playback ──

  /// `POST /api/v1/playback/viewings`（Kotlin `playbackViewings`，retrofit）。
  Future<OfflineViewingsView> playbackViewings({required OfflineViewingsRequest body}) async {
    final data = await _client.unwrapModel(Channel.live, 'POST', '$_prefix/playback/viewings', body: body.toJson());
    return OfflineViewingsView.fromJson(data);
  }

  /// `GET /api/v1/playback/policy`（Kotlin `playbackPolicy`，retrofit）。
  Future<PlaybackPolicy> playbackPolicy() async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/policy');
    return PlaybackPolicy.fromJson(data);
  }

  /// `PUT /api/v1/playback/policy`（Kotlin `updatePlaybackPolicy`，retrofit）。
  Future<PlaybackPolicy> updatePlaybackPolicy({required PlaybackPolicyPatchFull body}) async {
    final data = await _client.unwrapModel(Channel.live, 'PUT', '$_prefix/playback/policy', body: body.toJson());
    return PlaybackPolicy.fromJson(data);
  }

  /// `GET /api/v1/playback/items/{mediaItemId}`（Kotlin `playbackItem`，retrofit）。
  Future<PlaybackItemView> playbackItem(int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/items/$mediaItemId');
    return PlaybackItemView.fromJson(data);
  }

  /// `GET /api/v1/playback/up-next`（Kotlin `upNext`，retrofit）。
  Future<UpNextView> upNext({int? limit}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/up-next', query: {if (limit != null) 'limit': limit});
    return UpNextView.fromJson(data);
  }

  /// `GET /api/v1/playback/favorites`（Kotlin `favorites`，retrofit）。
  Future<FavoritesPageView> favorites({int? limit, int? offset, bool? unwatchedFirst, String? sort, String? order}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/favorites', query: {if (limit != null) 'limit': limit, if (offset != null) 'offset': offset, if (unwatchedFirst != null) 'unwatched_first': unwatchedFirst, if (sort != null) 'sort': sort, if (order != null) 'order': order});
    return FavoritesPageView.fromJson(data);
  }

  /// `GET /api/v1/playback/favorites/gallery`（Kotlin `favoritesGallery`，retrofit）。
  Future<List<LibraryGalleryGroupView>> favoritesGallery({int? limit, int? offset, String? sort, String? order}) async {
    final items = await _client.unwrapList(Channel.live, 'GET', '$_prefix/playback/favorites/gallery', query: {if (limit != null) 'limit': limit, if (offset != null) 'offset': offset, if (sort != null) 'sort': sort, if (order != null) 'order': order});
    return items.whereType<Map<String, dynamic>>().map(LibraryGalleryGroupView.fromJson).toList();
  }

  /// `DELETE /api/v1/playback/history`（Kotlin `clearPlaybackHistory`，retrofit）。
  Future<HistoryClearView> clearPlaybackHistory({String? scope, int? mediaItemId, int? libraryId}) async {
    final data = await _client.unwrapModel(Channel.live, 'DELETE', '$_prefix/playback/history', query: {if (scope != null) 'scope': scope, if (mediaItemId != null) 'media_item_id': mediaItemId, if (libraryId != null) 'library_id': libraryId});
    return HistoryClearView.fromJson(data);
  }

  /// `GET /api/v1/playback/marks`（Kotlin `playbackMarks`，retrofit）。
  Future<PlaybackMarks> playbackMarks({int? mediaItemId, int? seasonNumber, int? episodeNumber}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/marks', query: {if (mediaItemId != null) 'media_item_id': mediaItemId, if (seasonNumber != null) 'season_number': seasonNumber, if (episodeNumber != null) 'episode_number': episodeNumber});
    return PlaybackMarks.fromJson(data);
  }

  /// `POST /api/v1/playback/marks`（Kotlin `setPlaybackMarks`，retrofit）。
  Future<PlaybackMarks> setPlaybackMarks({required PlaybackMarksRequest body}) async {
    final data = await _client.unwrapModel(Channel.live, 'POST', '$_prefix/playback/marks', body: body.toJson());
    return PlaybackMarks.fromJson(data);
  }

  /// `GET /api/v1/playback/stats/watch`（Kotlin `playbackWatchStats`，retrofit）。
  Future<PlaybackWatchStatsView> playbackWatchStats({int? days, int? tzOffsetMinutes, String? scope, int? memberId}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/stats/watch', query: {if (days != null) 'days': days, if (tzOffsetMinutes != null) 'tz_offset': tzOffsetMinutes, if (scope != null) 'scope': scope, if (memberId != null) 'member_id': memberId});
    return PlaybackWatchStatsView.fromJson(data);
  }

  /// `GET /api/v1/playback/history`（Kotlin `playbackHistory`，retrofit）。
  Future<PlaybackHistoryView> playbackHistory({int? limit, int? before}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/history', query: {if (limit != null) 'limit': limit, if (before != null) 'before': before});
    return PlaybackHistoryView.fromJson(data);
  }

  /// `GET /api/v1/playback/resume`（Kotlin `resumeState`，retrofit）。
  Future<PlaybackStateView> resumeState({int? mediaItemId, int? seasonNumber, int? episodeNumber}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/resume', query: {if (mediaItemId != null) 'media_item_id': mediaItemId, if (seasonNumber != null) 'season_number': seasonNumber, if (episodeNumber != null) 'episode_number': episodeNumber});
    return PlaybackStateView.fromJson(data);
  }

  /// `GET /api/v1/playback/activity`（Kotlin `playbackActivity`，retrofit）。
  Future<PlaybackActivityView> playbackActivity({String? scope}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/activity', query: {if (scope != null) 'scope': scope});
    return PlaybackActivityView.fromJson(data);
  }

  /// `POST /api/v1/playback/activity/sessions/{deviceId}/end`（Kotlin `endPlaybackSession`，retrofit）。
  Future<dynamic> endPlaybackSession(String deviceId) async {
    return _client.unwrapDynamic(Channel.live, 'POST', '$_prefix/playback/activity/sessions/$deviceId/end');
  }

  /// `DELETE /api/v1/playback/devices/{deviceId}`（Kotlin `revokePlaybackDevice`，retrofit）。
  Future<dynamic> revokePlaybackDevice(String deviceId) async {
    return _client.unwrapDynamic(Channel.live, 'DELETE', '$_prefix/playback/devices/$deviceId');
  }

  /// `POST /api/v1/playback/decide`（Kotlin `playbackDecide`，generated）。
  Future<PlaybackDecisionView> playbackDecide({required PlaybackDecideRequest body}) async {
    final data = await _client.unwrapModel(Channel.live, 'POST', '$_prefix/playback/decide', body: body.toJson());
    return PlaybackDecisionView.fromJson(data);
  }

  /// `POST /api/v1/playback/sessions`（Kotlin `playbackSessionStart`，generated）。
  Future<PlaybackSessionView> playbackSessionStart({required PlaybackSessionRequest body}) async {
    final data = await _client.unwrapModel(Channel.live, 'POST', '$_prefix/playback/sessions', body: body.toJson());
    return PlaybackSessionView.fromJson(data);
  }

  /// `POST /api/v1/playback/sessions/{sessionId}/ping`（Kotlin `playbackSessionPing`，generated）。
  Future<Map<String, dynamic>> playbackSessionPing(String sessionId) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.live, 'POST', '$_prefix/playback/sessions/$sessionId/ping');
  }

  /// `DELETE /api/v1/playback/sessions/{sessionId}`（Kotlin `playbackSessionStop`，generated）。
  Future<Map<String, dynamic>> playbackSessionStop(String sessionId) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.live, 'DELETE', '$_prefix/playback/sessions/$sessionId');
  }

  /// `POST /api/v1/playback/progress`（Kotlin `playbackProgress`，generated）。
  Future<PlaybackStateView> playbackProgress({required PlaybackProgressRequest body}) async {
    final data = await _client.unwrapModel(Channel.live, 'POST', '$_prefix/playback/progress', body: body.toJson());
    return PlaybackStateView.fromJson(data);
  }

  /// `PUT /api/v1/playback/auto-skip/intro/{mediaItemId}`（Kotlin `playbackAutoSkipIntroSet`，generated）。
  Future<void> playbackAutoSkipIntroSet(int mediaItemId, {required PlaybackAutoSkipRequest body}) async {
    await _client.unwrapDynamic(Channel.live, 'PUT', '$_prefix/playback/auto-skip/intro/$mediaItemId', body: body.toJson());
  }

  /// `GET /api/v1/playback/items/{mediaItemId}/episodes`（Kotlin `playbackItemEpisodes`，generated）。
  Future<SeasonEpisodesView> playbackItemEpisodes(int mediaItemId, {int? seasonNumber}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/items/$mediaItemId/episodes', query: {if (seasonNumber != null) 'seasonNumber': seasonNumber});
    return SeasonEpisodesView.fromJson(data);
  }

  /// `GET /api/v1/playback/files/{fileId}/trickplay`（Kotlin `playbackFileTrickplay`，generated）。
  Future<TrickplayView> playbackFileTrickplay(int fileId, {String? token}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/files/$fileId/trickplay', query: {if (token != null) 'token': token});
    return TrickplayView.fromJson(data);
  }

  /// `GET /api/v1/playback/files/{fileId}/bluray`（Kotlin `playbackFileBluray`，generated）。
  Future<PlaybackBlurayView> playbackFileBluray(int fileId, {String? token}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/files/$fileId/bluray', query: {if (token != null) 'token': token});
    return PlaybackBlurayView.fromJson(data);
  }

  /// `POST /api/v1/playback/client-log`（Kotlin `playbackClientLog`，generated）。
  Future<Map<String, dynamic>> playbackClientLog({required PlaybackClientLogPayload body}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.live, 'POST', '$_prefix/playback/client-log', body: body.toJson());
  }

  /// `POST /api/v1/playback/metrics`（Kotlin `playbackMetricReport`，generated）。
  Future<Map<String, dynamic>> playbackMetricReport({required PlaybackMetricPayload body}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.live, 'POST', '$_prefix/playback/metrics', body: body.toJson());
  }

  /// `GET /api/v1/playback/sessions/{sessionId}/diagnostics`（Kotlin `playbackSessionDiagnostics`，generated）。
  Future<PlaybackDiagnosticsView> playbackSessionDiagnostics(String sessionId, {String? token}) async {
    final data = await _client.unwrapModel(Channel.live, 'GET', '$_prefix/playback/sessions/$sessionId/diagnostics', query: {if (token != null) 'token': token});
    return PlaybackDiagnosticsView.fromJson(data);
  }

  // ── server ──

  /// `GET /api/v1/server/addresses`（Kotlin `serverAddresses`，retrofit）。
  Future<ServerAddressesView> serverAddresses() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/server/addresses');
    return ServerAddressesView.fromJson(data);
  }

  // ── scheduled-tasks ──

  /// `GET /api/v1/scheduled-tasks`（Kotlin `scheduledTasks`，retrofit）。
  Future<List<ScheduledTask>> scheduledTasks() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/scheduled-tasks');
    return items.whereType<Map<String, dynamic>>().map(ScheduledTask.fromJson).toList();
  }

  /// `PUT /api/v1/scheduled-tasks/{key}`（Kotlin `updateScheduledTask`，retrofit）。
  Future<ScheduledTask> updateScheduledTask(String key, {required ScheduledTaskUpdate body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/scheduled-tasks/$key', body: body.toJson());
    return ScheduledTask.fromJson(data);
  }

  // ── system ──

  /// `GET /api/v1/system/logs`（Kotlin `logDays`，retrofit）。
  Future<LogDayList> logDays() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/system/logs');
    return LogDayList.fromJson(data);
  }

  /// `GET /api/v1/system/logs/{day}`（Kotlin `logContent`，retrofit）。
  Future<LogContent> logContent(String day) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/system/logs/$day');
    return LogContent.fromJson(data);
  }

  /// `GET /api/v1/system/notices`（Kotlin `notices`，retrofit）。
  Future<List<Notice>> notices() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/system/notices');
    return items.whereType<Map<String, dynamic>>().map(Notice.fromJson).toList();
  }

  /// `POST /api/v1/system/notices/{noticeId}/dismiss`（Kotlin `dismissNotice`，retrofit）。
  Future<dynamic> dismissNotice(int noticeId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/system/notices/$noticeId/dismiss');
  }

  // ── fs ──

  /// `GET /api/v1/fs/browse`（Kotlin `fsBrowse`，retrofit）。
  Future<FsBrowseView> fsBrowse({String? path}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/fs/browse', query: {if (path != null) 'path': path});
    return FsBrowseView.fromJson(data);
  }

  // ── network ──

  /// `GET /api/v1/network/config`（Kotlin `networkConfig`，retrofit）。
  Future<NetworkConfig> networkConfig() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/network/config');
    return NetworkConfig.fromJson(data);
  }

  /// `PUT /api/v1/network/config`（Kotlin `saveNetworkConfig`，retrofit）。
  Future<NetworkConfig> saveNetworkConfig({required NetworkConfig body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/network/config', body: body.toJson());
    return NetworkConfig.fromJson(data);
  }

  /// `POST /api/v1/network/test`（Kotlin `testNetwork`，retrofit）。
  Future<NetworkTestResult> testNetwork({required NetworkTestPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/network/test', body: body.toJson());
    return NetworkTestResult.fromJson(data);
  }

  // ── members ──

  /// `GET /api/v1/members`（Kotlin `members`，retrofit）。
  Future<List<MemberView>> members() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/members');
    return items.whereType<Map<String, dynamic>>().map(MemberView.fromJson).toList();
  }

  /// `POST /api/v1/members`（Kotlin `createMember`，retrofit）。
  Future<MemberView> createMember({required MemberCreateRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/members', body: body.toJson());
    return MemberView.fromJson(data);
  }

  /// `PUT /api/v1/members/{memberId}`（Kotlin `updateMember`，retrofit）。
  Future<MemberView> updateMember(int memberId, {required MemberUpdateRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/members/$memberId', body: body.toJson());
    return MemberView.fromJson(data);
  }

  /// `PUT /api/v1/members/{memberId}/status`（Kotlin `setMemberStatus`，retrofit）。
  Future<MemberView> setMemberStatus(int memberId, {required MemberStatusRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/members/$memberId/status', body: body.toJson());
    return MemberView.fromJson(data);
  }

  /// `POST /api/v1/members/{memberId}/reset-password`（Kotlin `resetMemberPassword`，retrofit）。
  Future<MemberPasswordReset> resetMemberPassword(int memberId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/members/$memberId/reset-password');
    return MemberPasswordReset.fromJson(data);
  }

  /// `POST /api/v1/members/{memberId}/sign-out`（Kotlin `signOutMember`，retrofit）。
  Future<dynamic> signOutMember(int memberId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/members/$memberId/sign-out');
  }

  /// `DELETE /api/v1/members/{memberId}`（Kotlin `deleteMember`，retrofit）。
  Future<dynamic> deleteMember(int memberId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/members/$memberId');
  }

  // ── libraries ──

  /// `GET /api/v1/libraries/{libraryId}/cover`（Kotlin `libraryCover`，retrofit）。
  Future<List<int>> libraryCover(int libraryId, {String? version}) async {
    return _client.getBytes(Channel.general, '$_prefix/libraries/$libraryId/cover', query: {if (version != null) 'v': version});
  }

  /// `POST /api/v1/libraries`（Kotlin `createLibrary`，retrofit）。
  Future<LibraryView> createLibrary({required LibraryPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries', body: body.toJson());
    return LibraryView.fromJson(data);
  }

  /// `PUT /api/v1/libraries/{libraryId}`（Kotlin `updateLibrary`，retrofit）。
  Future<LibraryView> updateLibrary(int libraryId, {required LibraryPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/libraries/$libraryId', body: body.toJson());
    return LibraryView.fromJson(data);
  }

  /// `GET /api/v1/libraries`（Kotlin `libraries`，retrofit）。
  /// 手补参数（P1）：服务端支持 kind（movie/tv）与 scope（visible/all），
  /// Kotlin 接口未声明；Flutter 侧调用方需要（订阅页按 kind 取库、scope=all
  /// 取超管全量），故在此补上。生成脚本重跑时需保留。
  Future<List<LibraryView>> libraries({String? kind, String? scope}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/libraries', query: {if (kind != null) 'kind': kind, if (scope != null) 'scope': scope});
    return items.whereType<Map<String, dynamic>>().map(LibraryView.fromJson).toList();
  }

  /// `GET /api/v1/libraries/routing-options`（Kotlin `routingOptions`，retrofit）。
  Future<RoutingOptionsView> routingOptions() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/routing-options');
    return RoutingOptionsView.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}`（Kotlin `library`，retrofit）。
  Future<LibraryView> libraryById(int libraryId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId');
    return LibraryView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/scan`（Kotlin `scanLibrary`，retrofit）。
  Future<dynamic> scanLibrary(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/scan');
  }

  /// `POST /api/v1/libraries/{libraryId}/scan/stop`（Kotlin `stopLibraryScan`，retrofit）。
  Future<dynamic> stopLibraryScan(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/scan/stop');
  }

  /// `POST /api/v1/libraries/{libraryId}/metadata/refresh`（Kotlin `refreshLibraryMetadata`，retrofit）。
  Future<dynamic> refreshLibraryMetadata(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/metadata/refresh');
  }

  /// `POST /api/v1/libraries/{libraryId}/metadata/refresh/stop`（Kotlin `stopLibraryMetadataRefresh`，retrofit）。
  Future<dynamic> stopLibraryMetadataRefresh(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/metadata/refresh/stop');
  }

  /// `POST /api/v1/libraries/{libraryId}/chapter-images`（Kotlin `generateLibraryChapters`，retrofit）。
  Future<dynamic> generateLibraryChapters(int libraryId, {bool? force}) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/chapter-images', query: {if (force != null) 'force': force});
  }

  /// `POST /api/v1/libraries/{libraryId}/file-organizations`（Kotlin `organizeLibrary`，retrofit）。
  Future<dynamic> organizeLibrary(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/file-organizations');
  }

  /// `POST /api/v1/libraries/{libraryId}/default-selection`（Kotlin `setDefaultLibrary`，retrofit）。
  Future<dynamic> setDefaultLibrary(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/default-selection');
  }

  /// `PUT /api/v1/libraries/display-order`（Kotlin `reorderLibraries`，retrofit）。
  Future<dynamic> reorderLibraries({required Map<String, dynamic> body}) async {
    return _client.unwrapDynamic(Channel.general, 'PUT', '$_prefix/libraries/display-order', body: body);
  }

  /// `DELETE /api/v1/libraries/{libraryId}`（Kotlin `deleteLibrary`，retrofit）。
  Future<dynamic> deleteLibrary(int libraryId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/libraries/$libraryId');
  }

  /// `GET /api/v1/libraries/{libraryId}/items`（Kotlin `libraryItems`，retrofit）。
  Future<List<LibraryItemView>> libraryItems(int libraryId, {int? limit, int? offset, String? sort, String? order, String? genres, String? countries, String? decades, String? watch, double? ratingGte, String? runtimes, String? languages, String? resolutions, bool? hdr, String? stock, String? actor}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items', query: {if (limit != null) 'limit': limit, if (offset != null) 'offset': offset, if (sort != null) 'sort': sort, if (order != null) 'order': order, if (genres != null) 'g': genres, if (countries != null) 'c': countries, if (decades != null) 'd': decades, if (watch != null) 'w': watch, if (ratingGte != null) 'rating_gte': ratingGte, if (runtimes != null) 'rt': runtimes, if (languages != null) 'lang': languages, if (resolutions != null) 'res': resolutions, if (hdr != null) 'hdr': hdr, if (stock != null) 'stock': stock, if (actor != null) 'actor': actor});
    return items.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// `GET /api/v1/libraries/kinds/{kind}`（Kotlin `libraryKindSummary`，retrofit）。
  Future<LibraryKindSummaryView> libraryKindSummary(String kind, {String? watch, String? genres}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/kinds/$kind', query: {if (watch != null) 'w': watch, if (genres != null) 'g': genres});
    return LibraryKindSummaryView.fromJson(data);
  }

  /// `GET /api/v1/libraries/kinds/{kind}/genres`（Kotlin `libraryKindGenres`，retrofit）。
  Future<List<LibraryKindGenreView>> libraryKindGenres(String kind) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/libraries/kinds/$kind/genres');
    return items.whereType<Map<String, dynamic>>().map(LibraryKindGenreView.fromJson).toList();
  }

  /// `GET /api/v1/libraries/kinds/{kind}/items`（Kotlin `libraryKindItems`，retrofit）。
  Future<List<LibraryItemView>> libraryKindItems(String kind, {String? sort, String? order, int? limit, int? offset, String? watch, String? genres}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/libraries/kinds/$kind/items', query: {if (sort != null) 'sort': sort, if (order != null) 'order': order, if (limit != null) 'limit': limit, if (offset != null) 'offset': offset, if (watch != null) 'w': watch, if (genres != null) 'g': genres});
    return items.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// `GET /api/v1/libraries/{libraryId}/facets`（Kotlin `libraryFacets`，retrofit）。
  Future<LibraryFacets> libraryFacets(int libraryId, {String? sort, String? order, String? genres, String? countries, String? decades, String? watch, double? ratingGte, String? runtimes, String? languages, String? resolutions, bool? hdr, String? stock, String? actor}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/facets', query: {if (sort != null) 'sort': sort, if (order != null) 'order': order, if (genres != null) 'g': genres, if (countries != null) 'c': countries, if (decades != null) 'd': decades, if (watch != null) 'w': watch, if (ratingGte != null) 'rating_gte': ratingGte, if (runtimes != null) 'rt': runtimes, if (languages != null) 'lang': languages, if (resolutions != null) 'res': resolutions, if (hdr != null) 'hdr': hdr, if (stock != null) 'stock': stock, if (actor != null) 'actor': actor});
    return LibraryFacets.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}/item-index`（Kotlin `libraryItemIndex`，retrofit）。
  Future<List<LibraryIndexEntry>> libraryItemIndex(int libraryId, {String? sort, String? order, String? genres, String? countries, String? decades, String? watch, double? ratingGte, String? runtimes, String? languages, String? resolutions, bool? hdr, String? stock, String? actor}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/libraries/$libraryId/item-index', query: {if (sort != null) 'sort': sort, if (order != null) 'order': order, if (genres != null) 'g': genres, if (countries != null) 'c': countries, if (decades != null) 'd': decades, if (watch != null) 'w': watch, if (ratingGte != null) 'rating_gte': ratingGte, if (runtimes != null) 'rt': runtimes, if (languages != null) 'lang': languages, if (resolutions != null) 'res': resolutions, if (hdr != null) 'hdr': hdr, if (stock != null) 'stock': stock, if (actor != null) 'actor': actor});
    return items.whereType<Map<String, dynamic>>().map(LibraryIndexEntry.fromJson).toList();
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{itemId}`（Kotlin `libraryItemDetail`，retrofit）。
  Future<LibraryItemDetailView> libraryItemDetail(int libraryId, int itemId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$itemId');
    return LibraryItemDetailView.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{itemId}/similar`（Kotlin `similarItems`，retrofit）。
  Future<List<LibraryItemView>> similarItems(int libraryId, int itemId, {bool? excludeSeries}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$itemId/similar', query: {if (excludeSeries != null) 'exclude_series': excludeSeries});
    return items.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{itemId}/episodes`（Kotlin `seasonEpisodes`，retrofit）。
  Future<SeasonEpisodesView> seasonEpisodes(int libraryId, int itemId, {int? seasonNumber}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$itemId/episodes', query: {if (seasonNumber != null) 'season_number': seasonNumber});
    return SeasonEpisodesView.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{mediaItemId}/share`（Kotlin `libraryItemShare`，retrofit）。
  Future<ShareView?> libraryItemShare(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapNullableModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$mediaItemId/share');
    return data == null ? null : ShareView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/share`（Kotlin `createLibraryItemShare`，retrofit）。
  Future<ShareView> createLibraryItemShare(int libraryId, int mediaItemId, {required ShareCreateRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/share', body: body.toJson());
    return ShareView.fromJson(data);
  }

  /// `DELETE /api/v1/libraries/{libraryId}/items/{mediaItemId}/share`（Kotlin `revokeLibraryItemShare`，retrofit）。
  Future<ShareRevokedView> revokeLibraryItemShare(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'DELETE', '$_prefix/libraries/$libraryId/items/$mediaItemId/share');
    return ShareRevokedView.fromJson(data);
  }

  /// `GET /api/v1/libraries/trashed-files`（Kotlin `trashedFiles`，retrofit）。
  Future<dynamic> trashedFiles() async {
    return _client.unwrapDynamic(Channel.general, 'GET', '$_prefix/libraries/trashed-files');
  }

  /// `POST /api/v1/libraries/trashed-files/restore`（Kotlin `restoreTrashed`，retrofit）。
  Future<dynamic> restoreTrashed({required Map<String, dynamic> body}) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/trashed-files/restore', body: body);
  }

  /// `GET /api/v1/libraries/duplicate-files`（Kotlin `duplicateFiles`，retrofit）。
  Future<dynamic> duplicateFiles() async {
    return _client.unwrapDynamic(Channel.general, 'GET', '$_prefix/libraries/duplicate-files');
  }

  /// `POST /api/v1/libraries/duplicate-files/scan`（Kotlin `scanDuplicates`，retrofit）。
  Future<dynamic> scanDuplicates() async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/duplicate-files/scan');
  }

  /// `DELETE /api/v1/libraries/{libraryId}/items/{mediaItemId}/files/{fileId}`（Kotlin `deleteLibraryFile`，retrofit）。
  Future<ItemDeleteResultView> deleteLibraryFile(int libraryId, int mediaItemId, int fileId, {String? options}) async {
    final data = await _client.unwrapModel(Channel.general, 'DELETE', '$_prefix/libraries/$libraryId/items/$mediaItemId/files/$fileId', query: {if (options != null) 'options': options});
    return ItemDeleteResultView.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{mediaItemId}/delete-preview`（Kotlin `deletePreview`，retrofit）。
  Future<ItemDeletePreviewView> deletePreview(int libraryId, int mediaItemId, {int? fileId}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$mediaItemId/delete-preview', query: {if (fileId != null) 'file_id': fileId});
    return ItemDeletePreviewView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/files/{fileId}/purge`（Kotlin `purgeLibraryFile`，retrofit）。
  Future<dynamic> purgeLibraryFile(int libraryId, int mediaItemId, int fileId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/files/$fileId/purge');
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/files/{fileId}/restore`（Kotlin `restoreLibraryFile`，retrofit）。
  Future<dynamic> restoreLibraryFile(int libraryId, int mediaItemId, int fileId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/files/$fileId/restore');
  }

  /// `DELETE /api/v1/libraries/{libraryId}/items/{mediaItemId}`（Kotlin `deleteLibraryItem`，retrofit）。
  Future<ItemDeleteResultView> deleteLibraryItem(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'DELETE', '$_prefix/libraries/$libraryId/items/$mediaItemId');
    return ItemDeleteResultView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/metadata/refresh`（Kotlin `refreshItemMetadata`，retrofit）。
  Future<ItemJobView> refreshItemMetadata(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/metadata/refresh');
    return ItemJobView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/chapter-images`（Kotlin `regenerateItemChapters`，retrofit）。
  Future<ItemJobView> regenerateItemChapters(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/chapter-images');
    return ItemJobView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/reidentification-preview`（Kotlin `reidentifyPreview`，retrofit）。
  Future<ReidentifyPreviewView> reidentifyPreview(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/reidentification-preview');
    return ReidentifyPreviewView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/reidentifications`（Kotlin `reidentify`，retrofit）。
  Future<ReidentifyResultView> reidentify(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/reidentifications');
    return ReidentifyResultView.fromJson(data);
  }

  /// `POST /api/v1/libraries/identification/file-title-assignments`（Kotlin `assignFilesToTitle`，retrofit）。
  Future<dynamic> assignFilesToTitle({required ClaimBatchPayload body}) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/identification/file-title-assignments', body: body.toJson());
  }

  /// `POST /api/v1/libraries/identification/files/mark-as-extras`（Kotlin `markFilesAsExtras`，retrofit）。
  Future<dynamic> markFilesAsExtras({required DetachPayload body}) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/libraries/identification/files/mark-as-extras', body: body.toJson());
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{mediaItemId}/artwork/candidates`（Kotlin `artworkCandidates`，retrofit）。
  Future<ArtworkCandidatesView> artworkCandidates(int libraryId, int mediaItemId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$mediaItemId/artwork/candidates');
    return ArtworkCandidatesView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/artwork/select`（Kotlin `selectArtwork`，retrofit）。
  Future<ArtworkLockView> selectArtwork(int libraryId, int mediaItemId, {required ArtworkSelectPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/artwork/select', body: body.toJson());
    return ArtworkLockView.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}/items/{mediaItemId}/transfer-preview`（Kotlin `transferPreview`，retrofit）。
  Future<TransferPreviewView> transferPreview(int libraryId, int mediaItemId, {int? targetLibraryId}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/items/$mediaItemId/transfer-preview', query: {if (targetLibraryId != null) 'target_library_id': targetLibraryId});
    return TransferPreviewView.fromJson(data);
  }

  /// `POST /api/v1/libraries/{libraryId}/items/{mediaItemId}/transfers`（Kotlin `transferItem`，retrofit）。
  Future<TransferStartView> transferItem(int libraryId, int mediaItemId, {required TransferPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/$libraryId/items/$mediaItemId/transfers', body: body.toJson());
    return TransferStartView.fromJson(data);
  }

  /// `GET /api/v1/libraries/{libraryId}/item-transfer-status`（Kotlin `transferStatus`，retrofit）。
  Future<TransferStatusView> transferStatus(int libraryId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/item-transfer-status');
    return TransferStatusView.fromJson(data);
  }

  /// `GET /api/v1/libraries/files/{fileId}/subtitles/generation-preview`（Kotlin `subtitleGenerationPreview`，retrofit）。
  Future<SubtitleGenPreviewView> subtitleGenerationPreview(int fileId, {String? targetLanguage, String? secondaryLanguage, String? sourceCandidateKey}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/files/$fileId/subtitles/generation-preview', query: {if (targetLanguage != null) 'target_language': targetLanguage, if (secondaryLanguage != null) 'secondary_language': secondaryLanguage, if (sourceCandidateKey != null) 'source_candidate_key': sourceCandidateKey});
    return SubtitleGenPreviewView.fromJson(data);
  }

  /// `POST /api/v1/libraries/files/{fileId}/subtitles/generations`（Kotlin `startSubtitleGeneration`，retrofit）。
  Future<JobView> startSubtitleGeneration(int fileId, {required SubtitleGenStartPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/libraries/files/$fileId/subtitles/generations', body: body.toJson());
    return JobView.fromJson(data);
  }

  /// `DELETE /api/v1/libraries/files/{fileId}/subtitles`（Kotlin `deleteFileSubtitle`，retrofit）。
  Future<dynamic> deleteFileSubtitle(int fileId, {String? filename}) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/libraries/files/$fileId/subtitles', query: {if (filename != null) 'filename': filename});
  }

  /// `GET /api/v1/libraries/showcase`（Kotlin `uiLibraryShowcase`，generated）。
  Future<Map<String, dynamic>> uiLibraryShowcase({List<int>? ids}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'GET', '$_prefix/libraries/showcase', query: {if (ids != null) 'ids': ids});
  }

  /// `GET /api/v1/libraries/{libraryId}/relax`（Kotlin `libraryItemsRelax`，generated）。
  Future<LibraryRelaxView> libraryItemsRelax(int libraryId, {String? g, String? c, String? d, String? w, double? ratingGte, String? rt, String? lang, String? res, bool? hdr, String? stock, String? seriesKeys, String? actor}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/libraries/$libraryId/relax', query: {if (g != null) 'g': g, if (c != null) 'c': c, if (d != null) 'd': d, if (w != null) 'w': w, if (ratingGte != null) 'ratingGte': ratingGte, if (rt != null) 'rt': rt, if (lang != null) 'lang': lang, if (res != null) 'res': res, if (hdr != null) 'hdr': hdr, if (stock != null) 'stock': stock, if (seriesKeys != null) 'seriesKeys': seriesKeys, if (actor != null) 'actor': actor});
    return LibraryRelaxView.fromJson(data);
  }

  // ── reels ──

  /// `GET /api/v1/reels`（Kotlin `reels`，retrofit）。
  Future<ReelFeedView> reels({int? seed, int? offset, int? limit, String? modes, String? kind, String? genres, String? countries, String? decades, double? ratingGte, String? runtimes, String? watch}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/reels', query: {if (seed != null) 'seed': seed, if (offset != null) 'offset': offset, if (limit != null) 'limit': limit, if (modes != null) 'modes': modes, if (kind != null) 'kind': kind, if (genres != null) 'g': genres, if (countries != null) 'c': countries, if (decades != null) 'd': decades, if (ratingGte != null) 'rating_gte': ratingGte, if (runtimes != null) 'rt': runtimes, if (watch != null) 'w': watch});
    return ReelFeedView.fromJson(data);
  }

  /// `GET /api/v1/reels/facets`（Kotlin `reelFacets`，retrofit）。
  Future<ReelFacetsView> reelFacets({String? kind, String? genres, String? countries, String? decades, double? ratingGte, String? runtimes, String? watch}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/reels/facets', query: {if (kind != null) 'kind': kind, if (genres != null) 'g': genres, if (countries != null) 'c': countries, if (decades != null) 'd': decades, if (ratingGte != null) 'rating_gte': ratingGte, if (runtimes != null) 'rt': runtimes, if (watch != null) 'w': watch});
    return ReelFacetsView.fromJson(data);
  }

  /// `POST /api/v1/reels/events`（Kotlin `reportReelEvents`，retrofit）。
  Future<ReelEventResult> reportReelEvents({required ReelEventBatch body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/reels/events', body: body.toJson());
    return ReelEventResult.fromJson(data);
  }

  /// `GET /api/v1/reels/preview/{mediaItemId}`（Kotlin `reelsPreview`，generated）。
  Future<Map<String, dynamic>> reelsPreview(int mediaItemId, {String? source, int? season, int? episode, String? modes}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'GET', '$_prefix/reels/preview/$mediaItemId', query: {if (source != null) 'source': source, if (season != null) 'season': season, if (episode != null) 'episode': episode, if (modes != null) 'modes': modes});
  }

  // ── tips ──

  /// `GET /api/v1/tips/state`（Kotlin `tipsState`，retrofit）。
  Future<TipStateView> tipsState() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/tips/state');
    return TipStateView.fromJson(data);
  }

  /// `POST /api/v1/tips/{tipId}/displays`（Kotlin `recordTipDisplay`，retrofit）。
  Future<TipRecordView> recordTipDisplay(String tipId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/tips/$tipId/displays');
    return TipRecordView.fromJson(data);
  }

  /// `POST /api/v1/tips/{tipId}/invalidate`（Kotlin `invalidateTip`，retrofit）。
  Future<TipRecordView> invalidateTip(String tipId, {required InvalidateTipRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/tips/$tipId/invalidate', body: body.toJson());
    return TipRecordView.fromJson(data);
  }

  // ── collections ──

  /// `GET /api/v1/collections`（Kotlin `collections`，retrofit）。
  Future<List<CollectionView>> collections({int? libraryId, bool? includeEmpty, bool? includeHidden}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/collections', query: {if (libraryId != null) 'library_id': libraryId, if (includeEmpty != null) 'include_empty': includeEmpty, if (includeHidden != null) 'include_hidden': includeHidden});
    return items.whereType<Map<String, dynamic>>().map(CollectionView.fromJson).toList();
  }

  /// `GET /api/v1/collections/{collectionId}`（Kotlin `collection`，retrofit）。
  Future<CollectionView> collection(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/collections/$id');
    return CollectionView.fromJson(data);
  }

  /// `GET /api/v1/collections/{collectionId}/series`（Kotlin `collectionSeries`，retrofit）。
  Future<CollectionSeriesView> collectionSeries(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/collections/$id/series');
    return CollectionSeriesView.fromJson(data);
  }

  /// `GET /api/v1/collections/{collectionId}/items`（Kotlin `collectionItems`，retrofit）。
  Future<List<LibraryItemView>> collectionItems(int id, {int? limit, int? offset, String? sort, String? order}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/collections/$id/items', query: {if (limit != null) 'limit': limit, if (offset != null) 'offset': offset, if (sort != null) 'sort': sort, if (order != null) 'order': order});
    return items.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// `POST /api/v1/collections/{collectionId}/items`（Kotlin `collectionAddItems`，retrofit）。
  Future<CollectionView> collectionAddItems(int collectionId, {required CollectionItemsPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/collections/$collectionId/items', body: body.toJson());
    return CollectionView.fromJson(data);
  }

  /// `POST /api/v1/collections`（Kotlin `createCollection`，retrofit）。
  Future<CollectionView> createCollection({required CollectionPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/collections', body: body.toJson());
    return CollectionView.fromJson(data);
  }

  // ── downloaders ──

  /// `POST /api/v1/downloaders/{downloaderId}/torrents/{infoHash}/replace`（Kotlin `replaceDownloadTask`，retrofit）。
  Future<dynamic> replaceDownloadTask(int downloaderId, String infoHash) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/downloaders/$downloaderId/torrents/$infoHash/replace');
  }

  /// `DELETE /api/v1/downloaders/{downloaderId}/torrents/{infoHash}`（Kotlin `deleteDownloadTask`，retrofit）。
  Future<dynamic> deleteDownloadTask(int downloaderId, String infoHash, {bool? deleteFiles}) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/downloaders/$downloaderId/torrents/$infoHash', query: {if (deleteFiles != null) 'delete_files': deleteFiles});
  }

  /// `POST /api/v1/downloaders/submit`（Kotlin `submitDownload`，retrofit）。
  Future<DownloadSubmitView> submitDownload({required DownloadSubmitRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/downloaders/submit', body: body.toJson());
    return DownloadSubmitView.fromJson(data);
  }

  /// `POST /api/v1/downloaders/resolve-target`（Kotlin `resolveDownloadTarget`，retrofit）。
  Future<ManualDownloadTargetView> resolveDownloadTarget({required ManualDownloadTargetRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/downloaders/resolve-target', body: body.toJson());
    return ManualDownloadTargetView.fromJson(data);
  }

  /// `GET /api/v1/downloaders/target-prefs`（Kotlin `downloadTargetPrefs`，retrofit）。
  Future<List<DownloadTargetPrefView>> downloadTargetPrefs() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/downloaders/target-prefs');
    return items.whereType<Map<String, dynamic>>().map(DownloadTargetPrefView.fromJson).toList();
  }

  /// `DELETE /api/v1/downloaders/target-prefs/{category}`（Kotlin `forgetDownloadTargetPref`，retrofit）。
  Future<dynamic> forgetDownloadTargetPref(String category) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/downloaders/target-prefs/$category');
  }

  /// `GET /api/v1/downloaders/types`（Kotlin `downloaderTypes`，retrofit）。
  Future<List<DownloaderTypeInfo>> downloaderTypes() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/downloaders/types');
    return items.whereType<Map<String, dynamic>>().map(DownloaderTypeInfo.fromJson).toList();
  }

  /// `GET /api/v1/downloaders/{id}`（Kotlin `downloader`，retrofit）。
  Future<DownloaderView> downloader(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/downloaders/$id');
    return DownloaderView.fromJson(data);
  }

  /// `POST /api/v1/downloaders`（Kotlin `createDownloader`，retrofit）。
  Future<DownloaderView> createDownloader({required DownloaderPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/downloaders', body: body.toJson());
    return DownloaderView.fromJson(data);
  }

  /// `PUT /api/v1/downloaders/{id}`（Kotlin `updateDownloader`，retrofit）。
  Future<DownloaderView> updateDownloader(int id, {required DownloaderPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/downloaders/$id', body: body.toJson());
    return DownloaderView.fromJson(data);
  }

  /// `PATCH /api/v1/downloaders/{id}/status`（Kotlin `setDownloaderEnabled`，retrofit）。
  Future<DownloaderView> setDownloaderEnabled(int id, {required DownloaderStatusPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PATCH', '$_prefix/downloaders/$id/status', body: body.toJson());
    return DownloaderView.fromJson(data);
  }

  /// `POST /api/v1/downloaders/{id}/default`（Kotlin `setDefaultDownloader`，retrofit）。
  Future<DownloaderView> setDefaultDownloader(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/downloaders/$id/default');
    return DownloaderView.fromJson(data);
  }

  /// `POST /api/v1/downloaders/{id}/verify`（Kotlin `verifyDownloader`，retrofit）。
  Future<DownloaderView> verifyDownloader(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/downloaders/$id/verify');
    return DownloaderView.fromJson(data);
  }

  /// `DELETE /api/v1/downloaders/{id}`（Kotlin `deleteDownloader`，retrofit）。
  Future<DownloaderDeleteResult> deleteDownloader(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'DELETE', '$_prefix/downloaders/$id');
    return DownloaderDeleteResult.fromJson(data);
  }

  /// `GET /api/v1/downloaders/{id}/limits`（Kotlin `downloaderLimits`，retrofit）。
  Future<DownloaderLimits> downloaderLimits(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/downloaders/$id/limits');
    return DownloaderLimits.fromJson(data);
  }

  /// `PUT /api/v1/downloaders/{id}/limits`（Kotlin `setDownloaderLimits`，retrofit）。
  Future<DownloaderLimits> setDownloaderLimits(int id, {required DownloaderLimits body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/downloaders/$id/limits', body: body.toJson());
    return DownloaderLimits.fromJson(data);
  }

  /// `GET /api/v1/downloaders`（Kotlin `downloaders`，retrofit）。
  Future<List<DownloaderView>> downloaders() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/downloaders');
    return items.whereType<Map<String, dynamic>>().map(DownloaderView.fromJson).toList();
  }

  /// `GET /api/v1/downloaders/tasks`（Kotlin `downloadTasks`，retrofit）。
  Future<DownloadTaskList> downloadTasks() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/downloaders/tasks');
    return DownloadTaskList.fromJson(data);
  }

  // ── search ──

  /// `POST /api/v1/search/titles`（Kotlin `searchTitles`，retrofit）。
  Future<TitleSearchView> searchTitles({required TitleSearchRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/search/titles', body: body.toJson());
    return TitleSearchView.fromJson(data);
  }

  /// `GET /api/v1/search/library-items`（Kotlin `searchLibraryItems`，retrofit）。
  Future<List<LibrarySearchGroup>> searchLibraryItems({String? keyword}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/search/library-items', query: {if (keyword != null) 'keyword': keyword});
    return items.whereType<Map<String, dynamic>>().map(LibrarySearchGroup.fromJson).toList();
  }

  /// `GET /api/v1/search/library`（Kotlin `searchLibrary`，retrofit）。
  Future<LibrarySearchView> searchLibrary({String? q, int? personId, int? limit, String? cursor}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/search/library', query: {if (q != null) 'q': q, if (personId != null) 'person_id': personId, if (limit != null) 'limit': limit, if (cursor != null) 'cursor': cursor});
    return LibrarySearchView.fromJson(data);
  }

  /// `GET /api/v1/search/history`（Kotlin `searchHistory`，retrofit）。
  Future<List<SearchHistoryItem>> searchHistory() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/search/history');
    return items.whereType<Map<String, dynamic>>().map(SearchHistoryItem.fromJson).toList();
  }

  /// `GET /api/v1/search/presets`（Kotlin `searchPresets`，retrofit）。
  Future<SearchPresetsView> searchPresets() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/search/presets');
    return SearchPresetsView.fromJson(data);
  }

  /// `PUT /api/v1/search/presets`（Kotlin `updateSearchPresets`，retrofit）。
  Future<SearchPresetsView> updateSearchPresets({required SearchPresetsPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/search/presets', body: body.toJson());
    return SearchPresetsView.fromJson(data);
  }

  /// `DELETE /api/v1/search/history`（Kotlin `clearSearchHistory`，retrofit）。
  Future<dynamic> clearSearchHistory() async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/search/history');
  }

  /// `DELETE /api/v1/search/history/{historyId}`（Kotlin `deleteSearchHistory`，retrofit）。
  Future<dynamic> deleteSearchHistory(int historyId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/search/history/$historyId');
  }

  // ── import-watch ──

  /// `GET /api/v1/import-watch`（Kotlin `importWatch`，retrofit）。
  Future<List<ImportWatchView>> importWatch() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/import-watch');
    return items.whereType<Map<String, dynamic>>().map(ImportWatchView.fromJson).toList();
  }

  /// `POST /api/v1/import-watch`（Kotlin `createImportWatch`，retrofit）。
  Future<ImportWatchView> createImportWatch({required ImportWatchPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/import-watch', body: body.toJson());
    return ImportWatchView.fromJson(data);
  }

  /// `PUT /api/v1/import-watch/{id}`（Kotlin `updateImportWatch`，retrofit）。
  Future<ImportWatchView> updateImportWatch(int id, {required ImportWatchPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/import-watch/$id', body: body.toJson());
    return ImportWatchView.fromJson(data);
  }

  /// `DELETE /api/v1/import-watch/{id}`（Kotlin `deleteImportWatch`，retrofit）。
  Future<Map<String, dynamic>> deleteImportWatch(int id) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'DELETE', '$_prefix/import-watch/$id');
  }

  /// `GET /api/v1/import-watch/{id}/entries`（Kotlin `importWatchEntries`，retrofit）。
  Future<IngestEntriesView> importWatchEntries(int id, {String? status}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/import-watch/$id/entries', query: {if (status != null) 'status': status});
    return IngestEntriesView.fromJson(data);
  }

  /// `POST /api/v1/import-watch/entries/{entryId}/ignore`（Kotlin `ignoreIngestEntry`，retrofit）。
  Future<IngestEntryView> ignoreIngestEntry(int entryId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/import-watch/entries/$entryId/ignore');
    return IngestEntryView.fromJson(data);
  }

  /// `POST /api/v1/import-watch/entries/{entryId}/restore`（Kotlin `restoreIngestEntry`，retrofit）。
  Future<IngestEntryView> restoreIngestEntry(int entryId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/import-watch/entries/$entryId/restore');
    return IngestEntryView.fromJson(data);
  }

  /// `POST /api/v1/import-watch/entries/{entryId}/claim`（Kotlin `claimIngestEntry`，retrofit）。
  Future<IngestEntryView> claimIngestEntry(int entryId, {required ClaimPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/import-watch/entries/$entryId/claim', body: body.toJson());
    return IngestEntryView.fromJson(data);
  }

  // ── rule-sets ──

  /// `POST /api/v1/rule-sets`（Kotlin `createRuleSet`，retrofit）。
  Future<RuleSetView> createRuleSet({required RuleSetPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/rule-sets', body: body.toJson());
    return RuleSetView.fromJson(data);
  }

  /// `PUT /api/v1/rule-sets/{id}`（Kotlin `updateRuleSet`，retrofit）。
  Future<RuleSetView> updateRuleSet(int id, {required RuleSetPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/rule-sets/$id', body: body.toJson());
    return RuleSetView.fromJson(data);
  }

  /// `POST /api/v1/rule-sets/{id}/default`（Kotlin `setDefaultRuleSet`，retrofit）。
  Future<RuleSetView> setDefaultRuleSet(int id) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/rule-sets/$id/default');
    return RuleSetView.fromJson(data);
  }

  /// `DELETE /api/v1/rule-sets/{id}`（Kotlin `deleteRuleSet`，retrofit）。
  Future<Map<String, dynamic>> deleteRuleSet(int id) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'DELETE', '$_prefix/rule-sets/$id');
  }

  /// `GET /api/v1/rule-sets`（Kotlin `ruleSets`，retrofit）。
  Future<List<RuleSetView>> ruleSets() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/rule-sets');
    return items.whereType<Map<String, dynamic>>().map(RuleSetView.fromJson).toList();
  }

  // ── sites ──

  /// `GET /api/v1/sites/catalog`（Kotlin `sitesCatalog`，retrofit）。
  Future<List<SiteCatalogItem>> sitesCatalog() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/sites/catalog');
    return items.whereType<Map<String, dynamic>>().map(SiteCatalogItem.fromJson).toList();
  }

  /// `GET /api/v1/sites`（Kotlin `sites`，retrofit）。
  Future<List<ConfiguredSite>> sites() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/sites');
    return items.whereType<Map<String, dynamic>>().map(ConfiguredSite.fromJson).toList();
  }

  /// `GET /api/v1/sites/sync-stats`（Kotlin `siteSyncStats`，retrofit）。
  Future<Map<String, dynamic>> siteSyncStats() async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'GET', '$_prefix/sites/sync-stats');
  }

  /// `GET /api/v1/sites/boost-stats`（Kotlin `siteBoostStats`，retrofit）。
  Future<Map<String, dynamic>> siteBoostStats() async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'GET', '$_prefix/sites/boost-stats');
  }

  /// `POST /api/v1/sites`（Kotlin `createSite`，retrofit）。
  Future<ConfiguredSite> createSite({required SiteConfigCreate body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/sites', body: body.toJson());
    return ConfiguredSite.fromJson(data);
  }

  /// `PUT /api/v1/sites/{siteId}`（Kotlin `updateSite`，retrofit）。
  Future<ConfiguredSite> updateSite(String siteId, {required SiteConfigUpdate body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/sites/$siteId', body: body.toJson());
    return ConfiguredSite.fromJson(data);
  }

  /// `PATCH /api/v1/sites/{siteId}/status`（Kotlin `setSiteEnabled`，retrofit）。
  Future<ConfiguredSite> setSiteEnabled(String siteId, {required SiteEnabledPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PATCH', '$_prefix/sites/$siteId/status', body: body.toJson());
    return ConfiguredSite.fromJson(data);
  }

  /// `PATCH /api/v1/sites/{siteId}/protection`（Kotlin `setSiteProtection`，retrofit）。
  Future<ConfiguredSite> setSiteProtection(String siteId, {required SiteProtectedPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PATCH', '$_prefix/sites/$siteId/protection', body: body.toJson());
    return ConfiguredSite.fromJson(data);
  }

  /// `PATCH /api/v1/sites/{siteId}/ratio-boost`（Kotlin `setSiteBoost`，retrofit）。
  Future<ConfiguredSite> setSiteBoost(String siteId, {required SiteBoostPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PATCH', '$_prefix/sites/$siteId/ratio-boost', body: body.toJson());
    return ConfiguredSite.fromJson(data);
  }

  /// `PATCH /api/v1/sites/{siteId}/ratio-boost/pause`（Kotlin `setSiteBoostPaused`，retrofit）。
  Future<ConfiguredSite> setSiteBoostPaused(String siteId, {required SitePausePayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PATCH', '$_prefix/sites/$siteId/ratio-boost/pause', body: body.toJson());
    return ConfiguredSite.fromJson(data);
  }

  /// `POST /api/v1/sites/{siteId}/verify`（Kotlin `verifySite`，retrofit）。
  Future<ConfiguredSite> verifySite(String siteId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/sites/$siteId/verify');
    return ConfiguredSite.fromJson(data);
  }

  /// `DELETE /api/v1/sites/{siteId}`（Kotlin `deleteSite`，retrofit）。
  Future<Map<String, dynamic>> deleteSite(String siteId) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'DELETE', '$_prefix/sites/$siteId');
  }

  // ── subscriptions ──

  /// `POST /api/v1/subscriptions/{subscriptionId}/selected-torrent-downloads`（Kotlin `grabSubscriptionTorrent`，retrofit）。
  Future<GrabResultView> grabSubscriptionTorrent(int subscriptionId, {required GrabPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/subscriptions/$subscriptionId/selected-torrent-downloads', body: body.toJson());
    return GrabResultView.fromJson(data);
  }

  /// `GET /api/v1/subscriptions`（Kotlin `subscriptions`，retrofit）。
  Future<List<SubscriptionView>> subscriptions({String? kind}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/subscriptions', query: {if (kind != null) 'kind': kind});
    return items.whereType<Map<String, dynamic>>().map(SubscriptionView.fromJson).toList();
  }

  /// `GET /api/v1/subscriptions/today-arrivals`（Kotlin `todayArrivalsFull`，retrofit）。
  Future<List<TodayArrivalFull>> todayArrivalsFull({String? window}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/subscriptions/today-arrivals', query: {if (window != null) 'window': window});
    return items.whereType<Map<String, dynamic>>().map(TodayArrivalFull.fromJson).toList();
  }

  /// `GET /api/v1/subscriptions/recent-arrivals`（Kotlin `recentArrivals`，retrofit）。
  Future<List<RecentArrivalView>> recentArrivals({int? days, int? limit}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/subscriptions/recent-arrivals', query: {if (days != null) 'days': days, if (limit != null) 'limit': limit});
    return items.whereType<Map<String, dynamic>>().map(RecentArrivalView.fromJson).toList();
  }

  /// `GET /api/v1/subscriptions/today-arrivals`（Kotlin `todayArrivals`，retrofit）。
  /// 手补参数（P1）：服务端支持 window（focus/week，缺省 focus），Kotlin
  /// 接口未声明；Flutter 订阅首页默认要 week（整周日程），缺省会变 focus
  /// （只回最近有安排的一天），故在此补上。生成脚本重跑时需保留。
  Future<List<TodayArrival>> todayArrivals({String? window}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/subscriptions/today-arrivals', query: {if (window != null) 'window': window});
    return items.whereType<Map<String, dynamic>>().map(TodayArrival.fromJson).toList();
  }

  /// `GET /api/v1/subscriptions/automation-readiness`（Kotlin `automationReadiness`，retrofit）。
  Future<PipelineHealth> automationReadiness() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/subscriptions/automation-readiness');
    return PipelineHealth.fromJson(data);
  }

  /// `GET /api/v1/subscriptions/smart-profiles/{kind}`（Kotlin `smartProfile`，retrofit）。
  Future<SmartProfileView> smartProfile(String kind) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/subscriptions/smart-profiles/$kind');
    return SmartProfileView.fromJson(data);
  }

  /// `PUT /api/v1/subscriptions/smart-profiles/{kind}`（Kotlin `saveSmartProfile`，retrofit）。
  Future<SmartProfileView> saveSmartProfile(String kind, {required SmartProfilePayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/subscriptions/smart-profiles/$kind', body: body.toJson());
    return SmartProfileView.fromJson(data);
  }

  /// `POST /api/v1/subscriptions/title-preview`（Kotlin `titlePreview`，retrofit）。
  Future<PrepareView> titlePreview({required TitlePreviewRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/subscriptions/title-preview', body: body.toJson());
    return PrepareView.fromJson(data);
  }

  /// `POST /api/v1/subscriptions`（Kotlin `createSubscription`，retrofit）。
  Future<SubscriptionCreateView> createSubscription({required SubscriptionCreateRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/subscriptions', body: body.toJson());
    return SubscriptionCreateView.fromJson(data);
  }

  /// `GET /api/v1/subscriptions/smart-defaults`（Kotlin `smartDefaults`，retrofit）。
  Future<SmartDefaultsView> smartDefaults() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/subscriptions/smart-defaults');
    return SmartDefaultsView.fromJson(data);
  }

  /// `PUT /api/v1/subscriptions/smart-defaults`（Kotlin `saveSmartDefaults`，retrofit）。
  Future<SmartDefaultsView> saveSmartDefaults({required SmartDefaultsPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/subscriptions/smart-defaults', body: body.toJson());
    return SmartDefaultsView.fromJson(data);
  }

  /// `GET /api/v1/subscriptions/smart-memory`（Kotlin `smartMemory`，retrofit）。
  Future<SmartMemoryView> smartMemory() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/subscriptions/smart-memory');
    return SmartMemoryView.fromJson(data);
  }

  /// `PATCH /api/v1/subscriptions/smart-memory`（Kotlin `updateSmartMemory`，retrofit）。
  Future<SmartMemoryView> updateSmartMemory({required SmartMemoryPatch body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PATCH', '$_prefix/subscriptions/smart-memory', body: body.toJson());
    return SmartMemoryView.fromJson(data);
  }

  /// `POST /api/v1/subscriptions/{subscriptionId}/wanted/{wantedId}/smart-wait`（Kotlin `changeSmartWait`，retrofit）。
  Future<Map<String, dynamic>> changeSmartWait(int subscriptionId, int wantedId, {required SmartWaitPayload body}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'POST', '$_prefix/subscriptions/$subscriptionId/wanted/$wantedId/smart-wait', body: body.toJson());
  }

  /// `GET /api/v1/subscriptions/{subscriptionId}`（Kotlin `subscription`，retrofit）。
  Future<SubscriptionView> subscription(int subscriptionId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/subscriptions/$subscriptionId');
    return SubscriptionView.fromJson(data);
  }

  /// `PATCH /api/v1/subscriptions/{subscriptionId}`（Kotlin `updateSubscription`，retrofit）。
  Future<Map<String, dynamic>> updateSubscription(int subscriptionId, {required Map<String, dynamic> body}) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'PATCH', '$_prefix/subscriptions/$subscriptionId', body: body);
  }

  /// `GET /api/v1/subscriptions/download-routing-preview`（Kotlin `downloadRoutingPreview`，retrofit）。
  Future<DispatchPreviewView> downloadRoutingPreview({String? kind, int? libraryId, int? tmdbId, String? title, int? year}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/subscriptions/download-routing-preview', query: {if (kind != null) 'kind': kind, if (libraryId != null) 'library_id': libraryId, if (tmdbId != null) 'tmdb_id': tmdbId, if (title != null) 'title': title, if (year != null) 'year': year});
    return DispatchPreviewView.fromJson(data);
  }

  /// `PATCH /api/v1/subscriptions/{subscriptionId}/follow-future`（Kotlin `setFollowFuture`，retrofit）。
  Future<dynamic> setFollowFuture(int subscriptionId, {required FollowFutureRequest body}) async {
    return _client.unwrapDynamic(Channel.general, 'PATCH', '$_prefix/subscriptions/$subscriptionId/follow-future', body: body.toJson());
  }

  /// `GET /api/v1/subscriptions/{subscriptionId}/activities`（Kotlin `subscriptionActivities`，retrofit）。
  Future<List<SubActivityView>> subscriptionActivities(int id, {int? limit}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/subscriptions/$id/activities', query: {if (limit != null) 'limit': limit});
    return items.whereType<Map<String, dynamic>>().map(SubActivityView.fromJson).toList();
  }

  /// `GET /api/v1/subscriptions/{subscriptionId}/active-downloads`（Kotlin `activeDownloads`，retrofit）。
  Future<List<SubscriptionDownloadView>> activeDownloads(int id) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/subscriptions/$id/active-downloads');
    return items.whereType<Map<String, dynamic>>().map(SubscriptionDownloadView.fromJson).toList();
  }

  /// `POST /api/v1/subscriptions/{subscriptionId}/missing-resource-searches`（Kotlin `searchMissingResources`，retrofit）。
  Future<dynamic> searchMissingResources(int id) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/subscriptions/$id/missing-resource-searches');
  }

  /// `POST /api/v1/subscriptions/{subscriptionId}/upgrade-runs`（Kotlin `upgradeRun`，retrofit）。
  Future<UpgradeRunView> upgradeRun(int id, {required UpgradeRunPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/subscriptions/$id/upgrade-runs', body: body.toJson());
    return UpgradeRunView.fromJson(data);
  }

  /// `PATCH /api/v1/subscriptions/{subscriptionId}/tracking-state`（Kotlin `setTrackingState`，retrofit）。
  Future<dynamic> setTrackingState(int id, {required TrackingStateRequest body}) async {
    return _client.unwrapDynamic(Channel.general, 'PATCH', '$_prefix/subscriptions/$id/tracking-state', body: body.toJson());
  }

  /// `DELETE /api/v1/subscriptions/{subscriptionId}`（Kotlin `deleteSubscription`，retrofit）。
  Future<dynamic> deleteSubscription(int subscriptionId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/subscriptions/$subscriptionId');
  }

  // ── jobs ──

  /// `GET /api/v1/jobs`（Kotlin `jobs`，retrofit）。
  Future<JobListView> jobs({bool? activeOnly, String? jobType, String? resourceType, int? resourceId, String? status, int? limit}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/jobs', query: {if (activeOnly != null) 'active_only': activeOnly, if (jobType != null) 'job_type': jobType, if (resourceType != null) 'resource_type': resourceType, if (resourceId != null) 'resource_id': resourceId, if (status != null) 'status': status, if (limit != null) 'limit': limit});
    return JobListView.fromJson(data);
  }

  /// `GET /api/v1/jobs/{jobId}`（Kotlin `job`，retrofit）。
  Future<JobView> job(String jobId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/jobs/$jobId');
    return JobView.fromJson(data);
  }

  /// `POST /api/v1/jobs/{jobId}/cancel`（Kotlin `cancelJob`，retrofit）。
  Future<JobCancelView> cancelJob(String jobId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/jobs/$jobId/cancel');
    return JobCancelView.fromJson(data);
  }

  /// `POST /api/v1/jobs/{jobId}/retry`（Kotlin `retryJob`，retrofit）。
  Future<dynamic> retryJob(String jobId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/jobs/$jobId/retry');
  }

  /// `POST /api/v1/jobs/{jobId}/dismiss`（Kotlin `dismissJob`，retrofit）。
  Future<dynamic> dismissJob(String jobId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/jobs/$jobId/dismiss');
  }

  /// `POST /api/v1/jobs/{jobId}/undismiss`（Kotlin `undismissJob`，retrofit）。
  Future<dynamic> undismissJob(String jobId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/jobs/$jobId/undismiss');
  }

  /// `POST /api/v1/jobs/dismiss-all`（Kotlin `dismissAllJobs`，retrofit）。
  Future<dynamic> dismissAllJobs() async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/jobs/dismiss-all');
  }

  // ── ui ──

  /// `GET /api/v1/ui/preferences`（Kotlin `uiPreferences`，retrofit）。
  Future<UiPreferencesSetting> uiPreferences() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/ui/preferences');
    return UiPreferencesSetting.fromJson(data);
  }

  /// `PUT /api/v1/ui/preferences`（Kotlin `updateUiPreferences`，retrofit）。
  Future<UiPreferencesSetting> updateUiPreferences({required UiPreferencesSetting body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/ui/preferences', body: body.toJson());
    return UiPreferencesSetting.fromJson(data);
  }

  /// `GET /api/v1/ui/discovery/{mediaType}`（Kotlin `discoveryPage`，retrofit）。
  Future<DiscoveryPage> discoveryPage(String mediaType, {String? source}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/ui/discovery/$mediaType', query: {if (source != null) 'provider': source});
    return DiscoveryPage.fromJson(data);
  }

  // ── discover ──

  /// `GET /api/v1/discover/filters`（Kotlin `discoveryFilters`，retrofit）。
  Future<dynamic> discoveryFilters({String? mediaType}) async {
    return _client.unwrapDynamic(Channel.general, 'GET', '$_prefix/discover/filters', query: {if (mediaType != null) 'media_type': mediaType});
  }

  /// `GET /api/v1/discover/titles`（Kotlin `discoverTitles`，retrofit）。
  Future<dynamic> discoverTitles({String? mediaType, List<String>? genreIds, String? originCountry, String? year, String? ratingGte, String? runtimeLte, String? sort, int? page}) async {
    return _client.unwrapDynamic(Channel.general, 'GET', '$_prefix/discover/titles', query: {if (mediaType != null) 'media_type': mediaType, if (genreIds != null) 'genre_ids': genreIds, if (originCountry != null) 'origin_country': originCountry, if (year != null) 'year': year, if (ratingGte != null) 'rating_gte': ratingGte, if (runtimeLte != null) 'runtime_lte': runtimeLte, if (sort != null) 'sort': sort, if (page != null) 'page': page});
  }

  /// `GET /api/v1/discover/people/{tmdbPersonId}`（Kotlin `discoveredPerson`，retrofit）。
  Future<dynamic> discoveredPerson(int id) async {
    return _client.unwrapDynamic(Channel.general, 'GET', '$_prefix/discover/people/$id');
  }

  /// `GET /api/v1/discover/collections/{collectionRef}/titles`（Kotlin `collectionTitles`，retrofit）。
  Future<CollectionTitles> collectionTitles({required String collectionRef, int? limit, int? page}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/discover/collections/$collectionRef/titles', query: {if (limit != null) 'limit': limit, if (page != null) 'page': page});
    return CollectionTitles.fromJson(data);
  }

  /// `GET /api/v1/discover/titles/{titleRef}`（Kotlin `titleDetails`，retrofit）。
  Future<TitleDetails> titleDetails(String titleRef) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/discover/titles/$titleRef');
    return TitleDetails.fromJson(data);
  }

  // ── people ──

  /// `GET /api/v1/people/{tmdbPersonId}`（Kotlin `libraryPerson`，retrofit）。
  Future<dynamic> libraryPerson(int id) async {
    return _client.unwrapDynamic(Channel.general, 'GET', '$_prefix/people/$id');
  }

  // ── sessions ──

  /// `GET /api/v1/sessions`（Kotlin `sessions`，retrofit）。
  Future<List<SessionSummary>> sessions({int? limit, int? offset}) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/sessions', query: {if (limit != null) 'limit': limit, if (offset != null) 'offset': offset});
    return items.whereType<Map<String, dynamic>>().map(SessionSummary.fromJson).toList();
  }

  /// `GET /api/v1/sessions/{sessionId}`（Kotlin `sessionTranscript`，retrofit）。
  Future<SessionTranscript> sessionTranscript(String sessionId) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/sessions/$sessionId');
    return SessionTranscript.fromJson(data);
  }

  /// `POST /api/v1/sessions`（Kotlin `startAgentSession`，retrofit）。
  Future<SessionAccepted> startAgentSession({required AgentSessionStart body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/sessions', body: body.toJson());
    return SessionAccepted.fromJson(data);
  }

  /// `POST /api/v1/sessions/{sessionId}/stop`（Kotlin `stopAgentSession`，retrofit）。
  Future<dynamic> stopAgentSession(String sessionId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/sessions/$sessionId/stop');
  }

  /// `POST /api/v1/sessions/{sessionId}/retry`（Kotlin `retryAgentSession`，retrofit）。
  Future<SessionAccepted> retryAgentSession(String sessionId, {required SessionRetry body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/sessions/$sessionId/retry', body: body.toJson());
    return SessionAccepted.fromJson(data);
  }

  /// `POST /api/v1/sessions/{sessionId}/compact-context`（Kotlin `compactAgentContext`，retrofit）。
  Future<dynamic> compactAgentContext(String sessionId) async {
    return _client.unwrapDynamic(Channel.general, 'POST', '$_prefix/sessions/$sessionId/compact-context');
  }

  /// `POST /api/v1/sessions/{sessionId}/fork`（Kotlin `forkSession`，retrofit）。
  Future<SessionTranscript> forkSession(String sessionId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/sessions/$sessionId/fork');
    return SessionTranscript.fromJson(data);
  }

  /// `PATCH /api/v1/sessions/{sessionId}`（Kotlin `renameSession`，retrofit）。
  Future<dynamic> renameSession(String sessionId, {required SessionRename body}) async {
    return _client.unwrapDynamic(Channel.general, 'PATCH', '$_prefix/sessions/$sessionId', body: body.toJson());
  }

  /// `DELETE /api/v1/sessions/{sessionId}`（Kotlin `deleteSession`，retrofit）。
  Future<dynamic> deleteSession(String sessionId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/sessions/$sessionId');
  }

  /// `POST /api/v1/sessions/attachments`（Kotlin `uploadAgentAttachment`，retrofit）。
  Future<AgentAttachment> uploadAgentAttachment({required String filePath}) async {
    final data = await _client.postMultipart<Map<String, dynamic>>(Channel.general, '$_prefix/sessions/attachments', fileField: 'file', filePath: filePath);
    return AgentAttachment.fromJson(data);
  }

  // ── agent-handoff ──

  /// `POST /api/v1/agent-handoff`（Kotlin `agentHandoff`，retrofit）。
  Future<HandoffPrompt> agentHandoff({required HandoffRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/agent-handoff', body: body.toJson());
    return HandoffPrompt.fromJson(data);
  }

  // ── llm ──

  /// `GET /api/v1/llm/providers`（Kotlin `llmProviders`，retrofit）。
  Future<List<LlmProviderView>> llmProviders() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/llm/providers');
    return items.whereType<Map<String, dynamic>>().map(LlmProviderView.fromJson).toList();
  }

  /// `GET /api/v1/llm/presets`（Kotlin `llmPresets`，retrofit）。
  Future<List<LlmPresetView>> llmPresets() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/llm/presets');
    return items.whereType<Map<String, dynamic>>().map(LlmPresetView.fromJson).toList();
  }

  /// `POST /api/v1/llm/providers`（Kotlin `createLlmProvider`，retrofit）。
  Future<LlmProviderView> createLlmProvider({required LlmProviderPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/llm/providers', body: body.toJson());
    return LlmProviderView.fromJson(data);
  }

  /// `PUT /api/v1/llm/providers/{providerId}`（Kotlin `updateLlmProvider`，retrofit）。
  Future<LlmProviderView> updateLlmProvider(int providerId, {required LlmProviderPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/llm/providers/$providerId', body: body.toJson());
    return LlmProviderView.fromJson(data);
  }

  /// `POST /api/v1/llm/providers/{providerId}/verify`（Kotlin `verifyLlmProvider`，retrofit）。
  Future<LlmProviderView> verifyLlmProvider(int providerId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/llm/providers/$providerId/verify');
    return LlmProviderView.fromJson(data);
  }

  /// `DELETE /api/v1/llm/providers/{providerId}`（Kotlin `deleteLlmProvider`，retrofit）。
  Future<dynamic> deleteLlmProvider(int providerId) async {
    return _client.unwrapDynamic(Channel.general, 'DELETE', '$_prefix/llm/providers/$providerId');
  }

  /// `GET /api/v1/llm/defaults`（Kotlin `llmDefaultsShow`，retrofit）。
  Future<LlmDefaultsView> llmDefaultsShow() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/llm/defaults');
    return LlmDefaultsView.fromJson(data);
  }

  /// `PUT /api/v1/llm/defaults`（Kotlin `llmDefaultsUpdate`，retrofit）。
  Future<LlmDefaultsView> llmDefaultsUpdate({required LlmDefaultsPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/llm/defaults', body: body.toJson());
    return LlmDefaultsView.fromJson(data);
  }

  /// `GET /api/v1/llm/models`（Kotlin `llmModels`，retrofit）。
  Future<List<LlmModelOption>> llmModels() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/llm/models');
    return items.whereType<Map<String, dynamic>>().map(LlmModelOption.fromJson).toList();
  }

  /// `GET /api/v1/llm/web-search`（Kotlin `webSearchShow`，retrofit）。
  Future<WebSearchConfig> webSearchShow() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/llm/web-search');
    return WebSearchConfig.fromJson(data);
  }

  /// `PUT /api/v1/llm/web-search`（Kotlin `webSearchUpdate`，retrofit）。
  Future<WebSearchConfig> webSearchUpdate({required WebSearchSavePayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/llm/web-search', body: body.toJson());
    return WebSearchConfig.fromJson(data);
  }

  /// `DELETE /api/v1/llm/web-search`（Kotlin `webSearchClear`，retrofit）。
  Future<WebSearchConfig> webSearchClear() async {
    final data = await _client.unwrapModel(Channel.general, 'DELETE', '$_prefix/llm/web-search');
    return WebSearchConfig.fromJson(data);
  }

  /// `POST /api/v1/llm/web-search/test`（Kotlin `webSearchTest`，retrofit）。
  Future<WebSearchTestResult> webSearchTest({required WebSearchTestPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/llm/web-search/test', body: body.toJson());
    return WebSearchTestResult.fromJson(data);
  }

  // ── cloud ──

  /// `GET /api/v1/cloud`（Kotlin `cloudStatus`，retrofit）。
  Future<CloudStatusView> cloudStatus() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/cloud');
    return CloudStatusView.fromJson(data);
  }

  /// `POST /api/v1/cloud/renew`（Kotlin `cloudRenew`，retrofit）。
  Future<CloudStatusView> cloudRenew() async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/cloud/renew');
    return CloudStatusView.fromJson(data);
  }

  /// `PUT /api/v1/cloud/settings`（Kotlin `cloudSettingsSet`，retrofit）。
  Future<CloudStatusView> cloudSettingsSet({required CloudSettingsRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/cloud/settings', body: body.toJson());
    return CloudStatusView.fromJson(data);
  }

  // ── scrape ──

  /// `PUT /api/v1/scrape/config`（Kotlin `scrapeSet`，retrofit）。
  Future<ScrapeConfigView> scrapeSet({required ScrapeSetting body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/scrape/config', body: body.toJson());
    return ScrapeConfigView.fromJson(data);
  }

  /// `GET /api/v1/scrape/fanart`（Kotlin `scrapeFanartShow`，retrofit）。
  Future<ScrapeFanartView> scrapeFanartShow() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/scrape/fanart');
    return ScrapeFanartView.fromJson(data);
  }

  /// `PUT /api/v1/scrape/fanart`（Kotlin `scrapeFanartSetKey`，retrofit）。
  Future<ScrapeFanartView> scrapeFanartSetKey({required ScrapeFanartKeyPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/scrape/fanart', body: body.toJson());
    return ScrapeFanartView.fromJson(data);
  }

  /// `GET /api/v1/scrape/storage-estimate`（Kotlin `scrapeStorageEstimate`，retrofit）。
  Future<ScrapeStorageEstimate> scrapeStorageEstimate() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/scrape/storage-estimate');
    return ScrapeStorageEstimate.fromJson(data);
  }

  /// `GET /api/v1/scrape/language-options`（Kotlin `scrapeLanguages`，retrofit）。
  Future<List<ScrapeLanguageOption>> scrapeLanguages() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/scrape/language-options');
    return items.whereType<Map<String, dynamic>>().map(ScrapeLanguageOption.fromJson).toList();
  }

  /// `GET /api/v1/scrape/country-options`（Kotlin `scrapeCountries`，retrofit）。
  Future<List<ScrapeCountryOption>> scrapeCountries() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/scrape/country-options');
    return items.whereType<Map<String, dynamic>>().map(ScrapeCountryOption.fromJson).toList();
  }

  /// `GET /api/v1/scrape/config`（Kotlin `scrapeShow`，retrofit）。
  Future<ScrapeConfigView> scrapeShow() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/scrape/config');
    return ScrapeConfigView.fromJson(data);
  }

  // ── webhook ──

  /// `GET /api/v1/webhook`（Kotlin `webhookShow`，retrofit）。
  Future<WebhookConfigView> webhookShow() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/webhook');
    return WebhookConfigView.fromJson(data);
  }

  /// `PUT /api/v1/webhook`（Kotlin `webhookSet`，retrofit）。
  Future<WebhookConfigView> webhookSet({required WebhookConfigPayload body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/webhook', body: body.toJson());
    return WebhookConfigView.fromJson(data);
  }

  /// `POST /api/v1/webhook/endpoints/{endpointId}/test`（Kotlin `webhookTest`，retrofit）。
  Future<WebhookDeliveryView> webhookTest(String endpointId) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/webhook/endpoints/$endpointId/test');
    return WebhookDeliveryView.fromJson(data);
  }

  /// `GET /api/v1/webhook/endpoints/{endpointId}/deliveries`（Kotlin `webhookDeliveries`，retrofit）。
  Future<List<WebhookDeliveryView>> webhookDeliveries(String endpointId) async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/webhook/endpoints/$endpointId/deliveries');
    return items.whereType<Map<String, dynamic>>().map(WebhookDeliveryView.fromJson).toList();
  }

  // ── mcp ──

  /// `GET /api/v1/mcp/status`（Kotlin `mcpStatus`，retrofit）。
  Future<McpStatusView> mcpStatus() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/mcp/status');
    return McpStatusView.fromJson(data);
  }

  /// `PUT /api/v1/mcp/status`（Kotlin `mcpToggle`，retrofit）。
  Future<McpStatusView> mcpToggle({required McpToggleRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/mcp/status', body: body.toJson());
    return McpStatusView.fromJson(data);
  }

  // ── push ──

  /// `GET /api/v1/push/channels`（Kotlin `pushChannelsList`，retrofit）。
  Future<PushChannelsView> pushChannelsList() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/push/channels');
    return PushChannelsView.fromJson(data);
  }

  /// `PUT /api/v1/push/channels/official`（Kotlin `pushChannelsOfficialSet`，retrofit）。
  Future<PushChannelsView> pushChannelsOfficialSet({required OfficialChannelRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/push/channels/official', body: body.toJson());
    return PushChannelsView.fromJson(data);
  }

  /// `PUT /api/v1/push/me/registration`（Kotlin `pushRegister`，retrofit）。
  Future<PushRegistrationView> pushRegister({required PushRegistrationBody body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/push/me/registration', body: body.toJson());
    return PushRegistrationView.fromJson(data);
  }

  /// `POST /api/v1/push/me/ack`（Kotlin `pushAck`，retrofit）。
  Future<PushAckView> pushAck({required PushAckBody body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/push/me/ack', body: body.toJson());
    return PushAckView.fromJson(data);
  }

  /// `POST /api/v1/push/me/test`（Kotlin `pushTest`，retrofit）。
  Future<PushTestView> pushTest() async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/push/me/test');
    return PushTestView.fromJson(data);
  }

  /// `GET /api/v1/push/me`（Kotlin `pushMe`，retrofit）。
  Future<MyPushView> pushMe() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/push/me');
    return MyPushView.fromJson(data);
  }

  /// `PUT /api/v1/push/me/preferences`（Kotlin `pushPreferences`，retrofit）。
  Future<MyPushView> pushPreferences({required PushPreferencesBody body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/push/me/preferences', body: body.toJson());
    return MyPushView.fromJson(data);
  }

  // ── channels ──

  /// `GET /api/v1/channels/im/push-config`（Kotlin `channelsImPushConfigGet`，retrofit）。
  Future<ChannelPushConfigView> channelsImPushConfigGet() async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/channels/im/push-config');
    return ChannelPushConfigView.fromJson(data);
  }

  /// `PUT /api/v1/channels/im/push-config`（Kotlin `channelsImPushConfigUpdate`，retrofit）。
  Future<ChannelPushConfigView> channelsImPushConfigUpdate({required ChannelPushConfigView body}) async {
    final data = await _client.unwrapModel(Channel.general, 'PUT', '$_prefix/channels/im/push-config', body: body.toJson());
    return ChannelPushConfigView.fromJson(data);
  }

  // ── skills ──

  /// `GET /api/v1/skills`（Kotlin `skillsList`，retrofit）。
  Future<List<SkillView>> skillsList() async {
    final items = await _client.unwrapList(Channel.general, 'GET', '$_prefix/skills');
    return items.whereType<Map<String, dynamic>>().map(SkillView.fromJson).toList();
  }

  // ── share ──

  /// `GET /api/v1/share/{slug}`（Kotlin `sharePublic`，retrofit）。
  Future<SharePublic> sharePublic(String slug) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug');
    return SharePublic.fromJson(data);
  }

  /// `POST /api/v1/share/{slug}/unlock`（Kotlin `shareUnlock`，retrofit）。
  Future<SharePublic> shareUnlock(String slug, {required ShareUnlockRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/share/$slug/unlock', body: body.toJson());
    return SharePublic.fromJson(data);
  }

  /// `GET /api/v1/share/{slug}/item`（Kotlin `shareItem`，retrofit）。
  Future<SharedItem> shareItem(String slug) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug/item');
    return SharedItem.fromJson(data);
  }

  /// `GET /api/v1/share/{slug}/collection`（Kotlin `shareCollection`，retrofit）。
  Future<SharedCollection> shareCollection(String slug) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug/collection');
    return SharedCollection.fromJson(data);
  }

  /// `GET /api/v1/share/{slug}/episodes`（Kotlin `shareEpisodes`，retrofit）。
  Future<SeasonEpisodesView> shareEpisodes(String slug, {int? seasonNumber}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug/episodes', query: {if (seasonNumber != null) 'season_number': seasonNumber});
    return SeasonEpisodesView.fromJson(data);
  }

  /// `POST /api/v1/share/{slug}/playback/decide`（Kotlin `sharePlaybackDecide`，generated）。
  Future<PlaybackDecisionView> sharePlaybackDecide(String slug, {required PlaybackDecideRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/share/$slug/playback/decide', body: body.toJson());
    return PlaybackDecisionView.fromJson(data);
  }

  /// `POST /api/v1/share/{slug}/playback/sessions`（Kotlin `sharePlaybackSessionStart`，generated）。
  Future<PlaybackSessionView> sharePlaybackSessionStart(String slug, {required PlaybackSessionRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/share/$slug/playback/sessions', body: body.toJson());
    return PlaybackSessionView.fromJson(data);
  }

  /// `POST /api/v1/share/{slug}/playback/sessions/{sessionId}/ping`（Kotlin `sharePlaybackSessionPing`，generated）。
  Future<Map<String, dynamic>> sharePlaybackSessionPing(String sessionId, String slug) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'POST', '$_prefix/share/$slug/playback/sessions/$sessionId/ping');
  }

  /// `DELETE /api/v1/share/{slug}/playback/sessions/{sessionId}`（Kotlin `sharePlaybackSessionStop`，generated）。
  Future<Map<String, dynamic>> sharePlaybackSessionStop(String sessionId, String slug) async {
    return _client.unwrap<Map<String, dynamic>>(Channel.general, 'DELETE', '$_prefix/share/$slug/playback/sessions/$sessionId');
  }

  /// `POST /api/v1/share/{slug}/playback/progress`（Kotlin `sharePlaybackProgress`，generated）。
  Future<PlaybackStateView> sharePlaybackProgress(String slug, {required PlaybackProgressRequest body}) async {
    final data = await _client.unwrapModel(Channel.general, 'POST', '$_prefix/share/$slug/playback/progress', body: body.toJson());
    return PlaybackStateView.fromJson(data);
  }

  /// `GET /api/v1/share/{slug}/playback/items/{mediaItemId}`（Kotlin `sharePlaybackItem`，generated）。
  Future<PlaybackItemView> sharePlaybackItem(int mediaItemId, String slug) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug/playback/items/$mediaItemId');
    return PlaybackItemView.fromJson(data);
  }

  /// `GET /api/v1/share/{slug}/playback/items/{mediaItemId}/episodes`（Kotlin `sharePlaybackItemEpisodes`，generated）。
  Future<SeasonEpisodesView> sharePlaybackItemEpisodes(int mediaItemId, String slug, {int? seasonNumber}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug/playback/items/$mediaItemId/episodes', query: {if (seasonNumber != null) 'seasonNumber': seasonNumber});
    return SeasonEpisodesView.fromJson(data);
  }

  /// `GET /api/v1/share/{slug}/playback/sessions/{sessionId}/diagnostics`（Kotlin `sharePlaybackSessionDiagnostics`，generated）。
  Future<PlaybackDiagnosticsView> sharePlaybackSessionDiagnostics(String sessionId, String slug, {String? token}) async {
    final data = await _client.unwrapModel(Channel.general, 'GET', '$_prefix/share/$slug/playback/sessions/$sessionId/diagnostics', query: {if (token != null) 'token': token});
    return PlaybackDiagnosticsView.fromJson(data);
  }

}
