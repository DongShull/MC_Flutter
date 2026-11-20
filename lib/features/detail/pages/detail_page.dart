import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
// offline 域下载能力（任务明确授权的跨 feature import：只调公开 API，不改 offline 内部）。
import '../../offline/pages/profile_sheet.dart';
import '../../offline/state/models.dart';
import '../../../core/player/player_page_args.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';
import '../widgets/air_schedule.dart';
import '../widgets/cast_row.dart';
import '../widgets/detail_header.dart';
import '../widgets/episode_list.dart';
import '../widgets/episode_ranges.dart';
import '../widgets/item_actions_menu.dart';
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
    final action = await showItemActionsMenu(context);
    if (action == null || !mounted) return;
    switch (action) {
      case ItemAction.subscribe:
        _subscribe();
      case ItemAction.download:
        _download();
      case ItemAction.share:
        _share(controller);
      case ItemAction.subtitleGen:
        _subtitleGen(controller);
      case ItemAction.refreshMetadata:
        final err = await controller.refreshMetadata();
        if (mounted) _toast(err ?? '已提交刷新任务');
      case ItemAction.delete:
        _delete(controller);
    }
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

  /// 离线下载：拼好下载候选（文件 + 档位）交给 offline 域的选档面板，
  /// 之后的会话协商与字节搬运都在 offline 域完成。
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
    // 档位 id 即播放会话 tier（original = 原文件直下，其余服务器转码导出）。
    const profiles = [
      DownloadProfile(id: 'original', label: '原画', isOriginal: true),
      DownloadProfile(id: '1080p', label: '1080P', isOriginal: false, transcode: true),
      DownloadProfile(id: '720p', label: '720P', isOriginal: false, transcode: true),
      DownloadProfile(id: '480p', label: '480P', isOriginal: false, transcode: true),
    ];
    showDownloadProfileSheet(
      context,
      candidate: DownloadCandidate(
        fileId: fileId.toString(),
        title: entry.title,
        scopes: entry.isTv ? const ['本片', '全季'] : const ['本片'],
        profiles: profiles,
      ),
    );
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

  /// AI 字幕生成：预检 + 提交任务（见 DetailController.startSubtitleGen）。
  Future<void> _subtitleGen(DetailController controller) async {
    _toast('正在预检…');
    final message = await controller.startSubtitleGen();
    if (mounted) _toast(message);
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
              child: MetaLinks(entry: entry),
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
                              MetaLinks(entry: entry),
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
