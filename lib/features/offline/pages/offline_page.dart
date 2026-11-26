import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/models.dart';
import '../state/offline_state.dart';
import '../widgets/downloading_row.dart';

/// 离线下载页（1:1 对齐 Kotlin DownloadsScreen 的 sections 顺序）：
/// 下载中（含 waitingForWiFi 提示条 + 蜂窝一键开）→ 建议 → 已下载 →
/// 其他账号 → 容量条（StorageCard）最后；右上角设置圆钮打开蜂窝网络开关。
class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  void _openSettingsSheet() {
    showMcSheet<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, sheetRef, _) {
          final allow = sheetRef.watch(offlineProvider).allowCellular;
          final controller = sheetRef.read(offlineProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: McInsetGroup(
              header: '下载设置',
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.wifiOff,
                  title: '使用蜂窝网络下载',
                  subtitle: '无 Wi-Fi 时允许使用移动数据继续下载',
                  trailing: Switch(
                    value: allow,
                    onChanged: controller.setAllowCellular,
                  ),
                  onTap: () => controller.setAllowCellular(!allow),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final controller = ref.read(offlineProvider.notifier);
    final active = offline.activeUnits;
    final done = offline.doneUnits;
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '下载',
            titleVisible: true,
            trailing: [
              McFocusRing(
                borderRadius: 24,
                child: McGlassIconButton(
                  icon: McIcons.setting,
                  tooltip: '下载设置',
                  onTap: _openSettingsSheet,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: windowClass == McWindowClass.expanded
                      ? 720
                      : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    8,
                    McTokens.pagePadding,
                    36,
                  ),
                  children: [
                    if (active.isNotEmpty) ...[
                      _sectionHeader('下载中'),
                      if (!offline.allowCellular &&
                          active.any(
                            (u) => u.status == OfflineUnitStatus.waitingWifi,
                          ))
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: McTokens.surfaceRaised,
                            borderRadius:
                                BorderRadius.circular(McTokens.posterRadius),
                            border: Border.all(color: McTokens.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                McIcons.wifiOff,
                                size: 17,
                                color: McTokens.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '正在等待 Wi-Fi',
                                  style: McText.caption.muted,
                                ),
                              ),
                              McFocusRing(
                                borderRadius: McTokens.pillRadius,
                                child: McChip(
                                  label: '使用蜂窝网络下载',
                                  compact: true,
                                  selected: true,
                                  onTap: () =>
                                      controller.setAllowCellular(true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: true,
                        itemCount: active.length,
                        onReorder: controller.reorder,
                        itemBuilder: (context, index) {
                          final unit = active[index];
                          return Container(
                            key: ValueKey(unit.id),
                            child: DownloadingRow(
                              unit: unit,
                              onPauseResume: () => controller.toggle(unit),
                              onCancel: () => controller.cancel(unit),
                              onPrioritize: () => controller.prioritize(unit),
                            ),
                          );
                        },
                      ),
                    ],
                    _sectionHeader('建议'),
                    if (done.isEmpty)
                      Text('看过的好片，下载下来随时重温。', style: McText.caption.muted)
                    else
                      for (final unit in done)
                        DownloadingRow(
                          unit: unit,
                          onPauseResume: () {},
                          onCancel: () => controller.deleteDownloaded(unit),
                          onPrioritize: () {},
                          onDelete: () => _confirmDelete(unit),
                        ),
                    _sectionHeader('已下载'),
                    if (done.isEmpty)
                      Text('还没有已下载的内容。', style: McText.caption.muted),
                    _sectionHeader('其他账号'),
                    Text(
                      '本机其他账号下载的内容会显示在这里。',
                      style: McText.caption.muted,
                    ),
                    const SizedBox(height: 18),
                    if (offline.storage != null)
                      StorageCard(info: offline.storage!),
                    if (offline.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          offline.error!,
                          style: McText.caption.copyWith(color: McTokens.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DownloadUnit unit) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('删除这个下载？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text('只删本机上的副本，观看进度会保留。', style: McText.sub.muted),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '删除',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(offlineProvider.notifier).deleteDownloaded(unit);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(title, style: McText.titleSm),
      );
}
