
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/adaptive.dart';

import '../state/models.dart';
import '../state/offline_state.dart';
import '../widgets/downloading_row.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 离线下载页（1:1 对齐 Kotlin DownloadsScreen 的 sections 顺序）：
/// 下载中（含 waitingForWiFi 提示条 + 蜂窝一键开）→ 建议 → 已下载 →
/// 其他账号 → 容量条（StorageCard）最后；右上角设置菜单给蜂窝开关。
class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final controller = ref.read(offlineProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final active = offline.activeUnits;
    final done = offline.doneUnits;
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载'),
        actions: [
          // 设置菜单：使用蜂窝网络下载开关（TV 聚焦环）。
          McFocusRing(
            borderRadius: 24,
            child: PopupMenuButton<String>(
            icon: const Icon(McIcons.setting),
            onSelected: (_) {},
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: StatefulBuilder(
                  builder: (context, setMenuState) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('使用蜂窝网络下载'),
                    value: offline.allowCellular,
                    onChanged: (value) {
                      controller.setAllowCellular(value);
                      setMenuState(() {});
                    },
                  ),
                ),
              ),
            ],
          ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: windowClass == McWindowClass.expanded ? 720 : double.infinity,
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          // —— 下载中 ——
          if (active.isNotEmpty) ...[
            _sectionHeader('下载中'),
            // waitingForWiFi 提示条 + 蜂窝一键开。
            if (!offline.allowCellular &&
                active.any((u) => u.status == OfflineUnitStatus.waitingWifi))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(McIcons.wifiOff, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('正在等待 Wi-Fi',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ),
                    McFocusRing(
                      child: TextButton(
                        onPressed: () => controller.setAllowCellular(true),
                        child: const Text('使用蜂窝网络下载'),
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
          // —— 建议（已看完）——
          _sectionHeader('建议'),
          if (done.isEmpty)
            Text('看过的好片，下载下来随时重温。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
          else
            for (final unit in done)
              DownloadingRow(
                unit: unit,
                onPauseResume: () {},
                onCancel: () => controller.deleteDownloaded(unit),
                onPrioritize: () {},
                onDelete: () => _confirmDelete(unit),
              ),
          // —— 已下载 ——
          _sectionHeader('已下载'),
          if (done.isEmpty)
            Text('还没有已下载的内容。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          // —— 其他账号 ——
          _sectionHeader('其他账号'),
          Text('本机其他账号下载的内容会显示在这里。',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          // —— 容量条最后 ——
          if (offline.storage != null) StorageCard(info: offline.storage!),
          if (offline.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(offline.error!,
                  style: TextStyle(fontSize: 12, color: scheme.error)),
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(DownloadUnit unit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个下载？'),
        content: const Text('只删本机上的副本，观看进度会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(offlineProvider.notifier).deleteDownloaded(unit);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
}
