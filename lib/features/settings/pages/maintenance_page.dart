import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/state_views.dart';
import '../../../core/models/format.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/settings_ui.dart';

/// 服务器维护页（对应安卓 MaintenanceSectionScreen）：版本 / 重启 / 存储清理。
class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(maintenanceProvider.notifier).load());
  }

  Future<void> _restart() async {
    final ok = await confirmDialog(context,
        title: '重启服务器', message: '重启期间所有客户端会短暂断开，确定吗？', confirmLabel: '重启');
    if (!ok) return;
    final err = await ref.read(maintenanceProvider.notifier).restart();
    if (!mounted) return;
    showSettingsToast(context, err ?? '重启指令已发送');
  }

  Future<void> _clean(StorageDir dir) async {
    final ok = await confirmDialog(context,
        title: '清理「${dir.title}」',
        message: dir.description.isEmpty
            ? '删除该目录下的缓存内容。'
            : dir.description,
        confirmLabel: '清理');
    if (!ok) return;
    final err = await ref.read(maintenanceProvider.notifier).clean(dir.key);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已清理');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final data = state.valueOrNull;

    return SettingsScaffold(
      title: '服务器维护',
      body: state.isLoading && data == null
          ? const McLoadingView()
          : state.hasError
              ? McErrorView(
                  text: '加载失败',
                  onRetry: () => ref.read(maintenanceProvider.notifier).load(),
                )
              : ListView(
                  children: [
                    const SettingsGroupLabel('版本'),
                    SettingsRow(
                      icon: Icons.info_outline,
                      title: '当前版本',
                      subtitle: [
                        if (data?.status?.currentVersion.isNotEmpty ?? false)
                          'v${data!.status!.currentVersion}',
                        if (data?.status?.codeSource.isNotEmpty ?? false)
                          data!.status!.codeSource,
                      ].join(' · '),
                      trailing: data?.pending?.hasUpdate ?? false
                          ? FilledButton.tonal(
                              onPressed: () => context.push('/update'),
                              child: Text(data?.pending?.label ?? '有更新'),
                            )
                          : null,
                    ),
                    const SettingsGroupLabel('运行'),
                    SettingsRow(
                      icon: Icons.restart_alt,
                      title: '重启服务器',
                      subtitle: '重启 MovieClaw 服务进程',
                      onTap: _restart,
                    ),
                    const SettingsGroupLabel('存储'),
                    SettingsInfoCard(
                      icon: Icons.storage_outlined,
                      text: data?.storage == null
                          ? '计算中…'
                          : '磁盘共 ${mcFormatBytes(data!.storage!.diskTotal)}，'
                              '已用 ${mcFormatBytes(data.storage!.diskUsed)}，'
                              '缓存 ${mcFormatBytes(data.storage!.cacheBytes)}。',
                    ),
                    for (final dir in data?.storage?.dirs ?? const <StorageDir>[])
                      if (dir.clearable)
                        SettingsRow(
                          icon: dir.group == 'cache'
                              ? Icons.cleaning_services_outlined
                              : Icons.folder_outlined,
                          title: dir.title,
                          subtitle: dir.summary,
                          trailing: const Icon(Icons.delete_outline),
                          onTap: () => _clean(dir),
                        ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
