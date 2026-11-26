import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_ambient.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';
import '../widgets/discovery_filter.dart';
import 'discover_filtered_page.dart';

/// 发现页（1:1 对齐 iOS `DiscoverView.swift` & Web 银玻璃发现页）：
/// - 顶栏：移除生硬 AppBar 与占高分段条，左上角直接展示 `30sp Bold` 可点击大标题菜单（`电影 / 剧集` + `TMDB / 豆瓣`），
///   右上角为液态玻璃「筛选」圆钮与「搜索」圆钮；
/// - 沉浸首屏：全出血 `McImmersiveHero` 直抵状态栏顶边 + 剧照主色 `McAmbientTopGlow` 氛围底色晕染；
/// - 筛选态：无缝切换至已选条件胶囊条 + 自适应海报墙网格。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  double _scrollOffset = 0;
  Color? _ambientTint;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    final notifier = ref.read(discoverProvider.notifier);
    final filtering = state.filtering;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!filtering)
            McAmbientTopGlow(
              tint: _ambientTint,
              scrollOffset: _scrollOffset,
            ),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                setState(() => _scrollOffset = n.metrics.pixels);
              }
              return false;
            },
            child: RefreshIndicator(
              edgeOffset: topPad + 56,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceSolid,
              onRefresh: notifier.pullRefresh,
              child: filtering
                  ? Padding(
                      padding: EdgeInsets.only(top: topPad + 58),
                      child: const DiscoverFilteredPage(),
                    )
                  : _DiscoverHomeBody(
                      state: state,
                      scrollOffset: _scrollOffset,
                      topBarClearance: topPad + 58,
                      onAmbientChanged: (c) {
                        if (mounted && c != _ambientTint) {
                          setState(() => _ambientTint = c);
                        }
                      },
                    ),
            ),
          ),
          // 顶部沉浸标题菜单 + 筛选/搜索液态玻璃圆钮（带柔和黑雾护字）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                McPageFog(height: topPad + 72),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    topPad + 6,
                    12,
                    8,
                  ),
                  child: Row(
                    children: [
                      _DiscoverTitleMenu(
                        mediaType: state.mediaType,
                        source: state.source,
                        onMediaTypeChanged: (v) {
                          setState(() => _ambientTint = null);
                          notifier.switchMediaType(v);
                        },
                        onSourceChanged: (v) {
                          setState(() => _ambientTint = null);
                          notifier.switchSource(v);
                        },
                      ),
                      const Spacer(),
                      if (state.source.toLowerCase() == 'tmdb')
                        PopupMenuButton<String>(
                          tooltip: '筛选',
                          onSelected: (dim) => _openFilterDim(dim, state),
                          itemBuilder: (_) => [
                            for (final key in discoveryDimKeys)
                              PopupMenuItem(
                                value: key,
                                child: Text(discoveryDimTitle(key)),
                              ),
                            if (filtering) ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: '__clear__',
                                child: Text(
                                  '清空筛选条件',
                                  style: TextStyle(color: McTokens.danger),
                                ),
                              ),
                            ],
                          ],
                          child: IgnorePointer(
                            child: McGlassIconButton(
                              icon: McIcons.filterS,
                              onTap: () {},
                              badgeColor: filtering ? McTokens.accentStrong : null,
                            ),
                          ),
                        ),
                      McGlassIconButton(
                        icon: McIcons.search,
                        tooltip: '搜索',
                        onTap: () => context.push(feat_discover.routeSearchEntry),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterDim(String key, DiscoverState state) {
    if (key == '__clear__') {
      ref.read(discoverProvider.notifier).applyFilters(const DiscoveryFilter());
      return;
    }
    showMcSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        child: DiscoveryFilterOptionsPanel(
          dimKey: key,
          filter: state.filters,
          mediaType: state.mediaType,
          onApply: (f) {
            Navigator.of(context).pop();
            ref.read(discoverProvider.notifier).applyFilters(f);
          },
        ),
      ),
    );
  }
}

/// 左上角大标题切换菜单（对齐 iOS `DiscoverView`：大字显示「电影 / 剧集」，小胶囊标注数据源 `TMDB / 豆瓣`）。
class _DiscoverTitleMenu extends StatelessWidget {
  const _DiscoverTitleMenu({
    required this.mediaType,
    required this.source,
    required this.onMediaTypeChanged,
    required this.onSourceChanged,
  });

