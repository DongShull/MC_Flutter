import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/settings_ui.dart';

/// 我的设备页（对应安卓 DevicesSectionScreen）：
/// 当前设备 badge / 转码专用 badge / 改名 / 注销 / 清理 sheet（7/30/90 天）。
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(devicesProvider.notifier).load());
  }

  Future<void> _rename(LoginDevice d) async {
    final next = await textInputDialog(context,
        title: '重命名设备', initial: d.name, hint: '设备名称');
    if (next == null || next.isEmpty) return;
    final err = await ref.read(devicesProvider.notifier).rename(d.id, next);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已重命名');
  }

  Future<void> _revoke(LoginDevice d) async {
    final ok = await confirmDialog(context,
        title: '注销设备', message: '注销「${d.title}」后需要重新登录才能使用。', confirmLabel: '注销');
    if (!ok) return;
    final err = await ref.read(devicesProvider.notifier).revoke(d.id);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已注销');
  }

  Future<void> _cleanupSheet() async {
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('清理多久没用过的设备？'),
            ),
            for (final d in const [7, 30, 90])
              ListTile(
                title: Text('$d 天'),
                onTap: () => Navigator.of(ctx).pop(d),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (days == null) return;
    final notifier = ref.read(devicesProvider.notifier);
    // 先 dryRun 预览「将注销 N 台设备」，确认后再真跑。
    final preview = await notifier.cleanup(days, dryRun: true);
    if (!mounted) return;
    if (preview is DeviceCleanupView) {
      if (preview.devices.isEmpty) {
        showSettingsToast(context, '没有符合条件的设备');
        return;
      }
      final ok = await confirmDialog(context,
          title: '清理设备',
          message: '将注销 ${preview.devices.length} 台设备（$days 天未活动），确定吗？',
          confirmLabel: '清理');
      if (!ok) return;
      await notifier.cleanup(days, dryRun: false);
      if (!mounted) return;
      showSettingsToast(context, '清理完成');
    } else if (preview != null) {
      showSettingsToast(context, preview.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devicesProvider);
    final data = state.valueOrNull;

    return SettingsScaffold(
      title: '我的设备',
      body: state.isLoading && (data?.items.isEmpty ?? true)
          ? const McLoadingView()
          : state.hasError
              ? McErrorView(
                  text: '加载失败',
                  onRetry: () => ref.read(devicesProvider.notifier).load(),
                )
              : ListView(
                  children: [
                    SettingsRow(
                      icon: Icons.select_all,
                      title: '显示全部用户的设备',
                      subtitle: data?.showAll == true ? '已显示全部' : '仅我的设备',
                      trailing: Switch(
                        value: data?.showAll ?? false,
                        onChanged: (_) =>
                            ref.read(devicesProvider.notifier).toggleShowAll(),
                      ),
                    ),
                    for (final d in data?.items ?? const <LoginDevice>[])
                      SettingsRow(
                        icon: d.current
                            ? Icons.smartphone
                            : Icons.devices_other,
                        title: d.title,
                        subtitle: d.subtitle,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (d.current)
                              Text('当前',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                            if (d.isTranscode) ...[
                              const SizedBox(width: 8),
                              const Text('转码专用'),
                            ],
                          ],
                        ),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (d.renamable)
                                  ListTile(
                                    leading: const Icon(Icons.edit_outlined),
                                    title: const Text('重命名'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _rename(d);
                                    },
                                  ),
                                ListTile(
                                  leading: const Icon(Icons.logout),
                                  title: const Text('注销'),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _revoke(d);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('清理长期没用的设备'),
                        onPressed: _cleanupSheet,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
