import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../widgets/settings_ui.dart';

// ── MovieClaw Cloud 数据模型 ───────────────────────────────────────────────

class CloudPairingData {
  const CloudPairingData({
    required this.status,
    this.userCode = '',
    this.verificationUriComplete = '',
    this.expiresAt = '',
    this.instanceName,
    this.message,
  });

  factory CloudPairingData.fromJson(Map<String, dynamic> j) => CloudPairingData(
        status: (j['status'] ?? '').toString(),
        userCode: (j['user_code'] ?? j['userCode'] ?? '').toString(),
        verificationUriComplete: (j['verification_uri_complete'] ??
                j['verificationUriComplete'] ??
                j['verification_uri'] ??
                '')
            .toString(),
        expiresAt: (j['expires_at'] ?? j['expiresAt'] ?? '').toString(),
        instanceName:
            (j['instance_name'] ?? j['instanceName'])?.toString(),
        message: j['message']?.toString(),
      );

  final String status;
  final String userCode;
  final String verificationUriComplete;
  final String expiresAt;
  final String? instanceName;
  final String? message;

  bool get isPending => status == 'pending';
}

class CloudConnectionInfo {
  const CloudConnectionInfo({
    this.instanceName = '',
    this.accountDisplay = '',
    this.connectedAt,
    this.scopes = const [],
    this.limits = const {},
  });

  factory CloudConnectionInfo.fromJson(Map<String, dynamic> j) {
    final rawLimits = j['limits'];
    final limits = <String, int>{};
    if (rawLimits is Map) {
      for (final e in rawLimits.entries) {
        final v = e.value;
        if (v is num) limits[e.key.toString()] = v.toInt();
      }
    }
    return CloudConnectionInfo(
      instanceName: (j['instance_name'] ?? j['instanceName'] ?? '').toString(),
      accountDisplay:
          (j['account_display'] ?? j['accountDisplay'] ?? '').toString(),
      connectedAt: (j['connected_at'] ?? j['connectedAt'])?.toString(),
      scopes: ((j['scopes'] ?? const []) as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      limits: limits,
    );
  }

  final String instanceName;
  final String accountDisplay;
  final String? connectedAt;
  final List<String> scopes;
  final Map<String, int> limits;
}

class CloudNoticeData {
  const CloudNoticeData({
    required this.id,
    this.level = 'info',
    this.message = '',
  });

  factory CloudNoticeData.fromJson(Map<String, dynamic> j) => CloudNoticeData(
        id: (j['id'] ?? '').toString(),
        level: (j['level'] ?? 'info').toString(),
        message: (j['message'] ?? '').toString(),
      );

  final String id;
  final String level;
  final String message;
}

class CloudStatusData {
  const CloudStatusData({
    this.state = 'disconnected',
    this.health,
    this.healthMessage,
    this.serverName = '',
    this.cloudUrl = 'https://api.movieclaw.io',
    this.customCloudUrl = false,
    this.reportStats = false,
    this.connection,
    this.pairing,
    this.lastDisconnectMessage,
    this.notices = const [],
  });

