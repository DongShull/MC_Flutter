import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../../../core/player/player_page_args.dart';
import '../embed.dart';
import '../widgets/downloading_row.dart';

/// 离线下载管理专页：
/// 下载中（严格串行队列 + 拖拽调整顺序即时抢占 + Wi-Fi 守卫 + 503 转码排队提示）
/// → 已看完一键清理建议 → 已下载（真实本地海报 + 点击直接离线播放）→ 其他账号缓存 → 存储空间。
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

  void _playUnitOffline(DownloadUnit unit) {
    final uri = ref.read(offlineProvider.notifier).localPlayUri(unit);
    if (uri == null) {
      McToast.error('本地离线文件不存在');
      return;
    }
    context.push(
      '/player',
      extra: PlayerPageArgs(
        url: uri,
        mediaItemId: unit.mediaItemId,
        fileId: unit.fileId,
        title: unit.title,
        subtitle: unit.displaySeasonEpisode ?? '本机离线播放',
        seasonNumber: unit.isMovie ? null : unit.seasonNumber,
        episodeNumber: unit.isMovie ? null : unit.episodeNumber,
        isEpisode: !unit.isMovie,
        isOffline: true,
        offlineItemId: unit.mediaItemId?.toString(),
        offlineFileId: unit.fileId,
        artworkUrl: unit.posterUrl ?? unit.backdropUrl,
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
            title: '离线下载',
            titleVisible: true,
            trailing: [
              if (done.isNotEmpty) ...[
                McFocusRing(
                  borderRadius: 24,
                  child: McGlassIconButton(
                    icon: McIcons.mediaLibraryFill,
                    tooltip: '离线媒体库',
                    onTap: () => context.go('/offline/library'),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
                      _sectionHeader('下载中（拖拽调整顺序）'),
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
                              McChip(
                                label: '允许移动数据下载',
                                compact: true,
                                selected: true,
                                onTap: () => controller.setAllowCellular(true),
                              ),
                            ],
                          ),
                        ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: active.length,
                        onReorder: controller.reorder,
                        itemBuilder: (context, index) {
                          final unit = active[index];
                          return Container(
                            key: ValueKey(unit.id),
                            child: DownloadingRow(
                              unit: unit,
                              queueAhead: offline.queueAheadOf(unit.id),
                              waitingForWifi: !offline.allowCellular &&
                                  unit.status == OfflineUnitStatus.waitingWifi,
                              canPrioritize: offline.canPrioritize(unit.id),
                              onPauseResume: () => controller.toggle(unit),
                              onCancel: () => controller.cancel(unit),
                              onPrioritize: () => controller.prioritize(unit),
                              dragHandle: ReorderableDragStartListener(
                                index: index,
                                child: Tooltip(
                                  message: '拖动调整下载顺序',
                                  child: Semantics(
                                    label: '拖动调整下载顺序',
                                    child: const SizedBox(
                                      width: 40,
                                      height: 44,
                                      child: Center(
                                        child: Icon(
                                          McIcons.draggableS,
                                          size: 18,
                                          color: McTokens.textFaint,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const WatchedCard(),
                    Row(
                      children: [
                        Expanded(child: _sectionHeader('已下载')),
                        if (done.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: McChip(
                              label: '进入离线媒体库',
                              compact: true,
                              onTap: () => context.go('/offline/library'),
                            ),
                          ),
                      ],
                    ),
                    if (done.isEmpty)
                      Text(
                        '还没有已下载的内容。在影片详情页点击「⋯ → 离线缓存到本地」，无网环境也能随时播放。',
                        style: McText.caption.muted,
                      )
                    else
                      McInsetGroup(
                        margin: EdgeInsets.zero,
                        children: [
                          for (final unit in done)
                            McInsetRow(
                              leading: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(McTokens.radiusXs),
                                child: SizedBox(
                                  width: 38,
                                  height: 56,
                                  child: OfflineArtworkImage(
                                    rawUrl: unit.posterUrl ?? unit.backdropUrl,
                                    widthPx: 160,
                                    placeholderIcon: unit.kind == 'tv'
                                        ? McIcons.tv
                                        : McIcons.movie,
                                  ),
                                ),
                              ),
                              title: unit.title,
                              subtitle: [
                                if (unit.displaySeasonEpisode != null)
                                  unit.displaySeasonEpisode!,
                                unit.profileLabel,
                                if (unit.receivedBytes > 0)
                                  mcFormatBytes(unit.receivedBytes),
                                if (unit.watched) '已看完',
                              ].join(' · '),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  McChip(
                                    label: unit.watched ? '未看' : '标已看',
                                    compact: true,
                                    onTap: () => controller.markUnitWatched(
                                      unit,
                                      watched: !unit.watched,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: '删除副本',
                                    icon: const Icon(
                                      McIcons.trash2,
                                      size: 17,
                                      color: McTokens.danger,
                                    ),
                                    onPressed: () => _confirmDelete(unit),
                                  ),
                                ],
                              ),
                              onTap: () => _playUnitOffline(unit),
                            ),
                        ],
                      ),
                    const OtherOwnersSection(),
                    const CapacityCard(),
                    if (offline.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          offline.error!,
                          style:
                              McText.caption.copyWith(color: McTokens.danger),
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
            Text('删除「${unit.title}」的离线副本？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text('只删本机上的视频文件，观看进度会保留。', style: McText.sub.muted),
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

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(title, style: McText.titleSm),
      );
}
