import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/api/api_exception.dart';
// models.dart 也有同名 CastMember：此处隐藏它，页面用的 CastMember
// 来自 detail_controller（与 DetailEntry.cast 的类型一致）。
import '../../../core/api/models.dart' hide CastMember;
import '../../../core/player/player_page_args.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../library/routes.dart' as feat_library;
import '../../offline/state/models.dart';
import '../../offline/state/offline_state.dart';
import '../routes.dart' as feat_detail;
import '../state/detail_controller.dart';
import '../widgets/add_to_collection_sheet.dart';
import '../widgets/air_schedule.dart';
import '../widgets/cast_row.dart';
import '../widgets/chapters_subtitles.dart';
import '../widgets/detail_header.dart';
import '../widgets/episode_list.dart';
import '../widgets/episode_ranges.dart';
import '../widgets/files_section.dart';
import '../widgets/item_actions_menu.dart';
import '../widgets/item_download_host.dart';
import '../widgets/item_manage_sheets.dart';
import '../widgets/meta_links.dart';
import '../widgets/similar_row.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 媒体详情页（对齐 ItemDetailScreen.kt / 设计文档 04 第 4 节）：
/// 头部 / 动作区 / 元信息行 / 简介 / 演职员 / 剧集（季选择 + 分集 + 缺集 + 档期）/
/// 系列与相似推荐 / 订阅入口。播放只做导航意图，不自己播视频。
class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({super.key, this.libraryId = -1, this.itemId = -1});

  final int libraryId;
  final int itemId;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  late final String _key = '${widget.libraryId}:${widget.itemId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detailControllerProvider(_key).notifier).load();
    });
  }

  /// 播放导航（选集数据接口化）：只传 mediaItemId + fileId（选集接口数据来），
  /// 不再手传 season/episode。TV 入口先按接口分集数据解析出起播集。
  void _playEpisode(EpisodeEntry e) {
    if (!e.owned || e.fileIds.isEmpty) {
      _toast('第 ${e.episodeNumber} 集缺文件，无法播放');
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
      // TV：优先服务端续播锚点，其次当前季第一个可播集（全部由接口分集数据解析）。
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
        _toast('该集暂无在位文件，无法播放');
        return;
      }
      _pushPlayer(
        fileId: target.fileIds.first,
        title: '第 ${target.seasonNumber} 季第 ${target.episodeNumber} 集',
        subtitle: target.name,
        startPosition:
            (resume?.positionMs ?? target.resumeMs) > 0
                ? Duration(milliseconds: resume?.positionMs ?? target.resumeMs)
                : null,
        resumeSeason: target.seasonNumber,
        resumeEpisode: target.episodeNumber,
      );
      return;
    }
    _pushPlayer(); // 电影：整条一个 mediaItemId，fileId 交由会话协商解析。
  }

  void _pushPlayer({
    int? fileId,
    String? title,
    String? subtitle,
    Duration? startPosition,
    int? resumeSeason,
    int? resumeEpisode,
  }) {
    // 播放决策（流选择 / 预检 / 起播）在 player 域完成，这里只传导航意图。
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: widget.itemId,
        fileId: fileId,
        title: entry?.title,
        subtitle: subtitle ?? title,
        startPosition: startPosition,
        isEpisode: entry?.isTv ?? false,
        seasons: [for (final s in entry?.seasons ?? const <SeasonInfo>[]) s.number],
        episodes: [
          for (final seasonEntry in state.episodes.entries)
            for (final e in seasonEntry.value)
              EpisodeItem(
                season: e.seasonNumber,
                episode: e.episodeNumber,
                name: e.name,
              ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showActionMenu(DetailController controller) async {
    // 本条目在下任务（offline id 形如 dl-{fileId}-…，按文件 id 前缀匹配）。
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final fileIds = <int>{
      if (entry != null) ...entry.fileIds,
      if (entry != null)
        for (final list in ref
            .read(detailControllerProvider(_key))
            .episodes
            .values)
          for (final e in list) ...e.fileIds,
    };
    final offline = ref.read(offlineProvider);
    final active = offline.units
        .where((u) =>
            u.isActive &&
            fileIds.any((id) => u.id.startsWith('dl-$id-')))
        .toList();
    final otherActive = offline.units
        .where((u) =>
            u.isActive &&
            !fileIds.any((id) => u.id.startsWith('dl-$id-')))
        .isNotEmpty;
    final entries = itemMenuEntries(ItemMenuInput(
      activeDownloads: active.length,
      otherQueuedDownloads: otherActive,
      isTv: entry?.isTv ?? false,
    ));
    final action = await showItemActionsMenu(
      context,
      entries: entries,
      cancelLabel:
          active.length > 1 ? '取消下载（${active.length} 个）' : null,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ItemAction.subscribe:
        _subscribe();
      case ItemAction.prioritizeDownloads:
        _prioritizeDownloads(active);
      case ItemAction.cancelSelectedDownload:
      case ItemAction.cancelDownloads:
        _cancelDownloads(active);
      case ItemAction.download:
        _download();
      case ItemAction.searchResources:
        _searchResources();
      case ItemAction.share:
        _share(controller);
      case ItemAction.subtitleGen:
        _openSubtitleGen();
      case ItemAction.addToCollection:
        _addToCollection();
      case ItemAction.reidentify:
        _reidentify(controller);
      case ItemAction.refreshMetadata:
        final err = await controller.refreshMetadata();
        if (mounted) _toast(err ?? '已提交刷新任务');
      case ItemAction.artwork:
        _artwork(controller);
      case ItemAction.transfer:
        _transfer(controller);
      case ItemAction.delete:
        _delete(controller);
      case ItemAction.clearHistory:
        _clearHistory(controller);
    }
  }

  /// 搜资源：跳搜索页资源模式，默认以条目标题为关键词。
  void _searchResources() {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    if (entry == null) return;
    context.push(
        '/search?mode=torrents&q=${Uri.encodeComponent(entry.title)}');
  }

  /// 更换图片：候选弹层（海报 / 背景 / Logo），选后重拉详情。
  Future<void> _artwork(DetailController controller) async {
    await showArtworkPickerSheet(
      context,
      controller: controller,
      onChanged: () => controller.load(),
    );
  }

  /// 转移到其他库：目标库选择 + 预检确认，成功后返回上级（条目已不在本库）。
  Future<void> _transfer(DetailController controller) async {
    await showTransferSheet(
      context,
      controller: controller,
      currentLibraryId: widget.libraryId,
      onTransferred: () {
        if (mounted && context.canPop()) context.pop();
      },
    );
  }

  /// 清除观看记录：确认框 → DELETE → 刷新（续播点随之清掉）。
  Future<void> _clearHistory(DetailController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除观看记录'),
        content: const Text('将清除本条目的观看记录与续播点，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await controller.clearWatchHistory();
    if (!mounted) return;
    _toast(err ?? '观看记录已清除');
    if (err == null) await controller.load();
  }

  /// 取消本条目全部在下任务（逐个取消 offline 任务）。
  Future<void> _cancelDownloads(
      List<DownloadUnit> active) async {
    final offline = ref.read(offlineProvider.notifier);
    for (final unit in active) {
      await offline.cancel(unit);
    }
    if (mounted) _toast('已取消 ${active.length} 个下载');
  }

  /// 优先下载：把本条目在下任务的优先级提到最高（offline 的
  /// `prioritize` 取当前最大 priority +1；安卓 `canPrioritizeShow`
  /// 的精确语义见 itemMenuEntries 注释，此处为近似口径）。
  void _prioritizeDownloads(List<DownloadUnit> active) {
    if (active.isEmpty) return;
    final offline = ref.read(offlineProvider.notifier);
    for (final unit in active) {
      offline.prioritize(unit);
    }
    _toast('已优先下载本条目');
  }

  /// 当前季的文件（电影 = 全部；剧集 = 按选中季过滤；详情接口不回
  /// files 时为空，文件区不显示）。
  List<DetailFile> _filesForSelectedSeason(DetailState state) {
    final entry = state.entry;
    if (entry == null || entry.files.isEmpty) return const [];
    if (!entry.isTv) return entry.files;
    final season = state.selectedSeason;
    if (season == null) return entry.files;
    return entry.files.where((f) => f.seasonNumber == season).toList();
  }

  /// 删除文件：确认框 → DELETE → 重拉详情。
  Future<void> _deleteFile(
      DetailController controller, DetailFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除「${file.fileName}」吗？\n'
            '只删除该文件，条目本身保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await controller.deleteFile(file.id);
    if (!mounted) return;
    _toast(err ?? '文件已删除');
    if (err == null) await controller.load();
  }

  /// 订阅弹层（title-preview → 季勾选 → POST /subscriptions）；
  /// 已订阅时弹层转「管理订阅」。ref 形如 tmdb:movie:123。
  Future<void> _subscribe() async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final tmdbId = entry?.tmdbId;
    if (tmdbId == null) {
      _toast('该条目没有 TMDB 标识，暂不能订阅');
      return;
    }
    final refStr = 'tmdb:${entry!.isTv ? 'tv' : 'movie'}:$tmdbId';
    final outcome = await showSubscribeSheet(context, ref, titleRef: refStr);
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case SubscribeSheetOutcome.created:
        _toast('订阅成功');
      case SubscribeSheetOutcome.managed:
        context.push('/subscriptions');
    }
  }

  /// 离线下载（下载宿主 ItemDownloadHost：电影 = 单文件选档；
  /// 剧集 = 按当前季选范围逐集下载；分集长按走同一宿主的单文件档）。
  void _download() {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    final fileId =
        ref.read(detailControllerProvider(_key).notifier).leadFileId;
    if (fileId == null) {
      _toast('没有在位文件，无法下载');
      return;
    }
    showItemDownloadSheet(
      context,
      detail: entry,
      episodes: state.episodes,
      selectedSeason: state.selectedSeason,
      target: entry.isTv
          ? SeriesDownloadTarget(title: entry.title)
          : FileDownloadTarget(fileId: fileId, title: entry.title),
    );
  }

  /// 分集长按：下载这一集（对照安卓分集长按菜单「下载这一集」）。
  void _downloadEpisode(EpisodeEntry e) {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    if (entry == null) return;
    if (!e.owned || e.fileIds.isEmpty) {
      _toast('第 ${e.episodeNumber} 集缺文件，无法下载');
      return;
    }
    showItemDownloadSheet(
      context,
      detail: entry,
      episodes: state.episodes,
      selectedSeason: state.selectedSeason,
      selectedEpisode: e,
      target: FileDownloadTarget(
        fileId: e.fileIds.first,
        title: '第 ${e.seasonNumber} 季第 ${e.episodeNumber} 集 ${e.name}',
      ),
    );
  }

  /// AI 字幕生成：进字幕生成页（预检 + 提交全在页内走类型化 McApi）。
  void _openSubtitleGen() {
    final state = ref.read(detailControllerProvider(_key));
    final entry = state.entry;
    final fileId =
        ref.read(detailControllerProvider(_key).notifier).leadFileId;
    if (entry == null || fileId == null) {
      _toast('没有在位文件，无法生成字幕');
      return;
    }
    context.push(
      feat_detail.routeDetailSubtitles(
        widget.libraryId,
        widget.itemId,
        fileId,
        entry.title,
      ),
    );
  }

  /// 加入合集：合集弹层（列合集 / 新建 / 加条目，全走类型化 McApi）。
  Future<void> _addToCollection() async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    if (entry == null) return;
    final added = await showAddToCollectionSheet(
      context,
      mediaItemId: widget.itemId,
      title: entry.title,
    );
    if (mounted && added == true) _toast('已加入合集');
  }

  /// 重新识别：预检 → 确认框（当前条目 / 候选分组）→ 执行 → 有变化重载详情。
  Future<void> _reidentify(DetailController controller) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    if (entry == null) return;
    _toast('正在预检…');
    late final ReidentifyPreviewView preview;
    try {
      preview = await controller.reidentifyPreview();
    } on ApiException catch (e) {
      if (mounted) _toast(e.friendlyMessage);
      return;
    } catch (e) {
      if (mounted) _toast('预检失败：$e');
      return;
    }
    if (!mounted) return;
    final groups = preview.groups;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新识别'),
        content: Text(
          [
            '当前：${preview.current.title}'
                '${preview.current.year == null ? '' : ' (${preview.current.year})'}',
            if (preview.pinnedIdentity) '已锁定身份，将按锁定身份重新识别。',
            if (groups.isEmpty)
              '未发现新的识别候选，将按现有线索重新识别。'
            else
              '发现 ${groups.length} 组候选文件（共 ${groups.fold(0, (s, g) => s + g.fileCount)} 个文件），将重新匹配识别。',
            if (preview.skippedMissing > 0)
              '其中 ${preview.skippedMissing} 个文件已缺失，将跳过。',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('开始识别'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _toast('正在重新识别…');
    final message = await controller.reidentify();
    if (mounted) _toast(message);
  }

  /// 系统分享：先建一条服务端分享链接（POST …/share，7 天有效），再交给 share_plus。
  Future<void> _share(DetailController controller) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final err = StringBuffer();
    final url = await controller.createShareLink(err: err);
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      _toast('分享失败：${err.isEmpty ? '未知错误' : err}');
      return;
    }
    await Share.share(url, subject: entry?.title);
  }

  /// 删除：确认框 → DELETE → 成功返回上级。
  Future<void> _delete(DetailController controller) async {
    final entry = ref.read(detailControllerProvider(_key)).entry;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要删除「${entry?.title}」吗？该操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await controller.deleteItem();
    if (!mounted) return;
    if (err != null) {
      _toast(err);
      return;
    }
    _toast('已删除');
    if (context.canPop()) context.pop();
  }

  /// 系列行点进合集详情；合集行点进合集列表（合集名只有文字、无 id，
  /// 详情接口不回合集 id，故不直跳单个合集）。
  void _openSeries(int collectionId) {
    context.push(feat_library.routeLibraryCollection(collectionId));
  }

  void _openCollections() {
    context.push(feat_library.routeLibraryCollections);
  }

  /// 人物页（discover 域 /discover/person，TMDB id 路由参数；跨 feature 只走路由）。
  void _openPerson(CastMember member) {
    final id = member.personId;
    if (id == null || id <= 0) {
      _toast('暂无「${member.name}」的人物信息');
      return;
    }
    context.push('/discover/person?id=$id');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailControllerProvider(_key));
    if (state.loading && state.entry == null) {
      return const Scaffold(body: McLoadingView());
    }
    if (state.error != null && state.entry == null) {
      return Scaffold(
        body: McErrorView(
          text: state.error!,
          onRetry: () => ref.read(detailControllerProvider(_key).notifier).load(),
        ),
      );
    }
    final entry = state.entry;
    if (entry == null) return const Scaffold(body: SizedBox.shrink());
    final controller = ref.read(detailControllerProvider(_key).notifier);
    final episodes = state.episodes[state.selectedSeason] ?? const <EpisodeEntry>[];
    final form = McFormWatch.of(context);

    return Scaffold(
      backgroundColor: McColors.bgDark,
      body: RefreshIndicator(
        onRefresh: () => controller.load(),
        // 手机保持现单列布局；平板/TV 双栏（左操作/元信息，右简介/季集/相似）。
        child: form == McDeviceForm.phone
            ? ListView(
          padding: EdgeInsets.zero,
          children: [
            DetailHeader(entry: entry, onBack: () => context.pop()),
            // —— 动作区：播放/续播、收藏、已看、更多 ——
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: McFocusRing(
                      borderRadius: 20,
                      child: FilledButton.icon(
                      onPressed: _play,
                        icon: const Icon(McIcons.play2Fill),
                        label: Text(playButtonLabel(state)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  McFocusRing(
                    borderRadius: 20,
                    child: IconButton(
                      tooltip: '收藏',
                      onPressed: state.busy ? null : controller.toggleFavorite,
                      icon: Icon(
                        state.marks.isFavorite ? McIcons.heart2Fill : McIcons.heart2,
                        color: state.marks.isFavorite ? Colors.redAccent : null,
                      ),
                    ),
                  ),
                  McFocusRing(
                    borderRadius: 20,
                    child: IconButton(
                      tooltip: '已看',
                      onPressed: state.busy ? null : controller.togglePlayed,
                      icon: Icon(
                        state.marks.played ? McIcons.checkCircleFill : McIcons.checkCircle,
                        color: state.marks.played ? Colors.green : null,
                      ),
                    ),
                  ),
                  McFocusRing(
                    borderRadius: 20,
                    child: IconButton(
                      tooltip: '更多',
                      onPressed: () => _showActionMenu(controller),
                      icon: const Icon(McIcons.moreFill),
                    ),
                  ),
                ],
              ),
            ),
            // —— 元信息行组：音轨 / 字幕 / 系列 / 合集 ——
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: MetaLinks(
                entry: entry,
                onSeriesTap: _openSeries,
                onCollectionTap: (_) => _openCollections(),
              ),
            ),
            // —— 简介区（可展开）——
            if (entry.overview != null && entry.overview!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _Overview(
                  text: entry.overview!,
                  expanded: state.overviewExpanded,
                  onToggle: controller.toggleOverview,
                ),
              ),
            // —— 演职员横滚（cast 前 40，人物卡点进人物页）——
            CastRow(
              cast: entry.cast,
              onPersonTap: _openPerson,
            ),
            // —— 章节 / 字幕：字幕轨 + 生成入口 + 章节预览图 ——
            ChaptersSubtitlesSection(
              subtitleTracks: entry.subtitleTracks,
              trickplay: state.trickplay,
              trickplayLoading: state.trickplayLoading,
              regeneratingChapters: state.regeneratingChapters,
              onGenerateSubtitle: _openSubtitleGen,
              onRegenerateChapters: () async {
                final message = await controller.regenerateChapters();
                if (mounted) _toast(message);
              },
            ),
            // —— 文件区（电影 = 全部文件；剧集 = 当前季文件）——
            FilesSection(
              files: _filesForSelectedSeason(state),
              onDelete: (file) => _deleteFile(controller, file),
            ),
            // —— 剧集区 ——
            if (entry.isTv) ...[
              if (state.airSchedule != null) AirSchedule(schedule: state.airSchedule!),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('剧集',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              // 季选择器
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final s in entry.seasons)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.name ?? '第 ${s.number} 季'),
                          selected: state.selectedSeason == s.number,
                          onSelected: (_) => controller.loadSeason(s.number),
                        ),
                      ),
                  ],
                ),
              ),
              EpisodeRanges(episodes: episodes),
              EpisodeList(
                episodes: episodes,
                onEpisodeTap: _playEpisode,
                onEpisodeLongPress: _downloadEpisode,
              ),
            ],
            // —— 系列一行（按上映顺序列全，有这一行时相似推荐已排除同系列）——
            if (state.related.seriesParts.length > 1)
              SimilarRow(
                title: '系列 · ${state.related.seriesName ?? ''}',
                entries: state.related.seriesParts,
                onTap: (e) => context.push('/detail/${entry.libraryId}/${e.id}'),
              ),
            // —— 相似推荐 ——
            SimilarRow(
              title: '相似推荐',
              entries: state.related.similar,
              onTap: (e) => context.push('/detail/${entry.libraryId}/${e.id}'),
            ),
            const SizedBox(height: 32),
          ],
        )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  DetailHeader(entry: entry, onBack: () => context.pop()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左列：操作区 + 元信息
                        SizedBox(
                          width: 300,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              McFocusRing(
                                borderRadius: 20,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _play,
                                    icon: const Icon(McIcons.play2Fill),
                                    label: Text(playButtonLabel(state)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  McFocusRing(
                                    borderRadius: 20,
                                    child: IconButton(
                                      tooltip: '收藏',
                                      onPressed: state.busy
                                          ? null
                                          : controller.toggleFavorite,
                                      icon: Icon(
                                        state.marks.isFavorite
                                            ? McIcons.heart2Fill
                                            : McIcons.heart2,
                                        color: state.marks.isFavorite
                                            ? Colors.redAccent
                                            : null,
                                      ),
                                    ),
                                  ),
                                  McFocusRing(
                                    borderRadius: 20,
                                    child: IconButton(
                                      tooltip: '已看',
                                      onPressed: state.busy
                                          ? null
                                          : controller.togglePlayed,
                                      icon: Icon(
                                        state.marks.played
                                            ? McIcons.checkCircleFill
                                            : McIcons.checkCircle,
                                        color: state.marks.played
                                            ? Colors.green
                                            : null,
                                      ),
                                    ),
                                  ),
                                  McFocusRing(
                                    borderRadius: 20,
                                    child: IconButton(
                                      tooltip: '更多',
                                      onPressed: () =>
                                          _showActionMenu(controller),
                                      icon: const Icon(McIcons.moreFill),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              MetaLinks(
                                entry: entry,
                                onSeriesTap: _openSeries,
                                onCollectionTap: (_) => _openCollections(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // 右列：简介 / 演职员 / 剧集（季+集） / 系列 / 相似
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.overview != null &&
                                  entry.overview!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _Overview(
                                    text: entry.overview!,
                                    expanded: state.overviewExpanded,
                                    onToggle: controller.toggleOverview,
                                  ),
                                ),
                              CastRow(
                                cast: entry.cast,
                                onPersonTap: _openPerson,
                              ),
                              // —— 章节 / 字幕：字幕轨 + 生成入口 + 章节预览图 ——
                              ChaptersSubtitlesSection(
                                subtitleTracks: entry.subtitleTracks,
                                trickplay: state.trickplay,
                                trickplayLoading: state.trickplayLoading,
                                regeneratingChapters:
                                    state.regeneratingChapters,
                                onGenerateSubtitle: _openSubtitleGen,
                                onRegenerateChapters: () async {
                                  final message =
                                      await controller.regenerateChapters();
                                  if (mounted) _toast(message);
                                },
                              ),
                              // —— 文件区（电影 = 全部文件；剧集 = 当前季文件）——
                              FilesSection(
                                files: _filesForSelectedSeason(state),
                                onDelete: (file) =>
                                    _deleteFile(controller, file),
                              ),
                              if (entry.isTv) ...[
                                if (state.airSchedule != null)
                                  AirSchedule(schedule: state.airSchedule!),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                  child: Text('剧集',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(
                                  height: 40,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    children: [
                                      for (final s in entry.seasons)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(
                                                s.name ?? '第 ${s.number} 季'),
                                            selected: state.selectedSeason ==
                                                s.number,
                                            onSelected: (_) =>
                                                controller.loadSeason(s.number),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                EpisodeRanges(episodes: episodes),
                                EpisodeList(
                                  episodes: episodes,
                                  onEpisodeTap: _playEpisode,
                                  onEpisodeLongPress: _downloadEpisode,
                                ),
                              ],
                              if (state.related.seriesParts.length > 1)
                                SimilarRow(
                                  title:
                                      '系列 · ${state.related.seriesName ?? ''}',
                                  entries: state.related.seriesParts,
                                  onTap: (e) => context
                                      .push('/detail/${entry.libraryId}/${e.id}'),
                                ),
                              SimilarRow(
                                title: '相似推荐',
                                entries: state.related.similar,
                                onTap: (e) => context
                                    .push('/detail/${entry.libraryId}/${e.id}'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.text, required this.expanded, required this.onToggle});

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Text(
        text,
        maxLines: expanded ? null : 3,
        overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white70, height: 1.4),
      ),
    );
  }
}