  factory CloudStatusData.fromJson(Map<String, dynamic> j) {
    final connRaw = j['connection'];
    final pairRaw = j['pairing'];
    final lastDiscRaw = j['last_disconnect'] ?? j['lastDisconnect'];
    return CloudStatusData(
      state: (j['state'] ?? 'disconnected').toString(),
      health: j['health']?.toString(),
      healthMessage:
          (j['health_message'] ?? j['healthMessage'])?.toString(),
      serverName: (j['server_name'] ?? j['serverName'] ?? '').toString(),
      cloudUrl: (j['cloud_url'] ?? j['cloudUrl'] ?? 'https://api.movieclaw.io')
          .toString(),
      customCloudUrl:
          j['custom_cloud_url'] == true || j['customCloudUrl'] == true,
      reportStats: j['report_stats'] == true || j['reportStats'] == true,
      connection: connRaw is Map
          ? CloudConnectionInfo.fromJson(Map<String, dynamic>.from(connRaw))
          : null,
      pairing: pairRaw is Map
          ? CloudPairingData.fromJson(Map<String, dynamic>.from(pairRaw))
          : null,
      lastDisconnectMessage: lastDiscRaw is Map
          ? (lastDiscRaw['message'] ?? '').toString()
          : null,
      notices: ((j['notices'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => CloudNoticeData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  final String state;
  final String? health;
  final String? healthMessage;
  final String serverName;
  final String cloudUrl;
  final bool customCloudUrl;
  final bool reportStats;
  final CloudConnectionInfo? connection;
  final CloudPairingData? pairing;
  final String? lastDisconnectMessage;
  final List<CloudNoticeData> notices;

  bool get isConnected => state == 'connected';
  CloudPairingData? get pendingPairing =>
      (!isConnected && pairing != null && pairing!.isPending) ? pairing : null;
  CloudPairingData? get endedPairing =>
      (!isConnected && pairing != null && !pairing!.isPending) ? pairing : null;

  CloudStatusData copyWith({bool? reportStats}) => CloudStatusData(
        state: state,
        health: health,
        healthMessage: healthMessage,
        serverName: serverName,
        cloudUrl: cloudUrl,
        customCloudUrl: customCloudUrl,
        reportStats: reportStats ?? this.reportStats,
        connection: connection,
        pairing: pairing,
        lastDisconnectMessage: lastDisconnectMessage,
        notices: notices,
      );

  /// 官网 URL（去 `api.` 前缀，兜底 `https://movieclaw.io`）。
  String siteUrl(String path, {String? fragment}) {
    final parsed = Uri.tryParse(cloudUrl);
    if (parsed == null ||
        parsed.host.isEmpty ||
        !(parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return 'https://movieclaw.io$path${fragment != null ? '#$fragment' : ''}';
    }
    final host =
        parsed.host.startsWith('api.') ? parsed.host.substring(4) : parsed.host;
    return Uri(
      scheme: parsed.scheme,
      host: host,
      port: parsed.hasPort ? parsed.port : null,
      path: path,
      fragment: fragment,
    ).toString();
  }

  String get reportsInfoUrl => siteUrl('/zh/privacy', fragment: 'server-reports');
  String get accountSettingsUrl => siteUrl('/zh/settings');
}

// ── 共享 Cloud 连接控制器（CloudSettingsPage 与 NotificationSettingsPage 共用）──

class CloudConnectionController extends ChangeNotifier {
  CloudConnectionController(this._client);

  final McClient _client;

  CloudStatusData? _status;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _pollTimer;
  bool _disposed = false;

  CloudStatusData? get status => _status;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  bool get isConnected => _status?.isConnected ?? false;

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _syncPolling() {
    final shouldPoll = _status?.pendingPairing != null;
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(load(silent: true));
      });
    } else if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && _status == null) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/cloud',
      );
      _apply(CloudStatusData.fromJson(raw));
    } catch (e) {
      if (_status == null) {
        _error = settingsErrorText(e);
      }
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// 发起配对：`POST /api/v1/cloud/pairing`（兼容旧路径 `/api/v1/cloud/pairing/start`）。
  Future<CloudStatusData> startPairing({String? instanceName}) async {
    _busy = true;
    _notify();
    try {
      final trimmed = instanceName?.trim();
      final body = <String, dynamic>{
        if (trimmed != null && trimmed.isNotEmpty) 'instance_name': trimmed,
      };
      Map<String, dynamic> raw;
      try {
        raw = await _client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/cloud/pairing',
          body: body,
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 404 || e.httpStatus == 405) {
          raw = await _client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'POST',
            '/api/v1/cloud/pairing/start',
            body: body,
          );
        } else {
          rethrow;
        }
      }
      final next = CloudStatusData.fromJson(raw);
      _apply(next);
      return next;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// 取消配对：`DELETE /api/v1/cloud/pairing`（兼容旧路径 `POST /api/v1/cloud/pairing/cancel`）。
  Future<void> cancelPairing() async {
    _busy = true;
    _notify();
    try {
      Map<String, dynamic> raw;
      try {
        raw = await _client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'DELETE',
          '/api/v1/cloud/pairing',
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 404 || e.httpStatus == 405) {
          raw = await _client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'POST',
            '/api/v1/cloud/pairing/cancel',
          );
        } else {
          rethrow;
        }
      }
      _apply(CloudStatusData.fromJson(raw));
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> renew() async {
    _busy = true;
    _notify();
    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/cloud/renew',
      );
      _apply(CloudStatusData.fromJson(raw));
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// 断开连接；若云端不可达且未带 `force`，后端返回 HTTP 409 `CLOUD_UNREACHABLE`。
  Future<void> disconnect({bool force = false}) async {
    _busy = true;
    _notify();
    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/cloud/disconnect',
        body: force ? const {'force': true} : const <String, dynamic>{},
      );
      _apply(CloudStatusData.fromJson(raw));
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> dismissNotice(String noticeId) async {
    _busy = true;
    _notify();
    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/cloud/notices/${Uri.encodeComponent(noticeId)}/dismiss',
      );
      _apply(CloudStatusData.fromJson(raw));
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> setReportStats(bool value) async {
    final prev = _status;
    if (prev == null) return;
    _status = prev.copyWith(reportStats: value);
    _busy = true;
    _notify();
    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/cloud/settings',
        body: {'report_stats': value},
      );
      _apply(CloudStatusData.fromJson(raw));
    } catch (_) {
      _status = prev;
      rethrow;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _apply(CloudStatusData next) {
    _status = next;
    _error = null;
    _syncPolling();
    _notify();
  }
}

/// 复用配对卡片：配对码 + 打开官网批准页 + 1 秒倒计时 + 取消 / 失败重试。
class CloudPairingPanel extends StatefulWidget {
  const CloudPairingPanel({
    super.key,
    required this.controller,
  });

  final CloudConnectionController controller;

  @override
  State<CloudPairingPanel> createState() => _CloudPairingPanelState();
}

class _CloudPairingPanelState extends State<CloudPairingPanel> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  String _expiryText(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final sec = dt.toLocal().difference(DateTime.now()).inSeconds;
    if (sec <= 0) return '配对码已过期';
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '配对码 $m:$s 后失效';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.status;
    final pending = status?.pendingPairing;
    final ended = status?.endedPairing;

    if (pending != null) {
      return McInsetGroup(
        header: '等待在官网批准',
        footer: '请在浏览器中核对配对码并点「批准」，完成后回到本页会自动生效。',
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('配对码', style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    SelectableText(
                      pending.userCode,
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: pending.userCode),
                        );
                        McToast.success('已复制配对码');
                      },
                      style: McText.display.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 4,
                        color: McTokens.accentStrong,
                      ),
                    ),
                    McGlassIconButton(
                      icon: McIcons.fileCopy2Fill,
                      size: 36,
                      iconSize: 16,
                      tooltip: '复制配对码',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: pending.userCode),
                        );
                        McToast.success('已复制配对码');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                McActionPill(
                  icon: McIcons.globe,
                  label: '打开官网批准页',
                  primary: true,
                  expanded: true,
                  onTap: () => openExternalUrl(
                    context,
                    pending.verificationUriComplete,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('等待批准中…', style: McText.caption.muted),
                    const Spacer(),
                    Text(
                      _expiryText(pending.expiresAt),
                      style: McText.caption.tabular.faint,
                    ),
                  ],
                ),
              ],
            ),
          ),
          McInsetRow(
            icon: McIcons.close,
            title: '取消本次配对',
            destructive: true,
            onTap: widget.controller.busy
                ? null
                : () async {
                    try {
                      await widget.controller.cancelPairing();
                    } catch (e) {
                      McToast.error(settingsErrorText(e));
                    }
                  },
          ),
        ],
      );
    }

    if (ended != null) {
      final msg = (ended.message != null && ended.message!.isNotEmpty)
          ? ended.message!
          : switch (ended.status) {
              'denied' => '官网已拒绝本次连接请求。',
              'expired' => '配对码已过期，请重新获取。',
              _ => '本次连接未完成，请重试。',
            };
      return Column(
        children: [
          SettingsNoticeBanner(
            text: msg,
            tone: ended.status == 'denied'
                ? SettingsTone.warn
                : SettingsTone.danger,
          ),
          const SizedBox(height: 8),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            child: McActionPill(
              icon: McIcons.refreshS,
              label: '重新获取配对码',
              primary: true,
              expanded: true,
              onTap: widget.controller.busy
                  ? null
                  : () async {
                      try {
                        final next = await widget.controller.startPairing(
                          instanceName: ended.instanceName,
                        );
                        final uri =
                            next.pendingPairing?.verificationUriComplete ?? '';
                        if (context.mounted && uri.isNotEmpty) {
                          await openExternalUrl(context, uri);
                        }
                      } catch (e) {
                        McToast.error(settingsErrorText(e));
                      }
                    },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ── MovieClaw Cloud 主页面 ─────────────────────────────────────────────────

/// 设置 → MovieClaw Cloud（管理员）：
/// 连接服务器到管理员的 MovieClaw 账号，提供官方手机推送通道。
class CloudSettingsPage extends ConsumerStatefulWidget {
  const CloudSettingsPage({super.key});

  @override
  ConsumerState<CloudSettingsPage> createState() => _CloudSettingsPageState();
}

class _CloudSettingsPageState extends ConsumerState<CloudSettingsPage> {
  late final CloudConnectionController _ctrl;
  bool _wasConnected = false;

  @override
  void initState() {
    super.initState();
    _ctrl = CloudConnectionController(ref.read(mcClientProvider));
    _ctrl.addListener(_onChanged);
    Future.microtask(_ctrl.load);
  }

  void _onChanged() {
    if (!mounted) return;
    final nowConnected = _ctrl.isConnected;
    if (!_wasConnected && nowConnected && _ctrl.status != null) {
      McToast.success('已连接到 MovieClaw Cloud');
    }
    _wasConnected = nowConnected;
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openConnectSheet(CloudStatusData status) async {
    final nameCtrl = TextEditingController();
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('连接 MovieClaw Cloud', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '服务器将获取独立凭证（仅限已授予能力，不会接触账号本身）。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '服务器名称（可选）',
                hintText:
                    status.serverName.isNotEmpty ? status.serverName : '我的 NAS',
              ),
            ),
            const SizedBox(height: 12),
            const McInsetGroup(
              margin: EdgeInsets.zero,
              header: '将申请的能力',
              children: [
                McInsetRow(
                  icon: McIcons.bellOn,
                  title: '官方手机推送通道',
                  subtitle: '端到端加密，推送内容仅在家庭成员设备上解密',
                ),
              ],
            ),
            const SizedBox(height: 18),
            McActionPill(
              label: '继续并获取配对码',
              primary: true,
              expanded: true,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final chosen = nameCtrl.text.trim();
      final next = await _ctrl.startPairing(
        instanceName: chosen.isEmpty ? status.serverName : chosen,
      );
      final uri = next.pendingPairing?.verificationUriComplete ?? '';
      if (mounted && uri.isNotEmpty) {
        await openExternalUrl(context, uri);
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    }
  }

  Future<void> _renew() async {
    try {
      await _ctrl.renew();
      if (_ctrl.status?.health == null || _ctrl.status?.health == 'ok') {
        McToast.success('云端连接状态已同步');
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    }
  }

  Future<void> _disconnect() async {
    final ok = await confirmDialog(
      context,
      title: '断开 MovieClaw Cloud？',
      message: '断开后，这台服务器将停止通过官方推送通道向手机发送通知，随时可重新连接。',
      confirmLabel: '断开连接',
    );
    if (!ok || !mounted) return;
    try {
      await _ctrl.disconnect(force: false);
      if (mounted) McToast.success('已断开 MovieClaw Cloud');
    } on ApiException catch (e) {
      final isUnreachable =
          e.code == 'CLOUD_UNREACHABLE' || e.httpStatus == 409;
      if (!isUnreachable || !mounted) {
        McToast.error(e.friendlyMessage);
        return;
      }
      final force = await confirmDialog(
        context,
        title: '无法联系云端，是否仅删本地凭证？',
        message: '当前连不上 MovieClaw Cloud，强制断开只会清除本机保存的凭证；之后可在官网账号设置中移除旧实例记录。',
        confirmLabel: '仅删本地凭证',
      );
      if (!force || !mounted) return;
      try {
        await _ctrl.disconnect(force: true);
        if (mounted) McToast.success('已清除本地云端连接凭证');
      } catch (err) {
        McToast.error(settingsErrorText(err));
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    }
  }

  void _showConnectionDetails(CloudStatusData status) {
    final conn = status.connection;
    final connectedAt = conn?.connectedAt != null
        ? DateTime.tryParse(conn!.connectedAt!)
        : null;
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            McInsetGroup(
              header: '连接详情',
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  title: '服务器名称',
                  valueText: (conn?.instanceName.isNotEmpty ?? false)
                      ? conn!.instanceName
                      : status.serverName,
                ),
                if (conn != null && conn.accountDisplay.isNotEmpty)
                  McInsetRow(
                    title: '关联账号',
                    valueText: conn.accountDisplay,
                  ),
                if (connectedAt != null)
                  McInsetRow(
                    title: '连接时间',
                    valueText: McFormatting.dateTime(connectedAt),
                  ),
                McInsetRow(
                  title: '云端地址',
                  subtitle: status.cloudUrl,
                ),
              ],
            ),
            if (conn != null && conn.scopes.isNotEmpty) ...[
              const SizedBox(height: 14),
              McInsetGroup(
                header: '已授予权限',
                margin: EdgeInsets.zero,
                children: [
                  for (final s in conn.scopes)
                    McInsetRow(
                      icon: McIcons.checkCircleFill,
                      iconColor: McTokens.ok,
                      title: _scopeTitle(s),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _scopeTitle(String scope) =>
      scope == 'push' ? '官方手机推送通道' : scope;

  String _healthLabel(String? health) => switch (health) {
        null || 'ok' => '连接正常',
        'unreachable' => '暂时连不上云端',
        'expired' => '凭证已过期',
        'unsupported' => '服务器版本不受支持',
        _ => '连接异常',
      };

  SettingsTone _healthTone(String? health) => switch (health) {
        null || 'ok' => SettingsTone.ok,
        'unreachable' => SettingsTone.warn,
        _ => SettingsTone.danger,
      };

  String _limitsFooter(Map<String, int> limits) {
    final day = limits['day'];
    if (day == null || day <= 0) {
      return '官方推送通道已启用，推送载荷全程端到端加密。';
    }
    return '官方推送通道已启用，当前每日推送配额上限为 $day 条。';
  }

  @override
  Widget build(BuildContext context) {
    final status = _ctrl.status;

    return SettingsScaffold(
      title: 'MovieClaw Cloud',
      actions: [
        if (status != null && status.isConnected)
          PopupMenuButton<String>(
            icon: const Icon(McIcons.dotVerticalS, size: 20),
            onSelected: (v) {
              if (v == 'renew') _renew();
              if (v == 'disconnect') _disconnect();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'renew', child: Text('立即同步状态')),
              PopupMenuItem(
                value: 'disconnect',
                child: Text(
                  '断开连接',
                  style: TextStyle(color: McTokens.danger),
                ),
              ),
            ],
          )
        else
          McChip(label: '刷新', compact: true, onTap: _ctrl.load),
      ],
      body: _ctrl.loading && status == null
          ? const McLoadingView()
          : _ctrl.error != null && status == null
              ? McErrorView(text: _ctrl.error!, onRetry: _ctrl.load)
              : RefreshIndicator(
                  onRefresh: _ctrl.load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 36),
                    children: status!.isConnected
                        ? _buildConnected(status)
                        : _buildDisconnected(status),
                  ),
                ),
    );
  }

  List<Widget> _buildDisconnected(CloudStatusData status) {
    final hasPairing =
        status.pendingPairing != null || status.endedPairing != null;
    return [
      McInsetGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: McTokens.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    McIcons.cloudFill,
                    size: 26,
                    color: McTokens.accentStrong,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('连接到 MovieClaw 账号', style: McText.titleSm),
                      const SizedBox(height: 4),
                      Text(
                        '连上后整台服务器即可使用官方端到端加密手机推送，家庭成员都能实时收到新片入库与追更提醒。',
                        style: McText.caption.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (status.lastDisconnectMessage != null &&
          status.lastDisconnectMessage!.isNotEmpty) ...[
        const SizedBox(height: 10),
        SettingsNoticeBanner(
          text: status.lastDisconnectMessage!,
          tone: SettingsTone.warn,
        ),
      ],
      const SizedBox(height: 14),
      if (hasPairing)
        CloudPairingPanel(controller: _ctrl)
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
          child: McActionPill(
            icon: McIcons.cloud,
            label: '连接 MovieClaw Cloud',
            primary: true,
            expanded: true,
            onTap: _ctrl.busy ? null : () => _openConnectSheet(status),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Text(
            '仅管理员需要连接一次，其余家庭成员无需注册云端账号即可直接接收手机推送。',
            style: McText.caption.faint,
          ),
        ),
      ],
      const SizedBox(height: 18),
      McInsetGroup(
        header: '隐私、账号与其他渠道',
        footer: '不想连接云端？也可以通过下方的 IM 推送通道把通知发到微信、Telegram、飞书或企业微信。',
        children: [
          McInsetRow(
            icon: McIcons.shieldCheck,
            title: '服务器会发送什么数据',
            subtitle: '查看隐私说明与上报清单',
            onTap: () => openExternalUrl(context, status.reportsInfoUrl),
          ),
          McInsetRow(
            icon: McIcons.accountCircle,
            title: '管理 MovieClaw 账号（含删除账号）',
            subtitle: '前往官网账号设置管理登录方式、设备或永久删除账号',
            onTap: () => openExternalUrl(context, status.accountSettingsUrl),
          ),
          if (status.customCloudUrl)
            McInsetRow(
              icon: McIcons.globe,
              title: '自定义云端地址',
              subtitle: status.cloudUrl,
            ),
          McInsetRow(
            icon: McIcons.sendPlane,
            title: 'IM 推送通道',
            subtitle: '微信 / Telegram / Discord / 飞书等自建推送通道',
            onTap: () => context.push('/settings/push'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildConnected(CloudStatusData status) {
    final healthy = status.health == null || status.health == 'ok';
    final account = status.connection?.accountDisplay.trim() ?? '';
    final conn = status.connection;
    return [
      McInsetGroup(
        children: [
          McInsetRow(
            icon: healthy ? McIcons.cloudFill : McIcons.alert1,
            iconColor: healthy ? McTokens.ok : McTokens.warning,
            title: account.isNotEmpty ? account : 'MovieClaw Cloud 账号',
            subtitle: _healthLabel(status.health),
            trailing: SettingsStatusBadge(
              label: healthy ? '已连接' : _healthLabel(status.health),
              tone: _healthTone(status.health),
              showDot: true,
            ),
            showChevron: true,
            onTap: () => _showConnectionDetails(status),
          ),
        ],
      ),
      if (!healthy) ...[
        const SizedBox(height: 12),
        SettingsNoticeBanner(
          text: status.healthMessage ?? _healthLabel(status.health),
          tone: _healthTone(status.health),
          action: McChip(
            label: '立即同步',
            compact: true,
            onTap: _ctrl.busy ? null : _renew,
          ),
        ),
      ],
      if (status.notices.isNotEmpty) ...[
        const SizedBox(height: 14),
        McInsetGroup(
          header: '云端通知 (${status.notices.length})',
          children: [
            for (final n in status.notices)
              McInsetRow(
                icon: n.level == 'info' ? McIcons.information : McIcons.alert1,
                iconColor:
                    n.level == 'info' ? McTokens.info : McTokens.warning,
                title: n.message,
                trailing: IconButton(
                  icon: const Icon(McIcons.close, size: 17),
                  tooltip: '忽略通知',
                  onPressed: _ctrl.busy
                      ? null
                      : () async {
                          try {
                            await _ctrl.dismissNotice(n.id);
                          } catch (e) {
                            McToast.error(settingsErrorText(e));
                          }
                        },
                ),
              ),
          ],
        ),
      ],
      if (conn != null && conn.scopes.isNotEmpty) ...[
        const SizedBox(height: 16),
        McInsetGroup(
          header: '已开通服务与配额',
          footer: conn.scopes.contains('push')
              ? _limitsFooter(conn.limits)
              : null,
          children: [
            for (final scope in conn.scopes)
              McInsetRow(
                icon: McIcons.checkCircleFill,
                iconColor: McTokens.ok,
                title: _scopeTitle(scope),
                trailing: const SettingsStatusBadge(
                  label: '已启用',
                  tone: SettingsTone.ok,
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      McInsetGroup(
        header: '隐私与账号',
        footer: '关闭匿名统计不影响手机推送与任何核心功能。',
        children: [
          McInsetRow(
            icon: McIcons.barChart,
            title: '发送匿名运行统计',
            subtitle: '帮助改进 MovieClaw 稳定性，不包含片名与个人隐私',
            trailing: Switch(
              value: status.reportStats,
              onChanged: _ctrl.busy
                  ? null
                  : (v) async {
                      try {
                        await _ctrl.setReportStats(v);
                      } catch (e) {
                        McToast.error(settingsErrorText(e));
                      }
                    },
            ),
            onTap: _ctrl.busy
                ? null
                : () async {
                    try {
                      await _ctrl.setReportStats(!status.reportStats);
                    } catch (e) {
                      McToast.error(settingsErrorText(e));
                    }
                  },
          ),
          McInsetRow(
            icon: McIcons.shieldCheck,
            title: '服务器会发送什么数据',
            onTap: () => openExternalUrl(context, status.reportsInfoUrl),
          ),
          McInsetRow(
            icon: McIcons.accountCircle,
            title: '管理 MovieClaw 账号（含删除账号）',
            onTap: () => openExternalUrl(context, status.accountSettingsUrl),
          ),
        ],
      ),
      const SizedBox(height: 16),
      McInsetGroup(
        children: [
          McInsetRow(
            icon: McIcons.refreshS,
            title: '立即同步凭证与配额',
            onTap: _ctrl.busy ? null : _renew,
          ),
          McInsetRow(
            icon: McIcons.cloudOff,
            title: '断开 MovieClaw Cloud',
            destructive: true,
            onTap: _ctrl.busy ? null : _disconnect,
          ),
        ],
      ),
    ];
  }
}
