import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../widgets/settings_ui.dart';

/// 6) 刮削元数据与云盘挂载管理页（/api/v1/scrape/* + /api/v1/drives/*）。
class ScrapeDrivesAdminPage extends ConsumerStatefulWidget {
  const ScrapeDrivesAdminPage({super.key});

  @override
  ConsumerState<ScrapeDrivesAdminPage> createState() =>
      _ScrapeDrivesAdminPageState();
}

class _ScrapeDrivesAdminPageState extends ConsumerState<ScrapeDrivesAdminPage> {
  Map<String, dynamic> _scrape = const {};
  List<Map<String, dynamic>> _drives = const [];
  bool _loading = true;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sc = await _mc
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/scrape/config',
          )
          .catchError((_) => <String, dynamic>{});
      final drRaw = await _mc
          .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/drives/accounts')
          .catchError((_) => const <dynamic>[]);
      final drList = drRaw is List
          ? drRaw
          : (drRaw is Map
              ? (drRaw['items'] ?? drRaw['accounts'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      if (mounted) {
        setState(() {
          _scrape = sc;
          _drives =
              drList.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patchScrape(Map<String, dynamic> patch) async {
    final next = {..._scrape, ...patch};
    setState(() => _scrape = next);
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'PUT',
        '/api/v1/scrape/config',
        body: next,
      );
      if (mounted) McToast.success('刮削策略已保存');
    } catch (e) {
      if (mounted) McToast.error('保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final writeNfo = _scrape['write_nfo'] == true || _scrape['nfo_enabled'] == true;
    final saveImages = _scrape['download_images'] != false;
    final lang = (_scrape['language'] ?? 'zh-CN').toString();

    return SettingsScaffold(
      title: '刮削与云盘存储',
      body: _loading
          ? const McLoadingView()
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 36),
              children: [
                McInsetGroup(
                  header: '元数据刮削与本地落地',
                  children: [
                    McInsetRow(
                      icon: McIcons.translate,
                      title: '首选元数据语言',
                      valueText: lang,
                      onTap: () async {
                        final next = lang == 'zh-CN' ? 'en-US' : 'zh-CN';
                        await _patchScrape({'language': next});
                      },
                    ),
                    McInsetRow(
                      icon: McIcons.fileCode,
                      title: '生成本地 NFO 元数据文件',
                      subtitle: '与影片同目录写入兼容 Kodi / Jellyfin 的 NFO',
                      trailing: Switch(
                        value: writeNfo,
                        onChanged: (v) => _patchScrape({'write_nfo': v}),
                      ),
                      onTap: () => _patchScrape({'write_nfo': !writeNfo}),
                    ),
                    McInsetRow(
                      icon: McIcons.image,
                      title: '本地镜像缓存海报与剧照',
                      trailing: Switch(
                        value: saveImages,
                        onChanged: (v) => _patchScrape({'download_images': v}),
                      ),
                      onTap: () => _patchScrape({'download_images': !saveImages}),
                    ),
                    McInsetRow(
                      icon: McIcons.key,
                      title: '配置 Fanart.tv 高清透明 Logo 密钥…',
                      onTap: () async {
                        final key = await textInputDialog(
                          context,
                          title: 'Fanart.tv API Key',
                          hint: '粘贴 Personal API Key',
                        );
                        if (key == null) return;
                        try {
                          await _mc.unwrap<dynamic>(
                            Channel.general,
                            'PUT',
                            '/api/v1/scrape/fanart',
                            body: {'api_key': key},
                          );
                          if (context.mounted) McToast.success('Fanart 密钥已更新');
                        } catch (e) {
                          if (context.mounted) McToast.error('更新失败：$e');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                McInsetGroup(
                  header: '网盘直连账号 (${_drives.length})',
                  children: _drives.isEmpty
                      ? const [
                          McInsetRow(
                            icon: McIcons.cloud,
                            title: '暂未挂载网盘账号',
                            subtitle: '支持 115 / 阿里云盘 / WebDAV / OpenList 直连串流',
                          ),
                        ]
                      : [
                          for (final d in _drives)
                            McInsetRow(
                              icon: McIcons.cloudFill,
                              title:
                                  (d['name'] ?? d['backend'] ?? '网盘账号').toString(),
                              subtitle: (d['backend'] ?? '').toString(),
                              trailing: IconButton(
                                icon: const Icon(
                                  McIcons.trash2,
                                  size: 17,
                                  color: McTokens.danger,
                                ),
                                onPressed: () async {
                                  await _mc.unwrap<dynamic>(
                                    Channel.general,
                                    'DELETE',
                                    '/api/v1/drives/accounts/${d['id']}',
                                  );
                                  await _load();
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

/// 7) AI 模型供应商、MCP 与 Webhook 集成页（/api/v1/llm/* + /api/v1/webhooks）。
class AiIntegrationsAdminPage extends ConsumerStatefulWidget {
  const AiIntegrationsAdminPage({super.key});

  @override
  ConsumerState<AiIntegrationsAdminPage> createState() =>
      _AiIntegrationsAdminPageState();
}

class _AiIntegrationsAdminPageState
    extends ConsumerState<AiIntegrationsAdminPage> {
  List<Map<String, dynamic>> _providers = const [];
  List<Map<String, dynamic>> _models = const [];
  Map<String, dynamic> _defaults = const {};
  List<Map<String, dynamic>> _webhooks = const [];
  bool _loading = true;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<Map<String, dynamic>> asMaps(dynamic v) {
      final l = v is List
          ? v
          : (v is Map
              ? (v['items'] ?? v['providers'] ?? v['models'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      return l.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }

    final p = await _mc
        .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/llm/providers')
        .catchError((_) => const <dynamic>[]);
    final m = await _mc
        .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/llm/models')
        .catchError((_) => const <dynamic>[]);
    final def = await _mc
        .unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/llm/defaults',
        )
        .catchError((_) => <String, dynamic>{});
    final wh = await _mc
        .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/webhook')
        .catchError((_) => <String, dynamic>{});
    if (mounted) {
      setState(() {
        _providers = asMaps(p);
        _models = asMaps(m);
        _defaults = def;
        _webhooks = wh is Map
            ? asMaps(wh['endpoints'] ?? const <dynamic>[])
            : asMaps(wh);
        _loading = false;
      });
    }
  }

  Future<void> _addWebhook() async {
    final url = await textInputDialog(
      context,
      title: '添加事件通知 Webhook',
      hint: 'https://api.telegram.org/... 或企业微信/飞书机器人地址',
    );
    if (url == null || url.isEmpty || !mounted) return;
    try {
      final cur = await _mc
          .unwrap<Map<String, dynamic>>(Channel.general, 'GET', '/api/v1/webhook')
          .catchError((_) => <String, dynamic>{});
      final endpoints = [
        for (final e in (cur['endpoints'] as List? ?? const []))
          if (e is Map) Map<String, dynamic>.from(e),
        {
          'id': 'wh-${DateTime.now().millisecondsSinceEpoch}',
          'name': Uri.tryParse(url)?.host ?? 'Webhook',
          'url': url,
          'enabled': true,
        },
      ];
      await _mc.unwrap<dynamic>(
        Channel.general,
        'PUT',
        '/api/v1/webhook',
        body: {
          'enabled': true,
          'endpoints': endpoints,
        },
      );
      if (mounted) McToast.success('已添加 Webhook');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('添加失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultChat =
        (_defaults['agent_model'] ?? _defaults['chat_model'] ?? '自动选择')
            .toString();
    return SettingsScaffold(
      title: 'AI 模型与外部集成',
      actions: [
        McChip(
          icon: McIcons.addS,
          label: '添加 Webhook',
          compact: true,
          onTap: _addWebhook,
        ),
      ],
      body: _loading
          ? const McLoadingView()
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 36),
              children: [
                McInsetGroup(
                  header: '大模型默认路由',
                  children: [
                    McInsetRow(
                      icon: McIcons.aiStarFill,
                      title: 'AI 助手默认模型',
                      valueText: defaultChat,
                      onTap: _models.isEmpty
                          ? null
                          : () {
                              showMcSheet<void>(
                                context: context,
                                builder: (ctx) => Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                  child: McInsetGroup(
                                    header: '选择默认 Agent 模型',
                                    margin: EdgeInsets.zero,
                                    children: [
                                      for (final m in _models.take(12))
                                        McInsetRow(
                                          title: (m['label'] ?? m['ref'] ?? '')
                                              .toString(),
                                          onTap: () async {
                                            Navigator.of(ctx).pop();
                                            await _mc.unwrap<dynamic>(
                                              Channel.general,
                                              'PUT',
                                              '/api/v1/llm/defaults',
                                              body: {
                                                ..._defaults,
                                                'agent_model': m['ref'],
                                              },
                                            );
                                            await _load();
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                McInsetGroup(
                  header: '已接入 LLM 供应商 (${_providers.length})',
                  children: _providers.isEmpty
                      ? const [
                          McInsetRow(
                            icon: McIcons.robot,
                            title: '尚未配置大模型供应商',
                            subtitle: '支持 OpenAI / Claude / Gemini / DeepSeek 兼容接口',
                          ),
                        ]
                      : [
                          for (final p in _providers)
                            McInsetRow(
                              icon: McIcons.robotFill,
                              title: (p['name'] ?? p['id'] ?? '').toString(),
                              subtitle: (p['base_url'] ?? '').toString(),
                            ),
                        ],
                ),
                const SizedBox(height: 16),
                McInsetGroup(
                  header: '消息推送与 Webhook (${_webhooks.length})',
                  children: _webhooks.isEmpty
                      ? const [
                          McInsetRow(
                            icon: McIcons.sendPlane,
                            title: '暂无外部推送 Webhook',
                            subtitle: '入库完成、订阅命中与异常告警可实时推送到 IM',
                          ),
                        ]
                      : [
                          for (final w in _webhooks)
                            McInsetRow(
                              icon: McIcons.sendPlaneFill,
                              title: (w['name'] ?? w['url'] ?? '').toString(),
                              subtitle: (w['url'] ?? '').toString(),
                              trailing: IconButton(
                                icon: const Icon(
                                  McIcons.trash2,
                                  size: 17,
                                  color: McTokens.danger,
                                ),
                                 onPressed: () async {
                                  final next = _webhooks
                                      .where((item) => item['id'] != w['id'])
                                      .toList();
                                  await _mc.unwrap<dynamic>(
                                    Channel.general,
                                    'PUT',
                                    '/api/v1/webhook',
                                    body: {
                                      'enabled': next.isNotEmpty,
                                      'endpoints': next,
                                    },
                                  );
                                  await _load();
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

/// 8) 系统网络代理、LAN/WAN 地址簿、定时任务、插件与实时运行日志页。
class NetworkTasksLogsAdminPage extends ConsumerStatefulWidget {
  const NetworkTasksLogsAdminPage({super.key});

  @override
  ConsumerState<NetworkTasksLogsAdminPage> createState() =>
      _NetworkTasksLogsAdminPageState();
}

class _NetworkTasksLogsAdminPageState
    extends ConsumerState<NetworkTasksLogsAdminPage> {
  int _tab = 0; // 0=网络与地址, 1=定时任务, 2=插件, 3=实时日志
  Map<String, dynamic> _net = const {};
  List<String> _lanUrls = const [];
  List<String> _wanUrls = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _plugins = const [];
  List<String> _logDays = const [];
  String? _selectedDay;
  String _logContent = '';
  bool _loading = true;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_tab == 0) {
        _net = await _mc
            .unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/network/config',
            )
            .catchError((_) => <String, dynamic>{});
        final addr = await _mc
            .unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/server/addresses',
            )
            .catchError((_) => <String, dynamic>{});
        final addrList = (addr['addresses'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _lanUrls = [
          for (final a in addrList)
            if (a['kind'] == 'lan' && (a['url']?.toString().isNotEmpty ?? false))
              a['url'].toString(),
          for (final u in (addr['lan'] as List? ?? const [])) u.toString(),
        ];
        _wanUrls = [
          for (final a in addrList)
            if (a['kind'] == 'wan' && (a['url']?.toString().isNotEmpty ?? false))
              a['url'].toString(),
          for (final u in (addr['wan'] as List? ?? const [])) u.toString(),
        ];
      } else if (_tab == 1) {
        final raw = await _mc
            .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/scheduled-tasks')
            .catchError((_) => const <dynamic>[]);
        final l = raw is List
            ? raw
            : (raw is Map
                ? (raw['items'] ?? raw['tasks'] ?? const []) as List<dynamic>
                : const <dynamic>[]);
        _tasks = l.whereType<Map>().map(Map<String, dynamic>.from).toList();
      } else if (_tab == 2) {
        final raw = await _mc
            .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/app/plugins')
            .catchError((_) => const <dynamic>[]);
        final l = raw is List
            ? raw
            : (raw is Map
                ? (raw['items'] ?? raw['plugins'] ?? const []) as List<dynamic>
                : const <dynamic>[]);
        _plugins = l.whereType<Map>().map(Map<String, dynamic>.from).toList();
      } else {
        final raw = await _mc
            .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/system/logs')
            .catchError((_) => const <dynamic>[]);
        final days = raw is List
            ? [for (final d in raw) d is Map ? (d['day'] ?? d['name'] ?? '').toString() : d.toString()]
            : (raw is Map
                ? [for (final d in (raw['days'] ?? raw['files'] ?? const []) as List) d.toString()]
                : const <String>[]);
        _logDays = days.where((s) => s.isNotEmpty).toList();
        _selectedDay ??= _logDays.isNotEmpty ? _logDays.first : null;
        if (_selectedDay != null) {
          final logRaw = await _mc
              .unwrap<dynamic>(
                Channel.general,
                'GET',
                '/api/v1/system/logs/${Uri.encodeComponent(_selectedDay!)}',
                query: {'tail': 220},
              )
              .catchError((_) => '');
          _logContent = logRaw is Map
              ? ((logRaw['lines'] as List?)?.join('\n') ??
                  logRaw['content']?.toString() ??
                  '')
              : (logRaw is List ? logRaw.join('\n') : logRaw.toString());
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProxy() async {
    final proxy = await textInputDialog(
      context,
      title: '配置 HTTP / SOCKS5 代理',
      initial: (_net['proxy_url'] ?? _net['http_proxy'] ?? '').toString(),
      hint: 'http://127.0.0.1:7890（留空则直连）',
    );
    if (proxy == null || !mounted) return;
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'PUT',
        '/api/v1/network/config',
        body: {..._net, 'proxy_url': proxy, 'http_proxy': proxy},
      );
      if (mounted) McToast.success('代理设置已更新');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('保存失败：$e');
    }
  }

  Future<void> _addServerAddress(String kind) async {
    final url = await textInputDialog(
      context,
      title: kind == 'lan' ? '添加局域网直连地址 (LAN)' : '添加远程公网地址 (WAN)',
      hint: kind == 'lan' ? 'http://192.168.1.10:8000' : 'https://mc.example.com',
    );
    if (url == null || url.isEmpty || !mounted) return;
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/server/addresses',
        body: {'kind': kind, 'url': url},
      );
      if (mounted) McToast.success('已写入服务器地址簿');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('添加失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '网络、计划任务与日志',
      actions: [
        McChip(label: '刷新', compact: true, onTap: _load),
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
                    (0, '网络与地址簿', McIcons.router),
                    (1, '定时任务', McIcons.clock),
                    (2, '扩展插件', McIcons.puzzle),
                    (3, '运行日志', McIcons.terminal),
                  ]) ...[
                    McChip(
                      icon: icon,
                      label: label,
                      compact: true,
                      selected: _tab == idx,
                      onTap: () {
                        setState(() => _tab = idx);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: _loading
                ? const McLoadingView()
                : switch (_tab) {
                    0 => ListView(
                        padding: const EdgeInsets.only(top: 12, bottom: 36),
                        children: [
                          McInsetGroup(
                            header: '上游连通性与代理',
                            children: [
                              McInsetRow(
                                icon: McIcons.globe,
                                title: 'HTTP / SOCKS5 代理',
                                valueText:
                                    (_net['proxy_url'] ?? _net['http_proxy'] ?? '直连')
                                        .toString(),
                                onTap: _editProxy,
                              ),
                              McInsetRow(
                                icon: McIcons.radar,
                                title: '执行 TMDB / 豆瓣连通性测速',
                                onTap: () async {
                                  try {
                                    await _mc.unwrap<dynamic>(
                                      Channel.general,
                                      'POST',
                                      '/api/v1/network/test',
                                    );
                                    if (context.mounted) {
                                      McToast.success('上游连通测试通过');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      McToast.error('连通测试异常：$e');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          McInsetGroup(
                            header: 'Happy Eyeballs 双栈地址簿（供全客户端智能选路）',
                            children: [
                              McInsetRow(
                                icon: McIcons.wifiOn,
                                title: '局域网直连地址 (LAN)',
                                subtitle: _lanUrls.isEmpty
                                    ? '未登记'
                                    : _lanUrls.join('\n'),
                                trailing: McChip(
                                  label: '添加',
                                  compact: true,
                                  onTap: () => _addServerAddress('lan'),
                                ),
                              ),
                              McInsetRow(
                                icon: McIcons.cloud,
                                title: '公网/异地组网地址 (WAN)',
                                subtitle: _wanUrls.isEmpty
                                    ? '未登记'
                                    : _wanUrls.join('\n'),
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
                    1 => _tasks.isEmpty
                        ? const McEmptyView(text: '暂无后台计划任务')
                        : ListView(
                            padding: const EdgeInsets.only(top: 12, bottom: 36),
                            children: [
                              McInsetGroup(
                                children: [
                                  for (final t in _tasks)
                                    McInsetRow(
                                      icon: McIcons.clock,
                                      title:
                                          (t['title'] ?? t['name'] ?? t['key'] ?? '')
                                              .toString(),
                                      subtitle:
                                          (t['schedule'] ?? t['interval'] ?? '')
                                              .toString(),
                                      trailing: Switch(
                                        value: t['enabled'] != false,
                                        onChanged: (v) async {
                                          await _mc.unwrap<dynamic>(
                                            Channel.general,
                                            'PUT',
                                            '/api/v1/scheduled-tasks/${t['key'] ?? t['id']}',
                                            body: {'enabled': v},
                                          );
                                          await _load();
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                    2 => _plugins.isEmpty
                        ? const McEmptyView(
                            icon: McIcons.puzzle,
                            title: '尚未安装扩展插件',
                            text: '所有官方能力已原生内置，第三方插件安装后在此启用。',
                          )
                        : ListView(
                            padding: const EdgeInsets.only(top: 12, bottom: 36),
                            children: [
                              McInsetGroup(
                                children: [
                                  for (final p in _plugins)
                                    McInsetRow(
                                      icon: McIcons.puzzleFill,
                                      title: (p['name'] ?? p['id'] ?? '').toString(),
                                      subtitle: (p['description'] ?? '').toString(),
                                      trailing: Switch(
                                        value: p['enabled'] == true,
                                        onChanged: (v) async {
                                          await _mc.unwrap<dynamic>(
                                            Channel.general,
                                            'PUT',
                                            '/api/v1/app/plugins/${p['id']}/enabled',
                                            body: {'enabled': v},
                                          );
                                          await _load();
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                    _ => Padding(
                        padding: const EdgeInsets.fromLTRB(
                          McTokens.pagePadding,
                          10,
                          McTokens.pagePadding,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_logDays.isNotEmpty) ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final day in _logDays.take(7)) ...[
                                      McChip(
                                        label: day,
                                        compact: true,
                                        selected: _selectedDay == day,
                                        onTap: () {
                                          _selectedDay = day;
                                          _load();
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: McTokens.surfaceInset,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: McTokens.line),
                                ),
                                child: _logContent.isEmpty
                                    ? Center(
                                        child: Text(
                                          '暂无日志输出',
                                          style: McText.caption.faint,
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: SelectableText(
                                          _logContent,
                                          style: McText.micro.copyWith(
                                            fontFamily: 'monospace',
                                            height: 1.45,
                                            color: McTokens.textMuted,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  },
          ),
        ],
      ),
    );
  }
}
