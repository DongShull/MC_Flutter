import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  void _play({int? season, int? episode}) {
    // TODO(player): 播放决策（流选择 / 预检 / 起播）在 player 域完成，这里只传导航意图。
    context.push('/player', extra: {
      'libraryId': widget.libraryId,
      'itemId': widget.itemId,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
    });
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
        // TODO(subscriptions): 走订阅创建弹层（title-preview → 季勾选 → POST /subscriptions），
        // 已订阅时入口变「管理订阅」；这里先跳订阅列表占位。
        context.push('/subscriptions');
      case ItemAction.download:
        // TODO(offline): 离线下载（OfflineDownloadControl）由 offline 域完成。
        _toast('离线下载暂未接入');
      case ItemAction.share:
        // TODO(share): 分享链接由 share 域完成。
        _toast('分享暂未接入');
      case ItemAction.subtitleGen:
        // TODO(activity): AI 字幕生成走任务域（预检 + 任务轮询）。
        _toast('字幕生成暂未接入');
      case ItemAction.refreshMetadata:
        final err = await controller.refreshMetadata();
        if (mounted) _toast(err ?? '已提交刷新任务');
      case ItemAction.delete:
        // TODO(offline/library): 删除确认与预览由管理侧完成。
        _toast('删除暂未接入');
    }
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

    return Scaffold(
      backgroundColor: McColors.bgDark,
      body: RefreshIndicator(
        onRefresh: () => controller.load(),
        child: ListView(
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
                    child: FilledButton.icon(
                      onPressed: () => _play(
                        season: state.resume?.season ?? state.selectedSeason,
                        episode: state.resume?.episode ?? entry.resumeEpisode,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(playButtonLabel(state)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: '收藏',
                    onPressed: state.busy ? null : controller.toggleFavorite,
                    icon: Icon(
                      state.marks.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: state.marks.isFavorite ? Colors.redAccent : null,
                    ),
                  ),
                  IconButton(
                    tooltip: '已看',
                    onPressed: state.busy ? null : controller.togglePlayed,
                    icon: Icon(
                      state.marks.played ? Icons.check_circle : Icons.check_circle_outline,
                      color: state.marks.played ? Colors.green : null,
                    ),
                  ),
                  IconButton(
                    tooltip: '更多',
                    onPressed: () => _showActionMenu(controller),
                    icon: const Icon(Icons.more_horiz),
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
              onPersonTap: (member) {
                // TODO(library): 人物页（library_person_page）由 library 域提供，先占位提示。
                _toast('人物页：${member.name}');
              },
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
                onEpisodeTap: (e) => _play(season: e.seasonNumber, episode: e.episodeNumber),
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
