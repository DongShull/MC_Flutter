import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_ambient.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/player/player_page_args.dart';
// offline 域下载能力（任务明确授权的跨 feature import：只调公开 API，不改 offline 内部）。
import '../../offline/pages/profile_sheet.dart';
import '../../offline/state/models.dart';
import '../state/detail_controller.dart';
import '../widgets/air_schedule.dart';
import '../widgets/cast_row.dart';
import '../widgets/detail_admin_sheets.dart';
import '../widgets/detail_header.dart';
import '../widgets/episode_list.dart';
import '../widgets/episode_ranges.dart';
import '../widgets/item_actions_menu.dart';
import '../widgets/meta_links.dart';
import '../widgets/similar_row.dart';

/// 媒体详情页（1:1 对齐 iOS `LibraryItemDetailView` & 参考图 `scene-1.jpg`）：
/// - 全出血剧照 + `McAmbientColor.bottomEdge` 底边动态取色铺满上半页并向纯黑底平滑过渡；
/// - 顶部无实色栏，浮左 `<` 与右 `⋯` 两颗液态玻璃圆钮，滚过标题后片名与黑雾淡入；
/// - 黄金操作区：通栏亮银白胶囊主按钮 + 续播细进度线 + 等宽「已收藏 / 标为已看」双液态玻璃胶囊；
/// - 轨道胶囊行 → 简介 → 季选 `McChip` 与 16:9 分集卡 → 圆形演职员 → 同系列与相似推荐。
class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({super.key, this.libraryId = -1, this.itemId = -1});

  final int libraryId;
  final int itemId;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  late final String _key = '${widget.libraryId}:${widget.itemId}';
  double _scrollOffset = 0;
  Color? _edgeColor;
  String? _sampledUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detailControllerProvider(_key).notifier).load();
    });
  }

  void _ensureEdgeColor(DetailEntry entry) {
    final raw = entry.backdropUrl ?? entry.posterUrl;
    if (raw == null || raw.isEmpty || raw == _sampledUrl) return;
    _sampledUrl = raw;
    McAmbientColor.bottomEdge(raw).then((c) {
      if (mounted && c != null && c != _edgeColor) {
        setState(() => _edgeColor = c);
      }
    });
  }

  void _playEpisode(EpisodeEntry e) {
    if (!e.owned || e.fileIds.isEmpty) {
      McToast.error('第 ${e.episodeNumber} 集缺失文件，无法播放');
      return;
    }
    _pushPlayer(
      fileId: e.fileIds.first,
      title: '第 ${e.seasonNumber} 季第 ${e.episodeNumber} 集',
      subtitle: e.name,
      startPosition: e.resumeMs > 0 ? Duration(milliseconds: e.resumeMs) : null,
      resumeSeason: e.seasonNumber,
      resumeEpisode: e.episodeNumber,
    );
  }

  void _play() {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    if (entry.isTv) {
      final resume = state.resume;
      final season = resume?.season ?? state.selectedSeason;
      final episode = resume?.episode ?? entry.resumeEpisode;
      final list = state.episodes[season] ?? const <EpisodeEntry>[];
      EpisodeEntry? target;
      for (final e in list) {
        if (e.episodeNumber == episode) {
          target = e;
          break;
        }
      }
      target ??= list.isEmpty ? null : list.first;
      if (target == null || !target.owned || target.fileIds.isEmpty) {
        McToast.error('该集暂无在位文件，无法播放');
        return;
      }
      _pushPlayer(
        fileId: target.fileIds.first,
        title: '第 ${target.seasonNumber} 季第 ${target.episodeNumber} 集',
        subtitle: target.name,
        startPosition: (resume?.positionMs ?? target.resumeMs) > 0
            ? Duration(milliseconds: resume?.positionMs ?? target.resumeMs)
            : null,
        resumeSeason: target.seasonNumber,
        resumeEpisode: target.episodeNumber,
      );
      return;
    }
    _pushPlayer();
  }

  void _pushPlayer({
    int? fileId,
    String? title,
    String? subtitle,
    Duration? startPosition,
    int? resumeSeason,
    int? resumeEpisode,
  }) {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: widget.itemId,
        fileId: fileId,
        seasonNumber: resumeSeason,
        episodeNumber: resumeEpisode,
        title: entry?.title,
        subtitle: subtitle ?? title,
        startPosition: startPosition,
        isEpisode: entry?.isTv ?? false,
        seasons: [
          for (final s in entry?.seasons ?? const <SeasonInfo>[]) s.number,
        ],
        episodes: [
          for (final seasonEntry in state.episodes.entries)
            for (final e in seasonEntry.value)
              EpisodeItem(
                season: e.seasonNumber,
                episode: e.episodeNumber,
                name: e.name,
                fileId: e.playFileId,
                owned: e.owned,
              ),
        ],
      ),
    );
  }

  void _showActionMenu(DetailController controller) async {
    final action = await showItemActionsMenu(context);
    if (action == null || !mounted) return;
    final entry = ref.read(detailControllerProvider(_key)).entry;
    switch (action) {
      case ItemAction.subscribe:
        _subscribe();
      case ItemAction.download:
        _download();
      case ItemAction.addToCollection:
        showAddToCollectionSheet(context: context, controller: controller);
      case ItemAction.share:
        showConfigurableShareSheet(
          context: context,
          controller: controller,
          itemTitle: entry?.title ?? '影片',
        );
      case ItemAction.subtitleGen:
        showSubtitleGenSheet(context: context, controller: controller);
      case ItemAction.artwork:
        showArtworkPickerSheet(context: context, controller: controller);
      case ItemAction.reidentify:
        showReidentifySheet(
          context: context,
          controller: controller,
          initialTitle: entry?.title ?? '',
        );
      case ItemAction.refreshMetadata:
        final err = await controller.refreshMetadata();
        if (!mounted) return;
        if (err != null) {
          McToast.error(err);
        } else {
          McToast.success('已提交刷新元数据任务');
        }
      case ItemAction.delete:
        _delete(controller);
    }
  }

  Future<void> _subscribe() async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final tmdbId = entry?.tmdbId;
    if (tmdbId == null) {
      McToast.info('该条目没有 TMDB 标识，暂不能订阅');
      return;
    }
    final refStr = 'tmdb:${entry!.isTv ? 'tv' : 'movie'}:$tmdbId';
    final outcome = await showSubscribeSheet(context, ref, titleRef: refStr);
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case SubscribeSheetOutcome.created:
        McToast.success('已加入追更订阅');
      case SubscribeSheetOutcome.managed:
        context.push('/subscriptions');
    }
  }

  void _download({int? specificFileId, String? episodeSubtitle}) {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    final fileId = specificFileId ??
        ref.read(detailControllerProvider(_key).notifier).leadFileId;
    if (fileId == null) {
      McToast.error('没有在位文件，无法缓存');
      return;
    }
    final seasonList = state.episodes[state.selectedSeason] ?? const <EpisodeEntry>[];
    final seasonFileIds = [
      for (final e in seasonList)
        if (e.playFileId != null) e.playFileId.toString(),
    ];
    const profiles = [
      DownloadProfile(id: 'original', label: '原画', isOriginal: true),
      DownloadProfile(
        id: '1080p',
        label: '1080P',
        isOriginal: false,
        transcode: true,
      ),
      DownloadProfile(
        id: '720p',
        label: '720P',
        isOriginal: false,
        transcode: true,
      ),
      DownloadProfile(
        id: '480p',
        label: '480P',
        isOriginal: false,
        transcode: true,
      ),
    ];
    showDownloadProfileSheet(
      context,
      candidate: DownloadCandidate(
        fileId: fileId.toString(),
        title: episodeSubtitle != null
            ? '${entry.title} · $episodeSubtitle'
            : entry.title,
        scopes: entry.isTv && specificFileId == null && seasonFileIds.length > 1
            ? const ['当前集', '本季全部']
            : const ['本片'],
        profiles: profiles,
        seasonFileIds: seasonFileIds,
      ),
    );
  }

  Future<void> _delete(DetailController controller) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final ok = await showDeletePreviewSheet(
      context: context,
      controller: controller,
      title: entry?.title ?? '',
    );
    if (ok != true || !mounted) return;
    final err = await controller.deleteItem();
    if (!mounted) return;
    if (err != null) {
      McToast.error(err);
      return;
    }
    McToast.success('条目已删除');
    if (context.canPop()) context.pop();
  }

  void _openPerson(CastMember member) {
    final id = member.personId;
    if (id == null || id <= 0) {
      McToast.info('暂无「${member.name}」的人物档案');
      return;
    }
    context.push(
      '/library/person/$id?name=${Uri.encodeComponent(member.name)}',
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Widget _buildActionZone(DetailState state, DetailController controller) {
    final resume = state.resume;
    final hasProgress =
        resume != null && resume.positionMs > 0 && resume.durationMs > 0;
    final progressRatio = hasProgress
        ? (resume.positionMs / resume.durationMs).clamp(0.02, 1.0)
        : 0.0;
    final remainMins = hasProgress
        ? ((resume.durationMs - resume.positionMs) / 60000).ceil().clamp(1, 9999)
        : 0;
    final isFav = state.marks.isFavorite;
    final isPlayed = state.marks.played;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          McFocusRing(
            borderRadius: McTokens.pillRadius,
            child: McActionPill(
              label: playButtonLabel(state),
              icon: McIcons.play2Fill,
              primary: true,
              expanded: true,
              height: 44,
              onTap: _play,
            ),
          ),
          if (hasProgress) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 3,
                      backgroundColor: const Color(0x2EFFFFFF),
                      valueColor: const AlwaysStoppedAnimation(
                        McTokens.accentStrong,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '剩余 $remainMins 分钟',
                  style: McText.micro
                      .copyWith(
                        fontWeight: FontWeight.w500,
                        color: McTokens.textMuted,
                      )
                      .tabular,
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: McFocusRing(
                  borderRadius: McTokens.pillRadius,
                  child: McActionPill(
                    label: isFav ? '已收藏' : '收藏',
                    icon: isFav ? McIcons.heart2Fill : McIcons.heart2,
                    primary: false,
                    tone: isFav ? McGlassTone.danger : McGlassTone.secondary,
                    expanded: true,
                    height: 40,
                    onTap: state.busy ? null : controller.toggleFavorite,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McFocusRing(
                  borderRadius: McTokens.pillRadius,
                  child: McActionPill(
                    label: isPlayed ? '已看完' : '标为已看',
                    icon: isPlayed
                        ? McIcons.checkCircleFill
                        : McIcons.checkCircle,
                    primary: false,
                    tone: isPlayed ? McGlassTone.strong : McGlassTone.secondary,
                    expanded: true,
                    height: 40,
                    onTap: state.busy ? null : controller.togglePlayed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTvSeasons(
    DetailEntry entry,
    DetailState state,
    DetailController controller,
    List<EpisodeEntry> episodes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        if (state.airSchedule != null) AirSchedule(schedule: state.airSchedule!),
        const McSectionHeader(title: '剧集'),
        if (entry.seasons.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: entry.seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = entry.seasons[i];
                final label = s.name ??
                    (s.number == 0 ? '特别篇' : '第 ${s.number} 季');
                return McChip(
                  label: label,
                  selected: state.selectedSeason == s.number,
                  onTap: () => controller.loadSeason(s.number),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 6),
        EpisodeRanges(episodes: episodes),
        EpisodeList(
          episodes: episodes,
          onEpisodeTap: _playEpisode,
          onTogglePlayed: (ep) async {
            final err = await controller.toggleEpisodePlayed(ep);
            if (!mounted) return;
            if (err != null) {
              McToast.error(err);
            } else {
              McToast.success(ep.played ? '已标为未看' : '已标为看完');
            }
          },
          onDownloadEpisode: (ep) {
            if (ep.playFileId == null) {
              McToast.error('该集无在位文件');
              return;
            }
            _download(
              specificFileId: ep.playFileId,
              episodeSubtitle:
                  'S${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')}',
            );
          },
          onSubtitleEpisode: (ep) {
            if (ep.playFileId == null) {
              McToast.error('该集无在位文件');
              return;
            }
            showSubtitleGenSheet(
              context: context,
              controller: controller,
              fileId: ep.playFileId,
              label:
                  'S${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')}',
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailControllerProvider(_key));
    if (state.loading && state.entry == null) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Stack(
          children: [
            const McFeedSkeleton(showHero: true),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: McFloatingDetailBar(onBack: _back),
            ),
          ],
        ),
      );
    }
    if (state.error != null && state.entry == null) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Stack(
          children: [
            McErrorView(
              text: state.error!,
              onRetry: () =>
                  ref.read(detailControllerProvider(_key).notifier).load(),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: McFloatingDetailBar(onBack: _back),
            ),
          ],
        ),
      );
    }
    final entry = state.entry;
    if (entry == null) {
      return const Scaffold(
        backgroundColor: McTokens.bg,
        body: SizedBox.shrink(),
      );
    }

    _ensureEdgeColor(entry);
    final ambient = _edgeColor ?? McTokens.bg;
    final controller = ref.read(detailControllerProvider(_key).notifier);
    final episodes =
        state.episodes[state.selectedSeason] ?? const <EpisodeEntry>[];
    final form = McFormWatch.of(context);
    final wide = form != McDeviceForm.phone;

    final Widget scrollBody = wide
        ? ListView(
            padding: const EdgeInsets.only(bottom: 48),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DetailHeader(
                entry: entry,
                ambientColor: ambient,
                scrollOffset: _scrollOffset,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  McTokens.pagePaddingWide,
                  18,
                  McTokens.pagePaddingWide,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActionZone(state, controller),
                          const SizedBox(height: 16),
                          MetaLinks(
                            entry: entry,
                            onSeriesTap: (id) =>
                                context.push('/library/collection/$id'),
                            onCollectionTap: (_) =>
                                context.push('/library/collections'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.overview != null &&
                              entry.overview!.isNotEmpty)
                            _Overview(
                              text: entry.overview!,
                              expanded: state.overviewExpanded,
                              onToggle: controller.toggleOverview,
                            ),
                          CastRow(
                            cast: entry.cast,
                            onPersonTap: _openPerson,
                          ),
                          if (entry.isTv)
                            _buildTvSeasons(entry, state, controller, episodes),
                          if (state.related.seriesParts.length > 1)
                            SimilarRow(
                              title: '系列 · ${state.related.seriesName ?? ''}',
                              entries: state.related.seriesParts,
                              onTap: (e) => context.push(
                                '/detail/${entry.libraryId}/${e.id}',
                              ),
                            ),
                          SimilarRow(
                            title: '相似推荐',
                            entries: state.related.similar,
                            onTap: (e) => context.push(
                              '/detail/${entry.libraryId}/${e.id}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.only(bottom: 48),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DetailHeader(
                entry: entry,
                ambientColor: ambient,
                scrollOffset: _scrollOffset,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  McTokens.pagePadding,
                  14,
                  McTokens.pagePadding,
                  0,
                ),
                child: Center(child: _buildActionZone(state, controller)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  McTokens.pagePadding,
                  14,
                  McTokens.pagePadding,
                  0,
                ),
                child: MetaLinks(
                  entry: entry,
                  onSeriesTap: (id) => context.push('/library/collection/$id'),
                  onCollectionTap: (_) => context.push('/library/collections'),
                ),
              ),
              if (entry.overview != null && entry.overview!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    14,
                    McTokens.pagePadding,
                    0,
                  ),
                  child: _Overview(
                    text: entry.overview!,
                    expanded: state.overviewExpanded,
                    onToggle: controller.toggleOverview,
                  ),
                ),
              if (entry.isTv)
                _buildTvSeasons(entry, state, controller, episodes),
              CastRow(
                cast: entry.cast,
                onPersonTap: _openPerson,
              ),
              if (state.related.seriesParts.length > 1)
                SimilarRow(
                  title: '系列 · ${state.related.seriesName ?? ''}',
                  entries: state.related.seriesParts,
                  onTap: (e) =>
                      context.push('/detail/${entry.libraryId}/${e.id}'),
                ),
              SimilarRow(
                title: '相似推荐',
                entries: state.related.similar,
                onTap: (e) =>
                    context.push('/detail/${entry.libraryId}/${e.id}'),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Apple Music 式底边取色整页渐变背景，随深滚自然回归纯黑
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    ambient,
                    ambient.withValues(alpha: 0.42),
                    McTokens.bg,
                  ],
                ),
              ),
            ),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                setState(() => _scrollOffset = n.metrics.pixels);
              }
              return false;
            },
            child: RefreshIndicator(
              edgeOffset: MediaQuery.paddingOf(context).top + 54,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceSolid,
              onRefresh: controller.load,
              child: scrollBody,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: _back,
              title: entry.title,
              titleVisible: _scrollOffset > 220,
              trailing: [
                McGlassIconButton(
                  icon: McIcons.more,
                  tooltip: '更多操作',
                  onTap: () => _showActionMenu(controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onToggle,
      scaleDown: 0.992,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: expanded ? null : 4,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: McText.bodyLg.copyWith(
              fontSize: 15,
              height: 1.55,
              color: const Color(0xD6F3F5F9),
            ),
          ),
          if (text.length > 96) ...[
            const SizedBox(height: 4),
            Text(
              expanded ? '收起简介' : '展开全部',
              style: McText.caption.copyWith(
                color: McTokens.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
