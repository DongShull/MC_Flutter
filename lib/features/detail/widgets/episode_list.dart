import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../offline/embed.dart';
import '../state/detail_controller.dart';
import 'air_schedule.dart';
import 'episode_ranges.dart';

/// 分集列表（1:1 对齐 iOS `SeasonEpisodesSection` + 懒加载长季分段）：
/// - 超过 50 集自动分 50 集一段（`1–50`, `51–100`…），带「上一段 / 下一段」切换钮，绝不同步构建 200 个卡片；
/// - 结合 `SeasonAirSchedule` 区分「今日播出 / 未播定档（UnairedStill）」与「缺失文件」；
/// - 结合 `offlineProvider` 在剧照角标展示本机已下载 / 下载中进度；
/// - 支持点选切换当前集（同步更新轨道/章节/播放键）与直接播放、标为已看、离线缓存、AI 字幕。
class EpisodeList extends ConsumerStatefulWidget {
  const EpisodeList({
    super.key,
    required this.mediaItemId,
    required this.episodes,
    required this.onEpisodeTap,
    this.onEpisodeSelect,
    this.selectedEpisodeNumber,
    this.anchorEpisode,
    this.airSchedule,
    this.activeRangeIndex,
    this.onRangeChanged,
    this.onTogglePlayed,
    this.onDownloadEpisode,
    this.onSubtitleEpisode,
  });

  final int mediaItemId;
  final List<EpisodeEntry> episodes;
  final void Function(EpisodeEntry episode) onEpisodeTap;
  final void Function(EpisodeEntry episode)? onEpisodeSelect;
  final int? selectedEpisodeNumber;
  final int? anchorEpisode;
  final SeasonAirSchedule? airSchedule;
  final int? activeRangeIndex;
  final ValueChanged<EpisodeRange>? onRangeChanged;
  final void Function(EpisodeEntry episode)? onTogglePlayed;
  final void Function(EpisodeEntry episode)? onDownloadEpisode;
  final void Function(EpisodeEntry episode)? onSubtitleEpisode;

  @override
  ConsumerState<EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends ConsumerState<EpisodeList> {
  int _localRangeIndex = 0;

  @override
  void didUpdateWidget(covariant EpisodeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeRangeIndex != null) {
      _localRangeIndex = widget.activeRangeIndex!;
    } else if (oldWidget.episodes != widget.episodes) {
      final ranges = EpisodeRangesHelper.buildRanges(widget.episodes);
      final seed = widget.selectedEpisodeNumber ?? widget.anchorEpisode;
      if (seed != null && ranges.isNotEmpty) {
        final matched = EpisodeRangesHelper.rangeContaining(seed, ranges);
        if (matched != null) _localRangeIndex = matched.index;
      } else {
        _localRangeIndex = ranges.isEmpty ? 0 : ranges.first.index;
      }
    }
  }

  void _switchRange(EpisodeRange target) {
    setState(() => _localRangeIndex = target.index);
    widget.onRangeChanged?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty) return const SizedBox.shrink();

    final offline = ref.watch(offlineProvider);
    final ranges = EpisodeRangesHelper.buildRanges(widget.episodes);
    final effectiveRangeIdx = widget.activeRangeIndex ?? _localRangeIndex;
    EpisodeRange? currentRange;
    int? rangePos;
    for (var i = 0; i < ranges.length; i++) {
      if (ranges[i].index == effectiveRangeIdx) {
        currentRange = ranges[i];
        rangePos = i;
        break;
      }
    }
    if (currentRange == null && ranges.isNotEmpty) {
      currentRange = ranges.first;
      rangePos = 0;
    }

    final shown = currentRange == null
        ? widget.episodes
        : widget.episodes
            .where((e) => currentRange!.contains(e.episodeNumber))
            .toList();
    final prevRange =
        (rangePos != null && rangePos > 0) ? ranges[rangePos - 1] : null;
    final nextRange = (rangePos != null && rangePos + 1 < ranges.length)
        ? ranges[rangePos + 1]
        : null;

