import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/designsystem/mc_chrome.dart';
import '../../core/designsystem/mc_glass.dart';
import '../../core/designsystem/mc_icons.dart';
import '../../core/designsystem/theme.dart';
import '../../core/models/format.dart';
import '../../core/player/player_page_args.dart';
import 'pages/profile_sheet.dart';
import 'state/models.dart';
import 'state/offline_state.dart';
import 'state/server_reachability.dart';
import 'widgets/downloading_row.dart';

export 'pages/offline_library_page.dart'
    show OfflineBanner, OfflineLibraryPage, OfflineMinimalDetailPage;
export 'pages/profile_sheet.dart'
    show
        DownloadProfileSheet,
        OfflineDownloadSheet,
        showDownloadProfileSheet,
        showOfflineDownloadSheet;
export 'state/models.dart'
    show
        DownloadCandidate,
        DownloadProfile,
        DownloadUnit,
        OfflineChoiceEpisode,
        OfflineChoiceLocalState,
        OfflineDownloadChoices,
        OfflineDownloadScope,
        OfflineUnitStatus;
export 'state/offline_packager.dart' show OfflineImages;
export 'state/offline_state.dart' show offlineProvider;
export 'state/offline_viewings.dart'
    show OfflineViewingRecorder, OfflineViewingUploader;
export 'state/server_reachability.dart'
    show
        offlineModeProvider,
        serverReachabilityProvider,
        serverReachableProvider;
export 'widgets/downloading_row.dart' show OfflineArtworkImage;

/// 「我的」页下载段与详情页的内嵌组件总出口（模块化铁律：其他 feature 只允许 import 本文件）。

/// 退出登录时询问是否连同本机离线下载一并删除（对齐 iOS `OfflineDownloadCleanup.askOnLogout`）。
Future<void> askOfflineCleanupOnLogout(
  BuildContext context,
  WidgetRef ref, {
  bool everywhere = false,
}) async {
  final offline = ref.read(offlineProvider);
  final hasCurrent = offline.units.isNotEmpty;
  final hasOther = offline.otherOwnersCount > 0;
  if (!hasCurrent && !(everywhere && hasOther)) return;
  if (!context.mounted) return;

  final bytesMap =
      await ref.read(offlineProvider.notifier).downloadedFileBytes();
  final totalBytes = bytesMap.values.fold<int>(0, (a, b) => a + b) +
      (everywhere ? offline.otherOwnersBytes : 0);
  if (!context.mounted) return;

  final delete = await showMcSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            everywhere
                ? '同时删除本机所有账号的离线下载？'
                : '同时删除本机的 ${offline.units.length} 项离线下载？',
            style: McText.titleSm,
          ),
          const SizedBox(height: 8),
          Text(
            everywhere
                ? '共占用 ${mcFormatBytes(totalBytes)}。共享设备建议一并清除。'
                : '共占用 ${mcFormatBytes(totalBytes)}。保留的话，下次重新登录同一账号仍可直接离线播放。',
            style: McText.sub.muted,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '保留本机副本',
                  primary: false,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: everywhere ? '全部删除' : '删除下载',
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (delete == true) {
    final ctrl = ref.read(offlineProvider.notifier);
    if (everywhere) {
      await ctrl.deleteAllOwners();
    } else {
      await ctrl.deleteCurrentOwnerAll();
    }
  }
}

/// 详情页播放键旁的 App Store 风格圆形进度环下载状态条（对齐 iOS `OfflineDownloadControl`）：
/// 仅在该单元尚未下完（准备中 / 排队 / 下载中 / 暂停 / 失败 / 等待转码 / 文件损坏）时展示；
/// 点击弹出「优先下载 / 暂停 / 继续 / 重试 / 取消下载」菜单。
class OfflineDownloadControl extends ConsumerWidget {
  const OfflineDownloadControl({
    super.key,
    required this.mediaItemId,
    required this.title,
    this.season = 0,
    this.episode = 0,
    this.fileId,
  });

  final int mediaItemId;
  final String title;
  final int season;
  final int episode;
  final int? fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    final unit = (fileId != null ? offline.unitForFile(fileId!) : null) ??
        offline.unitForEpisode(
          mediaItemId: mediaItemId,
          season: season,
          episode: episode,
        );
    if (unit == null || unit.playable) return const SizedBox.shrink();

