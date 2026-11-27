import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/device_requests_api.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_store.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/settings_ui.dart';

class _DeviceCategory {
  const _DeviceCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<LoginDevice> items;
}

/// 我的设备页（1:1 对齐 iOS `DevicesSettingsView` + `DeviceTokenSheet` + `DeviceCleanupPopover`）：
/// - 管理员权限严格门控「创建 API 令牌」与「显示全部用户设备」；
/// - 批准配对码先 GET 核验终端身份再二次确认批准/拒绝；
/// - 4 分类（浏览器 / App / 配对设备与令牌 / 播放器）+ 搜索 + 15 秒轮询 + 设备详情（IP/首次登录/推送/90天休眠）+ 作用域清理。
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key, this.initialCode});

  /// 通过 `/activate?code=…` 或 `/settings/devices?code=…` 深度链接传入的配对码。
  final String? initialCode;

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  String _search = '';
  String? _selectedGroupId;
  bool _initialCodeHandled = false;

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        ref.read(devicesProvider.notifier).load(silent: true);
      }
    });
  }

  void _stopPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopPollTimer();
      case AppLifecycleState.resumed:
        _startPollTimer();
        if (mounted) {
          ref.read(devicesProvider.notifier).load(silent: true);
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(devicesProvider.notifier).load();
      if (!mounted || _initialCodeHandled) return;
      final code = widget.initialCode?.trim();
      if (code != null && code.isNotEmpty) {
        _initialCodeHandled = true;
        final perms = ref.read(permissionsProvider);
        final profile = ref.read(profileProvider).valueOrNull;
        final isAdmin = perms.isAdmin || (profile?.isAdmin ?? false);
        await _approveDevicePairing(isAdmin, prefilledCode: code);
      }
    });
    _startPollTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPollTimer();
    super.dispose();
  }

  List<_DeviceCategory> _categories(List<LoginDevice> all) => [
        _DeviceCategory(
          id: 'browser',
          title: '浏览器',
          icon: McIcons.globe,
          items: all.where((d) => d.groupId == 'browser').toList(),
        ),
        _DeviceCategory(
          id: 'app',
          title: 'App',
          icon: McIcons.iphone,
          items: all.where((d) => d.groupId == 'app').toList(),
        ),
        _DeviceCategory(
          id: 'paired',
          title: '配对设备与令牌',
          icon: McIcons.terminal,
          items: all.where((d) => d.groupId == 'paired').toList(),
        ),
        _DeviceCategory(
          id: 'player',
          title: '播放器',
          icon: McIcons.playCircle,
          items: all.where((d) => d.groupId == 'player').toList(),
        ),
      ];

  IconData _deviceIcon(LoginDevice d) {
    if (d.isTranscode) return McIcons.gpu;
    return switch (d.kind) {
      'ios' || 'android' => McIcons.iphone,
      'tvos' || 'androidtv' => McIcons.tv,
      'macos' => McIcons.computerFill,
      'web' => McIcons.globe,
      'jellyfin' => McIcons.playCircle,
      _ => McIcons.terminal,
    };
  }

  Future<void> _rename(LoginDevice d) async {
    final next = await textInputDialog(
      context,
      title: '重命名设备',
      initial: d.name,
      hint: '设备名称（最多 64 字）',
    );
    if (next == null || next.isEmpty || next == d.name) return;
    final trimmed = next.length > 64 ? next.substring(0, 64) : next;
    final err = await ref.read(devicesProvider.notifier).rename(d.id, trimmed);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已重命名');
  }

  Future<void> _revoke(LoginDevice d) async {
    if (d.current) {
      final ok = await confirmDialog(
        context,
        title: '退出当前设备登录？',
        message: '将注销本机的当前登录会话。',
        confirmLabel: '退出登录',
      );
      if (!ok || !mounted) return;
      await appSession.logoutCurrentAccount(autoSwitchSibling: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: '注销「${d.title}」？',
      message: d.isTranscode
          ? '注销后该远程转码节点会立刻断开，无法再接取转码任务。'
          : '注销后该终端需要重新登录才能访问服务器。',
      confirmLabel: '注销',
    );
    if (!ok || !mounted) return;
    final err = await ref.read(devicesProvider.notifier).revoke(d.id);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已注销');
  }

  void _openDeviceDetail(LoginDevice d, {required bool showAll}) {
    final createdDt =
        d.createdAt != null ? DateTime.tryParse(d.createdAt!) : null;
    final seenDt =
        d.lastSeenAt != null ? DateTime.tryParse(d.lastSeenAt!) : null;
    final statusText = d.current
        ? '本机（当前设备）'
        : d.isLive
            ? (d.isTranscode ? '已连接' : '在线')
            : '离线';

    showMcSheet<void>(
      context: context,
      maxWidth: 560,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            McInsetGroup(
              header: d.title,
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  title: '设备类型',
                  valueText: d.kindLabel.isNotEmpty ? d.kindLabel : d.kind,
                ),
                McInsetRow(
                  title: '连接状态',
                  trailing: SettingsStatusBadge(
                    label: statusText,
                    tone: d.isLive ? SettingsTone.ok : SettingsTone.neutral,
                    showDot: true,
                  ),
                ),
                if (showAll && d.ownerNickname.isNotEmpty)
                  McInsetRow(title: '所属成员', valueText: d.ownerNickname),
                if (d.platform != null && d.platform!.isNotEmpty)
                  McInsetRow(title: '系统平台', valueText: d.platform!),
                if (d.clientVersion != null && d.clientVersion!.isNotEmpty)
                  McInsetRow(title: '客户端版本', valueText: d.clientVersion!),
                McInsetRow(
                  title: '授权范围',
                  valueText: d.scope == 'transcode' ? '仅限远程转码' : '与账号权限一致',
                ),
              ],
            ),
            const SizedBox(height: 12),
            McInsetGroup(
              header: '活跃记录',
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  title: '最近活跃',
                  valueText: seenDt != null
                      ? McFormatting.relative(seenDt)
                      : '未知',
                ),
                if (d.lastSeenIp != null && d.lastSeenIp!.isNotEmpty)
                  McInsetRow(
                    title: '来源 IP',
                    valueText: d.lastSeenIp!,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: d.lastSeenIp!));
                      McToast.success('已复制 IP');
                    },
                  ),
                McInsetRow(
                  title: '首次登录',
                  valueText: createdDt != null
                      ? McFormatting.dateTime(createdDt)
                      : '未知',
                ),
              ],
            ),
            if (d.push != null && d.push!.statusText.isNotEmpty) ...[
              const SizedBox(height: 12),
              McInsetGroup(
                header: '手机推送状态',
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    icon: d.push!.status == 'ok'
                        ? McIcons.bellOn
                        : McIcons.bellOff,
                    iconColor: d.push!.status == 'ok'
                        ? McTokens.ok
                        : McTokens.warning,
                    title: d.push!.statusText,
                  ),
                ],
              ),
            ],
            if (d.isDormant) ...[
              const SizedBox(height: 12),
              const SettingsNoticeBanner(
                text: '该设备已超过 90 天未活跃。如不再使用，建议手动注销以确保账号安全。',
                tone: SettingsTone.warn,
                margin: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 14),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                if (d.renamable)
                  McInsetRow(
                    icon: McIcons.edit2,
                    title: '重命名设备',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _rename(d);
                    },
                  ),
                McInsetRow(
                  icon: McIcons.logout,
                  title: d.current ? '退出本机登录' : '注销此设备',
                  destructive: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _revoke(d);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// P0 修复：批准配对码前必须先 GET /api/v1/auth/devices/requests/{code} 核验设备身份，禁止盲批！
  Future<void> _approveDevicePairing(
    bool isAdmin, {
    String? prefilledCode,
  }) async {
    final rawCode = (prefilledCode != null && prefilledCode.trim().isNotEmpty)
        ? prefilledCode
        : await textInputDialog(
            context,
            title: '输入设备配对码',
            hint: '输入电视 / 桌面端 / 转码器屏幕显示的配对码',
          );
    if (rawCode == null || rawCode.trim().isEmpty || !mounted) return;
    final code = rawCode.trim().toUpperCase();
    final api = ref.read(deviceRequestsApiProvider);

    DeviceRequestView req;
    try {
      req = await api.request(code);
    } catch (e) {
      if (mounted) McToast.error('查询配对码失败：${settingsErrorText(e)}');
      return;
    }
    if (!mounted) return;

    final typeLabel = switch (req.clientType) {
      'worker' => '远程转码器',
      'cli' => '命令行工具 (CLI)',
      'tvos' => 'Apple TV',
      'macos' => 'Mac 客户端',
      'androidtv' => 'Android TV',
      'manual' => '手动令牌',
      _ => req.clientType ?? '未知终端',
    };
    final grantHint = req.clientType == 'worker'
        ? '仅授予远程转码权限（无法浏览媒体库或修改配置）'
        : isAdmin
            ? '将获得与你的超级管理员账号相同的完全权限'
            : '将获得与你的成员账号相同的访问权限';

    final action = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('核对并批准设备接入', style: McText.titleSm),
            const SizedBox(height: 12),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(title: '配对码', valueText: req.userCode),
                McInsetRow(title: '终端类型', valueText: typeLabel),
                if (req.clientName != null && req.clientName!.isNotEmpty)
                  McInsetRow(title: '设备名称', valueText: req.clientName!),
                if (req.sourceIp != null && req.sourceIp!.isNotEmpty)
                  McInsetRow(title: '来源 IP', valueText: req.sourceIp!),
                if (req.platform != null && req.platform!.isNotEmpty)
                  McInsetRow(title: '系统', valueText: req.platform!),
                if (req.clientVersion != null && req.clientVersion!.isNotEmpty)
                  McInsetRow(title: '版本', valueText: req.clientVersion!),
              ],
            ),
            const SizedBox(height: 10),
            SettingsNoticeBanner(
              text: req.requiresAdmin && !isAdmin
                  ? '该接入请求需要管理员身份批准，你的当前账号无权批准。'
                  : grantHint,
              tone: req.requiresAdmin && !isAdmin
                  ? SettingsTone.danger
                  : SettingsTone.warn,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '拒绝请求',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop('deny'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: McActionPill(
                    label: '确认批准',
                    primary: true,
                    expanded: true,
                    onTap: (req.requiresAdmin && !isAdmin)
                        ? null
                        : () => Navigator.of(ctx).pop('approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'approve') {
        await api.approve(code);
        McToast.success('已批准该设备登录');
      } else {
        await api.deny(code);
        McToast.info('已拒绝该设备的接入请求');
      }
      await ref.read(devicesProvider.notifier).load();
    } catch (e) {
      McToast.error('操作失败：${settingsErrorText(e)}');
    }
  }

  /// 创建手工 API 令牌（仅管理员）：支持 `scope: full | transcode` + 一次性令牌与 CLI 参数展示 + 关闭防误触确认。
  Future<void> _openCreateTokenSheet() async {
    final mc = ref.read(mcClientProvider);
    var externalUrl = '';
    try {
      final cfg = await mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/app/config',
      );
      externalUrl = (cfg['external_url'] ?? '').toString().trim();
    } catch (_) {}
    if (!mounted) return;

    final nameCtrl = TextEditingController();
    var scope = 'full';
    var busy = false;
    String? err;
    Map<String, dynamic>? created;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB8000000),
      constraints: const BoxConstraints(maxWidth: 580),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (created != null) {
            final token = (created!['token'] ?? created!['access_token'] ?? '')
                .toString();
            final tokenScope = (created!['scope'] ?? scope).toString();
            final address = externalUrl.isNotEmpty
                ? externalUrl
                : (appSession.baseUrl ?? 'http://your-nas:8000');
            final isTranscode = tokenScope == 'transcode';
            final snippet = isTranscode
                ? '--nas-url $address --token $token'
                : 'MOVIECLAW_SERVER=$address\nMOVIECLAW_TOKEN=$token';

            return McSheetFrame(
              title: '保存一次性 API 令牌',
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsNoticeBanner(
                      text:
                          '已创建令牌「${created!['name'] ?? nameCtrl.text.trim()}」。明文令牌仅本次展示，关闭后无法再次查看。',
                      tone: SettingsTone.ok,
                      margin: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 14),
                    Text('访问令牌', style: McText.caption.muted),
                    const SizedBox(height: 6),
                    SettingsCopyBox(value: token, copyLabel: '复制令牌'),
                    const SizedBox(height: 14),
                    Text(
                      isTranscode ? '远程转码器启动参数' : '环境变量片段',
                      style: McText.caption.muted,
                    ),
                    const SizedBox(height: 6),
                    SettingsCodeBlock(
                      code: snippet,
                      lang: isTranscode ? 'CLI' : 'ENV',
                    ),
                    if (externalUrl.isEmpty) ...[
                      const SizedBox(height: 10),
                      const SettingsNoticeBanner(
                        text: '尚未配置「外部访问地址」，当前使用本机连接地址，跨网段使用请先在网络设置中填写外部地址。',
                        tone: SettingsTone.warn,
                        margin: EdgeInsets.zero,
                      ),
                    ],
                    const SizedBox(height: 18),
                    McActionPill(
                      label: '完成',
                      primary: true,
                      expanded: true,
                      onTap: () async {
                        final ok = await confirmDialog(
                          ctx,
                          title: '确认已经保存令牌？',
                          message: '关闭后无法再找回这段明文令牌，遗失只能注销并重新生成。',
                          confirmLabel: '我已保存',
                          destructive: false,
                        );
                        if (ok && ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final trimmed = nameCtrl.text.trim();
          return McSheetFrame(
            title: '创建手动 API 令牌',
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (err != null) ...[
                    SettingsNoticeBanner(
                      text: err!,
                      tone: SettingsTone.danger,
                      margin: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameCtrl,
                    maxLength: 64,
                    decoration: const InputDecoration(
                      labelText: '令牌名称 *',
                      hintText: '例如：书房转码节点 / 自动化脚本',
                    ),
                    onChanged: (_) => setSheet(() => err = null),
                  ),
                  const SizedBox(height: 10),
                  Text('令牌权限范围 (scope)', style: McText.caption.muted),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      McChip(
                        label: '完全权限 (full)',
                        compact: true,
                        selected: scope == 'full',
                        onTap: () => setSheet(() => scope = 'full'),
                      ),
                      McChip(
                        label: '仅限远程转码 (transcode)',
                        compact: true,
                        selected: scope == 'transcode',
                        onTap: () => setSheet(() => scope = 'transcode'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scope == 'transcode'
                        ? '仅允许连接转码调度器领取转码任务，不能读取媒体库或修改服务器设置。'
                        : '拥有与管理员账号完全相同的 API 操作权限，请仅用于可信环境。',
                    style: McText.caption.faint,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: McActionPill(
                          label: '取消',
                          primary: false,
                          expanded: true,
                          onTap: busy ? null : () => Navigator.of(ctx).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: McActionPill(
                          label: busy ? '创建中…' : '创建令牌',
                          primary: true,
                          expanded: true,
                          onTap: (busy || trimmed.isEmpty)
                              ? null
                              : () async {
                                  setSheet(() {
                                    busy = true;
                                    err = null;
                                  });
                                  try {
                                    final res = await mc
                                        .unwrap<Map<String, dynamic>>(
                                      Channel.general,
                                      'POST',
                                      '/api/v1/auth/tokens',
                                      body: {'name': trimmed, 'scope': scope},
                                    );
                                    setSheet(() {
                                      created = res;
                                      busy = false;
                                    });
                                    ref.read(devicesProvider.notifier).load();
                                  } catch (e) {
                                    setSheet(() {
                                      busy = false;
                                      err = settingsErrorText(e);
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nameCtrl.dispose();
  }

  /// 清理长期不活跃设备：透传真实 `all` 标志 + 预览设备名单 + 按当前分类安全逐台注销。
  Future<void> _openCleanupSheet(_DeviceCategory? scopedGroup, bool showAll) async {
    var days = 30;
    var loading = true;
    var busy = false;
    var fetched = false;
    var sheetClosed = false;
    var previewSeq = 0;
    String? err;
    List<DeviceCleanupItem> candidates = const [];

    Future<void> fetchPreview(StateSetter setSheet) async {
      final seq = ++previewSeq;
      if (sheetClosed || !mounted) return;
      setSheet(() {
        loading = true;
        err = null;
      });
      final res = await ref.read(devicesProvider.notifier).cleanup(
            days,
            all: showAll,
            dryRun: true,
          );
      if (sheetClosed || !mounted || seq != previewSeq) return;
      if (res is DeviceCleanupView) {
        final allowedIds = scopedGroup?.items.map((e) => e.id).toSet();
        setSheet(() {
          candidates = allowedIds == null
              ? res.devices
              : res.devices.where((d) => allowedIds.contains(d.id)).toList();
          loading = false;
        });
      } else {
        setSheet(() {
          loading = false;
          err = res.toString();
        });
      }
    }

    await showMcSheet<void>(
      context: context,
      maxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (!fetched) {
            fetched = true;
            Future.microtask(() => fetchPreview(setSheet));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  scopedGroup != null
                      ? '清理长期未活跃的「${scopedGroup.title}」'
                      : '清理长期未活跃的设备',
                  style: McText.titleSm,
                ),
                const SizedBox(height: 4),
                Text(
                  showAll ? '范围：全部成员设备' : '范围：仅我的设备',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in const [7, 30, 90])
                      McChip(
                        label: '$d 天未活动',
                        compact: true,
                        selected: days == d,
                        onTap: busy
                            ? null
                            : () {
                                days = d;
                                fetchPreview(setSheet);
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (err != null)
                  SettingsNoticeBanner(
                    text: err!,
                    tone: SettingsTone.danger,
                    margin: EdgeInsets.zero,
                  )
                else if (candidates.isEmpty)
                  const SettingsNoticeBanner(
                    text: '当前范围内没有超过该天数未活动的设备。',
                    tone: SettingsTone.ok,
                    margin: EdgeInsets.zero,
                  )
                else ...[
                  Text(
                    '将注销以下 ${candidates.length} 台设备（$days 天未活动）：',
                    style: McText.sub.semibold,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (_, idx) {
                        final item = candidates[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name, style: McText.sub),
                          subtitle: showAll && item.ownerNickname.isNotEmpty
                              ? Text(item.ownerNickname,
                                  style: McText.micro.faint)
                              : null,
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                McActionPill(
                  label: busy
                      ? '正在注销…'
                      : '确认注销 ${candidates.length} 台设备',
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  onTap: (busy || loading || candidates.isEmpty)
                      ? null
                      : () async {
                          final ok = await confirmDialog(
                            ctx,
                            title: '确认批量注销 ${candidates.length} 台设备？',
                            message: '注销后这些设备将立即掉线并需重新登录。',
                            confirmLabel: '确认清理',
                          );
                          if (!ok) return;
                          setSheet(() => busy = true);
                          var done = 0;
                          try {
                            for (final item in candidates) {
                              await ref
                                  .read(devicesProvider.notifier)
                                  .revoke(item.id);
                              done++;
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            McToast.success('已清理 $done 台不活跃设备');
                          } catch (e) {
                            setSheet(() {
                              busy = false;
                              err = '已清理 $done 台，其余失败：${settingsErrorText(e)}';
                            });
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
    sheetClosed = true;
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final isAdmin = perms.isAdmin || (profile?.isAdmin ?? false);

    final state = ref.watch(devicesProvider);
    final data = state.valueOrNull;
    final showAll = isAdmin && (data?.showAll ?? false);
    final items = data?.items ?? const <LoginDevice>[];
    final cats = _categories(items);

    final currentDevice = items.cast<LoginDevice?>().firstWhere(
          (d) => d!.current,
          orElse: () => null,
        );

    final activeGroup = _selectedGroupId == null
        ? null
        : cats.firstWhere(
            (c) => c.id == _selectedGroupId,
            orElse: () => cats.first,
          );

    return PopScope(
      canPop: activeGroup == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && activeGroup != null) {
          setState(() {
            _selectedGroupId = null;
            _search = '';
          });
        }
      },
      child: SettingsScaffold(
        title: activeGroup != null ? activeGroup.title : '我的设备',
        onBack: activeGroup != null
            ? () => setState(() {
                  _selectedGroupId = null;
                  _search = '';
                })
            : null,
        actions: [
          if (activeGroup != null) ...[
            McChip(
              label: '返回分类',
              compact: true,
              onTap: () => setState(() {
                _selectedGroupId = null;
                _search = '';
              }),
            ),
            const SizedBox(width: 6),
            McChip(
              icon: McIcons.eraser,
              label: '清理',
              compact: true,
              onTap: () => _openCleanupSheet(activeGroup, showAll),
            ),
          ] else
            McChip(
              icon: McIcons.qrCodeFill,
              label: '批准配对码',
              selected: true,
              compact: true,
              onTap: () => _approveDevicePairing(isAdmin),
            ),
        ],
        body: state.isLoading && items.isEmpty
            ? const McLoadingView()
            : state.hasError && items.isEmpty
                ? McErrorView(
                    text: '加载设备列表失败',
                    onRetry: () => ref.read(devicesProvider.notifier).load(),
                  )
                : activeGroup != null
                    ? _buildGroupDetailList(activeGroup, showAll)
                    : _buildOverviewList(
                        isAdmin: isAdmin,
                        showAll: showAll,
                        currentDevice: currentDevice,
                        categories: cats,
                      ),
      ),
    );
  }

  Widget _buildOverviewList({
    required bool isAdmin,
    required bool showAll,
    required LoginDevice? currentDevice,
    required List<_DeviceCategory> categories,
  }) {
    return RefreshIndicator(
      onRefresh: () => ref.read(devicesProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          McInsetGroup(
            children: [
              McInsetRow(
                icon: McIcons.qrCodeFill,
                title: '输入配对码批准新终端登录',
                subtitle: '先核验终端信息再授权，支持电视、Mac 与转码器',
                onTap: () => _approveDevicePairing(isAdmin),
              ),
              if (isAdmin)
                McInsetRow(
                  icon: McIcons.key,
                  title: '创建手动 API 令牌',
                  subtitle: '生成完全权限或仅限远程转码的一次性访问令牌',
                  onTap: _openCreateTokenSheet,
                ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 14),
            McInsetGroup(
              children: [
                McInsetRow(
                  icon: McIcons.team,
                  title: '显示全部成员的设备',
                  subtitle: showAll ? '当前显示所有家庭成员的终端' : '当前仅显示我的设备',
                  trailing: Switch(
                    value: showAll,
                    onChanged: (v) =>
                        ref.read(devicesProvider.notifier).setShowAll(v),
                  ),
                  onTap: () =>
                      ref.read(devicesProvider.notifier).setShowAll(!showAll),
                ),
              ],
            ),
          ],
          if (currentDevice != null) ...[
            const SizedBox(height: 16),
            McInsetGroup(
              header: '当前设备',
              children: [_buildDeviceRow(currentDevice, showAll: showAll)],
            ),
          ],
          const SizedBox(height: 16),
          McInsetGroup(
            header: showAll ? '全部成员设备分类' : '我的设备分类',
            footer: '列表每 15 秒自动刷新在线状态；点入分类可搜索或按分类清理不活跃终端。',
            children: [
              for (final cat in categories)
                Builder(
                  builder: (context) {
                    final onlineCount =
                        cat.items.where((d) => d.isLive).length;
                    return McInsetRow(
                      icon: cat.icon,
                      title: cat.title,
                      subtitle: '${cat.items.length} 台设备 · $onlineCount 台在线',
                      showChevron: true,
                      onTap: () => setState(() {
                        _selectedGroupId = cat.id;
                        _search = '';
                      }),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            child: McActionPill(
              icon: McIcons.eraser,
              label: '清理长期未活跃的设备',
              primary: false,
              expanded: true,
              onTap: () => _openCleanupSheet(null, showAll),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDetailList(_DeviceCategory group, bool showAll) {
    final kw = _search.trim().toLowerCase();
    final filtered = group.items.where((d) {
      if (kw.isEmpty) return true;
      return d.title.toLowerCase().contains(kw) ||
          d.ownerNickname.toLowerCase().contains(kw) ||
          (d.platform ?? '').toLowerCase().contains(kw);
    }).toList();
    final online = filtered.where((d) => d.isLive).toList();
    final offline = filtered.where((d) => !d.isLive).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(devicesProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(McIcons.search, size: 17),
                hintText: showAll ? '搜索设备名、成员或系统…' : '搜索设备名或系统…',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            McEmptyView(
              icon: group.icon,
              title: kw.isEmpty ? '暂无${group.title}' : '没有匹配的设备',
              text: kw.isEmpty ? '该分类下暂无已登录终端。' : '请尝试调整搜索关键词。',
            )
          else ...[
            if (online.isNotEmpty) ...[
              McInsetGroup(
                header: '在线 (${online.length})',
                children: [
                  for (final d in online) _buildDeviceRow(d, showAll: showAll),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (offline.isNotEmpty)
              McInsetGroup(
                header: '离线 (${offline.length})',
                children: [
                  for (final d in offline) _buildDeviceRow(d, showAll: showAll),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceRow(LoginDevice d, {required bool showAll}) {
    return McInsetRow(
      icon: _deviceIcon(d),
      iconColor: d.isLive ? McTokens.accentStrong : McTokens.textMuted,
      title: d.title,
      subtitle: d.subtitleFor(showOwner: showAll),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.current)
            const SettingsStatusBadge(label: '当前', tone: SettingsTone.ok),
          if (d.isTranscode) ...[
            const SizedBox(width: 4),
            const SettingsStatusBadge(label: '转码', tone: SettingsTone.info),
          ],
          if (d.isDormant) ...[
            const SizedBox(width: 4),
            const SettingsStatusBadge(label: '休眠', tone: SettingsTone.warn),
          ],
        ],
      ),
      showChevron: true,
      onTap: () => _openDeviceDetail(d, showAll: showAll),
    );
  }
}
