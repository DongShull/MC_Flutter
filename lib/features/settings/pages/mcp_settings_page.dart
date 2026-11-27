import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ── MCP 数据模型（1:1 对齐 iOS SettingsBMCP* & Endpoints.swift）──────────────

class _McpService {
  const _McpService({
    required this.domain,
    this.description = '',
    this.commandCount = 0,
    this.expandedBytes = 0,
    this.collapsedBytes = 0,
  });

  factory _McpService.fromJson(Map<String, dynamic> j) => _McpService(
        domain: (j['domain'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        commandCount: ((j['command_count'] ?? j['commandCount']) as num?)
                ?.toInt() ??
            0,
        expandedBytes: ((j['expanded_bytes'] ?? j['expandedBytes']) as num?)
                ?.toInt() ??
            0,
        collapsedBytes: ((j['collapsed_bytes'] ?? j['collapsedBytes']) as num?)
                ?.toInt() ??
            0,
      );

  final String domain;
  final String description;
  final int commandCount;
  final int expandedBytes;
  final int collapsedBytes;
}

class _McpEndpoint {
  const _McpEndpoint({
    required this.id,
    required this.name,
    required this.slug,
    this.url = '',
    this.enabled = true,
    this.services = const [],
    this.missingServices = const [],
    this.expandTools = true,
    this.timeoutSeconds = 300,
    this.toolCount = 0,
    this.tokenHint = '',
    this.lastUsedAt,
  });

  factory _McpEndpoint.fromJson(Map<String, dynamic> j) => _McpEndpoint(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        enabled: j['enabled'] != false,
        services: ((j['services'] ?? const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        missingServices:
            ((j['missing_services'] ?? j['missingServices'] ?? const [])
                    as List<dynamic>)
                .map((e) => e.toString())
                .toList(),
        expandTools:
            j['expand_tools'] != false && j['expandTools'] != false,
        timeoutSeconds: ((j['timeout_seconds'] ?? j['timeoutSeconds']) as num?)
                ?.toInt() ??
            300,
        toolCount:
            ((j['tool_count'] ?? j['toolCount']) as num?)?.toInt() ?? 0,
        tokenHint: (j['token_hint'] ?? j['tokenHint'] ?? '').toString(),
        lastUsedAt: (j['last_used_at'] ?? j['lastUsedAt'])?.toString(),
      );

  final String id;
  final String name;
  final String slug;
  final String url;
  final bool enabled;
  final List<String> services;
  final List<String> missingServices;
  final bool expandTools;
  final int timeoutSeconds;
  final int toolCount;
  final String tokenHint;
  final String? lastUsedAt;
}

class _McpStatus {
  const _McpStatus({
    this.enabled = false,
    this.baseUrl = '',
    this.endpoints = const [],
    this.services = const [],
  });

  factory _McpStatus.fromJson(Map<String, dynamic> j) => _McpStatus(
        enabled: j['enabled'] == true,
        baseUrl: (j['base_url'] ?? j['baseUrl'] ?? '').toString(),
        endpoints: ((j['endpoints'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _McpEndpoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        services: ((j['services'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _McpService.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final bool enabled;
  final String baseUrl;
  final List<_McpEndpoint> endpoints;
  final List<_McpService> services;

  String fullUrl(_McpEndpoint ep) {
    if (ep.url.startsWith('http://') || ep.url.startsWith('https://')) {
      return ep.url;
    }
    final b = baseUrl.trim().isNotEmpty ? baseUrl.trim() : 'https://your-server';
    final path = ep.url.isNotEmpty ? ep.url : '/mcp/${ep.slug}';
    return '$b$path';
  }
}

class _McpToolParam {
  const _McpToolParam({
    required this.name,
    this.type = 'string',
    this.required = false,
    this.location = '',
    this.description = '',
    this.options = const [],
  });

  factory _McpToolParam.fromJson(Map<String, dynamic> j) => _McpToolParam(
        name: (j['name'] ?? '').toString(),
        type: (j['type'] ?? 'string').toString(),
        required: j['required'] == true,
        location: (j['location'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        options: ((j['options'] ?? const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final String name;
  final String type;
  final bool required;
  final String location;
  final String description;
  final List<String> options;
}

class _McpToolCommand {
  const _McpToolCommand({
    required this.name,
    this.summary = '',
    this.dangerous = '',
    this.isJob = false,
    this.params = const [],
  });

  factory _McpToolCommand.fromJson(Map<String, dynamic> j) => _McpToolCommand(
        name: (j['name'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        dangerous: (j['dangerous'] ?? '').toString(),
        isJob: j['is_job'] == true || j['isJob'] == true,
        params: ((j['params'] ?? const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final String name;
  final String summary;
  final String dangerous;
  final bool isJob;
  final List<String> params;
}

class _McpToolPreview {
  const _McpToolPreview({
    required this.name,
    this.service = '',
    this.summary = '',
    this.description = '',
    this.readOnly = true,
    this.destructive = false,
    this.parameters = const [],
    this.commands = const [],
  });

  factory _McpToolPreview.fromJson(Map<String, dynamic> j) => _McpToolPreview(
        name: (j['name'] ?? '').toString(),
        service: (j['service'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        readOnly: j['read_only'] == true || j['readOnly'] == true,
        destructive: j['destructive'] == true,
        parameters: ((j['parameters'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _McpToolParam.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        commands: ((j['commands'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _McpToolCommand.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final String name;
  final String service;
  final String summary;
  final String description;
  final bool readOnly;
  final bool destructive;
  final List<_McpToolParam> parameters;
  final List<_McpToolCommand> commands;

  String sampleJson() {
    if (commands.isNotEmpty) {
      return const JsonEncoder.withIndent('  ').convert({
        'name': name,
        'arguments': {
          'command': commands.first.name,
          'params': const <String, dynamic>{},
        },
      });
    }
    final req = parameters.where((p) => p.required).toList();
    final args = <String, dynamic>{
      for (final p in req) p.name: '<${p.type}>',
    };
    return const JsonEncoder.withIndent('  ').convert({
      'name': name,
      'arguments': args,
    });
  }
}

class _McpPreview {
  const _McpPreview({this.approxBytes = 0, this.tools = const []});

  factory _McpPreview.fromJson(Map<String, dynamic> j) => _McpPreview(
        approxBytes:
            ((j['approx_bytes'] ?? j['approxBytes']) as num?)?.toInt() ?? 0,
        tools: ((j['tools'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _McpToolPreview.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final int approxBytes;
  final List<_McpToolPreview> tools;
}

class _McpSelfCheck {
  const _McpSelfCheck({
    required this.ok,
    required this.message,
    this.protocolVersion = '',
    this.toolCount = 0,
    this.elapsedMs = 0,
    this.probeTool = '',
    this.probeOk = false,
    this.probeMessage = '',
    this.warnings = const [],
  });

  factory _McpSelfCheck.fromJson(Map<String, dynamic> j) => _McpSelfCheck(
        ok: j['ok'] == true,
        message: (j['message'] ?? '').toString(),
        protocolVersion:
            (j['protocol_version'] ?? j['protocolVersion'] ?? '').toString(),
        toolCount:
            ((j['tool_count'] ?? j['toolCount']) as num?)?.toInt() ?? 0,
        elapsedMs:
            ((j['elapsed_ms'] ?? j['elapsedMs']) as num?)?.toInt() ?? 0,
        probeTool: (j['probe_tool'] ?? j['probeTool'] ?? '').toString(),
        probeOk: j['probe_ok'] == true || j['probeOk'] == true,
        probeMessage:
            (j['probe_message'] ?? j['probeMessage'] ?? '').toString(),
        warnings: ((j['warnings'] ?? const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final bool ok;
  final String message;
  final String protocolVersion;
  final int toolCount;
  final int elapsedMs;
  final String probeTool;
  final bool probeOk;
  final String probeMessage;
  final List<String> warnings;
}

String _fmtDefBytes(int n) =>
    n >= 1024 ? '${(n / 1024).toStringAsFixed(1)} KB' : '$n B';

final _mcpSlugRegex = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,38}[a-z0-9])?$');

/// 设置 → MCP 服务（管理员，1:1 对齐 iOS `MCPSettingsView` + `SettingsBMCP*`）。
class McpSettingsPage extends ConsumerStatefulWidget {
  const McpSettingsPage({super.key});

  @override
  ConsumerState<McpSettingsPage> createState() => _McpSettingsPageState();
}

class _McpSettingsPageState extends ConsumerState<McpSettingsPage> {
  _McpStatus? _status;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_status == null) setState(() => _loading = true);
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/mcp/status',
      );
      if (!mounted) return;
      setState(() {
        _status = _McpStatus.fromJson(raw);
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

  Future<void> _toggleService(bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/mcp/status',
        body: {'enabled': enabled},
      );
      if (mounted) setState(() => _status = _McpStatus.fromJson(raw));
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCreateSheet() async {
    final status = _status;
    if (status == null) return;
    final created = await showMcSheet<({_McpEndpoint endpoint, String token})>(
      context: context,
      maxWidth: 600,
      builder: (_) => _McpEndpointFormSheet(
        mc: _mc,
        status: status,
        takenSlugs: status.endpoints.map((e) => e.slug).toList(),
      ),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    final latest = _status ?? status;
    await _showTokenIssuedSheet(
      name: created.endpoint.name,
      url: latest.fullUrl(created.endpoint),
      token: created.token,
    );
    if (!mounted) return;
    await _openDetail(created.endpoint.id);
  }

  Future<void> _showTokenIssuedSheet({
    required String name,
    required String url,
    required String token,
  }) {
    final claudeCmd =
        'claude mcp add --transport http movieclaw $url --header "Authorization: Bearer $token"';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB8000000),
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (ctx) => McSheetFrame(
        title: '保存 MCP 访问令牌',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsNoticeBanner(
                text: '端点「$name」的明文令牌仅在本次展示，服务端只存哈希，关闭后无法再次查看，请立刻复制保存。',
                tone: SettingsTone.warn,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              Text('端点地址', style: McText.caption.muted),
              const SizedBox(height: 6),
              SettingsCopyBox(value: url, copyLabel: '复制地址'),
              const SizedBox(height: 12),
              Text('访问令牌 (Bearer Token)', style: McText.caption.muted),
              const SizedBox(height: 6),
              SettingsCopyBox(value: token, copyLabel: '复制令牌'),
              const SizedBox(height: 14),
              Text('Claude Code 一键接入命令', style: McText.caption.muted),
              const SizedBox(height: 6),
              SettingsCodeBlock(code: claudeCmd, lang: 'BASH'),
              const SizedBox(height: 18),
              McActionPill(
                label: '我已妥善保存，继续',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(String endpointId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _McpEndpointDetailPage(
          mc: _mc,
          endpointId: endpointId,
          initialStatus: _status!,
          onStatusChanged: (next) {
            if (mounted) setState(() => _status = next);
          },
          onTokenIssued: (name, url, token) => _showTokenIssuedSheet(
            name: name,
            url: url,
            token: token,
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return SettingsScaffold(
      title: 'MCP 服务',
      actions: [
        McChip(
          icon: McIcons.addS,
          label: '新建端点',
          selected: true,
          compact: true,
          onTap: (_busy || status == null) ? null : _openCreateSheet,
        ),
      ],
      body: _loading && status == null
          ? const McLoadingView()
          : _error != null && status == null
              ? McErrorView(text: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 36),
                    children: [
                      if (_error != null) ...[
                        SettingsNoticeBanner(
                          text: _error!,
                          tone: SettingsTone.danger,
                        ),
                        const SizedBox(height: 8),
                      ],
                      McInsetGroup(
                        header: 'MCP 总开关',
                        children: [
                          McInsetRow(
                            icon: McIcons.links,
                            iconColor: status!.enabled
                                ? McTokens.ok
                                : McTokens.textMuted,
                            title: '启用 MCP HTTP 服务',
                            subtitle: status.baseUrl.isNotEmpty
                                ? '${status.baseUrl}/mcp/<slug>'
                                : '未配置外部访问地址（使用当前服务地址）',
                            trailing: Switch(
                              value: status.enabled,
                              onChanged: _busy ? null : _toggleService,
                            ),
                            onTap: _busy
                                ? null
                                : () => _toggleService(!status.enabled),
                          ),
                        ],
                      ),
                      if (!status.enabled && status.endpoints.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const SettingsNoticeBanner(
                          text: 'MCP 总开关当前已关闭，外部客户端请求所有端点都将返回不可用。',
                          tone: SettingsTone.warn,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (status.endpoints.isEmpty)
                        McEmptyView(
                          icon: McIcons.links,
                          title: '暂无 MCP 端点',
                          text:
                              '创建专用 MCP 端点并按需开放服务域，即可把 MovieClaw 安全接入 Claude Code、Cursor 等外部智能体。',
                          actionLabel: '新建端点',
                          onRetry: _openCreateSheet,
                        )
                      else
                        McInsetGroup(
                          header: '已配置端点 (${status.endpoints.length})',
                          footer: '每个端点使用独立 Bearer 令牌与可访问的服务白名单，支持实时握手自检与工具目录预览。',
                          children: [
                            for (final ep in status.endpoints)
                              McInsetRow(
                                icon: McIcons.links,
                                iconColor: ep.enabled
                                    ? McTokens.ok
                                    : McTokens.textFaint,
                                title: ep.name,
                                subtitle:
                                    '/mcp/${ep.slug} · ${ep.toolCount} 个工具 · ${ep.enabled ? '已启用' : '已停用'}',
                                trailing: SettingsStatusBadge(
                                  label: ep.enabled ? '运行中' : '停用',
                                  tone: ep.enabled
                                      ? SettingsTone.ok
                                      : SettingsTone.neutral,
                                  showDot: true,
                                ),
                                showChevron: true,
                                onTap: () => _openDetail(ep.id),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ── MCP 端点详情页（含实时握手自检 + 工具目录导航 + 轮换令牌 + Slug 确认删除）──

class _McpEndpointDetailPage extends StatefulWidget {
  const _McpEndpointDetailPage({
    required this.mc,
    required this.endpointId,
    required this.initialStatus,
    required this.onStatusChanged,
    required this.onTokenIssued,
  });

  final McClient mc;
  final String endpointId;
  final _McpStatus initialStatus;
  final ValueChanged<_McpStatus> onStatusChanged;
  final Future<void> Function(String name, String url, String token)
      onTokenIssued;

  @override
  State<_McpEndpointDetailPage> createState() => _McpEndpointDetailPageState();
}

class _McpEndpointDetailPageState extends State<_McpEndpointDetailPage> {
  late _McpStatus _status = widget.initialStatus;
  _McpPreview? _preview;
  String? _previewError;
  _McpSelfCheck? _check;
  bool _checking = false;
  bool _busy = false;
  String? _error;

  _McpEndpoint? get _endpoint {
    for (final e in _status.endpoints) {
      if (e.id == widget.endpointId) return e;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPreview);
  }

  Future<void> _reloadStatus() async {
    final raw = await widget.mc.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/mcp/status',
    );
    final next = _McpStatus.fromJson(raw);
    if (!mounted) return;
    setState(() => _status = next);
    widget.onStatusChanged(next);
  }

  Future<void> _loadPreview() async {
    final ep = _endpoint;
    if (ep == null) return;
    setState(() {
      _preview = null;
      _previewError = null;
    });
    try {
      final raw = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/mcp/endpoints/preview',
        body: {
          'services': ep.services,
          'expand_tools': ep.expandTools,
        },
      );
      if (mounted) setState(() => _preview = _McpPreview.fromJson(raw));
    } catch (e) {
      if (mounted) setState(() => _previewError = settingsErrorText(e));
    }
  }

  Future<void> _updateEndpoint(Map<String, dynamic> body) async {
    final ep = _endpoint;
    if (ep == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      try {
        await widget.mc.unwrap<dynamic>(
          Channel.general,
          'PUT',
          '/api/v1/mcp/endpoints/${Uri.encodeComponent(ep.id)}',
          body: body,
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 405) {
          await widget.mc.unwrap<dynamic>(
            Channel.general,
            'PATCH',
            '/api/v1/mcp/endpoints/${Uri.encodeComponent(ep.id)}',
            body: body,
          );
        } else {
          rethrow;
        }
      }
      await _reloadStatus();
      await _loadPreview();
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runCheck() async {
    final ep = _endpoint;
    if (ep == null || _checking) return;
    setState(() => _checking = true);
    try {
      final raw = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/mcp/endpoints/${Uri.encodeComponent(ep.id)}/check',
      );
      if (mounted) setState(() => _check = _McpSelfCheck.fromJson(raw));
    } catch (e) {
      if (mounted) {
        setState(
          () => _check = _McpSelfCheck(
            ok: false,
            message: '握手探测请求失败：${settingsErrorText(e)}',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _rotateToken() async {
    final ep = _endpoint;
    if (ep == null) return;
    final ok = await confirmDialog(
      context,
      title: '轮换访问令牌？',
      message: '生成新令牌后，旧令牌将立即失效，已连接的 MCP 客户端需要同步更新配置。',
      confirmLabel: '生成新令牌',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Map<String, dynamic> raw;
      try {
        raw = await widget.mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/mcp/endpoints/${Uri.encodeComponent(ep.id)}/token',
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 404) {
          raw = await widget.mc.unwrap<Map<String, dynamic>>(
            Channel.general,
            'POST',
            '/api/v1/mcp/endpoints/${Uri.encodeComponent(ep.id)}/rotate-token',
          );
        } else {
          rethrow;
        }
      }
      final token = (raw['token'] ?? '').toString();
      await _reloadStatus();
      if (mounted && token.isNotEmpty) {
        final refreshed = _endpoint ?? ep;
        await widget.onTokenIssued(
          refreshed.name,
          _status.fullUrl(refreshed),
          token,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditSheet() async {
    final ep = _endpoint;
    if (ep == null) return;
    final updated = await showMcSheet<bool>(
      context: context,
      maxWidth: 600,
      builder: (_) => _McpEndpointFormSheet(
        mc: widget.mc,
        status: _status,
        existing: ep,
        takenSlugs: const [],
      ),
    );
    if (updated == true && mounted) {
      await _reloadStatus();
      await _loadPreview();
      McToast.success('端点配置已更新');
    }
  }

  Future<void> _openDeleteSheet() async {
    final ep = _endpoint;
    if (ep == null) return;
    final slugCtrl = TextEditingController();
    final deleted = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final match = slugCtrl.text.trim() == ep.slug;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('删除 MCP 端点「${ep.name}」', style: McText.titleSm),
                const SizedBox(height: 8),
                Text(
                  '删除后该端点的所有令牌立即失效，且无法恢复。请输入端点标识 ${ep.slug} 以确认删除。',
                  style: McText.sub.muted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '输入 ${ep.slug} 确认',
                    hintText: ep.slug,
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 18),
                McActionPill(
                  label: '永久删除端点',
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  onTap: !match
                      ? null
                      : () async {
                          try {
                            await widget.mc.unwrap<dynamic>(
                              Channel.general,
                              'DELETE',
                              '/api/v1/mcp/endpoints/${Uri.encodeComponent(ep.id)}',
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            McToast.error(settingsErrorText(e));
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
    if (deleted == true && mounted) {
      McToast.success('端点已删除');
      Navigator.of(context).pop();
    }
  }

  void _openToolCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _McpToolCatalogPage(
          endpointName: _endpoint?.name ?? '工具目录',
          preview: _preview,
          previewError: _previewError,
          onReload: _loadPreview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ep = _endpoint;
    if (ep == null) {
      return const SettingsScaffold(
        title: 'MCP 端点',
        body: McEmptyView(
          title: '端点不存在或已被删除',
          text: '请返回列表刷新查看最新 MCP 端点。',
        ),
      );
    }

    final fullUrl = _status.fullUrl(ep);
    final lastUsedDt =
        ep.lastUsedAt != null ? DateTime.tryParse(ep.lastUsedAt!) : null;

    return SettingsScaffold(
      title: ep.name,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(McIcons.dotVerticalS, size: 20),
          onSelected: (v) {
            if (v == 'edit') _openEditSheet();
            if (v == 'rotate') _rotateToken();
            if (v == 'delete') _openDeleteSheet();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑配置')),
            PopupMenuItem(value: 'rotate', child: Text('轮换访问令牌')),
            PopupMenuItem(
              value: 'delete',
              child: Text('删除端点', style: TextStyle(color: McTokens.danger)),
            ),
          ],
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          await _reloadStatus();
          await _loadPreview();
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 36),
          children: [
            if (_error != null) ...[
              SettingsNoticeBanner(text: _error!, tone: SettingsTone.danger),
              const SizedBox(height: 8),
            ],
            McInsetGroup(
              children: [
                McInsetRow(
                  icon: ep.enabled ? McIcons.checkCircleFill : McIcons.pause,
                  iconColor: ep.enabled ? McTokens.ok : McTokens.textMuted,
                  title: ep.enabled ? '端点已启用' : '端点已停用',
                  trailing: Switch(
                    value: ep.enabled,
                    onChanged: _busy
                        ? null
                        : (v) => _updateEndpoint({'enabled': v}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('端点地址', style: McText.caption.muted),
                  const SizedBox(height: 6),
                  SettingsCopyBox(value: fullUrl, copyLabel: '复制地址'),
                  if (!ep.url.startsWith('http')) ...[
                    const SizedBox(height: 8),
                    const SettingsNoticeBanner(
                      text: '尚未配置「外部访问地址」，当前使用相对路径拼装；如需公网接入请在「系统 → 网络与外部访问」设置。',
                      tone: SettingsTone.warn,
                      margin: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text('认证请求头样例', style: McText.caption.muted),
                  const SizedBox(height: 6),
                  const SettingsCodeBlock(
                    code: 'Authorization: Bearer <你的端点令牌>',
                    lang: 'HTTP',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 实时握手自检
            McInsetGroup(
              header: '实时协议握手自检',
              children: [
                McInsetRow(
                  icon: McIcons.radar,
                  title: '执行实时握手探测',
                  subtitle: '真实发起 MCP 握手并调用只读探针工具，检测耗时与工具数',
                  trailing: McChip(
                    label: _checking
                        ? '探测中…'
                        : (_check == null ? '开始自检' : '再次自检'),
                    selected: true,
                    compact: true,
                    onTap: _checking ? null : _runCheck,
                  ),
                ),
                if (_check != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SettingsStatusBadge(
                              label: _check!.ok ? '通过' : '未通过',
                              tone: _check!.ok
                                  ? SettingsTone.ok
                                  : SettingsTone.danger,
                              showDot: true,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _check!.message,
                                style: McText.sub.copyWith(
                                  color: _check!.ok
                                      ? McTokens.text
                                      : McTokens.danger,
                                ),
                              ),
                            ),
                            Text(
                              '${_check!.elapsedMs} ms',
                              style: McText.caption.tabular.faint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '协议版本：${_check!.protocolVersion.isEmpty ? '—' : _check!.protocolVersion} · 工具数：${_check!.toolCount}',
                          style: McText.caption.muted,
                        ),
                        if (_check!.probeTool.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '只读探针：${_check!.probeTool}（${_check!.probeOk ? '成功' : '失败'}）${_check!.probeMessage.isNotEmpty ? ' · ${_check!.probeMessage}' : ''}',
                            style: McText.caption.faint,
                          ),
                        ],
                        for (final w in _check!.warnings) ...[
                          const SizedBox(height: 8),
                          SettingsNoticeBanner(
                            text: w,
                            tone: SettingsTone.warn,
                            margin: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 端点概览与工具目录入口
            McInsetGroup(
              header: '开放范围与工具目录',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('已开放服务域 (${ep.services.length})',
                          style: McText.caption.muted),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in ep.services)
                            SettingsStatusBadge(
                              label: s,
                              tone: SettingsTone.info,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                McInsetRow(
                  icon: McIcons.listSettings2,
                  title: '浏览工具目录 (Tool Catalog)',
                  subtitle: _preview != null
                      ? '${_preview!.tools.length} 个工具 · 定义体积 ${_fmtDefBytes(_preview!.approxBytes)}'
                      : (_previewError ?? '正在计算工具定义…'),
                  valueText: '${ep.toolCount} 个',
                  showChevron: true,
                  onTap: _openToolCatalog,
                ),
                McInsetRow(
                  title: '工具暴露模式',
                  valueText: ep.expandTools ? '按命令展开' : '按服务折叠',
                ),
                McInsetRow(
                  title: '令牌标识',
                  valueText: ep.tokenHint.isNotEmpty ? ep.tokenHint : '—',
                ),
                McInsetRow(
                  title: '超时限制',
                  valueText: '${ep.timeoutSeconds} 秒',
                ),
                McInsetRow(
                  title: '最近调用',
                  valueText: lastUsedDt != null
                      ? McFormatting.relative(lastUsedDt)
                      : '从未调用',
                ),
              ],
            ),
            if (ep.missingServices.isNotEmpty) ...[
              const SizedBox(height: 12),
              SettingsNoticeBanner(
                text:
                    '以下 ${ep.missingServices.length} 个已声明服务当前不可用：${ep.missingServices.join('、')}',
                tone: SettingsTone.warn,
              ),
            ],
            const SizedBox(height: 16),
            McInsetGroup(
              children: [
                McInsetRow(
                  icon: McIcons.edit2,
                  title: '编辑端点配置',
                  onTap: _openEditSheet,
                ),
                McInsetRow(
                  icon: McIcons.key,
                  title: '轮换访问令牌',
                  onTap: _busy ? null : _rotateToken,
                ),
                McInsetRow(
                  icon: McIcons.trash2,
                  title: '删除此端点',
                  destructive: true,
                  onTap: _busy ? null : _openDeleteSheet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── MCP 工具目录页（搜索、All/Read-only/Mutating 过滤、破坏性标记、展开参数 & 复制 JSON 示例）──

class _McpToolCatalogPage extends StatefulWidget {
  const _McpToolCatalogPage({
    required this.endpointName,
    required this.preview,
    required this.previewError,
    required this.onReload,
  });

  final String endpointName;
  final _McpPreview? preview;
  final String? previewError;
  final Future<void> Function() onReload;

  @override
  State<_McpToolCatalogPage> createState() => _McpToolCatalogPageState();
}

class _McpToolCatalogPageState extends State<_McpToolCatalogPage> {
  String _query = '';
  int _filter = 0; // 0=全部, 1=只读, 2=会改动
  String? _openTool;
  final Set<String> _collapsedGroups = {};

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    if (preview == null) {
      return SettingsScaffold(
        title: '${widget.endpointName} · 工具目录',
        body: widget.previewError != null
            ? McErrorView(text: widget.previewError!, onRetry: widget.onReload)
            : const McLoadingView(),
      );
    }

    final kw = _query.trim().toLowerCase();
    final matched = preview.tools.where((t) {
      if (_filter == 1 && !t.readOnly) return false;
      if (_filter == 2 && t.readOnly) return false;
      if (kw.isEmpty) return true;
      return t.name.toLowerCase().contains(kw) ||
          t.description.toLowerCase().contains(kw) ||
          t.commands.any(
            (c) => '${c.name} ${c.summary}'.toLowerCase().contains(kw),
          );
    }).toList();

    final grouped = <String, List<_McpToolPreview>>{};
    for (final t in matched) {
      grouped.putIfAbsent(t.service.isEmpty ? 'default' : t.service, () => [])
          .add(t);
    }
    final keys = grouped.keys.toList()..sort();

    return SettingsScaffold(
      title: '工具目录 (${matched.length}/${preview.tools.length})',
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 36),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(McIcons.search, size: 18),
                    hintText: '搜索工具名、说明或命令…',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final (idx, label) in const [
                      (0, '全部'),
                      (1, '仅只读'),
                      (2, '会改动'),
                    ]) ...[
                      McChip(
                        label: label,
                        compact: true,
                        selected: _filter == idx,
                        onTap: () => setState(() => _filter = idx),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (matched.isEmpty)
            const McEmptyView(
              title: '没有匹配的工具',
              text: '请尝试修改搜索关键词或切换读写筛选。',
            )
          else
            for (final service in keys) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: InkWell(
                  onTap: () => setState(() {
                    if (_collapsedGroups.contains(service)) {
                      _collapsedGroups.remove(service);
                    } else {
                      _collapsedGroups.add(service);
                    }
                  }),
                  child: Row(
                    children: [
                      Icon(
                        _collapsedGroups.contains(service)
                            ? McIcons.arrowRightMFill
                            : McIcons.arrowDownMFill,
                        size: 14,
                        color: McTokens.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        service,
                        style: McText.sub.semibold.copyWith(
                          fontFamily: 'monospace',
                          color: McTokens.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${grouped[service]!.length} 个工具',
                        style: McText.caption.faint,
                      ),
                    ],
                  ),
                ),
              ),
              if (!_collapsedGroups.contains(service))
                McInsetGroup(
                  children: [
                    for (final tool in grouped[service]!) _buildToolRow(tool),
                  ],
                ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildToolRow(_McpToolPreview tool) {
    final open = _openTool == tool.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _openTool = open ? null : tool.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            tool.name,
                            style: McText.sub.semibold.copyWith(
                              fontFamily: 'monospace',
                              color: McTokens.accentStrong,
                            ),
                          ),
                          if (tool.readOnly)
                            const SettingsStatusBadge(
                              label: '只读',
                              tone: SettingsTone.info,
                            ),
                          if (tool.destructive)
                            const SettingsStatusBadge(
                              label: '破坏性',
                              tone: SettingsTone.danger,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.summary.isNotEmpty
                            ? tool.summary
                            : tool.description,
                        style: McText.caption.muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tool.commands.isNotEmpty
                      ? '${tool.commands.length} 命令'
                      : '${tool.parameters.length} 参数',
                  style: McText.caption.tabular.faint,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Container(
            color: const Color(0x33000000),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tool.description.isNotEmpty) ...[
                  Text(tool.description, style: McText.caption.muted),
                  const SizedBox(height: 10),
                ],
                if (tool.commands.isNotEmpty) ...[
                  Text('包含命令 (${tool.commands.length})',
                      style: McText.micro.faint),
                  const SizedBox(height: 6),
                  for (final cmd in tool.commands) ...[
                    Row(
                      children: [
                        Text(
                          cmd.name,
                          style: McText.caption.copyWith(
                            fontFamily: 'monospace',
                            color: McTokens.text,
                          ),
                        ),
                        if (cmd.dangerous.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const SettingsStatusBadge(
                            label: '高风险',
                            tone: SettingsTone.danger,
                          ),
                        ],
                      ],
                    ),
                    if (cmd.summary.isNotEmpty)
                      Text(cmd.summary, style: McText.micro.muted),
                    if (cmd.params.isNotEmpty)
                      Text(
                        cmd.params.join(', '),
                        style: McText.micro.copyWith(
                          fontFamily: 'monospace',
                          color: McTokens.textFaint,
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                ] else if (tool.parameters.isEmpty)
                  Text('无需参数', style: McText.caption.faint)
                else ...[
                  Text('输入参数', style: McText.micro.faint),
                  const SizedBox(height: 6),
                  for (final p in tool.parameters) ...[
                    Row(
                      children: [
                        Text(
                          '${p.name}${p.required ? '*' : ''}',
                          style: McText.caption.copyWith(
                            fontFamily: 'monospace',
                            color: p.required
                                ? McTokens.danger
                                : McTokens.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.type,
                          style: McText.micro.copyWith(
                            fontFamily: 'monospace',
                            color: McTokens.textMuted,
                          ),
                        ),
                        if (p.location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(p.location, style: McText.micro.faint),
                        ],
                      ],
                    ),
                    if (p.description.isNotEmpty)
                      Text(p.description, style: McText.micro.muted),
                    if (p.options.isNotEmpty)
                      Text(
                        '可选值：${p.options.join(' / ')}',
                        style: McText.micro.copyWith(
                          fontFamily: 'monospace',
                          color: McTokens.textFaint,
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    McChip(
                      label: '复制工具名',
                      compact: true,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tool.name));
                        McToast.success('已复制工具名');
                      },
                    ),
                    McChip(
                      label: '复制调用 JSON 样例',
                      compact: true,
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: tool.sampleJson()),
                        );
                        McToast.success('已复制调用 JSON 样例');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 新建 / 编辑 MCP 端点表单弹层 ────────────────────────────────────────────

class _McpEndpointFormSheet extends StatefulWidget {
  const _McpEndpointFormSheet({
    required this.mc,
    required this.status,
    required this.takenSlugs,
    this.existing,
  });

  final McClient mc;
  final _McpStatus status;
  final List<String> takenSlugs;
  final _McpEndpoint? existing;

  @override
  State<_McpEndpointFormSheet> createState() => _McpEndpointFormSheetState();
}

class _McpEndpointFormSheetState extends State<_McpEndpointFormSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _slugCtrl =
      TextEditingController(text: widget.existing?.slug ?? '');
  late final TextEditingController _timeoutCtrl = TextEditingController(
    text: '${widget.existing?.timeoutSeconds ?? 300}',
  );
  late final Set<String> _picked = Set<String>.from(
    widget.existing?.services ?? const <String>[],
  );
  late bool _expandTools = widget.existing?.expandTools ?? true;
  String _serviceSearch = '';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _timeoutCtrl.dispose();
    super.dispose();
  }

  String? get _slugError {
    if (_isEdit) return null;
    final s = _slugCtrl.text.trim();
    if (s.isEmpty) return null;
    if (!_mcpSlugRegex.hasMatch(s)) {
      return '只能含小写字母、数字和连字符，且首尾不能是连字符（2~40 字符）';
    }
    if (widget.takenSlugs.contains(s)) return '该路径标识已被占用';
    return null;
  }

  int? get _timeoutVal {
    final n = int.tryParse(_timeoutCtrl.text.trim());
    if (n == null || n < 5 || n > 900) return null;
    return n;
  }

  bool get _canSubmit =>
      !_busy &&
      _nameCtrl.text.trim().isNotEmpty &&
      (_isEdit || (_slugCtrl.text.trim().isNotEmpty && _slugError == null)) &&
      _picked.isNotEmpty &&
      _timeoutVal != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final body = {
          'name': _nameCtrl.text.trim(),
          'services': _picked.toList(),
          'expand_tools': _expandTools,
          'timeout_seconds': _timeoutVal,
        };
        try {
          await widget.mc.unwrap<dynamic>(
            Channel.general,
            'PUT',
            '/api/v1/mcp/endpoints/${Uri.encodeComponent(widget.existing!.id)}',
            body: body,
          );
        } on ApiException catch (e) {
          if (e.httpStatus == 405) {
            await widget.mc.unwrap<dynamic>(
              Channel.general,
              'PATCH',
              '/api/v1/mcp/endpoints/${Uri.encodeComponent(widget.existing!.id)}',
              body: body,
            );
          } else {
            rethrow;
          }
        }
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final raw = await widget.mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/mcp/endpoints',
          body: {
            'name': _nameCtrl.text.trim(),
            'slug': _slugCtrl.text.trim(),
            'services': _picked.toList(),
            'expand_tools': _expandTools,
            'timeout_seconds': _timeoutVal,
          },
        );
        final epRaw = raw['endpoint'];
        final ep = epRaw is Map
            ? _McpEndpoint.fromJson(Map<String, dynamic>.from(epRaw))
            : _McpEndpoint.fromJson(raw);
        final token = (raw['token'] ?? '').toString();
        if (mounted) Navigator.of(context).pop((endpoint: ep, token: token));
      }
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = widget.status.services
        .where((s) => _picked.contains(s.domain))
        .toList();
    final cmdTotal = chosen.fold<int>(0, (a, b) => a + b.commandCount);
    final toolCount = _expandTools ? cmdTotal : chosen.length;
    final bytes = chosen.fold<int>(
      0,
      (a, b) => a + (_expandTools ? b.expandedBytes : b.collapsedBytes),
    );
    final kw = _serviceSearch.trim().toLowerCase();
    final filtered = widget.status.services.where((s) {
      if (kw.isEmpty) return true;
      return s.domain.toLowerCase().contains(kw) ||
          s.description.toLowerCase().contains(kw);
    }).toList();
    final ordered = [
      ...filtered.where((s) => _picked.contains(s.domain)),
      ...filtered.where((s) => !_picked.contains(s.domain)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isEdit ? '编辑 MCP 端点' : '新建 MCP 端点', style: McText.titleSm),
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
              labelText: '端点名称 *',
              hintText: '例如：Claude Code 家庭媒体助手',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _slugCtrl,
            enabled: !_isEdit,
            decoration: InputDecoration(
              labelText: _isEdit ? '路径标识（创建后不可改）' : '路径标识 (slug) *',
              hintText: 'home-assistant',
              errorText: _slugError,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              McChip(
                label: '展开命令 ($cmdTotal 工具)',
                compact: true,
                selected: _expandTools,
                onTap: () => setState(() => _expandTools = true),
              ),
              const SizedBox(width: 8),
              McChip(
                label: '按服务折叠 (${chosen.length} 工具)',
                compact: true,
                selected: !_expandTools,
                onTap: () => setState(() => _expandTools = false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '预计客户端可见 $toolCount 个工具 · 定义约 ${_fmtDefBytes(bytes)}',
            style: McText.caption.faint,
          ),
          if (_expandTools && toolCount > 30) ...[
            const SizedBox(height: 8),
            const SettingsNoticeBanner(
              text: '工具数量超过 30 个可能降低部分模型调用准确度，建议切换为「按服务折叠」。',
              tone: SettingsTone.warn,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _timeoutCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '调用超时（5~900 秒）',
              errorText: _timeoutVal == null ? '请输入 5 到 900 之间的整数' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '选择开放服务域 (${_picked.length}/${widget.status.services.length})',
                  style: McText.sub.semibold,
                ),
              ),
              if (_picked.isNotEmpty)
                McChip(
                  label: '清空',
                  compact: true,
                  onTap: () => setState(() => _picked.clear()),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(McIcons.search, size: 17),
              hintText: '筛选服务域…',
            ),
            onChanged: (v) => setState(() => _serviceSearch = v),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ordered.length,
              itemBuilder: (_, idx) {
                final s = ordered[idx];
                final on = _picked.contains(s.domain);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: on,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _picked.add(s.domain);
                    } else {
                      _picked.remove(s.domain);
                    }
                  }),
                  title: Text(
                    '${s.domain} (${s.commandCount} 命令)',
                    style: McText.caption.copyWith(
                      fontFamily: 'monospace',
                      color: McTokens.text,
                    ),
                  ),
                  subtitle: Text(s.description, style: McText.micro.muted),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          McActionPill(
            label: _busy ? '提交中…' : (_isEdit ? '保存更改' : '创建端点并生成令牌'),
            primary: true,
            expanded: true,
            onTap: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