    final watchedAny = widget.episodes.any((e) => e.played || e.resumeMs > 0);
    // 单页最多渲染 50 集且采用 shrinkWrap ListView.builder，避免一次性同步构造上百集大树。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prevRange != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              McTokens.pagePadding,
              6,
            ),
            child: _RangeNavButton(
              label: '← 上一段 (${prevRange.label})',
              onTap: () => _switchRange(prevRange),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: shown.length,
          separatorBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(
              left: McTokens.pagePadding + 144,
              right: McTokens.pagePadding,
            ),
            child: Divider(height: 1, color: McTokens.line),
          ),
          itemBuilder: (context, i) {
            final ep = shown[i];
            final unit = offline.unitForEpisode(
              mediaItemId: widget.mediaItemId,
              season: ep.seasonNumber,
              episode: ep.episodeNumber,
            );
            return _EpisodeCard(
              episode: ep,
              selected: widget.selectedEpisodeNumber == ep.episodeNumber,
              isResumeAnchor:
                  watchedAny && widget.anchorEpisode == ep.episodeNumber,
              schedule: widget.airSchedule,
              downloadUnit: unit,
              onTap: () => widget.onEpisodeTap(ep),
              onSelect: widget.onEpisodeSelect == null
                  ? null
                  : () => widget.onEpisodeSelect!(ep),
              onTogglePlayed: widget.onTogglePlayed == null
                  ? null
                  : () => widget.onTogglePlayed!(ep),
              onDownload: widget.onDownloadEpisode == null
                  ? null
                  : () => widget.onDownloadEpisode!(ep),
              onSubtitle: widget.onSubtitleEpisode == null
                  ? null
                  : () => widget.onSubtitleEpisode!(ep),
            );
          },
        ),
        if (nextRange != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              6,
              McTokens.pagePadding,
              4,
            ),
            child: _RangeNavButton(
              label: '下一段 (${nextRange.label}) →',
              onTap: () => _switchRange(nextRange),
            ),
          ),
      ],
    );
  }
}

