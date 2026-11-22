// MCP 页（对应 web settings mcp 分区 / 安卓 McpSettingsScreen）：
// 总开关、服务地址、外部地址配置状态、端点列表（工具数、上次使用）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class McpPage extends ConsumerStatefulWidget {
  const McpPage({super.key});

  @override
  ConsumerState<McpPage> createState() => _McpPageState();
}

class _McpPageState extends ConsumerState<McpPage> {
  late Future<core.McpStatusView> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.McpStatusView> _load() =>
      ref.read(settingsApiProvider).mcpStatus();

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: 'MCP',
        body: AdminAsyncBody<core.McpStatusView>(
          future: _future,
          onRetry: _reload,
          builder: (context, status) => ListView(
            children: [
              AdminSwitchTile(
                title: '启用 MCP 服务',
                subtitle: '允许外部 MCP 客户端连接本服务器',
                value: status.enabled,
                onChanged: (v) async {
                  try {
                    await ref.read(settingsApiProvider).mcpToggle(v);
                    if (!context.mounted) return;
                    showSettingsToast(context, v ? 'MCP 已启用' : 'MCP 已停用');
                    _reload();
                  } catch (e) {
                    if (!context.mounted) return;
                    showSettingsToast(context, '操作失败：$e');
                  }
                },
              ),
              SettingsRow(
                icon: Icons.link,
                title: status.baseUrl.isEmpty ? '未配置服务地址' : status.baseUrl,
                subtitle: status.externalUrlConfigured
                    ? '外部地址已配置'
                    : '外部地址未配置（外部客户端需在“外部访问”里配置）',
              ),
              const SettingsGroupLabel('端点'),
              if (status.endpoints.isEmpty)
                const SettingsInfoCard(text: '当前没有 MCP 端点。'),
              for (final e in status.endpoints)
                SettingsRow(
                  icon: Icons.extension,
                  title: e.name.isEmpty ? e.slug : e.name,
                  subtitle: [
                    if (e.description.isNotEmpty) e.description,
                    '${e.toolCount} 个工具',
                    if (!e.enabled) '已停用',
                    if ((e.lastUsedAt ?? '').isNotEmpty)
                      '上次使用 ${e.lastUsedAt}',
                  ].join(' · '),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