    final controller = ref.read(offlineProvider.notifier);
    final ahead = offline.queueAheadOf(unit.id);
    final canPrio = offline.canPrioritize(unit.id);
    final tint = unit.needsAttention ? McTokens.warning : McTokens.accentStrong;
    final statusText = unit.status.text(
      ahead: ahead,
      waitingForWifi: !offline.allowCellular &&
          unit.status == OfflineUnitStatus.waitingWifi,
      transcodeWait: unit.transcodeWait,
      progress: unit.progressFraction,
      receivedBytes: unit.receivedBytes,
      expectedBytes: unit.effectiveTotalBytes,
      error: unit.error,
      retryable: unit.retryable,
      damaged: unit.damaged,
    );

    return McPressable(
      onTap: () => _openMenu(context, ref, unit, controller, canPrio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(McTokens.pillRadius),
          border: Border.all(color: tint.withValues(alpha: 0.32)),
        ),
        child: Row(
          children: [
            _DownloadRingIcon(unit: unit, color: tint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.semibold.copyWith(color: tint),
              ),
            ),
            if (unit.status == OfflineUnitStatus.running &&
                unit.speedBps > 0) ...[
              const SizedBox(width: 8),
              Text(
                mcFormatSpeed(unit.speedBps),
                style: McText.caption.tabular.copyWith(
                  color: tint.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openMenu(
    BuildContext context,
    WidgetRef ref,
    DownloadUnit unit,
    OfflineController controller,
    bool canPrio,
  ) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: unit.displaySeasonEpisode != null
              ? '$title · ${unit.displaySeasonEpisode}'
              : title,
          margin: EdgeInsets.zero,
          children: [
            if (canPrio)
              McInsetRow(
                icon: McIcons.arrowUpCircle,
                title: '优先下载',
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.prioritize(unit);
                },
              ),
            if (unit.status == OfflineUnitStatus.running ||
                unit.status == OfflineUnitStatus.queued)
              McInsetRow(
                icon: McIcons.pause,
                title: '暂停下载',
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.toggle(unit);
                },
              )
            else if (unit.status == OfflineUnitStatus.paused ||
                (unit.status == OfflineUnitStatus.failed &&
                    !unit.waitingForTranscode))
              McInsetRow(
                icon: McIcons.play2Fill,
                title: unit.status == OfflineUnitStatus.failed ? '重试下载' : '继续下载',
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.toggle(unit);
                },
              ),
            McInsetRow(
              icon: McIcons.trash2,
              title: '取消下载',
              destructive: true,
              onTap: () {
                Navigator.of(ctx).pop();
                controller.cancel(unit);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadRingIcon extends StatelessWidget {
  const _DownloadRingIcon({required this.unit, required this.color});

  final DownloadUnit unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (unit.status == OfflineUnitStatus.paused) {
      return Icon(McIcons.pause, size: 18, color: color);
    }
    if (unit.waitingForTranscode) {
      return Icon(McIcons.stopwatch, size: 18, color: color);
    }
    if (unit.needsAttention) {
      return Icon(McIcons.close, size: 18, color: color);
    }
    final determinate = unit.status == OfflineUnitStatus.running ||
        unit.status == OfflineUnitStatus.queued;
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        value: determinate ? unit.progressFraction.clamp(0.04, 1.0) : null,
        strokeWidth: 2.4,
        color: color,
        backgroundColor: color.withValues(alpha: 0.22),
      ),
    );
  }
}

/// 详情页「文件」区本机副本行（对齐 iOS `OfflineLocalFileRow`）：
/// 绿底「本机」标签 + 展开后展示保存位置、下载时间、来源（原画/转码档位）与本机文件大小；
/// 右侧垃圾桶二次确认删除，长按支持改下其他画质。
class OfflineLocalFileRow extends ConsumerStatefulWidget {
  const OfflineLocalFileRow({
    super.key,
    required this.fileId,
    required this.title,
    this.fileName,
    this.specRows = const [],
  });

  final int fileId;
  final String title;
  final String? fileName;
  final List<({String label, String value})> specRows;

  @override
  ConsumerState<OfflineLocalFileRow> createState() =>
      _OfflineLocalFileRowState();
}

class _OfflineLocalFileRowState extends ConsumerState<OfflineLocalFileRow> {
  bool _expanded = false;

  void _confirmDelete(BuildContext context, DownloadUnit unit) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('删除本机离线副本？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '立即释放 ${mcFormatBytes(unit.receivedBytes)}，删除后无网时将无法播放此副本；观看进度会保留。',
              style: McText.sub.muted,
            ),
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
                    label: '删除副本',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref
                          .read(offlineProvider.notifier)
                          .deleteDownloaded(unit);
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
    final unit = ref.watch(offlineProvider).unitForFile(widget.fileId);
    if (unit == null || !unit.playable) return const SizedBox.shrink();
    final isOffline = ref.watch(offlineModeProvider);
    final isOriginal = unit.profile == 'original';

    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McPressable(
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: !isOffline
                ? () => showOfflineDownloadSheet(
                      context,
                      title: widget.title,
                      fileId: widget.fileId,
                    )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? McIcons.arrowDownMFill
                        : McIcons.arrowRightMFill,
                    size: 14,
                    color: McTokens.textFaint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.fileName ?? widget.title,
                      maxLines: _expanded ? null : 1,
                      overflow:
                          _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: McText.caption.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: McTokens.ok.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '本机',
                      style: McText.micro.copyWith(
                        color: McTokens.ok,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '删除本机副本',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      McIcons.trash2,
                      size: 16,
                      color: McTokens.textFaint,
                    ),
                    onPressed: () => _confirmDelete(context, unit),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: Column(
                children: [
                  _specLine('保存位置', '本机离线存档'),
                  _specLine(
                    '下载时间',
                    unit.completedAt != null
                        ? mcFromNow(unit.completedAt!)
                        : '—',
                  ),
                  _specLine(
                    '来源',
                    isOriginal ? '原画（与源文件一致）' : '服务器转码 · ${unit.profileLabel}',
                  ),
                  _specLine(
                    '文件大小',
                    mcFormatBytes(unit.receivedBytes),
                  ),
                  if (isOriginal)
                    for (final r in widget.specRows)
                      _specLine(r.label, r.value)
                  else
                    _specLine('视频规格', unit.profileLabel),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _specLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: McText.micro.faint),
            ),
            Expanded(
              child: Text(value, style: McText.micro.muted),
            ),
          ],
        ),
      );
}

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
    final bytes =
        await ref.read(offlineProvider.notifier).downloadedFileBytes();
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
                queueAhead: offline.queueAheadOf(unit.id),
                waitingForWifi: !offline.allowCellular &&
                    unit.status == OfflineUnitStatus.waitingWifi,
                canPrioritize: offline.canPrioritize(unit.id),
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
                const Spacer(),
                if (byTitle.isNotEmpty)
                  McChip(
                    label: '离线媒体库',
                    compact: true,
                    onTap: () => context.push('/offline/library'),
                  ),
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
      if (u.displaySeasonEpisode != null) u.displaySeasonEpisode!,
      u.profileLabel,
      if (u.watched) '已看完',
    ].join(' · ');
  }

  void _playOffline(BuildContext context, OfflineController controller) {
    if (units.length == 1) {
      final u = units.first;
      final uri = controller.localPlayUri(u);
      if (uri == null) {
        McToast.error('本地文件不存在');
        return;
      }
      context.push(
        '/player',
        extra: PlayerPageArgs(
          url: uri,
          mediaItemId: u.mediaItemId,
          fileId: u.fileId,
          title: u.title,
          subtitle: u.displaySeasonEpisode ?? '本机离线播放',
          seasonNumber: u.isMovie ? null : u.seasonNumber,
          episodeNumber: u.isMovie ? null : u.episodeNumber,
          isEpisode: !u.isMovie,
          isOffline: true,
          offlineItemId: u.mediaItemId?.toString(),
          offlineFileId: u.fileId,
          artworkUrl: u.posterUrl ?? u.backdropUrl,
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
                title: u.displaySeasonEpisode ?? u.title,
                subtitle: u.profileLabel,
                onTap: () {
                  Navigator.of(ctx).pop();
                  final uri = controller.localPlayUri(u);
                  if (uri != null) {
                    context.push(
                      '/player',
                      extra: PlayerPageArgs(
                        url: uri,
                        mediaItemId: u.mediaItemId,
                        fileId: u.fileId,
                        title: u.title,
                        subtitle: u.displaySeasonEpisode,
                        seasonNumber: u.isMovie ? null : u.seasonNumber,
                        episodeNumber: u.isMovie ? null : u.episodeNumber,
                        isEpisode: !u.isMovie,
                        isOffline: true,
                        offlineItemId: u.mediaItemId?.toString(),
                        offlineFileId: u.fileId,
                        artworkUrl: u.posterUrl ?? u.backdropUrl,
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
    final art = units.first.posterUrl ?? units.first.backdropUrl;
    return McPressable(
      onTap: () => _playOffline(context, controller),
      onLongPress: () => _openActions(context, controller),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(McTokens.radiusSm),
              child: SizedBox(
                width: 44,
                height: 66,
                child: OfflineArtworkImage(
                  rawUrl: art,
                  widthPx: 160,
                  placeholderIcon:
                      units.first.kind == 'tv' ? McIcons.tv : McIcons.movie,
                ),
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