  final String mediaType;
  final String source;
  final ValueChanged<String> onMediaTypeChanged;
  final ValueChanged<String> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final typeLabel = mediaType == 'tv' ? '剧集' : '电影';
    final sourceLabel = source == 'douban' ? '豆瓣' : 'TMDB';

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      onSelected: (v) {
        if (v == 'type:movie') onMediaTypeChanged('movie');
        if (v == 'type:tv') onMediaTypeChanged('tv');
        if (v == 'src:tmdb') onSourceChanged('tmdb');
        if (v == 'src:douban') onSourceChanged('douban');
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'type:movie',
          child: Row(
            children: [
              const Icon(McIcons.movie, size: 17),
              const SizedBox(width: 10),
              const Expanded(child: Text('电影')),
              if (mediaType != 'tv')
                const Icon(McIcons.check, size: 16, color: McTokens.accentStrong),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'type:tv',
          child: Row(
            children: [
              const Icon(McIcons.tv, size: 17),
              const SizedBox(width: 10),
              const Expanded(child: Text('剧集')),
              if (mediaType == 'tv')
                const Icon(McIcons.check, size: 16, color: McTokens.accentStrong),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'src:tmdb',
          child: Row(
            children: [
              const Expanded(child: Text('TMDB 数据源')),
              if (source != 'douban')
                const Icon(McIcons.check, size: 16, color: McTokens.accentStrong),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'src:douban',
          child: Row(
            children: [
              const Expanded(child: Text('豆瓣片单')),
              if (source == 'douban')
                const Icon(McIcons.check, size: 16, color: McTokens.accentStrong),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(typeLabel, style: McText.display),
          const SizedBox(width: 4),
          const Icon(
            McIcons.arrowDownS,
            size: 18,
            color: McTokens.textMuted,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x24FFFFFF),
              borderRadius: BorderRadius.circular(McTokens.pillRadius),
              border: Border.all(color: McTokens.lineStrong, width: 0.8),
            ),
            child: Text(
              sourceLabel,
              style: McText.micro.copyWith(color: McTokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverHomeBody extends ConsumerWidget {
  const _DiscoverHomeBody({
    required this.state,
    required this.scrollOffset,
    required this.topBarClearance,
    required this.onAmbientChanged,
  });

  final DiscoverState state;
  final double scrollOffset;
  final double topBarClearance;
  final ValueChanged<Color?> onAmbientChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.rows.isEmpty) {
      return const McFeedSkeleton(showHero: true);
    }
    if (state.error != null && state.rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: topBarClearance + 72),
          McErrorView(
            title: '发现内容暂时无法加载',
            text: state.error!,
            onRetry: () => ref.read(discoverProvider.notifier).load(),
          ),
        ],
      );
    }

    DiscoverRowData? heroRow;
    final shelfRows = <DiscoverRowData>[];
    for (final r in state.rows) {
      if (heroRow == null && r.presentation == 'hero' && r.titles.isNotEmpty) {
        heroRow = r;
      } else if (r.titles.isNotEmpty) {
        shelfRows.add(r);
      }
    }
    // 若后端未单独下发 hero 行（如豆瓣视角），取第一排前 5 部升格为沉浸 Hero
    if (heroRow == null && shelfRows.isNotEmpty) {
      heroRow = DiscoverRowData(
        collectionRef: shelfRows.first.collectionRef,
        title: shelfRows.first.title,
        presentation: 'hero',
        titles: shelfRows.first.titles.take(5).toList(),
      );
    }

    final heroItems = (heroRow?.titles ?? const []).take(6).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: McTokens.bottomBarClearance),
      children: [
        if (heroItems.isNotEmpty)
          McImmersiveHero(
            height: 480,
            scrollOffset: scrollOffset,
            itemCount: heroItems.length,
            imageUrlOf: (i) => heroItems[i].posterUrl,
            onAmbientColorChanged: onAmbientChanged,
            onTapSlide: (i) => feat_discover.pushTitle(context, heroItems[i].ref),
            foregroundBuilder: (context, i) {
              final t = heroItems[i];
              final metaParts = <String>[
                if (t.year != null) '${t.year}',
                if ((t.rating ?? 0) > 0) '★ ${t.rating!.toStringAsFixed(1)}',
                if (t.genres.isNotEmpty) t.genres.take(2).join(' · '),
              ];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: McText.fontFamily,
                      fontFamilyFallback: McText.fontFallback,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                      color: McTokens.text,
                    ),
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (t.owned) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: McTokens.ok,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            [
                              if (t.owned) '在库',
                              ...metaParts,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.sub.copyWith(
                              color: const Color(0xD9F3F5F9),
                              fontWeight: FontWeight.w500,
                            ).tabular,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  McActionPill(
                    label: t.owned ? '查看影片' : '了解详情',
                    icon: t.owned ? McIcons.playFill : McIcons.film,
                    primary: true,
                    onTap: () => feat_discover.pushTitle(context, t.ref),
                  ),
                ],
              );
            },
          )
        else
          SizedBox(height: topBarClearance),
        for (final row in shelfRows) _DiscoverSectionShelf(row: row),
      ],
    );
  }
}

class _DiscoverSectionShelf extends StatelessWidget {
  const _DiscoverSectionShelf({required this.row});

  final DiscoverRowData row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(title: row.title),
          const SizedBox(height: 12),
          SizedBox(
            height: 234,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: row.titles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final t = row.titles[i];
                return McFocusRing(
                  borderRadius: McTokens.posterRadius,
                  child: McPosterCard(
                    title: t.title,
                    posterUrl: t.posterUrl,
                    width: 122,
                    subtitle: [
                      if (t.year != null) '${t.year}',
                      if (t.genres.isNotEmpty) t.genres.first,
                    ].join(' · '),
                    rating: (t.rating ?? 0) > 0 ? t.rating : null,
                    badge: t.owned ? '在库' : null,
                    badgeDotColor: t.owned ? McTokens.ok : null,
                    onTap: () => feat_discover.pushTitle(context, t.ref),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
