import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/models.dart' as core;
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';
import 'raw_models.dart';

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

  // ---- 总览 / 健康 ----

  /// GET /health（服务健康）与 GET /automation/readiness（链路体检）。
  Future<core.HealthView> health() => _api.health();
  Future<core.PipelineHealth> automationReadiness() =>
      _api.automationReadiness();

  // ---- 成员（直接用 core 模型，不再另建本地模型） ----

  Future<List<core.MemberView>> members() => _api.members();
  Future<core.MemberView> createMember(core.MemberCreateRequest body) =>
      _api.createMember(body: body);
  Future<core.MemberView> updateMember(
          int id, core.MemberUpdateRequest body) =>
      _api.updateMember(id, body: body);
  Future<core.MemberView> setMemberStatus(
          int id, core.MemberStatusRequest body) =>
      _api.setMemberStatus(id, body: body);
  Future<core.MemberPasswordReset> resetMemberPassword(int id) =>
      _api.resetMemberPassword(id);
  Future<void> signOutMember(int id) => _api.signOutMember(id);
  Future<void> deleteMember(int id) => _api.deleteMember(id);

  // ---- 订阅设置（智能默认 / 智能计划 / 智能记忆） ----

  Future<core.SmartDefaultsView> smartDefaults() => _api.smartDefaults();
  Future<core.SmartDefaultsView> saveSmartDefaults(
          core.SmartDefaultsPayload body) =>
      _api.saveSmartDefaults(body: body);
  Future<core.SmartProfileView> smartProfile(String kind) =>
      _api.smartProfile(kind);
  Future<core.SmartProfileView> saveSmartProfile(
          String kind, core.SmartProfilePayload body) =>
      _api.saveSmartProfile(kind, body: body);
  Future<core.SmartMemoryView> smartMemory() => _api.smartMemory();
  Future<core.SmartMemoryView> updateSmartMemory(core.SmartMemoryPatch body) =>
      _api.updateSmartMemory(body: body);

  // ---- 站点 + 浏览器扩展同步令牌 ----

  Future<List<core.SiteCatalogItem>> sitesCatalog() => _api.sitesCatalog();
  Future<List<core.ConfiguredSite>> sites() => _api.sites();
  Future<core.ConfiguredSite> createSite(core.SiteConfigCreate body) =>
      _api.createSite(body: body);
  Future<core.ConfiguredSite> updateSite(
          String siteId, core.SiteConfigUpdate body) =>
      _api.updateSite(siteId, body: body);
  Future<core.ConfiguredSite> setSiteEnabled(String siteId, bool enabled) =>
      _api.setSiteEnabled(siteId,
          body: core.SiteEnabledPayload(enabled: enabled));
  Future<core.ConfiguredSite> setSiteProtection(
          String siteId, bool isProtected) =>
      _api.setSiteProtection(siteId,
          body: core.SiteProtectedPayload(isProtected: isProtected));
  Future<core.ConfiguredSite> setSiteBoost(String siteId,
          {required bool enabled, int? budgetBytes, int? holdDays,
          int? downloaderId}) =>
      _api.setSiteBoost(siteId,
          body: core.SiteBoostPayload(
              enabled: enabled,
              budgetBytes: budgetBytes,
              holdDays: holdDays,
              downloaderId: downloaderId));
  Future<core.ConfiguredSite> setSiteBoostPaused(
          String siteId, bool paused) =>
      _api.setSiteBoostPaused(siteId,
          body: core.SitePausePayload(paused: paused));
  Future<core.ConfiguredSite> verifySite(String siteId) =>
      _api.verifySite(siteId);
  Future<void> deleteSite(String siteId) => _api.deleteSite(siteId);

  /// 扩展同步令牌（web lib/api/extension.ts：GET/POST/DELETE /extension/token）。
  Future<SyncTokenView> syncToken() async => SyncTokenView.fromJson(
      await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'GET', '/api/v1/extension/token'));
  Future<SyncTokenView> generateSyncToken() async =>
      SyncTokenView.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'POST', '/api/v1/extension/token'));
  Future<SyncTokenView> revokeSyncToken() async =>
      SyncTokenView.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'DELETE', '/api/v1/extension/token'));

  // ---- 下载器 ----

  Future<List<core.DownloaderTypeInfo>> downloaderTypes() =>
      _api.downloaderTypes();
  Future<List<core.DownloaderView>> downloaders() => _api.downloaders();
  Future<core.DownloaderView> createDownloader(core.DownloaderPayload body) =>
      _api.createDownloader(body: body);
  Future<core.DownloaderView> updateDownloader(
          int id, core.DownloaderPayload body) =>
      _api.updateDownloader(id, body: body);
  Future<core.DownloaderView> setDownloaderEnabled(int id, bool enabled) =>
      _api.setDownloaderEnabled(id,
          body: core.DownloaderStatusPayload(enabled: enabled));
  Future<core.DownloaderView> setDefaultDownloader(int id) =>
      _api.setDefaultDownloader(id);
  Future<core.DownloaderView> verifyDownloader(int id) =>
      _api.verifyDownloader(id);
  Future<void> deleteDownloader(int id) => _api.deleteDownloader(id);
  Future<core.DownloaderLimits> downloaderLimits(int id) =>
      _api.downloaderLimits(id);
  Future<core.DownloaderLimits> setDownloaderLimits(
          int id, core.DownloaderLimits body) =>
      _api.setDownloaderLimits(id, body: body);

  // ---- 导入监听 ----

  Future<List<core.ImportWatchView>> importWatch() => _api.importWatch();
  Future<core.ImportWatchView> createImportWatch(
          core.ImportWatchPayload body) =>
      _api.createImportWatch(body: body);
  Future<core.ImportWatchView> updateImportWatch(
          int id, core.ImportWatchPayload body) =>
      _api.updateImportWatch(id, body: body);
  Future<void> deleteImportWatch(int id) => _api.deleteImportWatch(id);
  Future<core.IngestEntriesView> importWatchEntries(int id,
          {String? status}) =>
      _api.importWatchEntries(id, status: status);
  Future<core.IngestEntryView> ignoreIngestEntry(int entryId) =>
      _api.ignoreIngestEntry(entryId);
  Future<core.IngestEntryView> restoreIngestEntry(int entryId) =>
      _api.restoreIngestEntry(entryId);
  Future<core.IngestEntryView> claimIngestEntry(
          int entryId, core.ClaimPayload body) =>
      _api.claimIngestEntry(entryId, body: body);

  // ---- 规则集 ----

  Future<List<core.RuleSetView>> ruleSets() => _api.ruleSets();
  Future<core.RuleSetView> createRuleSet(core.RuleSetPayload body) =>
      _api.createRuleSet(body: body);
  Future<core.RuleSetView> updateRuleSet(int id, core.RuleSetPayload body) =>
      _api.updateRuleSet(id, body: body);
  Future<core.RuleSetView> setDefaultRuleSet(int id) =>
      _api.setDefaultRuleSet(id);
  Future<void> deleteRuleSet(int id) => _api.deleteRuleSet(id);

  // ---- 刮削 ----

  Future<core.ScrapeConfigView> scrapeShow() => _api.scrapeShow();
  Future<core.ScrapeConfigView> scrapeSet(core.ScrapeSetting body) =>
      _api.scrapeSet(body: body);
  Future<core.ScrapeFanartView> scrapeFanartShow() => _api.scrapeFanartShow();
  Future<core.ScrapeFanartView> scrapeFanartSetKey(String key) =>
      _api.scrapeFanartSetKey(body: core.ScrapeFanartKeyPayload(key: key));
  Future<core.ScrapeStorageEstimate> scrapeStorageEstimate() =>
      _api.scrapeStorageEstimate();
  Future<List<core.ScrapeLanguageOption>> scrapeLanguages() =>
      _api.scrapeLanguages();
  Future<List<core.ScrapeCountryOption>> scrapeCountries() =>
      _api.scrapeCountries();

  // ---- Webhook ----

  Future<core.WebhookConfigView> webhookShow() => _api.webhookShow();
  Future<core.WebhookConfigView> webhookSet(core.WebhookConfigPayload body) =>
      _api.webhookSet(body: body);
  Future<core.WebhookDeliveryView> webhookTest(String endpointId) =>
      _api.webhookTest(endpointId);
  Future<List<core.WebhookDeliveryView>> webhookDeliveries(
          String endpointId) =>
      _api.webhookDeliveries(endpointId);

  // ---- LLM / MCP / AI 默认 / 联网搜索 / 搜索预设 ----

  Future<List<core.LlmProviderView>> llmProviders() => _api.llmProviders();
  Future<List<core.LlmPresetView>> llmPresets() => _api.llmPresets();
  Future<core.LlmProviderView> createLlmProvider(
          core.LlmProviderPayload body) =>
      _api.createLlmProvider(body: body);
  Future<core.LlmProviderView> updateLlmProvider(
          int id, core.LlmProviderPayload body) =>
      _api.updateLlmProvider(id, body: body);
  Future<core.LlmProviderView> verifyLlmProvider(int id) =>
      _api.verifyLlmProvider(id);
  Future<void> deleteLlmProvider(int id) => _api.deleteLlmProvider(id);
  Future<core.LlmDefaultsView> llmDefaultsShow() => _api.llmDefaultsShow();
  Future<core.LlmDefaultsView> llmDefaultsUpdate(
          core.LlmDefaultsPayload body) =>
      _api.llmDefaultsUpdate(body: body);
  Future<List<core.LlmModelOption>> llmModels() => _api.llmModels();
  Future<core.WebSearchConfig> webSearchShow() => _api.webSearchShow();
  Future<core.WebSearchConfig> webSearchUpdate(
          core.WebSearchSavePayload body) =>
      _api.webSearchUpdate(body: body);
  Future<core.WebSearchConfig> webSearchClear() => _api.webSearchClear();
  Future<core.WebSearchTestResult> webSearchTest(
          core.WebSearchTestPayload body) =>
      _api.webSearchTest(body: body);
  Future<core.McpStatusView> mcpStatus() => _api.mcpStatus();
  Future<core.McpStatusView> mcpToggle(bool enabled) =>
      _api.mcpToggle(body: core.McpToggleRequest(enabled: enabled));
  Future<core.SearchPresetsView> searchPresets() => _api.searchPresets();
  Future<core.SearchPresetsView> updateSearchPresets(
          core.SearchPresetsPayload body) =>
      _api.updateSearchPresets(body: body);

  // ---- 推送（App 推送 + IM 推送） ----

  Future<core.PushChannelsView> pushChannelsList() => _api.pushChannelsList();
  Future<core.PushChannelsView> pushChannelsOfficialSet(bool enabled) =>
      _api.pushChannelsOfficialSet(
          body: core.OfficialChannelRequest(enabled: enabled));
  Future<core.MyPushView> pushMe() => _api.pushMe();
  Future<core.MyPushView> pushPreferences(Map<String, bool> events) =>
      _api.pushPreferences(body: core.PushPreferencesBody(events: events));
  Future<core.PushTestView> pushTest() => _api.pushTest();
  Future<core.ChannelPushConfigView> imPushConfigGet() =>
      _api.channelsImPushConfigGet();
  Future<core.ChannelPushConfigView> imPushConfigUpdate(
          core.ChannelPushConfigView body) =>
      _api.channelsImPushConfigUpdate(body: body);

  // ---- 云 ----

  Future<core.CloudStatusView> cloudStatus() => _api.cloudStatus();
  Future<core.CloudStatusView> cloudRenew() => _api.cloudRenew();
  Future<core.CloudStatusView> cloudSettingsSet(
          core.CloudSettingsRequest body) =>
      _api.cloudSettingsSet(body: body);

  /// 断开云连接（web lib/api/cloud.ts：POST /cloud/disconnect）。
  Future<void> cloudDisconnect() async {
    await _client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '/api/v1/cloud/disconnect');
  }

  // ---- 应用（外部访问 / GitHub Token / 更新保留 / 识别模型更新） ----

  Future<core.AppConfig> appConfigShow() => _api.appConfigShow();
  Future<core.AppConfig> appConfigSave(core.AppConfigPayload body) =>
      _api.appConfigSave(body: body);
  Future<core.AppConfig> appPortSave(int? port) =>
      _api.appPortSave(body: core.WebPortPayload(port: port));
  Future<core.GithubToken> githubToken() => _api.githubToken();
  Future<core.GithubToken> saveGithubToken(String token) =>
      _api.saveGithubToken(body: core.GithubTokenPayload(token: token));
  Future<void> saveUpdateRetention(int keepVersions) =>
      _api.saveUpdateRetention(
          body: core.RetentionRequest(keepVersions: keepVersions));
  Future<core.ModelUpdateCheck> checkModelUpdate() =>
      _api.checkModelUpdate();
  Future<core.UpdateProgress> applyModelUpdate() => _api.applyModelUpdate();

  // ---- 网络 / 日志 / 定时任务 ----

  Future<core.NetworkConfig> networkConfig() => _api.networkConfig();
  Future<core.NetworkConfig> saveNetworkConfig(core.NetworkConfig body) =>
      _api.saveNetworkConfig(body: body);
  Future<core.NetworkTestResult> testNetwork(String service) =>
      _api.testNetwork(body: core.NetworkTestPayload(service: service));
  Future<core.LogDayList> logDays() => _api.logDays();
  Future<core.LogContent> logContent(String day) => _api.logContent(day);
  Future<List<core.ScheduledTask>> scheduledTasks() => _api.scheduledTasks();
  Future<core.ScheduledTask> updateScheduledTask(
          String key, core.ScheduledTaskUpdate body) =>
      _api.updateScheduledTask(key, body: body);

  // ---- 外观 ----

  Future<core.UiPreferencesSetting> uiPreferences() => _api.uiPreferences();
  Future<core.UiPreferencesSetting> updateUiPreferences(
          core.UiPreferencesSetting body) =>
      _api.updateUiPreferences(body: body);

  // ---- 设备激活（批准登录） ----

  /// GET /server/addresses：服务端监听地址一览。
  Future<core.ServerAddressesView> serverAddresses() =>
      _api.serverAddresses();

  Future<core.DeviceRequestView> deviceRequest(String userCode) =>
      _api.deviceRequest(userCode);
  Future<void> approveDeviceRequest(String userCode) =>
      _api.approveDeviceRequest(userCode);
  Future<void> denyDeviceRequest(String userCode) =>
      _api.denyDeviceRequest(userCode);

  // ---- 插件（typed McApi 未覆盖，走原始端点；见 web lib/api/plugins.ts） ----

  /// GET /app/plugins。
  Future<PluginsOverview> pluginsOverview() async =>
      PluginsOverview.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'GET', '/api/v1/app/plugins'));

  /// PUT /app/plugins/{id}/enabled。
  Future<void> setPluginEnabled(String id, bool enabled) async {
    await _client.unwrap<Map<String, dynamic>>(Channel.general, 'PUT',
        '/api/v1/app/plugins/$id/enabled',
        body: {'enabled': enabled});
  }

  /// POST /app/plugins/safe-mode/exit。
  Future<void> exitPluginSafeMode() async {
    await _client.unwrap<Map<String, dynamic>>(Channel.general, 'POST',
        '/api/v1/app/plugins/safe-mode/exit');
  }

  /// GET /app/features（功能目录与开关）。
  Future<List<PluginFeature>> pluginFeatures() async {
    final items = await _client.unwrapList(
        Channel.general, 'GET', '/api/v1/app/features');
    return items
        .whereType<Map<String, dynamic>>()
        .map(PluginFeature.fromJson)
        .toList();
  }

  /// PUT /app/features/{key}。
  Future<void> setPluginFeatureEnabled(String key, bool enabled) async {
    await _client.unwrap<Map<String, dynamic>>(Channel.general, 'PUT',
        '/api/v1/app/features/$key',
        body: {'enabled': enabled});
  }

  // ---- 网盘（typed McApi 未覆盖，走原始端点；见 web lib/api/drives.ts） ----

  /// GET /drives/status。
  Future<DriveStatus> driveStatus() async => DriveStatus.fromJson(
      await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'GET', '/api/v1/drives/status'));

  /// GET /drives/backends。
  Future<List<DriveBackend>> driveBackends() async {
    final items = await _client.unwrapList(
        Channel.general, 'GET', '/api/v1/drives/backends');
    return items
        .whereType<Map<String, dynamic>>()
        .map(DriveBackend.fromJson)
        .toList();
  }

  /// GET /drives/accounts。
  Future<List<DriveAccount>> driveAccounts() async {
    final items = await _client.unwrapList(
        Channel.general, 'GET', '/api/v1/drives/accounts');
    return items
        .whereType<Map<String, dynamic>>()
        .map(DriveAccount.fromJson)
        .toList();
  }

  /// GET /drives/settings。
  Future<DriveSettings> driveSettings() async => DriveSettings.fromJson(
      await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'GET', '/api/v1/drives/settings'));

  /// PUT /drives/settings。
  Future<DriveSettings> updateDriveSettings(DriveSettings body) async =>
      DriveSettings.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'PUT', '/api/v1/drives/settings',
          body: body.toJson()));

  /// POST /drives/accounts/{id}/refresh。
  Future<DriveAccount> refreshDriveAccount(int id) async =>
      DriveAccount.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'POST', '/api/v1/drives/accounts/$id/refresh'));

  /// DELETE /drives/accounts/{id}。
  Future<void> deleteDriveAccount(int id) async {
    await _client.unwrap<Map<String, dynamic>>(
        Channel.general, 'DELETE', '/api/v1/drives/accounts/$id');
  }

  /// POST /drives/logins：发起扫码登录，返回二维码。
  Future<DriveLogin> startDriveLogin(String backend) async =>
      DriveLogin.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'POST', '/api/v1/drives/logins',
          body: {'backend': backend}));

  /// GET /drives/logins/{loginId}：轮询扫码状态。
  Future<DriveLogin> driveLoginStatus(String loginId) async =>
      DriveLogin.fromJson(await _client.unwrap<Map<String, dynamic>>(
          Channel.general, 'GET', '/api/v1/drives/logins/$loginId'));
}
