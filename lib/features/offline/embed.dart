
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/format.dart';

export 'state/offline_state.dart' show offlineProvider;
import 'widgets/downloading_row.dart';
import 'state/models.dart';
import 'state/offline_state.dart';

/// 「我的」页下载段的五个内嵌分区（1:1 对照鸿蒙 OfflineStoragePage.ets 导出的
/// OfflineCapacityCard / OfflineDownloadingSection / OfflineWatchedCard /
/// OfflineDownloadedSection / OfflineOtherOwnersSection）。
///
/// 与鸿蒙一致的空段策略：
/// - 下载中：有任务才出现；
/// - 清理建议（已看完）：有已看完的才出现——Flutter offline 域暂无本机观看
///   进度数据（对应鸿蒙 store.localProgress 的 played），恒为空 → 整段隐藏；
/// - 已下载：始终出现，空时显示引导文案（口径照抄鸿蒙）；
/// - 其他账号：这台设备上有其他账号的下载才出现——Flutter 只有单账号本机
///   目录（无鸿蒙 OfflineStore.scanOwners），恒为空 → 整段隐藏。
///
/// more 域只允许 import 本文件这一个入口（模块化铁律）。

/// 容量卡片（鸿蒙下载页里放最后；MorePage 内嵌时放最上：下载前先看还剩多少）。
/// 布局照抄 OfflineCapacityCard：标题「本机储存空间」+「可用 X」、
/// 三段式容量条（下载 / 其他已用 / 剩余）+ 两颗图例点。
class CapacityCard extends ConsumerStatefulWidget {
  const CapacityCard({super.key});

  @override
  ConsumerState<CapacityCard> createState() => _CapacityCardState();
}

class _CapacityCardState extends ConsumerState<CapacityCard> {
  int _doneBytes = 0;
  int _lastDoneCount = -1;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant CapacityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 下完 / 删掉时重查磁盘（对齐鸿蒙 @Monitor('store.doneBytes')）。
    final done = ref.read(offlineProvider).doneUnits.length;
    if (done != _lastDoneCount) {
      _lastDoneCount = done;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    ref.read(offlineProvider.notifier).refreshStorage();
    final bytes = await ref.read(offlineProvider.notifier).downloadedFileBytes();
    if (!mounted) return;
    setState(() => _doneBytes = bytes.values.fold(0, (a, b) => a + b));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final storage = ref.watch(offlineProvider).storage;
    final hasDisk = storage != null && storage.totalBytes > 0;
    return _sectionCard(
      context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('本机储存空间',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface)),
              ),
              if (storage != null)
                Text('可用 ${mcFormatBytes(storage.availableBytes)}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDisk) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    // 下载段：最小可见 1%（对齐鸿蒙 downloadsBarWidth）。
                    Flexible(
                      fit: FlexFit.loose,
                      child: Container(color: scheme.primary),
                    ),
                    // 其他已用段。
                    Flexible(
                      fit: FlexFit.loose,
                      child: Container(color: scheme.outlineVariant),
                    ),
                    Expanded(child: Container(color: scheme.surfaceContainerLow)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(context, scheme.primary,
                    '下载 ${mcFormatBytes(_doneBytes)}'),
                const Spacer(),
                _legendDot(context, scheme.outlineVariant, '其他已用'),
              ],
            ),
          ] else
            Text('MovieClaw 下载 ${mcFormatBytes(_doneBytes)}',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text,
            style:
                TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// 下载中分区：有任务才出现；一张卡里每集一行（复用 offline 域的 DownloadingRow，
/// 长按菜单含 暂停/继续/取消/优先下载，对齐鸿蒙左滑 + 长按菜单）。
class DownloadingSection extends ConsumerWidget {
  const DownloadingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    final controller = ref.read(offlineProvider.notifier);
    final active = offline.activeUnits;
    if (active.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '下载中'),
          for (final unit in active)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DownloadingRow(
                unit: unit,
                onPauseResume: () => controller.toggle(unit),
                onCancel: () => controller.cancel(unit),
                onPrioritize: () => controller.prioritize(unit),
              ),
            ),
        ],
      ),
    );
  }
}

