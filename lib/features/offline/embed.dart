import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/designsystem/mc_chrome.dart';
import '../../core/designsystem/mc_glass.dart';
import '../../core/designsystem/theme.dart';
import '../../core/models/format.dart';
import 'state/models.dart';
import 'state/offline_state.dart';
import 'widgets/downloading_row.dart';

export 'state/offline_state.dart' show offlineProvider;

/// 「我的」页下载段的五个内嵌分区（1:1 对照鸿蒙 OfflineStoragePage.ets）。
/// more 域只允许 import 本文件这一个入口（模块化铁律）。

/// 容量卡片：标题「本机储存空间」+「可用 X」、三段式银玻璃容量条 + 图例点。
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
    final storage = ref.watch(offlineProvider).storage;
    final hasDisk = storage != null && storage.totalBytes > 0;
    final total = hasDisk ? storage.totalBytes : 1;
    final avail = hasDisk ? storage.availableBytes.clamp(0, total) : 0;
    final usedTotal = (total - avail).clamp(0, total);
    final mcBytes = _doneBytes.clamp(0, usedTotal);
    final otherBytes = (usedTotal - mcBytes).clamp(0, total);

    final mcFlex = mcBytes > 0 ? ((mcBytes * 1000) ~/ total).clamp(15, 1000) : 0;
    final otherFlex =
        otherBytes > 0 ? ((otherBytes * 1000) ~/ total).clamp(15, 1000) : 0;
    final freeFlex = ((avail * 1000) ~/ total).clamp(10, 1000);

    return _sectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('本机储存空间', style: McText.ui),
              ),
              if (storage != null)
                Text(
                  '可用 ${mcFormatBytes(storage.availableBytes).trim()}',
                  style: McText.caption.muted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDisk) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(McTokens.radiusXs),
              child: SizedBox(
                height: 7,
                child: Row(
                  children: [
                    if (mcFlex > 0)
                      Expanded(
                        flex: mcFlex,
                        child: const ColoredBox(color: McTokens.accentStrong),
                      ),
                    if (otherFlex > 0)
                      Expanded(
                        flex: otherFlex,
                        child: const ColoredBox(color: Color(0x47FFFFFF)),
                      ),
                    Expanded(
                      flex: freeFlex,
                      child: const ColoredBox(color: McTokens.surfaceInset),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _legendDot(
                  McTokens.accentStrong,
                  'MovieClaw 下载 ${mcFormatBytes(_doneBytes)}',
                ),
                const Spacer(),
                _legendDot(const Color(0x47FFFFFF), '其他已用'),
              ],
            ),
          ] else
            Text(
              'MovieClaw 下载 ${mcFormatBytes(_doneBytes)}',
              style: McText.caption.muted,
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: McText.caption.muted),
      ],
    );
  }
}

/// 下载中分区：有任务才出现。
class DownloadingSection extends ConsumerWidget {
  const DownloadingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    final controller = ref.read(offlineProvider.notifier);
    final active = offline.activeUnits;
    if (active.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('下载中'),
          for (final unit in active)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

/// 清理建议卡（已看完的下载）：恒为空，整段隐藏。
class WatchedCard extends ConsumerWidget {
  const WatchedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

/// 已下载分区：始终出现，空时按「有没有在下载」给不同引导文案。
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
    final offline = ref.watch(offlineProvider);
    final done = offline.doneUnits;
    final hasActive = offline.activeUnits.isNotEmpty;

    final byTitle = <String, List<DownloadUnit>>{};
    for (final u in done) {
      byTitle.putIfAbsent(u.title, () => []).add(u);
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Text(
                  '已下载',
                  style: McText.caption.copyWith(
                    color: McTokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (byTitle.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${byTitle.length} 部', style: McText.caption.faint),
                ],
              ],
            ),
          ),
          if (byTitle.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                hasActive ? '下完的会出现在这里。' : '还没有下载。在影片详情页点「下载」，没网的时候也能看。',
                style: McText.sub.muted,
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

class _DownloadedRow extends StatelessWidget {
  const _DownloadedRow({required this.units, required this.totalBytes});

  final List<DownloadUnit> units;
  final int totalBytes;

  String get _title => units.first.title;

  String get _detail {
    if (units.length > 1) return '已下载 ${units.length} 集';
    final u = units.first;
    return [if (u.seasonEpisode != null) u.seasonEpisode!, u.profileLabel]
        .join(' · ');
  }

  void _confirmDelete(BuildContext context, OfflineController controller) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('删除「$_title」的下载？', style: McText.titleSm),
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
                    label: '删除（${mcFormatBytes(totalBytes)}）',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      for (final u in units) {
                        controller.deleteDownloaded(u);
                      }
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => McPressable(
        onTap: null,
        onLongPress: () =>
            _confirmDelete(context, ref.read(offlineProvider.notifier)),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: McText.ui,
                    ),
                    const SizedBox(height: 2),
                    Text(_detail, style: McText.caption.muted),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(mcFormatBytes(totalBytes), style: McText.caption.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 其他账号分区：恒为空，整段隐藏。
class OtherOwnersSection extends ConsumerWidget {
  const OtherOwnersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

Widget _sectionCard({
  required Widget child,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
}) {
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: McTokens.surfaceRaised,
      borderRadius: BorderRadius.circular(McTokens.cardRadius),
      border: Border.all(color: McTokens.line, width: 1),
    ),
    child: child,
  );
}

Widget _sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(
      title,
      style: McText.caption.copyWith(
        color: McTokens.textMuted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
