import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
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
    final next = await textInputDialog(
      context,
      title: '重命名设备',
      initial: d.name,
      hint: '设备名称',
    );
    if (next == null || next.isEmpty) return;
    final err = await ref.read(devicesProvider.notifier).rename(d.id, next);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已重命名');
  }

  Future<void> _revoke(LoginDevice d) async {
    final ok = await confirmDialog(
      context,
      title: '注销设备',
      message: '注销「${d.title}」后需要重新登录才能使用。',
      confirmLabel: '注销',
    );
    if (!ok) return;
    final err = await ref.read(devicesProvider.notifier).revoke(d.id);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已注销');
  }

  Future<void> _openDeviceActions(LoginDevice d) {
    return showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: d.title,
          margin: EdgeInsets.zero,
          children: [
            if (d.renamable)
              McInsetRow(
                icon: McIcons.edit2,
                title: '重命名',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _rename(d);
                },
              ),
            McInsetRow(
              icon: McIcons.logout,
              title: '注销此设备',
              destructive: true,
              onTap: () {
                Navigator.of(ctx).pop();
                _revoke(d);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cleanupSheet() async {
    final days = await showMcSheet<int>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '清理多久没用过的设备？',
          margin: EdgeInsets.zero,
          children: [
            for (final d in const [7, 30, 90])
              McInsetRow(
                icon: McIcons.clock,
                title: '$d 天未活动',
                onTap: () => Navigator.of(ctx).pop(d),
              ),
          ],
        ),
      ),
    );
    if (days == null) return;
    final notifier = ref.read(devicesProvider.notifier);
    final preview = await notifier.cleanup(days, dryRun: true);
    if (!mounted) return;
    if (preview is DeviceCleanupView) {
      if (preview.devices.isEmpty) {
        showSettingsToast(context, '没有符合条件的设备');
        return;
      }
      final ok = await confirmDialog(
        context,
        title: '清理设备',
        message: '将注销 ${preview.devices.length} 台设备（$days 天未活动），确定吗？',
        confirmLabel: '清理',
      );
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
    final items = data?.items ?? const <LoginDevice>[];

    return SettingsScaffold(
      title: '我的设备',
      body: state.isLoading && items.isEmpty
          ? const McLoadingView()
          : state.hasError
              ? McErrorView(
                  text: '加载失败',
                  onRetry: () => ref.read(devicesProvider.notifier).load(),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  children: [
                    McInsetGroup(
                      children: [
                        McInsetRow(
                          icon: McIcons.checkDouble,
                          title: '显示全部用户的设备',
                          subtitle: data?.showAll == true ? '已显示全部' : '仅我的设备',
                          trailing: Switch(
                            value: data?.showAll ?? false,
                            onChanged: (_) => ref
                                .read(devicesProvider.notifier)
                                .toggleShowAll(),
                          ),
                          onTap: () => ref
                              .read(devicesProvider.notifier)
                              .toggleShowAll(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (items.isNotEmpty)
                      McInsetGroup(
                        header: '已登录设备',
                        dividerIndent: 48,
                        children: [
                          for (final d in items)
                            McInsetRow(
                              icon: d.current ? McIcons.iphone : McIcons.device,
                              iconColor: d.current
                                  ? McTokens.accentStrong
                                  : McTokens.textMuted,
                              title: d.title,
                              subtitle: d.subtitle,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (d.current)
                                    const _DeviceTag(
                                      label: '当前',
                                      color: McTokens.ok,
                                    ),
                                  if (d.isTranscode) ...[
                                    const SizedBox(width: 6),
                                    const _DeviceTag(
                                      label: '转码专用',
                                      color: McTokens.textMuted,
                                    ),
                                  ],
                                ],
                              ),
                              showChevron: true,
                              onTap: () => _openDeviceActions(d),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: McTokens.pagePadding,
                      ),
                      child: Center(
                        child: McActionPill(
                          icon: McIcons.eraser,
                          label: '清理长期没用的设备',
                          primary: false,
                          expanded: true,
                          onTap: _cleanupSheet,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DeviceTag extends StatelessWidget {
  const _DeviceTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(McTokens.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: McText.micro.copyWith(color: color)),
    );
  }
}