/// 清理建议卡（已看完的下载）：鸿蒙有已看完的才出现。Flutter offline 域
/// 暂无本机观看进度（鸿蒙 store.localProgress 的 played）→ 恒为空，整段隐藏。
class WatchedCard extends ConsumerWidget {
  const WatchedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

/// 已下载分区：始终出现（鸿蒙同款），空时按「有没有在下载」给不同引导文案；
/// 行 = 片名 + 明细（已下载 N 集 / 档位）+ 占用。
class DownloadedSection extends ConsumerStatefulWidget {
  const DownloadedSection({super.key});

  @override
  ConsumerState<DownloadedSection> createState() => _DownloadedSectionState();
}

class _DownloadedSectionState extends ConsumerState<DownloadedSection> {
  Map<String, int> _bytesById = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant DownloadedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  Future<void> _refresh() async {
    final bytes =
        await ref.read(offlineProvider.notifier).downloadedFileBytes();
    if (!mounted) return;
    setState(() => _bytesById = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = ref.watch(offlineProvider);
    final done = offline.doneUnits;
    final hasActive = offline.activeUnits.isNotEmpty;

    // 按片名聚合（一集 = 一个 unit，对齐鸿蒙 downloadedItems 的条目口径）。
    final byTitle = <String, List<DownloadUnit>>{};
    for (final u in done) {
      byTitle.putIfAbsent(u.title, () => []).add(u);
    }

    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Text('已下载',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                if (byTitle.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${byTitle.length} 部',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (byTitle.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                hasActive ? '下完的会出现在这里。' : '还没有下载。在影片详情页点「下载」，没网的时候也能看。',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (final entry in byTitle.entries)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _DownloadedRow(
                  units: entry.value,
                  totalBytes: entry.value
                      .fold(0, (sum, u) => sum + (_bytesById[u.id] ?? 0)),
                ),
              ),
        ],
      ),
    );
  }
}

/// 已下载的一行（对齐鸿蒙 OfflineDownloadedRow）：片名 + 明细 + 占用；长按删除。
class _DownloadedRow extends StatelessWidget {
  const _DownloadedRow({required this.units, required this.totalBytes});

  final List<DownloadUnit> units;
  final int totalBytes;

  String get _title => units.first.title;

  /// 明细：多集 → 「已下载 N 集」；单集 → 季集 · 档位（对齐鸿蒙 detailLine）。
  String get _detail {
    if (units.length > 1) return '已下载 ${units.length} 集';
    final u = units.first;
    return [if (u.seasonEpisode != null) u.seasonEpisode!, u.profileLabel]
        .join(' · ');
  }

  void _confirmDelete(BuildContext context, OfflineController controller) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除「$_title」的下载？'),
        content: const Text('只删本机上的副本，观看进度会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              for (final u in units) {
                controller.deleteDownloaded(u);
              }
            },
            child: Text('删除（释放 ${mcFormatBytes(totalBytes)}）',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer(
      builder: (context, ref, _) => InkWell(
        onLongPress: () =>
            _confirmDelete(context, ref.read(offlineProvider.notifier)),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface)),
              const SizedBox(height: 2),
              Text(_detail,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(mcFormatBytes(totalBytes),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 其他账号分区：鸿蒙这台设备上有其他账号的下载才出现。Flutter 只有单账号
/// 本机目录（无 OfflineStore.scanOwners 同类扫描）→ 恒为空，整段隐藏。
class OtherOwnersSection extends ConsumerWidget {
  const OtherOwnersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

/// 分区卡片容器（对齐鸿蒙 ListItemGroup：surface 底 + 1dp 描边 + 圆角）。
Widget _sectionCard(
  BuildContext context, {
  required Widget child,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: child,
  );
}

/// 分区小标题（对齐鸿蒙 SectionHeader：13 号浅色字）。
Widget _sectionHeader(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(title,
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
  );
}