import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../widgets/settings_ui.dart';

export 'ai_admin_page.dart' show AiIntegrationsAdminPage, WebhookSettingsPage;
export 'scrape_settings_page.dart' show ScrapeDrivesAdminPage;

/// 系统网络代理、外部访问与端口、LAN/WAN 地址簿、定时任务、扩展插件与结构化运行日志页。
class NetworkTasksLogsAdminPage extends ConsumerStatefulWidget {
  const NetworkTasksLogsAdminPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<NetworkTasksLogsAdminPage> createState() =>
      _NetworkTasksLogsAdminPageState();
}

class _NetworkTasksLogsAdminPageState
    extends ConsumerState<NetworkTasksLogsAdminPage> {
  late int _tab = widget.initialTab.clamp(0, 3);

  final _netKey = GlobalKey<_NetworkAdminTabState>();
  final _tasksKey = GlobalKey<_ScheduledTasksTabState>();
  final _pluginsKey = GlobalKey<_PluginsTabState>();
  final _logsKey = GlobalKey<_StructuredLogsTabState>();

  void _refreshActive() {
    switch (_tab) {
      case 0:
        _netKey.currentState?.load();
      case 1:
        _tasksKey.currentState?.load();
      case 2:
        _pluginsKey.currentState?.load();
      case 3:
        _logsKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '网络、定时任务与日志',
      actions: [
        McChip(
          icon: McIcons.refresh,
          label: '刷新',
          compact: true,
          onTap: _refreshActive,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              McTokens.pagePadding,
              10,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (idx, label, icon) in const [
                    (0, '网络与访问', McIcons.router),
                    (1, '定时任务', McIcons.clock),
                    (2, '扩展插件', McIcons.puzzle),
                    (3, '运行日志', McIcons.terminal),
                  ]) ...[
                    McChip(
                      icon: icon,
                      label: label,
                      compact: true,
                      selected: _tab == idx,
                      onTap: () => setState(() => _tab = idx),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _NetworkAdminTab(key: _netKey),
                _ScheduledTasksTab(key: _tasksKey),
                _PluginsTab(key: _pluginsKey),
                _StructuredLogsTab(key: _logsKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 0: 网络代理、分服务测速、外部访问/端口、TMDB 镜像与 LAN/WAN 地址簿
// ===========================================================================

class _NetworkTestResult {
  const _NetworkTestResult({
    this.pending = false,
    this.ok = false,
    this.latencyMs,
    this.message = '',
  });

  final bool pending;
  final bool ok;
  final int? latencyMs;
  final String message;
}

class _NetworkAdminTab extends ConsumerStatefulWidget {
  const _NetworkAdminTab({super.key});

  @override
  ConsumerState<_NetworkAdminTab> createState() => _NetworkAdminTabState();
}

class _NetworkAdminTabState extends ConsumerState<_NetworkAdminTab> {
  bool _loading = true;
  String? _error;

  // /api/v1/network/config
  String _proxyMode = 'off';
  String _proxyUrl = '';
  String _envProxyDetected = '';
  List<String> _proxyServices = const [];
  String _tmdbApiBaseUrl = '';
  String _tmdbImageBaseUrl = '';
  String _doubanApiBaseUrl = '';
  Map<String, String> _mirrorDefaults = const {};
  List<Map<String, dynamic>> _services = const [];

  bool _savingNet = false;
  int _configGeneration = 0;
  final Map<String, _NetworkTestResult> _tests = {};

  // /api/v1/app/config
  Map<String, dynamic> _appConfig = const {};
  int? _restartingPort;

  // /api/v1/server/addresses
  List<String> _lanUrls = const [];
  List<String> _wanUrls = const [];

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      _loading = _services.isEmpty && _appConfig.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/network/config',
        ),
        _mc
            .unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/app/config',
            )
            .catchError((_) => <String, dynamic>{}),
        _mc
            .unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/server/addresses',
            )
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final net = results[0] as Map<String, dynamic>;
      final appCfg = results[1] as Map<String, dynamic>;
      final addr = results[2] as Map<String, dynamic>;

      _acceptNetConfig(net);
      final addrList = (addr['addresses'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      final lan = <String>[
        for (final a in addrList)
          if (a['kind'] == 'lan' && (a['url']?.toString().isNotEmpty ?? false))
            a['url'].toString(),
        for (final u in (addr['lan'] as List? ?? const [])) u.toString(),
      ];
      final wan = <String>[
        for (final a in addrList)
          if (a['kind'] == 'wan' && (a['url']?.toString().isNotEmpty ?? false))
            a['url'].toString(),
        for (final u in (addr['wan'] as List? ?? const [])) u.toString(),
      ];
      setState(() {
        _appConfig = appCfg;
        _lanUrls = lan.toSet().toList();
        _wanUrls = wan.toSet().toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
    }
  }

  void _acceptNetConfig(Map<String, dynamic> net) {
    final defaultsRaw = net['mirror_defaults'];
    final defaults = <String, String>{};
    if (defaultsRaw is Map) {
      for (final e in defaultsRaw.entries) {
        defaults[e.key.toString()] = (e.value ?? '').toString();
      }
    }
    final servicesRaw = (net['services'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    setState(() {
      _proxyMode = (net['proxy_mode'] ?? 'off').toString();
      _proxyUrl = (net['proxy_url'] ?? '').toString();
      _envProxyDetected = (net['env_proxy_detected'] ?? '').toString();
      _proxyServices = ((net['proxy_services'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      _tmdbApiBaseUrl = (net['tmdb_api_base_url'] ?? '').toString();
      _tmdbImageBaseUrl = (net['tmdb_image_base_url'] ?? '').toString();
      _doubanApiBaseUrl = (net['douban_api_base_url'] ?? '').toString();
      _mirrorDefaults = defaults;
      _services = servicesRaw;
      _configGeneration += 1;
      _tests.clear();
    });
  }

  bool _validUrl(String value, {bool proxy = false, bool allowEmpty = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return allowEmpty;
    if (trimmed.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    final allowed = proxy
        ? const {'http', 'https', 'socks5', 'socks5h'}
        : const {'http', 'https'};
    return allowed.contains(scheme);
  }

  bool get _proxyActive => switch (_proxyMode) {
        'manual' => _validUrl(_proxyUrl, proxy: true),
        'env' => _envProxyDetected.isNotEmpty,
        _ => false,
      };

  String get _proxyLabel => switch (_proxyMode) {
        'manual' => _proxyUrl.isEmpty ? '手动代理' : '手动 · $_proxyUrl',
        'env' => _envProxyDetected.isEmpty
            ? '环境变量（未检测到）'
            : '环境变量 · $_envProxyDetected',
        _ => '关闭（直连）',
      };

  Map<String, dynamic> _buildNetPayload({
    String? proxyMode,
    String? proxyUrl,
    List<String>? proxyServices,
    String? tmdbApiBaseUrl,
    String? tmdbImageBaseUrl,
  }) =>
      {
        'proxy_mode': proxyMode ?? _proxyMode,
        'proxy_url': (proxyUrl ?? _proxyUrl).trim(),
        'proxy_services': proxyServices ?? _proxyServices,
        'tmdb_api_base_url': (tmdbApiBaseUrl ?? _tmdbApiBaseUrl).trim(),
        'tmdb_image_base_url': (tmdbImageBaseUrl ?? _tmdbImageBaseUrl).trim(),
        'douban_api_base_url': _doubanApiBaseUrl.trim(),
      };

  Future<bool> _saveNetConfig(Map<String, dynamic> payload) async {
    setState(() => _savingNet = true);
    try {
      final saved = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/network/config',
        body: payload,
      );
      if (!mounted) return false;
      _acceptNetConfig(saved);
      McToast.success('网络配置已保存');
      return true;
    } catch (e) {
      if (mounted) McToast.error('保存失败：${settingsErrorText(e)}');
      return false;
    } finally {
      if (mounted) setState(() => _savingNet = false);
    }
  }

  Future<void> _toggleServiceProxy(String serviceId, bool enabled) async {
    if (_savingNet) return;
    final next = List<String>.from(_proxyServices);
    if (enabled) {
      if (!next.contains(serviceId)) next.add(serviceId);
    } else {
      next.remove(serviceId);
    }
    await _saveNetConfig(_buildNetPayload(proxyServices: next));
  }

  Future<void> _testService(String serviceId) async {
    if (_savingNet || (_tests[serviceId]?.pending ?? false)) return;
    final gen = _configGeneration;
    setState(() {
      _tests[serviceId] = const _NetworkTestResult(pending: true);
    });
    try {
      final res = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/network/test',
        body: {'service': serviceId},
      );
      if (!mounted || gen != _configGeneration) return;
      setState(() {
        _tests[serviceId] = _NetworkTestResult(
          ok: res['ok'] == true,
          latencyMs: (res['latency_ms'] as num?)?.toInt(),
          message: (res['message'] ?? '').toString(),
        );
      });
    } catch (e) {
      if (!mounted || gen != _configGeneration) return;
      setState(() {
        _tests[serviceId] = _NetworkTestResult(
          ok: false,
          message: settingsErrorText(e),
        );
      });
    }
  }

  Future<void> _openProxySheet() async {
    var mode = _proxyMode;
    final urlCtrl = TextEditingController(text: _proxyUrl);
    var busy = false;
    String? err;

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid =
              mode != 'manual' || _validUrl(urlCtrl.text, proxy: true);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('上游代理设置', style: McText.titleSm),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (id, label) in const [
                      ('off', '关闭'),
                      ('env', '环境变量'),
                      ('manual', '手动配置'),
                    ])
                      McChip(
                        label: label,
                        compact: true,
                        selected: mode == id,
                        onTap: busy ? null : () => setS(() => mode = id),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (mode == 'manual') ...[
                  TextField(
                    controller: urlCtrl,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '代理地址',
                      hintText: 'http://192.168.1.2:7890 或 socks5://127.0.0.1:7891',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '支持 http / https / socks5 / socks5h 协议。启用后请在下方勾选需要走代理的服务。',
                    style: McText.caption.muted,
                  ),
                ] else if (mode == 'env') ...[
                  SettingsInfoCard(
                    icon: McIcons.terminal,
                    text: _envProxyDetected.isEmpty
                        ? '当前容器环境未检测到 HTTP_PROXY / ALL_PROXY 变量。'
                        : '已检测到环境变量代理：$_envProxyDetected',
                  ),
                ] else ...[
                  Text(
                    '所有元数据、豆瓣与 PT 站点均直接连接。',
                    style: McText.caption.muted,
                  ),
                ],
                if (!valid) ...[
                  const SizedBox(height: 8),
                  Text(
                    '请输入有效的代理 URL（需含协议与主机名，不含空格）。',
                    style: McText.caption.copyWith(color: McTokens.warn),
                  ),
                ],
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    err!,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || !valid
                      ? null
                      : () async {
                          setS(() {
                            busy = true;
                            err = null;
                          });
                          final ok = await _saveNetConfig(
                            _buildNetPayload(
                              proxyMode: mode,
                              proxyUrl: urlCtrl.text.trim(),
                            ),
                          );
                          if (!ctx.mounted) return;
                          if (ok) {
                            Navigator.of(ctx).pop();
                          } else {
                            setS(() {
                              busy = false;
                              err = '保存代理配置失败';
                            });
                          }
                        },
                  child: Text(busy ? '保存中…' : '保存'),
                ),
              ],
            ),
          );
        },
      ),
    );
    urlCtrl.dispose();
  }

  Future<void> _openMirrorsSheet() async {
    final apiCtrl = TextEditingController(text: _tmdbApiBaseUrl);
    final imgCtrl = TextEditingController(text: _tmdbImageBaseUrl);
    var busy = false;

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid = _validUrl(apiCtrl.text, allowEmpty: true) &&
              _validUrl(imgCtrl.text, allowEmpty: true);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('TMDB 反代镜像地址', style: McText.titleSm),
                const SizedBox(height: 12),
                TextField(
                  controller: apiCtrl,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'TMDB API 地址（留空使用官方默认）',
                    hintText: _mirrorDefaults['tmdb_api_base_url'] ??
                        'https://api.themoviedb.org',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imgCtrl,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'TMDB 图片地址（留空使用官方默认）',
                    hintText: _mirrorDefaults['tmdb_image_base_url'] ??
                        'https://image.tmdb.org',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                if (!valid) ...[
                  const SizedBox(height: 8),
                  Text(
                    '镜像地址须为 http:// 或 https:// 开头的有效 URL（可留空恢复默认）。',
                    style: McText.caption.copyWith(color: McTokens.warn),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || !valid
                      ? null
                      : () async {
                          setS(() => busy = true);
                          final ok = await _saveNetConfig(
                            _buildNetPayload(
                              tmdbApiBaseUrl: apiCtrl.text.trim(),
                              tmdbImageBaseUrl: imgCtrl.text.trim(),
                            ),
                          );
                          if (!ctx.mounted) return;
                          if (ok) {
                            Navigator.of(ctx).pop();
                          } else {
                            setS(() => busy = false);
                          }
                        },
                  child: Text(busy ? '保存中…' : '保存'),
                ),
              ],
            ),
          );
        },
      ),
    );
    apiCtrl.dispose();
  }

  Future<void> _editExternalUrl() async {
    final current = (_appConfig['external_url'] ?? '').toString();
    final origin = ref.read(sessionStoreProvider).baseUrl ?? '';
    final ctrl = TextEditingController(text: current);
    var busy = false;

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid = _validUrl(ctrl.text, allowEmpty: true);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('外部访问地址 (External URL)', style: McText.titleSm),
                const SizedBox(height: 8),
                Text(
                  '用于生成分享外链、通知跳转链接与 MCP 接入地址；留空则自动推断。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: '外部访问 URL',
                    hintText: origin.isNotEmpty
                        ? origin
                        : 'https://movieclaw.example.com',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                if (origin.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: McChip(
                      label: '填入当前服务器地址',
                      compact: true,
                      onTap: busy
                          ? null
                          : () {
                              ctrl.text = origin.replaceFirst(RegExp(r'/+$'), '');
                              setS(() {});
                            },
                    ),
                  ),
                ],
                if (!valid) ...[
                  const SizedBox(height: 8),
                  Text(
                    '请输入有效的 http/https 地址，或留空清除。',
                    style: McText.caption.copyWith(color: McTokens.warn),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || !valid
                      ? null
                      : () async {
                          setS(() => busy = true);
                          try {
                            final saved = await _mc.unwrap<Map<String, dynamic>>(
                              Channel.general,
                              'PUT',
                              '/api/v1/app/config',
                              body: {'external_url': ctrl.text.trim()},
                            );
                            if (!mounted) return;
                            setState(() => _appConfig = saved);
                            McToast.success('外部访问地址已更新');
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } catch (e) {
                            if (mounted) {
                              McToast.error('保存失败：${settingsErrorText(e)}');
                            }
                            setS(() => busy = false);
                          }
                        },
                  child: Text(busy ? '保存中…' : '保存'),
                ),
              ],
            ),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _editWebPort() async {
    final currentPort = (_appConfig['web_port'] as num?)?.toInt() ?? 8000;
    final source = (_appConfig['web_port_source'] ?? 'default').toString();
    final resetTarget = (_appConfig['web_port_reset_target'] as num?)?.toInt() ??
        (_appConfig['web_port_default'] as num?)?.toInt() ??
        8000;
    final ctrl = TextEditingController(text: '$currentPort');
    var busy = false;

    Future<void> applyPort(BuildContext ctx, int port, bool isReset) async {
      final targetDisplay = isReset ? resetTarget : port;
      final ok = await confirmDialog(
        ctx,
        title: isReset ? '恢复默认端口 $resetTarget' : '修改服务监听端口为 $port',
        message: '保存后服务端会立即重启并切换到新端口 $targetDisplay，请确保防火墙/容器映射已放行该端口。',
        confirmLabel: '修改并重启',
        destructive: true,
      );
      if (!ok || !ctx.mounted) return;
      try {
        final saved = await _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'PUT',
          '/api/v1/app/port',
          body: {'port': isReset ? 0 : port},
        );
        if (!mounted) return;
        final nextPort = (saved['web_port'] as num?)?.toInt() ?? targetDisplay;
        setState(() {
          _appConfig = saved;
          if (nextPort != currentPort) _restartingPort = nextPort;
        });
        McToast.success('端口已提交修改，服务端正在重启');
        if (ctx.mounted) Navigator.of(ctx).pop();
      } catch (e) {
        if (mounted) McToast.error('修改端口失败：${settingsErrorText(e)}');
      }
    }

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final parsed = int.tryParse(ctrl.text.trim());
          final valid = parsed != null && parsed >= 1 && parsed <= 65535;
          final dirty = parsed != currentPort;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Web 服务监听端口', style: McText.titleSm),
                const SizedBox(height: 8),
                Text(
                  '当前端口：$currentPort（来源：${source == 'setting' ? '自定义设置' : source == 'env' ? '环境变量' : '默认'}）',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '端口号 (1 - 65535)',
                    hintText: '8000',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                if (!valid) ...[
                  const SizedBox(height: 8),
                  Text(
                    '请输入 1 到 65535 之间的整数。',
                    style: McText.caption.copyWith(color: McTokens.warn),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || !valid || !dirty
                      ? null
                      : () async {
                          setS(() => busy = true);
                          await applyPort(ctx, parsed, false);
                          if (ctx.mounted) setS(() => busy = false);
                        },
                  child: Text(busy ? '应用中…' : '保存并重启'),
                ),
                if (source == 'setting') ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setS(() => busy = true);
                            await applyPort(ctx, 0, true);
                            if (ctx.mounted) setS(() => busy = false);
                          },
                    child: Text('恢复默认端口 ($resetTarget)'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _addServerAddress(String kind) async {
    final url = await textInputDialog(
      context,
      title: kind == 'lan' ? '添加局域网直连地址 (LAN)' : '添加公网/异地组网地址 (WAN)',
      hint: kind == 'lan' ? 'http://192.168.1.10:8000' : 'https://mc.example.com',
    );
    if (url == null || url.trim().isEmpty || !mounted) return;
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/server/addresses',
        body: {'kind': kind, 'url': url.trim()},
      );
      if (mounted) McToast.success('已写入服务器地址簿');
      await load();
    } catch (e) {
      if (mounted) McToast.error('添加失败：${settingsErrorText(e)}');
    }
  }

  String _portPreviewUrl(int port) {
    final origin = ref.read(sessionStoreProvider).baseUrl ?? '';
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return 'http://<server>:$port';
    return uri.replace(port: port).toString();
  }

  Widget _buildServiceCard(Map<String, dynamic> svc) {
    final id = (svc['id'] ?? '').toString();
    final label = (svc['label'] ?? id).toString();
    final desc = (svc['description'] ?? '').toString();
    final enabled = _proxyServices.contains(id);
    final test = _tests[id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McInsetRow(
          icon: id.startsWith('site:') ? McIcons.globe : McIcons.radar,
          title: label,
          subtitle: [
            if (desc.isNotEmpty) desc,
            if (test != null && !test.pending && test.message.isNotEmpty)
              test.message,
          ].join('\n'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (test != null && test.pending)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (test != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SettingsStatusBadge(
                    label: test.ok
                        ? (test.latencyMs != null ? '${test.latencyMs} ms' : '连通')
                        : '不可达',
                    tone: test.ok ? SettingsTone.ok : SettingsTone.danger,
                  ),
                ),
              McChip(
                label: '测速',
                compact: true,
                onTap: _savingNet || (test?.pending ?? false)
                    ? null
                    : () => _testService(id),
              ),
              const SizedBox(width: 6),
              Switch(
                value: enabled,
                onChanged: !_proxyActive || _savingNet
                    ? null
                    : (v) => _toggleServiceProxy(id, v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const McLoadingView();
    if (_error != null && _services.isEmpty) {
      return McErrorView(text: _error!, onRetry: load);
    }

    final coreServices =
        _services.where((s) => !(s['id'] ?? '').toString().startsWith('site:')).toList();
    final siteServices =
        _services.where((s) => (s['id'] ?? '').toString().startsWith('site:')).toList();

    final extUrl = (_appConfig['external_url'] ?? '').toString();
    final webPort = (_appConfig['web_port'] as num?)?.toInt();
    final portConfigurable = _appConfig['web_port_configurable'] == true;
    final portRejected = (_appConfig['web_port_rejected'] as num?)?.toInt();
    final hasCustomMirrors =
        _tmdbApiBaseUrl.isNotEmpty || _tmdbImageBaseUrl.isNotEmpty;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          if (_restartingPort != null) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.info,
              icon: McIcons.restart,
              title: '服务端正在切换到端口 $_restartingPort',
              message: '请稍候使用新地址重新连接：${_portPreviewUrl(_restartingPort!)}',
            ),
            const SizedBox(height: 14),
          ],
          if (portRejected != null && webPort != null) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.warn,
              icon: McIcons.alertCircle,
              title: '端口 $portRejected 已被占用或无权限绑定',
              message: '服务端已自动回退到端口 $webPort 启动，请在下方调整为可用端口。',
            ),
            const SizedBox(height: 14),
          ],
          McInsetGroup(
            header: '代理与反代镜像',
            children: [
              McInsetRow(
                icon: McIcons.globe,
                title: '出站代理模式',
                subtitle: _proxyLabel,
                onTap: _savingNet ? null : _openProxySheet,
              ),
              McInsetRow(
                icon: McIcons.links,
                title: 'TMDB 反代镜像',
                valueText: hasCustomMirrors ? '已自定义' : '官方默认',
                subtitle: hasCustomMirrors
                    ? [
                        if (_tmdbApiBaseUrl.isNotEmpty) 'API: $_tmdbApiBaseUrl',
                        if (_tmdbImageBaseUrl.isNotEmpty)
                          '图床: $_tmdbImageBaseUrl',
                      ].join(' · ')
                    : '直连 api.themoviedb.org / image.tmdb.org',
                onTap: _savingNet ? null : _openMirrorsSheet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (coreServices.isNotEmpty) ...[
            McInsetGroup(
              header: '核心服务连通测速与代理分流',
              children: [
                for (final svc in coreServices) _buildServiceCard(svc),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                McTokens.pagePadding + 4,
                6,
                McTokens.pagePadding + 4,
                0,
              ),
              child: Text(
                _proxyActive
                    ? '开启右侧开关后，该服务的请求将通过代理发出；点击「测速」实时验证当前策略。'
                    : '未启用有效代理时开关不可用，但仍可随时点击「测速」检查直连延迟。',
                style: McText.caption.faint,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (siteServices.isNotEmpty) ...[
            McInsetGroup(
              header: 'PT 站点代理分流 (${siteServices.length})',
              children: [
                for (final svc in siteServices) _buildServiceCard(svc),
              ],
            ),
            const SizedBox(height: 16),
          ],
          McInsetGroup(
            header: '外部访问与监听端口',
            children: [
              McInsetRow(
                icon: McIcons.shareBox2,
                title: '外部访问地址',
                subtitle: extUrl.isEmpty ? '未设置（自动使用请求来源）' : extUrl,
                onTap: _editExternalUrl,
              ),
              McInsetRow(
                icon: McIcons.server,
                title: 'Web 监听端口',
                subtitle: portConfigurable
                    ? '支持直接修改并自动重启'
                    : '由外部容器/反向代理接管，无法在应用内修改',
                valueText: webPort != null ? '$webPort' : '--',
                onTap: portConfigurable ? _editWebPort : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          McInsetGroup(
            header: 'Happy Eyeballs 双栈地址簿',
            children: [
              McInsetRow(
                icon: McIcons.wifiOn,
                title: '局域网直连地址 (LAN)',
                subtitle: _lanUrls.isEmpty ? '未登记' : _lanUrls.join('\n'),
                trailing: McChip(
                  label: '添加',
                  compact: true,
                  onTap: () => _addServerAddress('lan'),
                ),
              ),
              McInsetRow(
                icon: McIcons.cloud,
                title: '公网/异地组网地址 (WAN)',
                subtitle: _wanUrls.isEmpty ? '未登记' : _wanUrls.join('\n'),
                trailing: McChip(
                  label: '添加',
                  compact: true,
                  onTap: () => _addServerAddress('wan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 1: 后台定时任务（全量 ScheduledTaskUpdate + 网络挂载对账 1h 建议）
// ===========================================================================

class _ScheduledTasksTab extends ConsumerStatefulWidget {
  const _ScheduledTasksTab({super.key});

  @override
  ConsumerState<_ScheduledTasksTab> createState() => _ScheduledTasksTabState();
}

class _ScheduledTasksTabState extends ConsumerState<_ScheduledTasksTab> {
  List<Map<String, dynamic>> _tasks = const [];
  bool _anyNetworkMount = false;
  bool _loading = true;
  String? _error;
  String? _busyKey;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      _loading = _tasks.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<dynamic>(Channel.general, 'GET', '/api/v1/scheduled-tasks'),
        _mc
            .unwrap<dynamic>(
              Channel.general,
              'GET',
              '/api/v1/libraries',
              query: const {'scope': 'all'},
            )
            .catchError((_) => const <dynamic>[]),
      ]);
      if (!mounted) return;
      final raw = results[0];
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['tasks'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      final libsRaw = results[1];
      final libs = libsRaw is List
          ? libsRaw
          : (libsRaw is Map
              ? (libsRaw['items'] ?? libsRaw['libraries'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      final anyNet = libs.whereType<Map>().any((l) => l['network_mount'] == true);
      setState(() {
        _tasks = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
        _anyNetworkMount = anyNet;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
    }
  }

  static ({int hour, int minute})? _parseDailyCron(String? cron) {
    if (cron == null) return null;
    final parts = cron.trim().split(RegExp(r'\s+'));
    if (parts.length != 5 ||
        parts[2] != '*' ||
        parts[3] != '*' ||
        parts[4] != '*') {
      return null;
    }
    final minute = int.tryParse(parts[0]);
    final hour = int.tryParse(parts[1]);
    if (minute == null || hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute);
  }

  static String _describeTask(Map<String, dynamic> task) {
    final triggerType = (task['trigger_type'] ?? 'interval').toString();
    final intervalSeconds = (task['interval_seconds'] as num?)?.toInt() ?? 0;
    final cronExpr = task['cron_expr']?.toString();

    if (triggerType == 'interval') {
      if (intervalSeconds <= 0) return '未设置间隔';
      if (intervalSeconds % 3600 == 0) {
        final h = intervalSeconds ~/ 3600;
        return '每 $h 小时';
      }
      if (intervalSeconds % 60 == 0) {
        final m = intervalSeconds ~/ 60;
        return '每 $m 分钟';
      }
      return '每 $intervalSeconds 秒';
    }
    final daily = _parseDailyCron(cronExpr);
    if (daily != null) {
      final hh = daily.hour.toString().padLeft(2, '0');
      final mm = daily.minute.toString().padLeft(2, '0');
      return '每天 $hh:$mm';
    }
    return (cronExpr != null && cronExpr.isNotEmpty)
        ? 'Cron: $cronExpr'
        : '未设置计划';
  }

  bool _shouldSuggestReconcile(Map<String, dynamic> task) {
    if (!_anyNetworkMount) return false;
    final triggerType = (task['trigger_type'] ?? '').toString();
    final intervalSeconds = (task['interval_seconds'] as num?)?.toInt() ?? 0;
    if (triggerType != 'interval') return true;
    return intervalSeconds > 3600;
  }

  Future<String?> _saveTask(
    String key,
    Map<String, dynamic> body,
  ) async {
    setState(() => _busyKey = key);
    try {
      final updated = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/scheduled-tasks/${Uri.encodeComponent(key)}',
        body: body,
      );
      if (!mounted) return null;
      setState(() {
        _tasks = [
          for (final t in _tasks)
            if ((t['key'] ?? t['id']).toString() == key) updated else t,
        ];
      });
      McToast.success('计划任务已更新');
      return null;
    } catch (e) {
      final msg = settingsErrorText(e);
      if (mounted) McToast.error('更新失败：$msg');
      return msg;
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _toggleEnabled(Map<String, dynamic> task, bool nextEnabled) async {
    final key = (task['key'] ?? task['id'] ?? '').toString();
    final triggerType = (task['trigger_type'] ?? 'interval').toString();
    await _saveTask(key, {
      'enabled': nextEnabled,
      'trigger_type': triggerType,
      'interval_seconds':
          triggerType == 'interval' ? task['interval_seconds'] : null,
      'cron_expr': triggerType == 'cron' ? task['cron_expr'] : null,
    });
  }

  Future<void> _openEditor(Map<String, dynamic> task) async {
    final key = (task['key'] ?? task['id'] ?? '').toString();
    final title = (task['title'] ?? task['name'] ?? key).toString();
    final desc = (task['description'] ?? '').toString();
    final origEnabled = task['enabled'] != false;
    final origTrigger = (task['trigger_type'] ?? 'interval').toString();
    final origSeconds = (task['interval_seconds'] as num?)?.toInt();
    final origCron = task['cron_expr']?.toString() ?? '';
    final origDaily = _parseDailyCron(origCron);

    var enabled = origEnabled;
    var mode = origTrigger == 'interval'
        ? 'interval'
        : (origDaily != null ? 'daily' : 'cron');
    final origHours = ((origSeconds ?? 3600) / 3600).round().clamp(1, 168);
    var hours = origHours;
    var dailyTime = TimeOfDay(
      hour: origDaily?.hour ?? 3,
      minute: origDaily?.minute ?? 0,
    );
    final cronCtrl = TextEditingController(text: origCron);
    var busy = false;
    String? err;

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Map<String, dynamic> buildPayload() {
            if (mode == 'interval') {
              // 仅切换启停时不抹掉原有的精确分钟/秒间隔
              final seconds = origTrigger == 'interval' && hours == origHours
                  ? (origSeconds ?? hours * 3600)
                  : hours * 3600;
              return {
                'enabled': enabled,
                'trigger_type': 'interval',
                'interval_seconds': seconds,
                'cron_expr': null,
              };
            }
            if (mode == 'daily') {
              return {
                'enabled': enabled,
                'trigger_type': 'cron',
                'interval_seconds': null,
                'cron_expr': '${dailyTime.minute} ${dailyTime.hour} * * *',
              };
            }
            return {
              'enabled': enabled,
              'trigger_type': 'cron',
              'interval_seconds': null,
              'cron_expr': cronCtrl.text.trim(),
            };
          }

          final canSave =
              mode != 'cron' || cronCtrl.text.trim().isNotEmpty;
          final lastRun = task['last_run_at']?.toString();
          final nextRun = task['next_run_at']?.toString();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: McText.titleSm),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc, style: McText.caption.muted),
                ],
                const SizedBox(height: 14),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    McInsetRow(
                      icon: enabled ? McIcons.clock : McIcons.pauseCircle,
                      title: '启用该计划任务',
                      trailing: Switch(
                        value: enabled,
                        onChanged: busy ? null : (v) => setS(() => enabled = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (id, label) in const [
                      ('interval', '按小时间隔'),
                      ('daily', '每天定时'),
                      ('cron', '自定义 Cron'),
                    ])
                      McChip(
                        label: label,
                        compact: true,
                        selected: mode == id,
                        onTap: busy ? null : () => setS(() => mode = id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (mode == 'interval')
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        icon: McIcons.stopwatch,
                        title: '执行周期',
                        subtitle: origTrigger == 'interval' &&
                                hours == origHours &&
                                origSeconds != null &&
                                origSeconds % 3600 != 0
                            ? '当前保留原精确间隔：${_describeTask(task)}'
                            : '每 $hours 小时执行一次（1 - 168 小时）',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(McIcons.dash, size: 18),
                              onPressed: busy || hours <= 1
                                  ? null
                                  : () => setS(() => hours -= 1),
                            ),
                            Text(
                              '${hours}h',
                              style: McText.sub.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(McIcons.addS, size: 18),
                              onPressed: busy || hours >= 168
                                  ? null
                                  : () => setS(() => hours += 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (mode == 'daily')
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        icon: McIcons.alarm,
                        title: '每天执行时刻',
                        valueText:
                            '${dailyTime.hour.toString().padLeft(2, '0')}:${dailyTime.minute.toString().padLeft(2, '0')}',
                        onTap: busy
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: dailyTime,
                                );
                                if (picked != null) {
                                  setS(() => dailyTime = picked);
                                }
                              },
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: cronCtrl,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '5 段 Cron 表达式（分 时 日 月 周）',
                      hintText: '0 3 * * *',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                const SizedBox(height: 12),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    McInsetRow(
                      icon: McIcons.history,
                      title: '上次执行',
                      valueText:
                          (lastRun == null || lastRun.isEmpty) ? '从未运行' : lastRun,
                    ),
                    if (enabled && nextRun != null && nextRun.isNotEmpty)
                      McInsetRow(
                        icon: McIcons.calendar,
                        title: '下次计划',
                        valueText: nextRun,
                      ),
                  ],
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    err!,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || !canSave
                      ? null
                      : () async {
                          setS(() {
                            busy = true;
                            err = null;
                          });
                          final msg = await _saveTask(key, buildPayload());
                          if (!ctx.mounted) return;
                          if (msg == null) {
                            Navigator.of(ctx).pop();
                          } else {
                            setS(() {
                              busy = false;
                              err = msg;
                            });
                          }
                        },
                  child: Text(busy ? '保存中…' : '保存计划'),
                ),
              ],
            ),
          );
        },
      ),
    );
    cronCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const McLoadingView();
    if (_error != null && _tasks.isEmpty) {
      return McErrorView(text: _error!, onRetry: load);
    }
    if (_tasks.isEmpty) return const McEmptyView(text: '暂无后台计划任务');

    final reconcile = _tasks.cast<Map<String, dynamic>?>().firstWhere(
          (t) => (t?['key'] ?? t?['id']) == 'library_reconcile',
          orElse: () => null,
        );

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          if (reconcile != null && _shouldSuggestReconcile(reconcile)) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.info,
              icon: McIcons.folderCloud,
              title: '检测到网络挂载媒体库',
              message:
                  '当前媒体库对账周期为「${_describeTask(reconcile)}」。SMB / NFS / WebDAV 挂载无法可靠触发实时文件事件，建议调为每 1 小时对账。',
              trailing: McChip(
                label: '设为每 1 小时',
                compact: true,
                selected: true,
                onTap: _busyKey == 'library_reconcile'
                    ? null
                    : () => _saveTask('library_reconcile', {
                          'enabled': true,
                          'trigger_type': 'interval',
                          'interval_seconds': 3600,
                          'cron_expr': null,
                        }),
              ),
            ),
            const SizedBox(height: 14),
          ],
          McInsetGroup(
            header: '系统后台计划任务 (${_tasks.length})',
            children: [
              for (final t in _tasks) ...[
                Builder(
                  builder: (context) {
                    final key = (t['key'] ?? t['id'] ?? '').toString();
                    final enabled = t['enabled'] != false;
                    final lastRun = t['last_run_at']?.toString();
                    return McInsetRow(
                      icon: enabled ? McIcons.clock : McIcons.pauseCircle,
                      title: (t['title'] ?? t['name'] ?? key).toString(),
                      subtitle: [
                        enabled ? _describeTask(t) : '已暂停',
                        if (lastRun != null && lastRun.isNotEmpty)
                          '上次 $lastRun',
                      ].join(' · '),
                      trailing: Switch(
                        value: enabled,
                        onChanged: _busyKey == key
                            ? null
                            : (v) => _toggleEnabled(t, v),
                      ),
                      onTap: () => _openEditor(t),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 2: 扩展插件
// ===========================================================================

class _PluginsTab extends ConsumerStatefulWidget {
  const _PluginsTab({super.key});

  @override
  ConsumerState<_PluginsTab> createState() => _PluginsTabState();
}

class _PluginsTabState extends ConsumerState<_PluginsTab> {
  List<Map<String, dynamic>> _plugins = const [];
  bool _loading = true;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      _loading = _plugins.isEmpty;
      _error = null;
    });
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/app/plugins',
      );
      final l = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['plugins'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      if (!mounted) return;
      setState(() {
        _plugins = l.whereType<Map>().map(Map<String, dynamic>.from).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const McLoadingView();
    if (_error != null && _plugins.isEmpty) {
      return McErrorView(text: _error!, onRetry: load);
    }
    if (_plugins.isEmpty) {
      return const McEmptyView(
        icon: McIcons.puzzle,
        title: '尚未安装扩展插件',
        text: '所有官方能力已原生内置，第三方插件安装后在此启用。',
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          McInsetGroup(
            header: '已安装插件 (${_plugins.length})',
            children: [
              for (final p in _plugins)
                McInsetRow(
                  icon: McIcons.puzzleFill,
                  title: (p['name'] ?? p['id'] ?? '').toString(),
                  subtitle: (p['description'] ?? '').toString(),
                  trailing: Switch(
                    value: p['enabled'] == true,
                    onChanged: (v) async {
                      try {
                        await _mc.unwrap<dynamic>(
                          Channel.general,
                          'PUT',
                          '/api/v1/app/plugins/${Uri.encodeComponent((p['id'] ?? '').toString())}/enabled',
                          body: {'enabled': v},
                        );
                        await load();
                      } catch (e) {
                        if (mounted) {
                          McToast.error('切换失败：${settingsErrorText(e)}');
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 3: 结构化在线日志查看器（1:1 对齐 iOS LogsSettingsView）
// ===========================================================================

enum _LogLevel { error, warning, info, debug }

class _LogDayMeta {
  const _LogDayMeta({required this.day, this.sizeBytes = 0});

  final String day;
  final int sizeBytes;
}

class _LogEntry {
  _LogEntry({
    required this.time,
    required this.level,
    required this.module,
    required this.message,
  });

  final String time;
  final _LogLevel level;
  final String module;
  String message;
}

class _StructuredLogsTab extends ConsumerStatefulWidget {
  const _StructuredLogsTab({super.key});

  @override
  ConsumerState<_StructuredLogsTab> createState() => _StructuredLogsTabState();
}

class _StructuredLogsTabState extends ConsumerState<_StructuredLogsTab> {
  static const _refreshPrefKey = 'movieclaw.log-refresh-interval';
  static const _refreshOptions = <(String, int)>[
    ('关', 0),
    ('3s', 3000),
    ('10s', 10000),
    ('30s', 30000),
  ];
  static final _lineRegex = RegExp(
    r'^\d{4}-\d{2}-\d{2} (\d{2}:\d{2}:\d{2}) \| ([A-Z]+) \| (\S+) \| (.*)$',
  );

  List<_LogDayMeta> _days = const [];
  String? _activeDay;
  List<_LogEntry> _entries = const [];
  int _totalLines = 0;
  int _loadedLines = 0;
  bool _truncated = false;
  int? _tail;

  bool _loading = true;
  String? _error;
  _LogLevel? _levelFilter;
  String _query = '';
  int _refreshMs = 10000;

  bool _atBottom = true;
  int _pendingNew = 0;
  bool _inFlight = false;
  int _generation = 0;

  Timer? _autoTimer;
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final _fullscreenNotifier = ValueNotifier<int>(0);

  McClient get _mc => ref.read(mcClientProvider);

  bool get _isLatestDay =>
      _activeDay != null && _days.isNotEmpty && _activeDay == _days.first.day;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    Future.microtask(() async {
      await _restoreRefreshPref();
      await refresh();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _fullscreenNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final bottom = pos.pixels >= pos.maxScrollExtent - 48;
    if (bottom != _atBottom) {
      setState(() {
        _atBottom = bottom;
        if (bottom) _pendingNew = 0;
      });
      _fullscreenNotifier.value++;
    }
  }

  Future<void> _restoreRefreshPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_refreshPrefKey);
      if (stored != null &&
          _refreshOptions.any((opt) => opt.$2 == stored)) {
        _refreshMs = stored;
      }
    } catch (_) {}
    _rescheduleTimer();
  }

  Future<void> _setRefreshMs(int ms) async {
    setState(() => _refreshMs = ms);
    _fullscreenNotifier.value++;
    _rescheduleTimer();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_refreshPrefKey, ms);
    } catch (_) {}
  }

  void _rescheduleTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (_refreshMs <= 0) return;
    _autoTimer = Timer.periodic(Duration(milliseconds: _refreshMs), (_) {
      if (_isLatestDay && _activeDay != null) {
        _loadDay(_activeDay!, silent: true);
      }
    });
  }

  Future<void> refresh({String? prefer}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _fullscreenNotifier.value++;
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/system/logs',
      );
      final rawDays = raw is List
          ? raw
          : (raw is Map
              ? (raw['days'] ?? raw['files'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      final parsedDays = <_LogDayMeta>[];
      for (final d in rawDays) {
        if (d is Map) {
          final day = (d['day'] ?? d['name'] ?? '').toString();
          if (day.isNotEmpty) {
            parsedDays.add(
              _LogDayMeta(
                day: day,
                sizeBytes: (d['size_bytes'] as num?)?.toInt() ?? 0,
              ),
            );
          }
        } else {
          final day = d.toString();
          if (day.isNotEmpty) parsedDays.add(_LogDayMeta(day: day));
        }
      }
      if (!mounted) return;
      final desired = prefer ?? _activeDay;
      final target = (desired != null && parsedDays.any((e) => e.day == desired))
          ? desired
          : (parsedDays.isNotEmpty ? parsedDays.first.day : null);
      setState(() {
        _days = parsedDays;
        _activeDay = target;
      });
      if (target != null) {
        await _loadDay(target);
      } else {
        setState(() {
          _entries = const [];
          _totalLines = 0;
          _loadedLines = 0;
          _truncated = false;
          _loading = false;
        });
        _fullscreenNotifier.value++;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
      _fullscreenNotifier.value++;
    }
  }

  Future<void> _switchDay(String day) async {
    setState(() {
      _activeDay = day;
      _tail = null;
      _atBottom = true;
      _pendingNew = 0;
    });
    await _loadDay(day);
  }

  Future<void> _loadDay(
    String day, {
    int? newTail,
    bool silent = false,
  }) async {
    if (silent && _inFlight) return;
    _generation += 1;
    final mine = _generation;
    _inFlight = true;
    if (newTail != null) _tail = newTail;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
      _fullscreenNotifier.value++;
    }
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/system/logs/${Uri.encodeComponent(day)}',
        query: _tail != null ? {'tail': _tail} : null,
      );
      if (!mounted || mine != _generation) return;
      List<String> lines;
      int total;
      bool truncated;
      if (raw is Map) {
        lines = ((raw['lines'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        if (lines.isEmpty && raw['content'] is String) {
          lines = (raw['content'] as String).split('\n');
        }
        total = (raw['total_lines'] as num?)?.toInt() ?? lines.length;
        truncated = raw['truncated'] == true;
      } else if (raw is List) {
        lines = raw.map((e) => e.toString()).toList();
        total = lines.length;
        truncated = false;
      } else {
        lines = raw.toString().split('\n');
        total = lines.length;
        truncated = false;
      }

      final added = total - (_activeDay == day ? _totalLines : 0);
      final parsed = _parseLines(lines);

      setState(() {
        if (silent && !_atBottom && added > 0) {
          _pendingNew += added;
        }
        _entries = parsed;
        _totalLines = total;
        _loadedLines = lines.length;
        _truncated = truncated;
        _error = null;
        if (!silent) _loading = false;
      });
      _fullscreenNotifier.value++;

      if (_atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpBottom());
      }
    } catch (e) {
      if (!mounted || mine != _generation) return;
      if (!silent) {
        setState(() {
          _entries = const [];
          _error = settingsErrorText(e);
          _loading = false;
        });
        _fullscreenNotifier.value++;
      }
    } finally {
      if (mine == _generation) _inFlight = false;
    }
  }

  void _jumpBottom({ScrollController? controller}) {
    final ctrl = controller ?? _scrollCtrl;
    if (!ctrl.hasClients) return;
    ctrl.jumpTo(ctrl.position.maxScrollExtent);
    if (_pendingNew != 0 || !_atBottom) {
      setState(() {
        _atBottom = true;
        _pendingNew = 0;
      });
      _fullscreenNotifier.value++;
    }
  }

  static List<_LogEntry> _parseLines(List<String> lines) {
    final result = <_LogEntry>[];
    for (final line in lines) {
      final m = _lineRegex.firstMatch(line);
      if (m != null) {
        final rawLvl = m.group(2) ?? 'INFO';
        final lvl = switch (rawLvl) {
          'ERROR' || 'CRITICAL' => _LogLevel.error,
          'WARNING' || 'WARN' => _LogLevel.warning,
          'DEBUG' => _LogLevel.debug,
          _ => _LogLevel.info,
        };
        result.add(
          _LogEntry(
            time: m.group(1) ?? '',
            level: lvl,
            module: m.group(3) ?? '',
            message: m.group(4) ?? '',
          ),
        );
      } else if (result.isNotEmpty) {
        result.last.message = '${result.last.message}\n$line';
      } else if (line.trim().isNotEmpty) {
        result.add(
          _LogEntry(
            time: '',
            level: _LogLevel.info,
            module: '',
            message: line,
          ),
        );
      }
    }
    return result;
  }

  List<_LogEntry> get _visibleEntries {
    final q = _query.trim().toLowerCase();
    return _entries.where((e) {
      if (_levelFilter != null && e.level != _levelFilter) return false;
      if (q.isEmpty) return true;
      return e.message.toLowerCase().contains(q) ||
          e.module.toLowerCase().contains(q);
    }).toList();
  }

  int _countLevel(_LogLevel? level) {
    if (level == null) return _entries.length;
    return _entries.where((e) => e.level == level).length;
  }

  void _openFullscreen() {
    final fsScroll = ScrollController();
    fsScroll.addListener(() {
      if (!fsScroll.hasClients) return;
      final bottom =
          fsScroll.position.pixels >= fsScroll.position.maxScrollExtent - 48;
      if (bottom != _atBottom) {
        setState(() {
          _atBottom = bottom;
          if (bottom) _pendingNew = 0;
        });
        _fullscreenNotifier.value++;
      }
    });

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (ctx) => Scaffold(
              backgroundColor: McTokens.bg,
              appBar: AppBar(
                backgroundColor: McTokens.bg,
                title: const Text('系统运行日志'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
              body: ValueListenableBuilder<int>(
                valueListenable: _fullscreenNotifier,
                builder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: _buildLogsContent(
                    isFullscreen: true,
                    scrollController: fsScroll,
                  ),
                ),
              ),
            ),
          ),
        )
        .whenComplete(fsScroll.dispose);
  }

  Widget _buildLogsContent({
    required bool isFullscreen,
    required ScrollController scrollController,
  }) {
    final visible = _visibleEntries;
    final meta = _days.cast<_LogDayMeta?>().firstWhere(
          (d) => d?.day == _activeDay,
          orElse: () => null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部行：全量日期选择器 + 文件元信息 + 自动刷新频率
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<String>(
              enabled: !_loading && _days.isNotEmpty,
              onSelected: _switchDay,
              itemBuilder: (_) => [
                for (final d in _days)
                  PopupMenuItem<String>(
                    value: d.day,
                    child: Row(
                      children: [
                        Expanded(child: Text(d.day)),
                        if (d.sizeBytes > 0)
                          Text(
                            mcFormatBytes(d.sizeBytes),
                            style: McText.caption.muted,
                          ),
                        if (d.day == _activeDay) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            McIcons.check,
                            size: 16,
                            color: McTokens.accent,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: McTokens.glassFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: McTokens.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(McIcons.calendar, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _activeDay ?? '无日志文件',
                      style: McText.caption.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(McIcons.arrowDownS, size: 14),
                  ],
                ),
              ),
            ),
            if (meta != null)
              Text(
                [
                  if (meta.sizeBytes > 0) mcFormatBytes(meta.sizeBytes),
                  '$_totalLines 行',
                ].join(' · '),
                style: McText.caption.muted,
              ),
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_refreshMs > 0 && _isLatestDay)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: const BoxDecoration(
                      color: McTokens.ok,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text('自动刷新', style: McText.caption.muted),
                const SizedBox(width: 6),
                for (final (label, ms) in _refreshOptions) ...[
                  McChip(
                    label: label,
                    compact: true,
                    selected: _refreshMs == ms,
                    onTap: () => _setRefreshMs(ms),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          SettingsNoticeBanner(
            tone: SettingsTone.danger,
            icon: McIcons.alertCircle,
            title: '加载日志失败',
            message: _error!,
          ),
        ],
        const SizedBox(height: 10),
        // 日志窗口容器
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: McTokens.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 过滤栏：级别筛选（带计数）+ 搜索框 + 全屏按钮
                Container(
                  color: Colors.white.withValues(alpha: 0.03),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (lvl, label) in const [
                              (null, '全部'),
                              (_LogLevel.error, '错误'),
                              (_LogLevel.warning, '警告'),
                              (_LogLevel.info, '信息'),
                              (_LogLevel.debug, '调试'),
                            ]) ...[
                              _LevelFilterPill(
                                label: label,
                                count: _countLevel(lvl),
                                selected: _levelFilter == lvl,
                                isError: lvl == _LogLevel.error,
                                onTap: () {
                                  setState(() => _levelFilter = lvl);
                                  _fullscreenNotifier.value++;
                                },
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                prefixIcon: const Icon(McIcons.search, size: 15),
                                hintText: '搜索日志正文或模块名…',
                                suffixIcon: _query.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          McIcons.closeCircle,
                                          size: 15,
                                        ),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _query = '');
                                          _fullscreenNotifier.value++;
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (v) {
                                setState(() => _query = v);
                                _fullscreenNotifier.value++;
                              },
                            ),
                          ),
                          if (!isFullscreen) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: '全屏查看',
                              icon: const Icon(McIcons.fullscreen, size: 18),
                              onPressed: _openFullscreen,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (_truncated)
                  Container(
                    color: Colors.white.withValues(alpha: 0.02),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '当前显示末尾 $_loadedLines 行（共 $_totalLines 行）',
                            style: McText.caption.faint,
                          ),
                        ),
                        TextButton(
                          onPressed: _loading || _activeDay == null
                              ? null
                              : () => _loadDay(_activeDay!, newTail: 0),
                          child: const Text('加载全部'),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, color: McTokens.line),
                Expanded(
                  child: Stack(
                    children: [
                      if (_loading && _entries.isEmpty)
                        const Center(child: CircularProgressIndicator())
                      else if (visible.isEmpty)
                        Center(
                          child: Text(
                            _days.isEmpty
                                ? '暂无日志文件'
                                : _entries.isEmpty
                                    ? '当天日志为空'
                                    : '无匹配当前筛选条件的日志',
                            style: McText.sub.faint,
                          ),
                        )
                      else
                        SelectionArea(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: visible.length,
                            itemBuilder: (_, i) => _StructuredLogRow(
                              entry: visible[i],
                              query: _query.trim(),
                            ),
                          ),
                        ),
                      if (_pendingNew > 0)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _jumpBottom(controller: scrollController),
                            icon: const Icon(McIcons.arrowDown, size: 14),
                            label: Text('$_pendingNew 条新日志'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_isLatestDay && _activeDay != null && _refreshMs > 0) ...[
          const SizedBox(height: 6),
          Text(
            '正在查看历史日期日志，自动刷新已暂停。',
            style: McText.caption.faint,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        10,
        McTokens.pagePadding,
        20,
      ),
      child: _buildLogsContent(
        isFullscreen: false,
        scrollController: _scrollCtrl,
      ),
    );
  }
}

class _LevelFilterPill extends StatelessWidget {
  const _LevelFilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.isError,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool isError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isError && count > 0
        ? const Color(0xFFFF8A8A)
        : (selected ? McTokens.text : McTokens.textMuted);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: McText.caption.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: McText.caption.copyWith(
                  color: fg.withValues(alpha: 0.72),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StructuredLogRow extends StatelessWidget {
  const _StructuredLogRow({required this.entry, required this.query});

  final _LogEntry entry;
  final String query;

  @override
  Widget build(BuildContext context) {
    final (badge, badgeColor, textColor) = switch (entry.level) {
      _LogLevel.error => (
          'ERROR',
          const Color(0xFFFF8A8A),
          const Color(0xFFFFB4B4),
        ),
      _LogLevel.warning => (
          'WARN',
          McTokens.warn,
          const Color(0xCCFFF2CC),
        ),
      _LogLevel.info => ('INFO', McTokens.textMuted, McTokens.textMuted),
      _LogLevel.debug => ('DEBUG', McTokens.textFaint, McTokens.textFaint),
    };

    return Container(
      color: entry.level == _LogLevel.error
          ? McTokens.danger.withValues(alpha: 0.06)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (entry.time.isNotEmpty) ...[
            Text(
              entry.time,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: McTokens.textFaint,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.4,
                  color: textColor,
                ),
                children: [
                  if (entry.module.isNotEmpty)
                    TextSpan(
                      text: '[${entry.module}] ',
                      style: TextStyle(
                        color: McTokens.accent.withValues(alpha: 0.8),
                      ),
                    ),
                  ..._highlightSpans(entry.message, query, textColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightSpans(String text, String q, Color baseColor) {
    if (q.isEmpty) return [TextSpan(text: text)];
    final lower = text.toLowerCase();
    final qLower = q.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: TextStyle(
            backgroundColor: McTokens.accent.withValues(alpha: 0.35),
            color: McTokens.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = idx + q.length;
    }
    return spans;
  }
}
