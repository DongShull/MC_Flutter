// 插件页（对应 web settings plugins 分区）：
// 内置插件状态一览（可停用/启用）、功能开关、安全模式退出。
// 注意：插件包安装（.mcplugin 上传）与插件应用页（apps/[plugin] 的 iframe 承载）
// 不在本页：前者需文件上传流程、后者需 WebView 承载（见 P4.md）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mc_api.dart';
import '../state/raw_models.dart';
import '../widgets/admin_widgets.dart';

class _PluginsData {
  const _PluginsData({required this.overview, required this.features});

  final PluginsOverview overview;
  final List<PluginFeature> features;
}

class PluginsPage extends ConsumerStatefulWidget {
  const PluginsPage({super.key});

  @override
  ConsumerState<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends ConsumerState<PluginsPage> {
  late Future<_PluginsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PluginsData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results =
        await Future.wait([api.pluginsOverview(), api.pluginFeatures()]);
    return _PluginsData(
      overview: results[0] as PluginsOverview,
      features: results[1] as List<PluginFeature>,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '插件',
        body: AdminAsyncBody<_PluginsData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final groups = <String, List<PluginInfo>>{};
            for (final p in data.overview.plugins) {
              groups.putIfAbsent(p.group ?? '其他', () => []).add(p);
            }
            return ListView(
              children: [
                if (data.overview.safeModeActive) ...[
                  SettingsInfoCard(
                    text:
                        '插件安全模式已启用：${data.overview.safeModeReason}。上次运行不稳定，插件被跳过。',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(settingsApiProvider)
                              .exitPluginSafeMode();
                          if (!context.mounted) return;
                          showSettingsToast(context, '已退出安全模式');
                          _reload();
                        } catch (e) {
                          if (!context.mounted) return;
                          showSettingsToast(context, '操作失败：$e');
                        }
                      },
                      child: const Text('退出安全模式'),
                    ),
                  ),
                ],
                const SettingsGroupLabel('功能开关'),
                if (data.features.isEmpty)
                  const SettingsInfoCard(text: '当前没有可开关的功能。'),
                for (final f in data.features)
                  AdminSwitchTile(
                    title: f.title.isEmpty ? f.key : f.title,
                    subtitle: (f.lockedBy ?? '').isEmpty
                        ? null
                        : '被 ${f.lockedBy} 锁定',
                    value: f.enabled,
                    onChanged: !f.switchable
                        ? null
                        : (v) async {
                            try {
                              await ref
                                  .read(settingsApiProvider)
                                  .setPluginFeatureEnabled(f.key, v);
                              if (!context.mounted) return;
                              showSettingsToast(
                                  context, v ? '已开启' : '已停用');
                              _reload();
                            } catch (e) {
                              if (!context.mounted) return;
                              showSettingsToast(context, '操作失败：$e');
                            }
                          },
                  ),
                for (final entry in groups.entries) ...[
                  SettingsGroupLabel(entry.key),
                  for (final p in entry.value)
                    SettingsRow(
                      icon: Icons.extension,
                      title: p.title.isEmpty ? p.id : p.title,
                      subtitle: [
                        p.stateLabel,
                        if (p.source.isNotEmpty) p.source,
                        if ((p.disabledBy ?? '').isNotEmpty)
                          '停用：${p.disabledBy}',
                        if ((p.error ?? '').isNotEmpty) p.error!,
                        if (p.blockedReasons.isNotEmpty)
                          p.blockedReasons.join('; '),
                      ].join(' · '),
                      trailing: p.canToggle
                          ? Switch(
                              value: p.active,
                              onChanged: (v) async {
                                try {
                                  await ref
                                      .read(settingsApiProvider)
                                      .setPluginEnabled(p.id, v);
                                  if (!context.mounted) return;
                                  showSettingsToast(
                                      context, v ? '已启用' : '已停用');
                                  _reload();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showSettingsToast(context, '操作失败：$e');
                                }
                              },
                            )
                          : null,
                    ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
