import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// ── AI 大模型、AI 设定、联网搜索与 Webhook 集成页 ──────────────────────────

/// 7) AI 模型供应商、默认路由、联网搜索与 Webhook 集成页。
class AiIntegrationsAdminPage extends ConsumerStatefulWidget {
  const AiIntegrationsAdminPage({super.key, this.initialTab = 0});

  final int initialTab; // 0=AI设定与联网搜索, 1=大模型供应商, 2=Webhook

  @override
  ConsumerState<AiIntegrationsAdminPage> createState() =>
      _AiIntegrationsAdminPageState();
}

class _AiIntegrationsAdminPageState
    extends ConsumerState<AiIntegrationsAdminPage> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'AI 与外部集成',
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
                    (0, 'AI 默认与联网搜索', McIcons.aiStarFill),
                    (1, '大模型供应商', McIcons.robot),
                    (2, 'Webhook 推送', McIcons.sendPlane),
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
            child: switch (_tab) {
              0 => _AiDefaultsAndWebSearchTab(
                  onOpenProviders: () => setState(() => _tab = 1),
                ),
              1 => const _LlmProvidersTab(),
              _ => const _WebhookTabBody(),
            },
          ),
        ],
      ),
    );
  }
}

/// 独立 Webhook 页面（供 `/settings/webhook` 直达）。
class WebhookSettingsPage extends StatelessWidget {
  const WebhookSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScaffold(
      title: 'Webhook 推送',
      body: _WebhookTabBody(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: AI 默认路由（agent_model + subtitle_model）+ 网页搜索 (Web Search)
// ═══════════════════════════════════════════════════════════════════════════

class _AiDefaultsAndWebSearchTab extends ConsumerStatefulWidget {
  const _AiDefaultsAndWebSearchTab({required this.onOpenProviders});

  final VoidCallback onOpenProviders;

  @override
  ConsumerState<_AiDefaultsAndWebSearchTab> createState() =>
      _AiDefaultsAndWebSearchTabState();
}

class _AiDefaultsAndWebSearchTabState
    extends ConsumerState<_AiDefaultsAndWebSearchTab> {
  Map<String, dynamic>? _defaults;
  List<Map<String, dynamic>> _models = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Web Search state
  Map<String, dynamic>? _webSearch;
  bool _webSearchUnsupported = false;
  String? _webSearchError;
  bool _webSearchBusy = false;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = _defaults == null;
      _error = null;
    });
    await Future.wait([_loadDefaults(), _loadWebSearch()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDefaults() async {
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/llm/defaults',
        ),
        _mc.unwrap<dynamic>(Channel.general, 'GET', '/api/v1/llm/models'),
      ]);
      final d = results[0] as Map<String, dynamic>;
      final mRaw = results[1];
      final mList = mRaw is List
          ? mRaw
          : (mRaw is Map
              ? (mRaw['items'] ?? mRaw['models'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      if (!mounted) return;
      setState(() {
        _defaults = d;
        _models =
            mList.whereType<Map>().map(Map<String, dynamic>.from).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    }
  }

  Future<void> _loadWebSearch() async {
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/llm/web-search',
      );
      if (!mounted) return;
      setState(() {
        _webSearch = raw;
        _webSearchUnsupported = false;
        _webSearchError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.httpStatus == 404) {
        setState(() => _webSearchUnsupported = true);
      } else {
        setState(() => _webSearchError = e.friendlyMessage);
      }
    } catch (e) {
      if (mounted) setState(() => _webSearchError = settingsErrorText(e));
    }
  }

  String? _validRef(String? refVal) {
    if (refVal == null || refVal.isEmpty) return null;
    final exists = _models.any((m) => (m['ref'] ?? '').toString() == refVal);
    return exists ? refVal : null;
  }

  bool _isStale(String? refVal) =>
      refVal != null && refVal.isNotEmpty && _validRef(refVal) == null;

  String _modelLabel(String? refVal) {
    if (refVal == null || refVal.isEmpty) return '未选择';
    for (final m in _models) {
      if ((m['ref'] ?? '').toString() == refVal) {
        return (m['label'] ?? refVal).toString();
      }
    }
    return refVal;
  }

  Future<void> _pickDefaultModel({
    required String purposeKey, // 'agent_model' | 'subtitle_model'
    required String title,
    required String explanation,
  }) async {
    final cur = _defaults;
    if (cur == null) return;
    final original = cur[purposeKey]?.toString();
    var selected = original;
    var query = '';

    final chosen = await showMcSheet<String>(
      context: context,
      maxWidth: 600,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final kw = query.trim().toLowerCase();
          final visible = _models.where((m) {
            if (kw.isEmpty) return true;
            final hay =
                '${m['label'] ?? ''} ${m['provider_name'] ?? ''} ${m['ref'] ?? ''}'
                    .toLowerCase();
            return hay.contains(kw);
          }).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: McText.titleSm),
                const SizedBox(height: 4),
                Text(explanation, style: McText.caption.muted),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(McIcons.search, size: 17),
                    hintText: '搜索模型名称或供应商…',
                  ),
                  onChanged: (v) => setSheet(() => query = v),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: visible.isEmpty
                      ? const Center(child: Text('没有匹配的模型'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: visible.length,
                          itemBuilder: (_, idx) {
                            final m = visible[idx];
                            final refStr = (m['ref'] ?? '').toString();
                            final label = (m['label'] ?? refStr).toString();
                            final prov = (m['provider_name'] ??
                                    m['providerName'] ??
                                    '')
                                .toString();
                            final thinking = (m['thinking_levels'] as List?)
                                    ?.isNotEmpty ==
                                true;
                            final isSel = selected == refStr;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: Text(label, style: McText.ui),
                              subtitle: Text(
                                '$prov${thinking ? ' · 支持思考档位' : ''}',
                                style: McText.caption.muted,
                              ),
                              trailing: isSel
                                  ? const Icon(
                                      McIcons.checkCircleFill,
                                      color: McTokens.ok,
                                      size: 19,
                                    )
                                  : null,
                              onTap: () => setSheet(() => selected = refStr),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                McActionPill(
                  label: '保存默认模型',
                  primary: true,
                  expanded: true,
                  onTap: (selected != null &&
                          selected != original &&
                          _validRef(selected) != null)
                      ? () => Navigator.of(ctx).pop(selected)
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
    if (chosen == null || !mounted) return;

    // 关键口径：另一项若已失效，清理为 null 交由服务端按推荐补齐，避免整体被拒绝
    final nextAgent = purposeKey == 'agent_model'
        ? chosen
        : _validRef(cur['agent_model']?.toString());
    final nextSubtitle = purposeKey == 'subtitle_model'
        ? chosen
        : _validRef(cur['subtitle_model']?.toString());

    setState(() => _saving = true);
    try {
      final saved = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/llm/defaults',
        body: {
          'agent_model': nextAgent,
          'subtitle_model': nextSubtitle,
        },
      );
      if (mounted) {
        setState(() => _defaults = saved);
        McToast.success('AI 默认模型已保存');
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWebSearchSheet() async {
    final cfg = _webSearch;
    if (cfg == null) return;
    final providers = ((cfg['providers'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    if (providers.isEmpty) return;

    var selectedProvider = (cfg['provider'] ?? providers.first['id'] ?? '')
        .toString();
    final keyCtrl = TextEditingController();
    var showKey = false;
    var busy = false;
    String? sheetError;
    final configured = cfg['configured'] == true;
    final keyHint = (cfg['key_hint'] ?? cfg['keyHint'] ?? '').toString();

    final saved = await showMcSheet<Map<String, dynamic>>(
      context: context,
      maxWidth: 560,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Map<String, dynamic>? curProv;
          for (final p in providers) {
            if (p['id']?.toString() == selectedProvider) {
              curProv = p;
              break;
            }
          }
          final signupUrl =
              (curProv?['signup_url'] ?? curProv?['signupUrl'] ?? '').toString();
          final canSave = !busy &&
              selectedProvider.isNotEmpty &&
              keyCtrl.text.trim().isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  configured ? '更换网页搜索服务' : '接入网页搜索',
                  style: McText.titleSm,
                ),
                const SizedBox(height: 6),
                Text(
                  '提交时会实时执行一次测试搜索，验证通过才会保存。',
                  style: McText.caption.muted,
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 10),
                  SettingsNoticeBanner(
                    text: sheetError!,
                    tone: SettingsTone.danger,
                    margin: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 12),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  header: '搜索服务商',
                  children: [
                    for (final p in providers)
                      McInsetRow(
                        title: (p['label'] ?? p['id'] ?? '').toString(),
                        subtitle: (p['note'] ?? '').toString(),
                        trailing: selectedProvider == p['id']?.toString()
                            ? const Icon(
                                McIcons.checkCircleFill,
                                color: McTokens.ok,
                                size: 19,
                              )
                            : null,
                        onTap: () => setSheet(() {
                          selectedProvider = (p['id'] ?? '').toString();
                          sheetError = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyCtrl,
                  obscureText: !showKey,
                  decoration: InputDecoration(
                    labelText: 'API Key *',
                    hintText: (configured &&
                            selectedProvider == cfg['provider']?.toString() &&
                            keyHint.isNotEmpty)
                        ? '当前密钥 $keyHint（输入新密钥替换）'
                        : '粘贴 API Key',
                    suffixIcon: IconButton(
                      icon: Icon(
                        showKey ? McIcons.eyeOff : McIcons.eyeOpen,
                        size: 18,
                      ),
                      onPressed: () => setSheet(() => showKey = !showKey),
                    ),
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
                if (signupUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(McIcons.links, size: 16),
                      label: Text(
                        '前往 ${curProv?['label'] ?? '官网'} 申请 API Key',
                      ),
                      onPressed: () => openExternalUrl(ctx, signupUrl),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                McActionPill(
                  label: busy ? '验证并保存中…' : '验证并保存',
                  primary: true,
                  expanded: true,
                  onTap: !canSave
                      ? null
                      : () async {
                          setSheet(() {
                            busy = true;
                            sheetError = null;
                          });
                          try {
                            final next = await _mc.unwrap<Map<String, dynamic>>(
                              Channel.general,
                              'PUT',
                              '/api/v1/llm/web-search',
                              body: {
                                'provider': selectedProvider,
                                'api_key': keyCtrl.text.trim(),
                              },
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(next);
                          } catch (e) {
                            setSheet(() {
                              busy = false;
                              sheetError = settingsErrorText(e);
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
    if (saved != null && mounted) {
      setState(() => _webSearch = saved);
      McToast.success('网页搜索已验证并保存');
    }
  }

  Future<void> _retestWebSearch() async {
    setState(() => _webSearchBusy = true);
    try {
      final res = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/llm/web-search/test',
        body: {'provider': _webSearch?['provider']},
      );
      McToast.success((res['message'] ?? '网页搜索连接正常').toString());
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _webSearchBusy = false);
    }
  }

  Future<void> _clearWebSearch() async {
    final ok = await confirmDialog(
      context,
      title: '关闭网页搜索？',
      message: '关闭后 AI 助手将不再能实时联网检索影视资讯。',
      confirmLabel: '关闭',
    );
    if (!ok || !mounted) return;
    setState(() => _webSearchBusy = true);
    try {
      final res = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '/api/v1/llm/web-search',
      );
      if (mounted) {
        setState(() => _webSearch = res);
        McToast.success('网页搜索已关闭');
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _webSearchBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const McLoadingView();
    final d = _defaults;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          if (_error != null) ...[
            SettingsNoticeBanner(text: _error!, tone: SettingsTone.danger),
            const SizedBox(height: 8),
          ],
          if (d != null && _models.isEmpty)
            McEmptyView(
              icon: McIcons.aiStarFill,
              title: '尚未接入可用大模型',
              text: '请先在「大模型供应商」中接入至少一家供应商，再配置智能体与字幕处理默认模型。',
              actionLabel: '去接入大模型',
              onRetry: widget.onOpenProviders,
            )
          else if (d != null) ...[
            _buildPurposeCard(
              purposeKey: 'agent_model',
              effectiveKey: 'effective_agent_model',
              title: 'AI 助手默认模型',
              desc: '对话问答、选片推荐、故障排查与追更分析默认使用的模型。',
              icon: McIcons.aiStarFill,
              defaults: d,
            ),
            const SizedBox(height: 14),
            _buildPurposeCard(
              purposeKey: 'subtitle_model',
              effectiveKey: 'effective_subtitle_model',
              title: '字幕处理默认模型',
              desc: 'AI 字幕翻译、双语润色与时间轴校验默认使用的模型。',
              icon: McIcons.translate,
              defaults: d,
            ),
          ],
          if (!_webSearchUnsupported) ...[
            const SizedBox(height: 18),
            _buildWebSearchCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildPurposeCard({
    required String purposeKey,
    required String effectiveKey,
    required String title,
    required String desc,
    required IconData icon,
    required Map<String, dynamic> defaults,
  }) {
    final val = defaults[purposeKey]?.toString();
    final eff = defaults[effectiveKey]?.toString();
    final stale = _isStale(val);
    final display = _modelLabel((val == null || stale) ? eff : val);
    final subtitle = (val == null && eff != null && eff.isNotEmpty)
        ? '自动推荐：$display'
        : display;

    return Column(
      children: [
        McInsetGroup(
          header: title,
          footer: desc,
          children: [
            McInsetRow(
              icon: icon,
              title: title,
              subtitle: subtitle,
              showChevron: true,
              onTap: _saving
                  ? null
                  : () => _pickDefaultModel(
                        purposeKey: purposeKey,
                        title: '选择$title',
                        explanation: desc,
                      ),
            ),
          ],
        ),
        if (stale) ...[
          const SizedBox(height: 6),
          SettingsNoticeBanner(
            text:
                '原配置的模型已不在当前供应商目录中，目前回退至 ${_modelLabel(eff)}，请重新选择保存。',
            tone: SettingsTone.warn,
          ),
        ],
      ],
    );
  }

  Widget _buildWebSearchCard() {
    if (_webSearchError != null && _webSearch == null) {
      return SettingsNoticeBanner(
        text: '读取网页搜索配置失败：$_webSearchError',
        tone: SettingsTone.danger,
        action: McChip(label: '重试', compact: true, onTap: _loadWebSearch),
      );
    }
    final cfg = _webSearch;
    if (cfg == null) {
      return const SettingsInfoCard(text: '正在加载网页搜索配置…');
    }

    final configured = cfg['configured'] == true;
    final providerId = cfg['provider']?.toString();
    final providers = ((cfg['providers'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    Map<String, dynamic>? current;
    if (configured) {
      for (final p in providers) {
        if (p['id']?.toString() == providerId) {
          current = p;
          break;
        }
      }
    }
    final keyHint = (cfg['key_hint'] ?? cfg['keyHint'] ?? '').toString();

    return McInsetGroup(
      header: 'AI 联网搜索 (Web Search)',
      footer: current != null
          ? 'AI 助手在回答最新剧集档期、口碑与新闻时会自动调用联网搜索。'
          : '接入 Tavily 或 Brave Search API 后，AI 助手可实时检索外部网络信息。',
      children: [
        McInsetRow(
          icon: McIcons.globe,
          iconColor: current != null ? McTokens.ok : McTokens.textMuted,
          title: current != null
              ? (current['label'] ?? providerId ?? '已接入').toString()
              : '接入网页搜索服务',
          subtitle: current != null
              ? (keyHint.isNotEmpty ? '已连接 · 密钥 $keyHint' : '已连接')
              : '未接入',
          showChevron: true,
          onTap: _webSearchBusy ? null : _openWebSearchSheet,
        ),
        if (current != null) ...[
          McInsetRow(
            icon: McIcons.refreshS,
            title: '重新测试搜索连接',
            onTap: _webSearchBusy ? null : _retestWebSearch,
          ),
          McInsetRow(
            icon: McIcons.close,
            title: '关闭网页搜索',
            destructive: true,
            onTap: _webSearchBusy ? null : _clearWebSearch,
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: LLM 供应商 CRUD + 2s Verify 轮询 + #1338 default_model 保护
// ═══════════════════════════════════════════════════════════════════════════

class _LlmProvidersTab extends ConsumerStatefulWidget {
  const _LlmProvidersTab();

  @override
  ConsumerState<_LlmProvidersTab> createState() => _LlmProvidersTabState();
}

class _LlmProvidersTabState extends ConsumerState<_LlmProvidersTab> {
  List<Map<String, dynamic>> _providers = const [];
  List<Map<String, dynamic>> _presets = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _pollTimer;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_initialLoad);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _hasInProgress => _providers.any((p) {
        final st = (p['status'] ?? '').toString();
        return st == 'pending' || st == 'verifying';
      });

  void _syncPolling() {
    if (_hasInProgress && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_reloadProviders(silent: true));
      });
    } else if (!_hasInProgress) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  List<Map<String, dynamic>> _asMaps(dynamic v) {
    final l = v is List
        ? v
        : (v is Map
            ? (v['items'] ?? v['providers'] ?? v['presets'] ?? const [])
                as List<dynamic>
            : const <dynamic>[]);
    return l.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> _initialLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<dynamic>(Channel.general, 'GET', '/api/v1/llm/presets'),
        _mc.unwrap<dynamic>(Channel.general, 'GET', '/api/v1/llm/providers'),
      ]);
      if (!mounted) return;
      setState(() {
        _presets = _asMaps(results[0]);
        _providers = _asMaps(results[1]);
        _loading = false;
      });
      _syncPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = settingsErrorText(e);
        });
      }
    }
  }

  Future<void> _reloadProviders({bool silent = false}) async {
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/llm/providers',
      );
      if (!mounted) return;
      setState(() {
        _providers = _asMaps(raw);
        if (!silent) _error = null;
      });
      _syncPolling();
    } catch (e) {
      if (!silent && mounted) setState(() => _error = settingsErrorText(e));
    }
  }

  List<Map<String, dynamic>> get _editablePresets =>
      _presets.where((p) => (p['id'] ?? '').toString() != 'chatgpt').toList();

  Future<void> _openProviderForm({Map<String, dynamic>? existing}) async {
    if (existing != null &&
        (existing['provider_type'] ?? '').toString() == 'chatgpt') {
      McToast.info('ChatGPT 订阅渠道由服务端托管维护，仅支持查看状态。');
      return;
    }
    final saved = await showMcSheet<bool>(
      context: context,
      maxWidth: 620,
      builder: (_) => _LlmProviderFormSheet(
        mc: _mc,
        presets: _editablePresets,
        existing: existing,
        takenNames: _providers
            .where((p) => p['id'] != existing?['id'])
            .map((p) => (p['name'] ?? '').toString())
            .toList(),
      ),
    );
    if (saved == true && mounted) {
      await _reloadProviders();
    }
  }

  Future<void> _verify(Map<String, dynamic> p) async {
    final id = p['id'];
    setState(() => _busy = true);
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/llm/providers/$id/verify',
      );
      McToast.info('已发起连接验证…');
      await _reloadProviders();
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final name = (p['name'] ?? '').toString();
    final ok = await confirmDialog(
      context,
      title: '删除供应商「$name」？',
      message: '删除后该供应商下的模型将不再可用，已引用的默认路由会自动回退。',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/llm/providers/${p['id']}',
      );
      McToast.success('已删除 $name');
      await _reloadProviders();
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openProviderActions(Map<String, dynamic> p) {
    final isManaged = (p['provider_type'] ?? '').toString() == 'chatgpt';
    final name = (p['name'] ?? p['id'] ?? '').toString();
    final status = (p['status'] ?? '').toString();
    final errMsg = (p['error_message'] ?? p['last_error'] ?? '').toString();
    final defaultModel = (p['default_model'] ?? '').toString();
    final baseUrl = (p['base_url'] ?? '').toString();
    final proto = (p['api_protocol'] ?? '').toString();

    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            McInsetGroup(
              header: name,
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(title: '连接状态', valueText: _statusLabel(status)),
                if (baseUrl.isNotEmpty)
                  McInsetRow(title: '端点地址', subtitle: baseUrl),
                if (proto.isNotEmpty)
                  McInsetRow(
                    title: 'API 协议',
                    valueText: proto == 'openai_responses'
                        ? 'Responses API'
                        : 'Chat Completions',
                  ),
                if (defaultModel.isNotEmpty)
                  McInsetRow(title: '测试模型', valueText: defaultModel),
              ],
            ),
            if (errMsg.isNotEmpty) ...[
              const SizedBox(height: 10),
              SettingsNoticeBanner(
                text: errMsg,
                tone: SettingsTone.danger,
                margin: EdgeInsets.zero,
              ),
            ],
            if (isManaged) ...[
              const SizedBox(height: 10),
              const SettingsNoticeBanner(
                text: '此供应商为服务器托管的 ChatGPT 订阅渠道（只读）。',
                tone: SettingsTone.info,
                margin: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 12),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.refreshS,
                  title: '重新测试连接',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _verify(p);
                  },
                ),
                if (!isManaged) ...[
                  McInsetRow(
                    icon: McIcons.edit2,
                    title: '编辑供应商配置',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openProviderForm(existing: p);
                    },
                  ),
                  McInsetRow(
                    icon: McIcons.trash2,
                    title: '删除供应商',
                    destructive: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _delete(p);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'active' => '已连接',
        'verifying' => '测试中…',
        'pending' => '待测试',
        'failed' => '连接失败',
        _ => status.isEmpty ? '未知' : status,
      };

  static SettingsTone _statusTone(String status) => switch (status) {
        'active' => SettingsTone.ok,
        'verifying' => SettingsTone.info,
        'failed' => SettingsTone.danger,
        _ => SettingsTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const McLoadingView();
    return RefreshIndicator(
      onRefresh: _initialLoad,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '已接入供应商 (${_providers.length})',
                    style: McText.sub.semibold,
                  ),
                ),
                McChip(
                  icon: McIcons.addS,
                  label: '接入供应商',
                  selected: true,
                  compact: true,
                  onTap: (_busy || _editablePresets.isEmpty)
                      ? null
                      : () => _openProviderForm(),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            SettingsNoticeBanner(text: _error!, tone: SettingsTone.danger),
          ],
          const SizedBox(height: 10),
          if (_providers.isEmpty)
            McEmptyView(
              icon: McIcons.robot,
              title: '尚未配置大模型供应商',
              text: '支持百炼、DeepSeek、OpenAI、Claude、Gemini、Kimi、GLM 及任意 OpenAI 兼容端点。',
              actionLabel: _editablePresets.isNotEmpty ? '接入大模型供应商' : null,
              onRetry:
                  _editablePresets.isNotEmpty ? () => _openProviderForm() : null,
            )
          else
            McInsetGroup(
              footer: '保存后服务端会自动异步测试连通性；测试期间列表每 2 秒自动刷新状态。',
              children: [
                for (final p in _providers)
                  Builder(
                    builder: (context) {
                      final st = (p['status'] ?? '').toString();
                      final isManaged =
                          (p['provider_type'] ?? '').toString() == 'chatgpt';
                      return McInsetRow(
                        icon: McIcons.robotFill,
                        iconColor: settingsToneColor(_statusTone(st)),
                        title: (p['name'] ?? p['id'] ?? '').toString(),
                        subtitle: [
                          _statusLabel(st),
                          if (isManaged) '托管渠道',
                          if ((p['base_url'] ?? '').toString().isNotEmpty)
                            p['base_url'].toString(),
                        ].join(' · '),
                        trailing: SettingsStatusBadge(
                          label: _statusLabel(st),
                          tone: _statusTone(st),
                          showDot: true,
                        ),
                        showChevron: true,
                        onTap: () => _openProviderActions(p),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 接入 / 编辑 LLM 供应商弹层（动态字段、自定义模型草稿、#1338 保留 default_model）。
class _LlmProviderFormSheet extends StatefulWidget {
  const _LlmProviderFormSheet({
    required this.mc,
    required this.presets,
    required this.takenNames,
    this.existing,
  });

  final McClient mc;
  final List<Map<String, dynamic>> presets;
  final List<String> takenNames;
  final Map<String, dynamic>? existing;

  @override
  State<_LlmProviderFormSheet> createState() => _LlmProviderFormSheetState();
}

class _LlmProviderFormSheetState extends State<_LlmProviderFormSheet> {
  late String _providerType;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _uaCtrl;
  late final TextEditingController _keyCtrl;
  late String _apiProtocol;
  late List<Map<String, dynamic>> _extraModels;

  bool _showKey = false;
  bool _advancedOpen = false;
  bool _addingCustom = false;
  bool _busy = false;
  String? _error;

  // 自定义模型子表单状态
  final _cmIdCtrl = TextEditingController();
  final _cmCtxCtrl = TextEditingController(text: '131072');
  final _cmMaxOutCtrl = TextEditingController(text: '8192');
  final _cmMaxInCtrl = TextEditingController();
  final _cmBudgetCtrl = TextEditingController();
  bool _cmTools = true;
  bool _cmParallel = false;
  bool _cmThinking = false;
  bool _cmVision = false;
  bool _cmVideo = false;
  String _cmThinkingKind = 'none'; // none | effort | budget | toggle
  final Set<String> _cmEffortLevels = {};
  bool _cmSupportsOff = false;

  static const _effortVocab = ['minimal', 'low', 'medium', 'high', 'xhigh', 'max'];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _providerType = (ex?['provider_type'] ??
            (widget.presets.isNotEmpty ? widget.presets.first['id'] : 'bailian'))
        .toString();
    _nameCtrl = TextEditingController(text: (ex?['name'] ?? '').toString());
    _baseUrlCtrl =
        TextEditingController(text: (ex?['base_url'] ?? '').toString());
    _uaCtrl =
        TextEditingController(text: (ex?['user_agent'] ?? '').toString());
    _keyCtrl = TextEditingController();
    _apiProtocol = (ex?['api_protocol'] ?? '').toString();
    _advancedOpen = _uaCtrl.text.isNotEmpty || _apiProtocol.isNotEmpty;
    _extraModels = ((ex?['extra_models'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _uaCtrl.dispose();
    _keyCtrl.dispose();
    _cmIdCtrl.dispose();
    _cmCtxCtrl.dispose();
    _cmMaxOutCtrl.dispose();
    _cmMaxInCtrl.dispose();
    _cmBudgetCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _preset {
    for (final p in widget.presets) {
      if ((p['id'] ?? '').toString() == _providerType) return p;
    }
    return null;
  }

  List<Map<String, dynamic>> get _catalog =>
      ((_preset?['models'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

  bool get _isCustomEndpoint => _catalog.isEmpty;
  bool get _needBaseUrl => _preset?['requires_base_url'] == true;
  bool get _canCustomizeEndpoint => _preset?['base_url'] == null;
  List<String> get _selectableProtocols =>
      ((_preset?['selectable_protocols'] ?? const []) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
  bool get _canChooseProtocol => _selectableProtocols.length > 1;

  bool get _apiKeyRequired {
    final ex = widget.existing;
    if (ex == null) return true;
    var u = _baseUrlCtrl.text.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    final oldUrl = (ex['base_url'] ?? '').toString();
    return _providerType != (ex['provider_type'] ?? '').toString() ||
        u != oldUrl;
  }

  /// #1338 保护：编辑同一供应商类型且未删除原测试模型、未切到不兼容协议时，原样保留 `default_model`。
  String? _preservedDefaultModel(List<Map<String, dynamic>> extras) {
    final ex = widget.existing;
    if (ex == null ||
        _providerType != (ex['provider_type'] ?? '').toString()) {
      return null;
    }
    final current = (ex['default_model'] ?? '').toString().trim();
    if (current.isEmpty) return null;
    final oldExtras = ((ex['extra_models'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .toList();
    final wasInOldExtras =
        oldExtras.any((m) => (m['id'] ?? '').toString() == current);
    final stillInExtras =
        extras.any((m) => (m['id'] ?? '').toString() == current);
    if (wasInOldExtras && !stillInExtras) return null;

    final effectiveProto = (_canChooseProtocol && _apiProtocol.isNotEmpty)
        ? _apiProtocol
        : (_preset?['protocol'] ?? ex['api_protocol'] ?? '').toString();
    if (effectiveProto == 'openai_chat') {
      final known = [..._catalog, ...extras];
      for (final m in known) {
        if ((m['id'] ?? '').toString() == current &&
            m['requires_responses_for_tools'] == true) {
          return null;
        }
      }
    }
    return current;
  }

  String _fallbackName() {
    final base = (_preset?['display_name'] ?? _providerType).toString();
    var candidate = base;
    var i = 2;
    while (widget.takenNames.contains(candidate)) {
      candidate = '$base $i';
      i++;
    }
    return candidate;
  }

  String? get _submitHint {
    if (_nameCtrl.text.contains('/')) return '名称不能包含斜杠 /';
    if (_apiKeyRequired && _keyCtrl.text.trim().isEmpty) {
      return widget.existing == null ? '请填写 API Key' : '类型或端点变更，请重新填写 API Key';
    }
    final u = _baseUrlCtrl.text.trim();
    if (u.isEmpty && _needBaseUrl) return '请填写兼容端点 URL';
    if (u.isNotEmpty && !RegExp(r'^https?://.+').hasMatch(u)) {
      return '端点地址需以 http:// 或 https:// 开头';
    }
    if (_isCustomEndpoint && _extraModels.isEmpty) {
      return '请至少添加一个可用模型';
    }
    final ua = _uaCtrl.text.trim();
    if (ua.isNotEmpty &&
        ua.runes.any((r) => r < 0x20 || r > 0x7E)) {
      return 'User-Agent 仅允许可打印 ASCII 字符';
    }
    return null;
  }

  void _addCustomModel() {
    final id = _cmIdCtrl.text.trim();
    final ctx = int.tryParse(_cmCtxCtrl.text.trim());
    final maxOut = int.tryParse(_cmMaxOutCtrl.text.trim());
    final maxIn = int.tryParse(_cmMaxInCtrl.text.trim());
    final budget = int.tryParse(_cmBudgetCtrl.text.trim());
    if (id.isEmpty || ctx == null || ctx <= 0 || maxOut == null || maxOut <= 0) {
      McToast.error('请填写模型 ID、上下文窗口和最大输出 token');
      return;
    }
    if (_cmThinking && (budget == null || budget <= 0)) {
      McToast.error('开启思考输出时请填写思考预算上限');
      return;
    }
    if (_cmThinking && _cmThinkingKind == 'effort' && _cmEffortLevels.isEmpty) {
      McToast.error('请选择至少一个思考档位');
      return;
    }
    final modalities = <String>[
      'text',
      if (_cmVision) 'image',
      if (_cmVideo) 'video',
    ];
    final control = (!_cmThinking || _cmThinkingKind == 'none')
        ? null
        : <String, dynamic>{
            'kind': _cmThinkingKind,
            'levels': _cmThinkingKind == 'effort'
                ? _effortVocab.where(_cmEffortLevels.contains).toList()
                : const <String>[],
            'supports_off':
                _cmThinkingKind == 'toggle' ? true : _cmSupportsOff,
          };
    final entry = <String, dynamic>{
      'id': id,
      'context_window': ctx,
      if (maxIn != null && maxIn > 0) 'max_input_tokens': maxIn,
      'max_output_tokens': maxOut,
      'supports_tools': _cmTools,
      'supports_parallel_tool_calls': _cmTools && _cmParallel,
      'supports_thinking': _cmThinking,
      if (_cmThinking && budget != null) 'max_thinking_tokens': budget,
      if (control != null) 'thinking_control': control,
      'modalities': modalities,
    };
    setState(() {
      _extraModels = [
        ..._extraModels.where((m) => (m['id'] ?? '').toString() != id),
        entry,
      ];
      _cmIdCtrl.clear();
      _addingCustom = false;
    });
  }

  Future<void> _submit() async {
    if (_submitHint != null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final extras = _isCustomEndpoint ? _extraModels : const <Map<String, dynamic>>[];
    final name = _nameCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final ua = _uaCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    final defaultModel = _preservedDefaultModel(extras);

    final payload = <String, dynamic>{
      'name': name.isEmpty ? _fallbackName() : name,
      'provider_type': _providerType,
      if (baseUrl.isNotEmpty) 'base_url': baseUrl,
      'user_agent': (_canCustomizeEndpoint && ua.isNotEmpty) ? ua : null,
      if (_canChooseProtocol && _apiProtocol.isNotEmpty)
        'api_protocol': _apiProtocol,
      if (key.isNotEmpty) 'api_key': key,
      if (defaultModel != null) 'default_model': defaultModel,
      'extra_models': extras,
    };

    try {
      if (widget.existing != null) {
        await widget.mc.unwrap<dynamic>(
          Channel.general,
          'PUT',
          '/api/v1/llm/providers/${widget.existing!['id']}',
          body: payload,
        );
      } else {
        await widget.mc.unwrap<dynamic>(
          Channel.general,
          'POST',
          '/api/v1/llm/providers',
          body: payload,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = _submitHint;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? '接入大模型供应商' : '编辑大模型供应商',
            style: McText.titleSm,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            SettingsNoticeBanner(
              text: _error!,
              tone: SettingsTone.danger,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: widget.presets
                    .any((p) => (p['id'] ?? '').toString() == _providerType)
                ? _providerType
                : null,
            decoration: const InputDecoration(labelText: '供应商类型'),
            items: [
              for (final p in widget.presets)
                DropdownMenuItem(
                  value: (p['id'] ?? '').toString(),
                  child: Text((p['display_name'] ?? p['id'] ?? '').toString()),
                ),
            ],
            onChanged: (v) {
              if (v == null || v == _providerType) return;
              setState(() {
                _providerType = v;
                _baseUrlCtrl.clear();
                _uaCtrl.clear();
                _apiProtocol = '';
                _advancedOpen = false;
                _addingCustom = false;
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '实例名称（留空自动命名）',
              hintText: (_preset?['display_name'] ?? _providerType).toString(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_canCustomizeEndpoint) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _baseUrlCtrl,
              decoration: InputDecoration(
                labelText: _needBaseUrl ? 'API 端点地址 *' : 'API 端点地址（可选镜像/代理）',
                hintText: _needBaseUrl
                    ? 'http://192.168.1.5:8000/v1'
                    : '留空使用官方默认地址',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _keyCtrl,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: _apiKeyRequired ? 'API Key *' : 'API Key（留空沿用已存密钥）',
              hintText: _apiKeyRequired ? 'sk-...' : '留空不修改',
              suffixIcon: IconButton(
                icon: Icon(
                  _showKey ? McIcons.eyeOff : McIcons.eyeOpen,
                  size: 18,
                ),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_canCustomizeEndpoint) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _advancedOpen,
              onExpansionChanged: (v) => setState(() => _advancedOpen = v),
              title: Text(
                _canChooseProtocol ? '高级设置（API 协议 / User-Agent）' : '高级设置（User-Agent）',
                style: McText.sub,
              ),
              children: [
                if (_canChooseProtocol) ...[
                  DropdownButtonFormField<String>(
                    value: _apiProtocol.isNotEmpty
                        ? _apiProtocol
                        : (_preset?['protocol'] ?? _selectableProtocols.first)
                            .toString(),
                    decoration: const InputDecoration(labelText: 'API 协议'),
                    items: [
                      for (final id in _selectableProtocols)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            id == 'openai_responses'
                                ? 'Responses API'
                                : 'Chat Completions',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _apiProtocol = v ?? ''),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _uaCtrl,
                  decoration: InputDecoration(
                    labelText: '自定义 User-Agent（可选）',
                    hintText: (_preset?['default_user_agent'] ?? '留空使用默认 UA')
                        .toString(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
          if (_isCustomEndpoint) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '自定义模型目录 (${_extraModels.length})',
                    style: McText.sub.semibold,
                  ),
                ),
                McChip(
                  icon: McIcons.addS,
                  label: '添加模型',
                  compact: true,
                  onTap: () => setState(() => _addingCustom = !_addingCustom),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final m in _extraModels)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  (m['id'] ?? '').toString(),
                  style: McText.sub.copyWith(fontFamily: 'monospace'),
                ),
                subtitle: Text(
                  '上下文 ${m['context_window'] ?? '?'} · 输出 ${m['max_output_tokens'] ?? '?'}',
                  style: McText.micro.faint,
                ),
                trailing: IconButton(
                  icon: const Icon(McIcons.trash2, size: 16, color: McTokens.danger),
                  onPressed: () => setState(() {
                    _extraModels.removeWhere((e) => e['id'] == m['id']);
                  }),
                ),
              ),
            if (_addingCustom) _buildCustomModelDraft(),
          ] else if (_preset != null) ...[
            const SizedBox(height: 10),
            Text(
              '内置 ${_preset!['display_name']} 官方目录，共 ${_catalog.length} 个模型。',
              style: McText.caption.faint,
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(hint, style: McText.caption.copyWith(color: McTokens.warning)),
          ],
          const SizedBox(height: 16),
          McActionPill(
            label: _busy ? '保存中…' : '保存并自动验证连接',
            primary: true,
            expanded: true,
            onTap: hint == null && !_busy ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomModelDraft() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('添加自定义模型参数', style: McText.sub),
          const SizedBox(height: 10),
          TextField(
            controller: _cmIdCtrl,
            decoration: const InputDecoration(
              labelText: '模型 ID *',
              hintText: '例如：qwen3-235b / deepseek-r1',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmCtxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '上下文窗口 *'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cmMaxOutCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '最大输出 *'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cmMaxInCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '最大输入（可选）'),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('支持工具调用 (Tools)'),
            value: _cmTools,
            onChanged: (v) => setState(() {
              _cmTools = v;
              if (!v) _cmParallel = false;
            }),
          ),
          if (_cmTools)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('支持并发工具调用'),
              value: _cmParallel,
              onChanged: (v) => setState(() => _cmParallel = v),
            ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('支持图片输入 (Vision)'),
            value: _cmVision,
            onChanged: (v) => setState(() => _cmVision = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('支持视频输入 (Video)'),
            value: _cmVideo,
            onChanged: (v) => setState(() => _cmVideo = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('支持思考过程 (Thinking)'),
            value: _cmThinking,
            onChanged: (v) => setState(() {
              _cmThinking = v;
              if (!v) _cmThinkingKind = 'none';
            }),
          ),
          if (_cmThinking) ...[
            TextField(
              controller: _cmBudgetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '思考预算上限 (tokens) *',
                hintText: '例如：32768',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _cmThinkingKind,
              decoration: const InputDecoration(labelText: '思考控制模式'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('不可控（仅展示）')),
                DropdownMenuItem(value: 'effort', child: Text('档位直传 (effort)')),
                DropdownMenuItem(value: 'budget', child: Text('预算分段 (budget)')),
                DropdownMenuItem(value: 'toggle', child: Text('开关切换 (toggle)')),
              ],
              onChanged: (v) => setState(() => _cmThinkingKind = v ?? 'none'),
            ),
            if (_cmThinkingKind == 'effort') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final lv in _effortVocab)
                    McChip(
                      label: lv,
                      compact: true,
                      selected: _cmEffortLevels.contains(lv),
                      onTap: () => setState(() {
                        _cmEffortLevels.contains(lv)
                            ? _cmEffortLevels.remove(lv)
                            : _cmEffortLevels.add(lv);
                      }),
                    ),
                ],
              ),
            ],
            if (_cmThinkingKind == 'effort' || _cmThinkingKind == 'budget')
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('支持关闭思考 (supports_off)'),
                value: _cmSupportsOff,
                onChanged: (v) => setState(() => _cmSupportsOff = v),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '取消',
                  primary: false,
                  expanded: true,
                  onTap: () => setState(() => _addingCustom = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: McActionPill(
                  label: '加入目录',
                  primary: true,
                  expanded: true,
                  onTap: _addCustomModel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: Full Webhook（总开关、单端点开关/编辑/测试/投递历史、模板与请求头、HMAC 密钥轮换）
// ═══════════════════════════════════════════════════════════════════════════

class _WebhookTabBody extends ConsumerStatefulWidget {
  const _WebhookTabBody();

  @override
  ConsumerState<_WebhookTabBody> createState() => _WebhookTabBodyState();
}

class _WebhookTabBodyState extends ConsumerState<_WebhookTabBody> {
  bool _enabled = false;
  List<Map<String, dynamic>> _endpoints = const [];
  List<Map<String, dynamic>> _catalog = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  ({String name, String secret})? _revealed;
  String? _expandedEndpointId;
  List<Map<String, dynamic>> _deliveries = const [];

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  void _applyConfig(Map<String, dynamic> raw) {
    _enabled = raw['enabled'] == true;
    _endpoints = ((raw['endpoints'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    _catalog = ((raw['catalog'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<void> _load() async {
    if (_endpoints.isEmpty && _catalog.isEmpty) setState(() => _loading = true);
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/webhook',
      );
      if (!mounted) return;
      setState(() {
        _applyConfig(raw);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = settingsErrorText(e);
      });
    }
  }

  Map<String, dynamic> _toPayload(Map<String, dynamic> ep) => <String, dynamic>{
        'id': (ep['id'] ?? '').toString(),
        'name': (ep['name'] ?? '').toString(),
        'url': (ep['url'] ?? '').toString(),
        'format': (ep['format'] ?? 'movieclaw').toString(),
        'enabled': ep['enabled'] != false,
        'events': ((ep['events'] ?? const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        'template': (ep['template'] ?? '').toString(),
        'headers': ep['headers'] is Map
            ? Map<String, String>.fromEntries(
                (ep['headers'] as Map).entries.map(
                      (e) => MapEntry(e.key.toString(), e.value.toString()),
                    ),
              )
            : const <String, String>{},
        'egress_scope': (ep['egress_scope'] ?? 'lan').toString(),
      };

  Future<Map<String, dynamic>?> _saveAll({
    required bool enabled,
    required List<Map<String, dynamic>> endpoints,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/webhook',
        body: {
          'enabled': enabled,
          'endpoints': endpoints,
        },
      );
      if (mounted) {
        setState(() => _applyConfig(raw));
        // 捕获新建或从 jellyfin 切换到 movieclaw 时返回的一次性明文 secret
        for (final ep in _endpoints) {
          final sec = (ep['secret'] ?? '').toString();
          if (sec.isNotEmpty) {
            final epName = (ep['name']?.toString().isNotEmpty == true)
                ? ep['name'].toString()
                : (ep['url'] ?? 'Webhook').toString();
            setState(() => _revealed = (name: epName, secret: sec));
            break;
          }
        }
      }
      return raw;
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleGlobal(bool val) async {
    final prev = _enabled;
    setState(() => _enabled = val);
    final res = await _saveAll(
      enabled: val,
      endpoints: _endpoints.map(_toPayload).toList(),
    );
    if (res == null && mounted) setState(() => _enabled = prev);
  }

  Future<void> _toggleEndpoint(String id, bool val) async {
    final next = _endpoints.map((ep) {
      final p = _toPayload(ep);
      if (p['id'] == id) p['enabled'] = val;
      return p;
    }).toList();
    await _saveAll(enabled: _enabled, endpoints: next);
  }

  Future<void> _testEndpoint(Map<String, dynamic> ep) async {
    final id = (ep['id'] ?? '').toString();
    setState(() => _busy = true);
    try {
      final res = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/webhook/endpoints/${Uri.encodeComponent(id)}/test',
      );
      final ok = res['ok'] == true;
      if (ok) {
        McToast.success(
          '测试投递成功（HTTP ${res['status_code'] ?? '-'} · ${res['duration_ms'] ?? 0} ms）',
        );
      } else {
        final err = (res['error'] ?? '投递失败').toString();
        McToast.error(err);
      }
      await _load();
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleDeliveries(String id) async {
    if (_expandedEndpointId == id) {
      setState(() => _expandedEndpointId = null);
      return;
    }
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/webhook/endpoints/${Uri.encodeComponent(id)}/deliveries',
      );
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['items'] ?? const []) as List<dynamic> : const []);
      if (mounted) {
        setState(() {
          _deliveries =
              list.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _expandedEndpointId = id;
        });
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    }
  }

  Future<String?> _rotateSecret(String id) async {
    setState(() => _busy = true);
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/webhook/endpoints/${Uri.encodeComponent(id)}/rotate-secret',
      );
      final secret = (raw['secret'] ?? '').toString();
      final name = (raw['name']?.toString().isNotEmpty == true)
          ? raw['name'].toString()
          : (raw['url'] ?? 'Webhook').toString();
      if (secret.isNotEmpty && mounted) {
        setState(() => _revealed = (name: name, secret: secret));
      }
      await _load();
      return secret.isNotEmpty ? secret : null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    await showMcSheet<void>(
      context: context,
      maxWidth: 620,
      builder: (_) => _WebhookEditorSheet(
        existing: existing,
        catalog: _catalog,
        onSave: (payload) async {
          final id = (payload['id'] ?? '').toString();
          final rest = _endpoints
              .where((e) => (e['id'] ?? '').toString() != id)
              .map(_toPayload)
              .toList();
          final res = await _saveAll(
            enabled: _enabled,
            endpoints: [...rest, payload],
          );
          return res == null ? (_error ?? '保存失败') : null;
        },
        onRotate: _rotateSecret,
        onDelete: (id) async {
          final rest = _endpoints
              .where((e) => (e['id'] ?? '').toString() != id)
              .map(_toPayload)
              .toList();
          final res = await _saveAll(enabled: _enabled, endpoints: rest);
          return res != null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const McLoadingView();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          if (_error != null) ...[
            SettingsNoticeBanner(text: _error!, tone: SettingsTone.danger),
            const SizedBox(height: 8),
          ],
          if (_revealed != null) ...[
            McInsetGroup(
              header: '一次性 HMAC 签名密钥（${_revealed!.name}）',
              footer: '密钥明文仅显示这一次，请立刻复制并配置到接收端验证 X-MovieClaw-Signature。',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsCopyBox(
                        value: _revealed!.secret,
                        copyLabel: '复制密钥',
                      ),
                      const SizedBox(height: 10),
                      McActionPill(
                        label: '我已保存，关闭提示',
                        primary: false,
                        expanded: true,
                        onTap: () => setState(() => _revealed = null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          McInsetGroup(
            header: '全局开关',
            footer: '关闭总开关会暂停所有 Webhook 投递，但保留已配置目标。',
            children: [
              McInsetRow(
                icon: McIcons.sendPlaneFill,
                iconColor: _enabled ? McTokens.ok : McTokens.textMuted,
                title: '启用 Webhook 事件推送',
                trailing: Switch(
                  value: _enabled,
                  onChanged: _busy ? null : _toggleGlobal,
                ),
                onTap: _busy ? null : () => _toggleGlobal(!_enabled),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '推送目标 (${_endpoints.length})',
                    style: McText.sub.semibold,
                  ),
                ),
                McChip(
                  icon: McIcons.addS,
                  label: '新增目标',
                  selected: true,
                  compact: true,
                  onTap: _busy ? null : () => _openEditor(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_endpoints.isEmpty)
            McEmptyView(
              icon: McIcons.sendPlane,
              title: '暂无 Webhook 推送目标',
              text: '支持原生 MovieClaw HMAC 签名格式与 Jellyfin Handlebars 兼容模板。',
              actionLabel: '新增推送目标',
              onRetry: () => _openEditor(),
            )
          else
            McInsetGroup(
              children: [
                for (final ep in _endpoints) _buildEndpointTile(ep),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEndpointTile(Map<String, dynamic> ep) {
    final id = (ep['id'] ?? '').toString();
    final name = (ep['name']?.toString().isNotEmpty == true)
        ? ep['name'].toString()
        : (ep['url'] ?? '').toString();
    final url = (ep['url'] ?? '').toString();
    final format = (ep['format'] ?? 'movieclaw').toString();
    final enabled = ep['enabled'] != false;
    final last = ep['last_delivery'] is Map
        ? Map<String, dynamic>.from(ep['last_delivery'] as Map)
        : null;

    String statusLabel;
    SettingsTone tone;
    if (!enabled) {
      statusLabel = '已停用';
      tone = SettingsTone.neutral;
    } else if (last == null) {
      statusLabel = '尚未投递';
      tone = SettingsTone.neutral;
    } else {
      final dt = DateTime.tryParse((last['at'] ?? '').toString());
      final when = dt != null ? McFormatting.relative(dt) : '';
      final ok = last['ok'] == true;
      statusLabel = ok ? '已投递 $when' : '失败 $when';
      tone = ok ? SettingsTone.ok : SettingsTone.danger;
    }

    final expanded = _expandedEndpointId == id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.ui.semibold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SettingsStatusBadge(
                          label: format == 'jellyfin' ? 'Jellyfin 模板' : '原生格式',
                          tone: SettingsTone.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SettingsStatusBadge(
                          label: statusLabel,
                          tone: tone,
                          showDot: true,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.caption.faint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: _busy ? null : (v) => _toggleEndpoint(id, v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              McChip(
                label: '发送测试',
                compact: true,
                onTap: _busy ? null : () => _testEndpoint(ep),
              ),
              McChip(
                label: expanded ? '收起记录' : '投递记录',
                compact: true,
                selected: expanded,
                onTap: () => _toggleDeliveries(id),
              ),
              McChip(
                label: '编辑',
                compact: true,
                onTap: _busy ? null : () => _openEditor(existing: ep),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x38000000),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: McTokens.line),
              ),
              child: _deliveries.isEmpty
                  ? Text('暂无最近投递记录', style: McText.caption.faint)
                  : Column(
                      children: [
                        for (final d in _deliveries) ...[
                          Row(
                            children: [
                              SettingsStatusBadge(
                                label: d['ok'] == true ? 'OK' : 'ERR',
                                tone: d['ok'] == true
                                    ? SettingsTone.ok
                                    : SettingsTone.danger,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  (d['event'] ?? '').toString(),
                                  style: McText.micro.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Text(
                                'HTTP ${d['status_code'] ?? '-'} · ${d['duration_ms'] ?? 0}ms',
                                style: McText.micro.tabular.faint,
                              ),
                            ],
                          ),
                          if ((d['error'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  d['error'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: McText.micro.copyWith(
                                    color: McTokens.danger,
                                  ),
                                ),
                              ),
                            ),
                          const Divider(height: 12, color: McTokens.line),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebhookEditorSheet extends StatefulWidget {
  const _WebhookEditorSheet({
    required this.catalog,
    required this.onSave,
    required this.onRotate,
    required this.onDelete,
    this.existing,
  });

  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> catalog;
  final Future<String?> Function(Map<String, dynamic> payload) onSave;
  final Future<String?> Function(String id) onRotate;
  final Future<bool> Function(String id) onDelete;

  @override
  State<_WebhookEditorSheet> createState() => _WebhookEditorSheetState();
}

class _WebhookEditorSheetState extends State<_WebhookEditorSheet> {
  late final String _id = (widget.existing?['id'] ?? '').toString();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: (widget.existing?['name'] ?? '').toString());
  late final TextEditingController _urlCtrl =
      TextEditingController(text: (widget.existing?['url'] ?? '').toString());
  late final TextEditingController _tplCtrl = TextEditingController(
    text: (widget.existing?['template'] ?? '').toString(),
  );
  late final TextEditingController _headersCtrl;
  late String _format = (widget.existing?['format'] ?? 'movieclaw').toString();
  late bool _enabled = widget.existing?['enabled'] != false;
  late String _egressScope =
      (widget.existing?['egress_scope'] ?? 'lan').toString();
  late Set<String> _events;
  bool _busy = false;
  String? _error;
  String? _rotatedSecret;

  bool get _isNew => _id.isEmpty;

  @override
  void initState() {
    super.initState();
    final rawHeaders = widget.existing?['headers'];
    final headerLines = <String>[];
    if (rawHeaders is Map) {
      final keys = rawHeaders.keys.map((e) => e.toString()).toList()..sort();
      for (final k in keys) {
        headerLines.add('$k: ${rawHeaders[k]}');
      }
    }
    _headersCtrl = TextEditingController(text: headerLines.join('\n'));
    if (widget.existing != null) {
      _events = ((widget.existing!['events'] ?? const []) as List<dynamic>)
          .map((e) => e.toString())
          .toSet();
    } else {
      _events = widget.catalog
          .where((c) => c['default_on'] == true)
          .map((c) => (c['event'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _tplCtrl.dispose();
    _headersCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _parseHeaders() {
    final out = <String, String>{};
    for (final line in _headersCtrl.text.split('\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final k = line.substring(0, idx).trim();
      final v = line.substring(idx + 1).trim();
      if (k.isNotEmpty) out[k] = v;
    }
    return out;
  }

  bool _selectable(Map<String, dynamic> entry) =>
      _format != 'jellyfin' || entry['jellyfin_supported'] == true;

  void _setFormat(String next) {
    if (next == _format) return;
    setState(() {
      _format = next;
      if (next == 'jellyfin') {
        final allowed = widget.catalog
            .where((c) => c['jellyfin_supported'] == true)
            .map((c) => (c['event'] ?? '').toString())
            .toSet();
        _events.retainAll(allowed);
      }
    });
  }

  Future<void> _submit() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请填写目标 Webhook URL');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSave({
      'id': _id,
      'name': _nameCtrl.text.trim(),
      'url': url,
      'format': _format,
      'enabled': _enabled,
      'events': _events.toList(),
      'template': _tplCtrl.text,
      'headers': _parseHeaders(),
      'egress_scope': _egressScope,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsOrder = <String>[];
    final groupsMap = <String, List<Map<String, dynamic>>>{};
    for (final c in widget.catalog) {
      final g = (c['group'] ?? '事件').toString();
      if (!groupsMap.containsKey(g)) groupsOrder.add(g);
      groupsMap.putIfAbsent(g, () => []).add(c);
    }
    final secretMasked =
        (widget.existing?['secret_masked'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isNew ? '新增 Webhook 目标' : '编辑 Webhook 目标',
              style: McText.titleSm),
          if (_error != null) ...[
            const SizedBox(height: 10),
            SettingsNoticeBanner(
              text: _error!,
              tone: SettingsTone.danger,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '显示名称（可选）',
              hintText: '例如：Home Assistant / 通知网关',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: '目标 URL *',
              hintText: 'http://192.168.1.10:8123/api/webhook/xxx',
            ),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('启用此目标'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 6),
          Text('外发格式', style: McText.caption.muted),
          const SizedBox(height: 6),
          Row(
            children: [
              McChip(
                label: 'MovieClaw 原生 (HMAC)',
                compact: true,
                selected: _format == 'movieclaw',
                onTap: () => _setFormat('movieclaw'),
              ),
              const SizedBox(width: 8),
              McChip(
                label: 'Jellyfin 兼容模板',
                compact: true,
                selected: _format == 'jellyfin',
                onTap: () => _setFormat('jellyfin'),
              ),
            ],
          ),
          if (_format == 'jellyfin') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tplCtrl,
              maxLines: 6,
              style: McText.caption.copyWith(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Handlebars 载荷模板',
                hintText:
                    '{\n  "event": "{{NotificationType}}",\n  "title": {{json_encode Name}}\n}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _headersCtrl,
              maxLines: 3,
              style: McText.caption.copyWith(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: '附加请求头（每行一条 Key: Value）',
                hintText: 'X-Custom-Token: secret',
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('网络出口范围 (egress_scope)', style: McText.caption.muted),
          const SizedBox(height: 6),
          Row(
            children: [
              McChip(
                label: '仅局域网 (LAN)',
                compact: true,
                selected: _egressScope == 'lan',
                onTap: () => setState(() => _egressScope = 'lan'),
              ),
              const SizedBox(width: 8),
              McChip(
                label: '允许公网 (WAN)',
                compact: true,
                selected: _egressScope == 'wan',
                onTap: () => setState(() => _egressScope = 'wan'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final g in groupsOrder) ...[
            Builder(
              builder: (context) {
                final entries = groupsMap[g]!;
                final usable = entries.where(_selectable).toList();
                final allOn = usable.isNotEmpty &&
                    usable.every((e) => _events.contains(e['event']));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(g, style: McText.caption.semibold),
                        ),
                        if (usable.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              final ids = usable
                                  .map((e) => (e['event'] ?? '').toString())
                                  .toList();
                              if (allOn) {
                                _events.removeAll(ids);
                              } else {
                                _events.addAll(ids);
                              }
                            }),
                            child: Text(allOn ? '全不选' : '全选'),
                          ),
                      ],
                    ),
                    for (final entry in entries)
                      Builder(
                        builder: (context) {
                          final ev = (entry['event'] ?? '').toString();
                          final ok = _selectable(entry);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: ok && _events.contains(ev),
                            onChanged: !ok
                                ? null
                                : (v) => setState(() {
                                      v == true
                                          ? _events.add(ev)
                                          : _events.remove(ev);
                                    }),
                            title: Text(
                              (entry['label'] ?? ev).toString(),
                              style: McText.sub,
                            ),
                            subtitle: Text(
                              ok ? ev : '$ev（仅原生格式支持）',
                              style: McText.micro.copyWith(
                                fontFamily: 'monospace',
                                color: McTokens.textFaint,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
          if (!_isNew && _format == 'movieclaw') ...[
            const SizedBox(height: 12),
            McInsetGroup(
              margin: EdgeInsets.zero,
              header: 'HMAC 签名密钥',
              children: [
                McInsetRow(
                  title: '当前密钥',
                  valueText: secretMasked.isNotEmpty ? secretMasked : '无',
                ),
                if (_rotatedSecret != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SettingsCopyBox(
                      value: _rotatedSecret!,
                      copyLabel: '复制新密钥',
                    ),
                  ),
                McInsetRow(
                  icon: McIcons.key,
                  title: '轮换签名密钥',
                  onTap: _busy
                      ? null
                      : () async {
                          final ok = await confirmDialog(
                            context,
                            title: '轮换签名密钥？',
                            message: '旧密钥会立即失效，请同步更新接收端验签密钥。',
                            confirmLabel: '轮换',
                          );
                          if (!ok) return;
                          try {
                            final sec = await widget.onRotate(_id);
                            if (mounted) {
                              setState(() => _rotatedSecret = sec);
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _error = settingsErrorText(e));
                            }
                          }
                        },
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (!_isNew) ...[
                Expanded(
                  child: McActionPill(
                    label: '删除目标',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: _busy
                        ? null
                        : () async {
                            final nav = Navigator.of(context);
                            final ok = await confirmDialog(
                              context,
                              title: '删除此 Webhook？',
                              message: '删除后将不再向该地址推送事件。',
                              confirmLabel: '删除',
                            );
                            if (!ok || !mounted) return;
                            setState(() => _busy = true);
                            final done = await widget.onDelete(_id);
                            if (mounted) {
                              setState(() => _busy = false);
                              if (done) nav.pop();
                            }
                          },
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: McActionPill(
                  label: _busy ? '保存中…' : '保存目标',
                  primary: true,
                  expanded: true,
                  onTap: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
