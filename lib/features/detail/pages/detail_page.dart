import 'dart:async';

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
import '../../../core/session/permissions.dart';
import '../../offline/embed.dart';
import '../state/detail_controller.dart';
import '../widgets/air_schedule.dart';
import '../widgets/cast_row.dart';
import '../widgets/chapter_strip_section.dart';
import '../widgets/detail_admin_sheets.dart';
import '../widgets/detail_header.dart';
import '../widgets/episode_list.dart';
import '../widgets/episode_ranges.dart';
import '../widgets/item_actions_menu.dart';
import '../widgets/library_file_section.dart';
import '../widgets/media_track_section.dart';
import '../widgets/meta_links.dart';
import '../widgets/similar_row.dart';
import '../widgets/transfer_item_sheet.dart';

/// 媒体详情页（100% 对齐 iOS `LibraryItemDetailView`）：
/// - 全出血剧照 + ClearLogo + 底边氛围取色 + 浮动玻璃顶栏；
/// - 离线下载状态环（`OfflineDownloadControl`）+ 三态播放键（播放 / 继续 / 重看第 N 次）+ 宽屏「从头播放」；
/// - 多版本切换与交互式轨道（`MediaTrackSection` + `TrackListSheet` + 字幕预览与音频对齐校准 + 5 阶段 AI 字幕）；
/// - 剧集季选 + 交互式播出日历弹层（含单集补缺）+ >50 集分段胶囊与 5 列宫格选集；
/// - 章节横排（`ChapterStripSection` + 灯箱缩放跳播 + 后台生成自动轮询）；
/// - 演职员（TMDB 影人页 / 本地 NFO 演员同库筛选 `?actor=`）；
/// - 相似推荐 + 作品系列（含未入库 `MissingPartCell` 一键订阅）；
/// - 物理媒体文件区（本机副本行 / 展开规格 / 回收站恢复与彻底清理 / 单文件删除 / 重复文件跳转）+ 外部词条（TMDB / IMDb / 豆瓣 App）。
class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({
    super.key,
    this.libraryId = -1,
    this.itemId = -1,
    this.initialSeason,
    this.initialEpisode,
  });

  final int libraryId;
  final int itemId;
  final int? initialSeason;
  final int? initialEpisode;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  late final String _key = '${widget.libraryId}:${widget.itemId}';
  double _scrollOffset = 0;
  Color? _edgeColor;
  String? _sampledUrl;
  int? _activeRangeIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detailControllerProvider(_key).notifier).load(
            initialSeason: widget.initialSeason,
            initialEpisode: widget.initialEpisode,
          );
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

  void _playEpisode(EpisodeEntry e, {Duration? overrideStart}) {
    if (!e.owned || e.fileIds.isEmpty) {
      McToast.error('第 ${e.episodeNumber} 集缺失文件，无法播放');
      return;
    }
    final state = ref.read(detailControllerProvider(_key));
    final activeFile = state.activeTrackFile;
    final fileId = (state.selectedEpisodeNumber == e.episodeNumber &&
            activeFile != null &&
            e.fileIds.contains(activeFile.id))
        ? activeFile.id
        : e.fileIds.first;
    _pushPlayer(
      fileId: fileId,
      title: e.seasonNumber == 0
          ? '特别篇第 ${e.episodeNumber} 集'
          : '第 ${e.seasonNumber} 季第 ${e.episodeNumber} 集',
      subtitle: e.name,
      startPosition: overrideStart ??
          (e.resumeMs > 0 ? Duration(milliseconds: e.resumeMs) : null),
      resumeSeason: e.seasonNumber,
      resumeEpisode: e.episodeNumber,
    );
  }

  void _play({Duration? overrideStart}) {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    if (entry.isTv) {
      final target = state.selectedEpisode;
      if (target == null || !target.owned || target.fileIds.isEmpty) {
        McToast.error('该集暂无在位文件，无法播放');
        return;
      }
      final resumePos = state.resume?.positionMs ?? target.resumeMs;
      _playEpisode(
        target,
        overrideStart: overrideStart ??
            (resumePos > 0 ? Duration(milliseconds: resumePos) : null),
      );
      return;
    }
    final active = state.activeTrackFile;
    final resumePos = state.resume?.positionMs ?? 0;
    _pushPlayer(
      fileId: active?.id ?? (entry.fileIds.isEmpty ? null : entry.fileIds.first),
      startPosition: overrideStart ??
          (resumePos > 0 ? Duration(milliseconds: resumePos) : null),
    );
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

  Future<void> _showActionMenu(DetailController controller) async {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    final perms = ref.read(permissionsProvider);
    final isVideoOrPhoto = entry.kind == 'video' || entry.kind == 'photo';

    final action = await showItemActionsMenu(
      context,
      isAdmin: perms.isAdmin,
      canManageLibraries: perms.canManageLibraries,
      canSubscribe: perms.canSubscribe,
      canDownload: perms.canDownloadVideo && state.availableUnitFiles.isNotEmpty,
      isScraped: state.libraryMeta?.scraped ?? entry.isScraped,
      hasTmdbId: (entry.tmdbId ?? 0) > 0,
      isVideoOrPhoto: isVideoOrPhoto,
      showChapterRegen: state.libraryMeta?.extractChapterImages ?? true,
      chaptersPending: entry.chaptersPending,
      scraping: entry.scraping,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ItemAction.subscribe:
        await _subscribe();
      case ItemAction.upgrade:
        await _upgrade(controller);
      case ItemAction.download:
        _download();
      case ItemAction.addToCollection:
        await showAddToCollectionSheet(
          context: context,
          controller: controller,
        );
      case ItemAction.share:
        await showConfigurableShareSheet(
          context: context,
          controller: controller,
          itemTitle: entry.title,
        );
      case ItemAction.subtitleGen:
        await showSubtitleGenSheet(
          context: context,
          controller: controller,
          fileId: state.activeTrackFile?.id,
          file: state.activeTrackFile,
        );
      case ItemAction.artwork:
        await showArtworkPickerSheet(
          context: context,
          controller: controller,
        );
      case ItemAction.reidentify:
        await showReidentifySheet(
          context: context,
          controller: controller,
          initialTitle: entry.title,
        );
      case ItemAction.refreshMetadata:
        final err = await controller.refreshMetadata();
        if (!mounted) return;
        if (err != null) {
          McToast.error(err);
        } else {
          McToast.success('已提交刷新元数据任务');
        }
      case ItemAction.reloadNfo:
        final err = await controller.reloadNfo();
        if (!mounted) return;
        if (err != null) {
          McToast.error(err);
        } else {
          McToast.success('已提交重读本地 NFO 任务');
        }
      case ItemAction.regenerateChapters:
        final err = await controller.regenerateChapters();
        if (!mounted) return;
        if (err != null) {
          McToast.error(err);
        } else {
          McToast.success('已开始重新生成章节缩略图');
        }
      case ItemAction.transfer:
        await showTransferItemSheet(
          context: context,
          controller: controller,
          title: entry.title,
          onDone: () => controller.load(silent: true),
        );
      case ItemAction.delete:
        await _deleteItem(controller);
    }
  }

  Future<void> _subscribe({String? overrideTitleRef}) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    String? refStr = overrideTitleRef;
    if (refStr == null) {
      final tmdbId = entry?.tmdbId;
      if (tmdbId == null || tmdbId <= 0) {
        McToast.info('该条目没有 TMDB 标识，暂不能订阅');
        return;
      }
      refStr = 'tmdb:${entry!.isTv ? 'tv' : 'movie'}:$tmdbId';
    }
    final outcome = await showSubscribeSheet(context, ref, titleRef: refStr);
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case SubscribeSheetOutcome.created:
        McToast.success('已加入追更订阅');
        unawaited(ref.read(detailControllerProvider(_key).notifier).load(silent: true));
      case SubscribeSheetOutcome.managed:
        context.push('/subscriptions');
    }
  }

  Future<void> _upgrade(DetailController controller) async {
    final existingId = await controller.findExistingSubscriptionId();
    if (!mounted) return;
    if (existingId != null && existingId > 0) {
      context.push('/subscriptions/detail/$existingId?upgrade-run=1');
      return;
    }
    await _subscribe();
  }

  void _download({int? specificFileId, String? episodeSubtitle}) {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    final offline = ref.read(offlineProvider);

    if (specificFileId != null) {
      showOfflineDownloadSheet(
        context,
        title: episodeSubtitle != null
            ? '${entry.title} · $episodeSubtitle'
            : entry.title,
        fileId: specificFileId,
      );
      return;
    }

    if (!entry.isTv) {
      final leadId = state.activeTrackFile?.id ??
          ref.read(detailControllerProvider(_key).notifier).leadFileId;
      if (leadId == null) {
        McToast.error('没有在位文件，无法缓存');
        return;
      }
      showOfflineDownloadSheet(
        context,
        title: entry.title,
        fileId: leadId,
      );
      return;
    }

    final seasonNum = state.selectedSeason;
    final seasonList = state.currentSeasonEpisodes;
    final choiceEps = <OfflineChoiceEpisode>[
      for (final e in seasonList)
        if (e.owned && e.playFileId != null)
          OfflineChoiceEpisode(
            season: e.seasonNumber,
            episode: e.episodeNumber,
            fileId: e.playFileId,
            played: e.played,
            local: _localStateFor(offline, e.playFileId!),
          ),
    ];
    if (choiceEps.isEmpty) {
      McToast.error('本季暂无可下载的在位文件');
      return;
    }
    final sel = state.selectedEpisode;
    final choices = OfflineDownloadChoices.make(
      episodes: choiceEps,
      selected: sel != null
          ? (season: sel.seasonNumber, episode: sel.episodeNumber)
          : null,
      selectedFile: state.activeTrackFile?.id ?? sel?.playFileId,
      multiSeason: entry.seasons.length > 1,
      season: seasonNum,
    );
    showOfflineDownloadSheet(
      context,
      title: entry.title,
      choices: choices,
    );
  }

  OfflineChoiceLocalState? _localStateFor(dynamic offlineState, int fileId) {
    final unit = offlineState.unitForFile(fileId) as DownloadUnit?;
    if (unit == null) return null;
    return unit.playable
        ? OfflineChoiceLocalState.done
        : OfflineChoiceLocalState.active;
  }

  Future<void> _deleteItem(DetailController controller) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final deleted = await showDeletePreviewSheet(
      context: context,
      controller: controller,
      title: entry?.title ?? '',
    );
    if (deleted != true || !mounted) return;
    McToast.success('条目已删除');
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _deleteSingleFile(
    DetailController controller,
    DetailFileInfo file,
  ) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final res = await showDeleteFileSheet(
      context: context,
      controller: controller,
      title: entry?.title ?? '',
      file: file,
    );
    if (res == null || !res.deleted || !mounted) return;
    if (res.wholeItemDeleted) {
      McToast.success('最后一个文件已删除，条目已移除');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      McToast.success('文件已删除');
      await controller.load(silent: true);
    }
  }

  Future<void> _restoreFile(
    DetailController controller,
    DetailFileInfo file,
  ) async {
    final err = await controller.restoreFile(file.id);
    if (!mounted) return;
    if (err != null) {
      McToast.error(err);
    } else {
      McToast.success('已恢复 ${file.fileName}');
    }
  }

  Future<void> _purgeFile(
    DetailController controller,
    DetailFileInfo file,
  ) async {
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('立即彻底清理「${file.fileName}」？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              file.purgeAfter == null
                  ? '将从磁盘永久删除该待回收文件，不可恢复。'
                  : '将提前永久清除回收站中的该文件并释放磁盘空间，不可恢复。',
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
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '彻底删除',
                    icon: McIcons.trash2,
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
    if (confirmed != true || !mounted) return;
    final err = await controller.purgeFile(file.id);
    if (!mounted) return;
    if (err != null) {
      McToast.error(err);
    } else {
      McToast.success('已彻底清理 ${file.fileName}');
    }
  }

  /// 演职员点击路由（对齐 iOS `CastLink.resolve`）：
  /// - 有 TMDB personId -> `/library/person/$id?name=...`
  /// - 本地 / NFO 库无 personId 的演员 -> `/library/detail/${entry.libraryId}?actor=...`
  void _openPerson(CastMember member) {
    final id = member.personId;
    if (id != null && id > 0) {
      context.push(
        '/library/person/$id?name=${Uri.encodeComponent(member.name)}',
      );
      return;
    }
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final trimmed = member.name.trim();
    if (entry != null &&
        entry.libraryId > 0 &&
        member.isActor &&
        trimmed.isNotEmpty) {
      context.push(
        '/library/detail/${entry.libraryId}?actor=${Uri.encodeComponent(trimmed)}',
      );
      return;
    }
    McToast.info('暂无「${member.name}」的关联作品');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Widget _buildStatusBanners(DetailEntry entry) {
    if (!entry.scraping) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: McTokens.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: McTokens.info.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: McTokens.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '正在刷新元数据'
                '${entry.scrapingPhase != null ? ' · ${entry.scrapingPhase}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(color: McTokens.info),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionZone(
    DetailState state,
    DetailController controller, {
    required bool wide,
  }) {
    final entry = state.entry!;
    final resume = state.resume;
    final hasProgress =
        resume != null && resume.positionMs > 0 && resume.durationMs > 0;
    final resumable = resume != null && resume.positionMs > 0;
    final progressRatio = hasProgress
        ? (resume.positionMs / resume.durationMs).clamp(0.02, 1.0)
        : 0.0;
    final remainMins = hasProgress
        ? ((resume.durationMs - resume.positionMs) / 60000).ceil().clamp(1, 9999)
        : 0;
    final isFav = state.marks.isFavorite;
    final isPlayed = (resume?.played ?? false) || state.marks.played;
    final playCount = resume?.playCount ?? 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!entry.isTv)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OfflineDownloadControl(
                mediaItemId: entry.id,
                title: entry.title,
                fileId: state.activeTrackFile?.id,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: McFocusRing(
                  borderRadius: McTokens.pillRadius,
                  child: McActionPill(
                    label: playButtonLabel(state),
                    icon: McIcons.play2Fill,
                    primary: true,
                    expanded: true,
                    height: 44,
                    onTap: () => _play(),
                  ),
                ),
              ),
              if (wide && resumable) ...[
                const SizedBox(width: 10),
                McFocusRing(
                  borderRadius: McTokens.pillRadius,
                  child: McActionPill(
                    label: '从头播放',
                    icon: McIcons.replay2,
                    primary: false,
                    height: 44,
                    onTap: () => _play(overrideStart: Duration.zero),
                  ),
                ),
              ],
            ],
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
          ] else if (isPlayed && !resumable && playCount > 1) ...[
            const SizedBox(height: 6),
            Text(
              '已累计观看 $playCount 次',
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: McText.micro.faint.tabular,
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
          _buildStatusBanners(entry),
        ],
      ),
    );
  }

  String _seasonLabel(DetailEntry entry, int seasonNum) {
    for (final s in entry.seasons) {
      if (s.number == seasonNum && s.name != null && s.name!.isNotEmpty) {
        return s.name!;
      }
    }
    return seasonNum == 0 ? '特别篇' : '第 $seasonNum 季';
  }

  Widget _buildTvSeasons(
    DetailEntry entry,
    DetailState state,
    DetailController controller,
    List<EpisodeEntry> episodes,
  ) {
    final perms = ref.watch(permissionsProvider);
    final schedule = state.currentAirSchedule;
    final ranges = EpisodeRangesHelper.buildRanges(episodes);
    final anchor = state.currentAnchorEpisode;
    final seasonNum = state.selectedSeason ?? 1;
    final seasonTitle = _seasonLabel(entry, seasonNum);

    int currentRangeIndex = _activeRangeIndex ?? 0;
    if (ranges.isNotEmpty) {
      final exists = ranges.any((r) => r.index == currentRangeIndex);
      if (!exists) {
        final seed = state.selectedEpisodeNumber ?? anchor;
        final matched = seed != null
            ? EpisodeRangesHelper.rangeContaining(seed, ranges)
            : null;
        currentRangeIndex = matched?.index ?? ranges.first.index;
      }
    }

    void openAirSheet() {
      if (schedule == null) return;
      showAirScheduleSheet(
        context: context,
        title: entry.title,
        seasonLabel: seasonTitle,
        episodes: episodes,
        schedule: schedule,
        canSubscribe: perms.canSubscribe,
        controller: controller,
        onSubscribe: perms.canSubscribe && (entry.tmdbId ?? 0) > 0
            ? () => _subscribe()
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        McSectionHeader(
          title: '剧集',
          countLabel: episodes.isNotEmpty
              ? '${episodes.where((e) => e.owned).length}/${episodes.length}'
              : null,
          trailingText: ranges.isNotEmpty
              ? '全部 ${episodes.length} 集'
              : (schedule != null ? '播出日历' : null),
          onTap: ranges.isNotEmpty
              ? () async {
                  final picked = await showEpisodeGridSheet(
                    context: context,
                    episodes: episodes,
                    ranges: ranges,
                    anchorEpisode: anchor,
                    selectedEpisode: state.selectedEpisodeNumber,
                  );
                  if (picked == null || !mounted) return;
                  setState(
                    () => _activeRangeIndex = EpisodeRangesHelper.indexOf(picked),
                  );
                  await controller.selectEpisode(seasonNum, picked);
                }
              : (schedule != null ? openAirSheet : null),
        ),
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
                  onTap: () {
                    setState(() => _activeRangeIndex = null);
                    controller.loadSeason(s.number);
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (schedule != null || state.airSchedule != null)
          AirSchedule(
            schedule: schedule,
            legacyBanner: state.airSchedule,
            episodes: episodes,
            onOpenSheet: schedule != null ? openAirSheet : null,
          ),
        if (ranges.isNotEmpty) ...[
          const SizedBox(height: 4),
          EpisodeRangeChips(
            ranges: ranges,
            currentIndex: currentRangeIndex,
            anchorEpisode: anchor,
            onSelect: (r) {
              setState(() => _activeRangeIndex = r.index);
              final targetEp = EpisodeRangesHelper.entryOf(r, anchor: anchor);
              controller.selectEpisode(seasonNum, targetEp);
            },
          ),
          const SizedBox(height: 6),
        ] else if (schedule == null)
          EpisodeRanges(episodes: episodes),
        if (state.episodesLoading && episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: McTokens.accent)),
          )
        else
          EpisodeList(
            mediaItemId: entry.id,
            episodes: episodes,
            selectedEpisodeNumber: state.selectedEpisodeNumber,
            anchorEpisode: anchor,
            airSchedule: schedule,
            activeRangeIndex: ranges.isNotEmpty ? currentRangeIndex : null,
            onRangeChanged: (r) {
              setState(() => _activeRangeIndex = r.index);
              final targetEp = EpisodeRangesHelper.entryOf(r, anchor: anchor);
              controller.selectEpisode(seasonNum, targetEp);
            },
            onEpisodeSelect: (ep) =>
                controller.selectEpisode(ep.seasonNumber, ep.episodeNumber),
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
              DetailFileInfo? epFile;
              for (final f in entry.files) {
                if (f.id == ep.playFileId) {
                  epFile = f;
                  break;
                }
              }
              showSubtitleGenSheet(
                context: context,
                controller: controller,
                fileId: ep.playFileId,
                file: epFile,
                label:
                    'S${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')}',
              );
            },
          ),
      ],
    );
  }

  Widget _buildRelatedAndFiles(
    DetailEntry entry,
    DetailState state,
    DetailController controller,
  ) {
    final perms = ref.watch(permissionsProvider);
    final unitFiles = state.currentUnitFiles;
    final ep = state.selectedEpisode;
    final localTitle = entry.isTv && ep != null
        ? '${entry.title} S${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')}'
        : entry.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.activeChapters.isNotEmpty || entry.chaptersPending)
          ChapterStripSection(
            chapters: state.activeChapters,
            pending: entry.chaptersPending,
            resumeMs: state.resume?.positionMs,
            onPlayFrom: (pos) => _play(overrideStart: pos),
          ),
        CastRow(
          cast: entry.cast,
          onPersonTap: _openPerson,
        ),
        SimilarRow(
          title: '相似推荐',
          entries: state.related.similar,
          onTap: (e) => context.push(
            '/detail/${e.libraryId > 0 ? e.libraryId : entry.libraryId}/${e.id}',
          ),
        ),
        if (state.related.series != null &&
            state.related.series!.parts.length > 1)
          SeriesSectionRow(
            series: state.related.series!,
            currentItemId: entry.id,
            onOwnedTap: (id) => context.push('/detail/${entry.libraryId}/$id'),
            onMissingTap: (part) => _subscribe(
              overrideTitleRef: 'tmdb:movie:${part.tmdbId}',
            ),
          )
        else if (state.related.seriesParts.length > 1)
          SimilarRow(
            title: '系列 · ${state.related.seriesName ?? ''}',
            entries: state.related.seriesParts,
            onTap: (e) => context.push('/detail/${entry.libraryId}/${e.id}'),
          ),
        LibraryFileSection(
          entry: entry,
          files: unitFiles,
          localTitle: localTitle,
          canManage: perms.canManageLibraries,
          onManageDuplicates: () =>
              context.push('/library/manage?tab=duplicates&item=${entry.id}'),
          onDeleteFile: (f) => _deleteSingleFile(controller, f),
          onRestoreFile: (f) => _restoreFile(controller, f),
          onPurgeFile: (f) => _purgeFile(controller, f),
        ),
        ExternalLinksBar(entry: entry),
      ],
    );
  }

  Widget _buildMetaAndTracks(
    DetailEntry entry,
    DetailState state,
    DetailController controller,
  ) {
    final unitFiles = state.currentUnitFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaLinks(
          entry: entry,
          showLegacyTracks: unitFiles.isEmpty,
          onSeriesTap: (id) => context.push('/library/collection/$id'),
          onCollectionTap: (name) {
            final cid = entry.collectionIds[name];
            if (cid != null) {
              context.push('/library/collection/$cid');
            } else {
              context.push('/library/collections');
            }
          },
        ),
        if (unitFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          MediaTrackSection(
            files: unitFiles,
            selectedFileId: state.selectedFileId,
            onSelectFile: controller.selectTrackFile,
            controller: controller,
          ),
        ],
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
              onRetry: () => ref
                  .read(detailControllerProvider(_key).notifier)
                  .load(
                    initialSeason: widget.initialSeason,
                    initialEpisode: widget.initialEpisode,
                  ),
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
    final episodes = state.currentSeasonEpisodes;
    final form = McFormWatch.of(context);
    final wide = form != McDeviceForm.phone;
    final plot = entry.isTv
        ? (state.selectedEpisode?.overview ?? entry.overview)
        : entry.overview;

    final Widget scrollBody = wide
        ? ListView(
            padding: const EdgeInsets.only(bottom: 52),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DetailHeader(
                entry: entry,
                selectedEpisode: state.selectedEpisode,
                activeFile: state.activeTrackFile,
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
                      width: 340,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActionZone(state, controller, wide: true),
                          const SizedBox(height: 16),
                          _buildMetaAndTracks(entry, state, controller),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (plot != null && plot.isNotEmpty)
                            _Overview(
                              text: plot,
                              expanded: state.overviewExpanded,
                              onToggle: controller.toggleOverview,
                            ),
                          if (entry.isTv)
                            _buildTvSeasons(entry, state, controller, episodes),
                          _buildRelatedAndFiles(entry, state, controller),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.only(bottom: 52),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DetailHeader(
                entry: entry,
                selectedEpisode: state.selectedEpisode,
                activeFile: state.activeTrackFile,
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
                child: Center(
                  child: _buildActionZone(state, controller, wide: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  McTokens.pagePadding,
                  14,
                  McTokens.pagePadding,
                  0,
                ),
                child: _buildMetaAndTracks(entry, state, controller),
              ),
              if (plot != null && plot.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    14,
                    McTokens.pagePadding,
                    0,
                  ),
                  child: _Overview(
                    text: plot,
                    expanded: state.overviewExpanded,
                    onToggle: controller.toggleOverview,
                  ),
                ),
              if (entry.isTv)
                _buildTvSeasons(entry, state, controller, episodes),
              _buildRelatedAndFiles(entry, state, controller),
            ],
          );

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
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
              onRefresh: () => controller.load(),
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    McGlassIconButton(
                      icon: McIcons.more,
                      tooltip: '更多操作',
                      onTap: () => _showActionMenu(controller),
                    ),
                    if (entry.scraping)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: McTokens.info,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