class _RangeNavButton extends StatelessWidget {
  const _RangeNavButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: McTokens.line),
        ),
        child: Text(
          label,
          style: McText.caption.muted.tabular,
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.selected,
    required this.isResumeAnchor,
    required this.onTap,
    this.onSelect,
    this.schedule,
    this.downloadUnit,
    this.onTogglePlayed,
    this.onDownload,
    this.onSubtitle,
  });

  final EpisodeEntry episode;
  final bool selected;
  final bool isResumeAnchor;
  final VoidCallback onTap;
  final VoidCallback? onSelect;
  final SeasonAirSchedule? schedule;
  final DownloadUnit? downloadUnit;
  final VoidCallback? onTogglePlayed;
  final VoidCallback? onDownload;
  final VoidCallback? onSubtitle;

  List<McPosterMenuAction> _actions() => [
        if (episode.owned)
          McPosterMenuAction(
            icon: McIcons.play2Fill,
            label: '立即播放本集',
            onTap: onTap,
          ),
        if (onSelect != null && !selected)
          McPosterMenuAction(
            icon: McIcons.eyeCheck,
            label: '查看本集轨道与文件',
            onTap: onSelect!,
          ),
        if (onTogglePlayed != null)
          McPosterMenuAction(
            icon: episode.played
                ? McIcons.eyeClosedFill
                : McIcons.checkCircleFill,
            label: episode.played ? '标为未看' : '标为已看',
            onTap: onTogglePlayed!,
          ),
        if (episode.owned && onDownload != null)
          McPosterMenuAction(
            icon: McIcons.downloadCloudOut,
            label: '离线缓存本集',
            onTap: onDownload!,
          ),
        if (episode.owned && onSubtitle != null)
          McPosterMenuAction(
            icon: McIcons.closedCaptioning,
            label: 'AI 生成本集字幕…',
            onTap: onSubtitle!,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final airsToday = AirScheduleLogic.airsToday(episode, schedule);
    final unaired = AirScheduleLogic.isUnaired(episode, schedule);
    final totalMs = (episode.runtimeMinutes ?? 0) * 60000;
    final progress = episode.progressPercent != null &&
            episode.progressPercent! > 0 &&
            episode.resumeMs > 0
        ? (episode.progressPercent! / 100.0).clamp(0.02, 1.0)
        : (episode.resumeMs > 0 && totalMs > 0)
            ? (episode.resumeMs / totalMs).clamp(0.02, 1.0)
            : null;

    final epPrefix = 'E${episode.episodeNumber.toString().padLeft(2, '0')}';
    final fullTitle =
        episode.name.isEmpty ? epPrefix : '$epPrefix · ${episode.name}';

    final metaParts = <String>[
      if (episode.airDate != null && episode.airDate!.isNotEmpty)
        episode.airDate!,
      if (episode.runtimeMinutes != null && episode.runtimeMinutes! > 0)
        '${episode.runtimeMinutes} 分钟',
    ];
    final actions = _actions();
    final isDownloaded = downloadUnit?.playable == true;
    final isDownloading = downloadUnit != null && !downloadUnit!.playable;

    return Opacity(
      opacity: (episode.owned || unaired) ? 1.0 : 0.48,
      child: McFocusRing(
        borderRadius: 12,
        child: McPressable(
          onTap: () {
            onSelect?.call();
            if (episode.owned) {
              onTap();
            } else if (unaired) {
              McToast.info(
                airsToday ? '本集今日播出，尚未入库' : '本集尚未播出',
              );
            } else {
              onTap();
            }
          },
          scaleDown: 0.985,
          onSecondaryTapUp: actions.isEmpty
              ? null
              : (d) => showMcContextActions(
                    context: context,
                    title: fullTitle,
                    actions: actions,
                    globalPosition: d.globalPosition,
                  ),
          onLongPress: actions.isEmpty
              ? null
              : () => showMcContextActions(
                    context: context,
                    title: fullTitle,
                    actions: actions,
                  ),
          child: Container(
            color: selected
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 132,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.78)
                          : (unaired ? Colors.transparent : McTokens.line),
                      width: selected ? 1.8 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (schedule != null && unaired)
                        UnairedStill(
                          episode: episode,
                          schedule: schedule!,
                          today: airsToday,
                          radius: 10,
                        )
                      else
                        McArtwork(
                          url: episode.stillUrl,
                          frameAspect: 16 / 9,
                          widthPx: 360,
                          placeholderIcon: McIcons.tv,
                        ),
                      if (episode.owned)
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0x78000000),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x42FFFFFF),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              McIcons.play2Fill,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isResumeAnchor)
                        Positioned(
                          left: 5,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '接着看',
                              style: McText.micro.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDownloaded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xA6000000),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      McIcons.arrowDown,
                                      size: 9,
                                      color: McTokens.ok,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '本机',
                                      style: McText.micro.copyWith(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isDownloaded && episode.played)
                              const SizedBox(width: 4),
                            if (episode.played)
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: McTokens.ok,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  McIcons.check,
                                  size: 11,
                                  color: McTokens.onAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isDownloading)
                        Positioned(
                          left: 5,
                          right: 5,
                          bottom: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: downloadUnit!.progressFraction
                                  .clamp(0.05, 1.0),
                              minHeight: 3,
                              backgroundColor: const Color(0x66000000),
                              valueColor: const AlwaysStoppedAnimation(
                                McTokens.info,
                              ),
                            ),
                          ),
                        )
                      else if (progress != null)
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.5,
                              backgroundColor: const Color(0x47FFFFFF),
                              valueColor: const AlwaysStoppedAnimation(
                                McTokens.accentStrong,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub
                            .copyWith(
                              color: McTokens.text,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                            )
                            .tabular,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          if (!episode.owned && !unaired)
                            Text(
                              '● 缺失文件',
                              style: McText.micro.copyWith(
                                color: McTokens.warning,
                              ),
                            ),
                          if (metaParts.isNotEmpty)
                            Text(
                              metaParts.join(' · '),
                              style: McText.caption.faint.tabular,
                            ),
                          if (episode.rating != null && episode.rating! > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  McIcons.star2Fill,
                                  size: 11,
                                  color: McTokens.warning,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  episode.rating!.toStringAsFixed(1),
                                  style: McText.caption.faint.tabular,
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (episode.overview != null &&
                          episode.overview!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          episode.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: McText.caption.muted,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => showMcContextActions(
                      context: context,
                      title: fullTitle,
                      actions: actions,
                      globalPosition: d.globalPosition,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(6, 2, 2, 6),
                      child: Icon(
                        McIcons.more,
                        size: 17,
                        color: McTokens.textFaint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
