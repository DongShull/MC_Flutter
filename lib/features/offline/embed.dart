import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/designsystem/mc_chrome.dart';
import '../../core/designsystem/mc_glass.dart';
import '../../core/designsystem/mc_icons.dart';
import '../../core/designsystem/theme.dart';
import '../../core/models/format.dart';
import '../../core/player/player_page_args.dart';
import 'state/models.dart';
import 'state/offline_state.dart';
import 'widgets/downloading_row.dart';

export 'state/offline_state.dart' show offlineProvider;

/// 「我的」页下载段的五个内嵌分区（支持真离线点按直播、已看完一键清理与多账号存储隔离）。
/// more 域只允许 import 本文件这一个入口（模块化铁律）。

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

    final mcFlex =
        mcBytes > 0 ? ((mcBytes * 1000) ~/ total).clamp(15, 1000) : 0;
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

/// 清理建议卡（已看完的离线副本一键清理释放空间）。
class WatchedCard extends ConsumerWidget {
  const WatchedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watched = ref.watch(offlineProvider).watchedUnits;
    if (watched.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(McIcons.eraser, size: 19, color: McTokens.accentStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已看完 ${watched.length} 项离线缓存', style: McText.sub.semibold),
                const SizedBox(height: 2),
                Text('清理本机文件不会影响服务端观看进度', style: McText.micro.muted),
              ],
            ),
          ),
          McChip(
            label: '一键清理',
            selected: true,
            compact: true,
            onTap: () async {
              final count = await ref
                  .read(offlineProvider.notifier)
                  .clearWatchedDownloads();
              if (context.mounted) {
                McToast.success('已清理 $count 项已看完的离线副本');
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 已下载分区：点击直接本机零流量离线起播，长按标记已看或删除。
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

class _DownloadedRow extends ConsumerWidget {
  const _DownloadedRow({required this.units, required this.totalBytes});

  final List<DownloadUnit> units;
  final int totalBytes;

  String get _title => units.first.title;

  String get _detail {
    if (units.length > 1) return '已下载 ${units.length} 集 · 点击离线播放';
    final u = units.first;
    return [
      if (u.seasonEpisode != null) u.seasonEpisode!,
      u.profileLabel,
      if (u.watched) '已看完',
    ].join(' · ');
  }

  void _playOffline(BuildContext context, OfflineController controller) {
    if (units.length == 1) {
      final uri = controller.localPlayUri(units.first);
      if (uri == null) {
        McToast.error('本地文件不存在');
        return;
      }
      context.push(
        '/player',
        extra: PlayerPageArgs(
          url: uri,
          title: units.first.title,
          subtitle: units.first.seasonEpisode ?? '本机离线播放',
        ),
      );
      return;
    }
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '选择离线剧集播放',
          margin: EdgeInsets.zero,
          children: [
            for (final u in units)
              McInsetRow(
                icon: McIcons.play2Fill,
                title: u.seasonEpisode ?? u.title,
                subtitle: u.profileLabel,
                onTap: () {
                  Navigator.of(ctx).pop();
                  final uri = controller.localPlayUri(u);
                  if (uri != null) {
                    context.push(
                      '/player',
                      extra: PlayerPageArgs(
                        url: uri,
                        title: u.title,
                        subtitle: u.seasonEpisode,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openActions(BuildContext context, OfflineController controller) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: _title,
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.play2Fill,
              title: '本机离线播放',
              onTap: () {
                Navigator.of(ctx).pop();
                _playOffline(context, controller);
              },
            ),
            McInsetRow(
              icon: McIcons.checkCircle,
              title: units.first.watched ? '标为未看' : '标为已看完（纳入清理建议）',
              onTap: () {
                Navigator.of(ctx).pop();
                final target = !units.first.watched;
                for (final u in units) {
                  controller.markUnitWatched(u, watched: target);
                }
              },
            ),
            McInsetRow(
              icon: McIcons.trash2,
              title: '删除本机下载（${mcFormatBytes(totalBytes)}）',
              destructive: true,
              onTap: () {
                Navigator.of(ctx).pop();
                for (final u in units) {
                  controller.deleteDownloaded(u);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(offlineProvider.notifier);
    return McPressable(
      onTap: () => _playOffline(context, controller),
      onLongPress: () => _openActions(context, controller),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                shape: BoxShape.circle,
                border: Border.all(color: McTokens.line),
              ),
              child: const Icon(
                McIcons.play2Fill,
                size: 15,
                color: McTokens.accentStrong,
              ),
            ),
            const SizedBox(width: 12),
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
            Text(
              mcFormatBytes(totalBytes),
              style: McText.caption.muted.tabular,
            ),
          ],
        ),
      ),
    );
  }
}

/// 其他账号离线占用分区：本机其他账号存在已下载副本时才展示，支持一键清理释放空间。
class OtherOwnersSection extends ConsumerWidget {
  const OtherOwnersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(offlineProvider);
    if (s.otherOwnersCount <= 0) return const SizedBox.shrink();
    return _sectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(McIcons.userSwitch, size: 19, color: McTokens.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本机其他账号缓存 ${s.otherOwnersCount} 项（${mcFormatBytes(s.otherOwnersBytes)}）',
              style: McText.caption.muted,
            ),
          ),
          McChip(
            label: '清理释放',
            compact: true,
            onTap: () async {
              await ref
                  .read(offlineProvider.notifier)
                  .clearOtherOwnersDownloads();
              if (context.mounted) McToast.success('已清理其他账号的离线缓存');
            },
          ),
        ],
      ),
    );
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
