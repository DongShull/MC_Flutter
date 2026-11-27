import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_ambient.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/permissions.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';
import '../widgets/discovery_filter.dart';
import 'discover_filtered_page.dart';

/// 发现页（1:1 对齐 iOS `DiscoverView.swift`）：
/// - 4 视角内存缓存 + `PageSnapshots` 磁盘冷启动快照，切类型/数据源即时恢复不白屏；
/// - 沉浸 Hero 强制使用 `backdrop_url`（TMDB `w1280` 升级 `original` 经代理按需缩放）；
/// - 每个片单行支持「查看全部 ›」直达 `DiscoverCollectionPage`；
/// - 电影 × TMDB 底部挂载 `DiscoverRegionFooter`（管理员可就地切换院线地区并刷新全部视角）；
/// - 识别 `UPSTREAM_UNREACHABLE` 错误码并提取 `details[0].hint`，展示代理诊断与超管「前往网络设置」入口。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
  Color? _ambientTint;

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
  }

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
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (_, offset, __) => McAmbientTopGlow(
                tint: _ambientTint,
                scrollOffset: offset,
              ),
            ),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                _scrollOffset.value = n.metrics.pixels;
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
                      scrollOffsetListenable: _scrollOffset,
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
                          HapticFeedback.selectionClick();
                          setState(() => _ambientTint = null);
                          notifier.switchMediaType(v);
                        },
                        onSourceChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _ambientTint = null);
                          notifier.switchSource(v);
                        },
                      ),
                      const Spacer(),
                      if (state.source.toLowerCase() == 'tmdb') ...[
                        PopupMenuButton<String>(
                          tooltip: '筛选',
                          onSelected: (dim) {
                            HapticFeedback.selectionClick();
                            _openFilterDim(dim, state);
                          },
                          itemBuilder: (_) => [
                            for (final key in discoveryDimKeys)
                              PopupMenuItem(
                                value: key,
                                child: Row(
                                  children: [
                                    Icon(
                                      discoveryDimIcon(key),
                                      size: 16,
                                      color: McTokens.textMuted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        discoveryDimTitle(
                                          key,
                                          mediaType: state.mediaType,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      dimValue(
                                        key,
                                        state.filters,
                                        state.mediaType,
                                        genreNames: state.genreNameMap,
                                      ),
                                      style: McText.caption.faint,
                                    ),
                                  ],
                                ),
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
                              badgeColor:
                                  filtering ? McTokens.accentStrong : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      McGlassIconButton(
                        icon: McIcons.search,
                        tooltip: '搜索',
                        onTap: () => context.push(
                          '${feat_discover.routeSearchEntry}?tab=media',
                        ),
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
          genres: state.genres,
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
      tooltip: '切换媒体类型与数据源',
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
                const Icon(
                  McIcons.check,
                  size: 16,
                  color: McTokens.accentStrong,
                ),
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
                const Icon(
                  McIcons.check,
                  size: 16,
                  color: McTokens.accentStrong,
                ),
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
                const Icon(
                  McIcons.check,
                  size: 16,
                  color: McTokens.accentStrong,
                ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'src:douban',
          child: Row(
            children: [
              const Expanded(child: Text('豆瓣片单')),
              if (source == 'douban')
                const Icon(
                  McIcons.check,
                  size: 16,
                  color: McTokens.accentStrong,
                ),
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
    required this.scrollOffsetListenable,
    required this.topBarClearance,
    required this.onAmbientChanged,
  });

  final DiscoverState state;
  final ValueListenable<double> scrollOffsetListenable;
  final double topBarClearance;
  final ValueChanged<Color?> onAmbientChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    if (state.loading && state.rows.isEmpty) {
      return const McFeedSkeleton(showHero: true);
    }
    if (state.failure != null && state.rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: topBarClearance + 56),
          _DiscoverErrorView(
            failure: state.failure!,
            isAdmin: perms.isAdmin,
            onRetry: () =>
                ref.read(discoverProvider.notifier).load(force: true),
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

    // 仅当服务端显式声明 hero 分区（或有含横版剧照的片单）时渲染 Hero；
    // 豆瓣等无横版剧照的视角绝不把 2:3 竖版海报拉伸铺满横版 Hero
    final heroItems = (heroRow?.titles ?? const <DiscTitle>[]).take(6).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: McTokens.bottomBarClearance + bottomPad),
      children: [
        if (heroItems.isNotEmpty)
          ValueListenableBuilder<double>(
            valueListenable: scrollOffsetListenable,
            builder: (context, scrollOffset, _) => McImmersiveHero(
              height: 500,
              scrollOffset: scrollOffset,
              itemCount: heroItems.length,
              imageUrlOf: (i) => heroItems[i].heroImageUrl,
              onAmbientColorChanged: onAmbientChanged,
              onTapSlide: (i) => feat_discover.pushTitle(
                context,
                heroItems[i].ref,
                seed: heroItems[i],
              ),
              foregroundBuilder: (context, i) {
                final t = heroItems[i];
                final sub = subs.findByTitle(t);
                final metaParts = <String>[
                  if (t.year != null) '${t.year}',
                  if (t.genres.isNotEmpty) t.genres.take(2).join(' / '),
                  if (t.extentLabel.isNotEmpty) t.extentLabel,
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '今日精选 · ${t.mediaType == 'tv' ? '剧集' : '电影'}',
                      style: McText.micro.copyWith(
                        color: McTokens.accent2,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.title,
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
                    if (t.originalTitle.isNotEmpty &&
                        t.originalTitle != t.title) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.originalTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.copyWith(
                          color: const Color(0x8CFFFFFF),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if ((t.rating ?? 0) > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                McIcons.star2Fill,
                                size: 13,
                                color: McTokens.warning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                t.rating!.toStringAsFixed(1),
                                style: McText.sub
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    )
                                    .tabular,
                              ),
                            ],
                          ),
                        for (final part in metaParts)
                          Text(
                            part,
                            style: McText.sub
                                .copyWith(color: const Color(0xCCFFFFFF))
                                .tabular,
                          ),
                        if (t.owned)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: McTokens.ok,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '已入库',
                                style: McText.caption.copyWith(
                                  color: const Color(0xFF6EE7B7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (t.overview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        t.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          color: const Color(0xBFFFFFFF),
                        ),
                      ),
                    ],
                    if (perms.canSubscribe) ...[
                      const SizedBox(height: 14),
                      McActionPill(
                        label: sub == null ? '订阅影片' : '已订阅',
                        icon: sub == null ? McIcons.addCircle : McIcons.check,
                        primary: sub == null,
                        onTap: () async {
                          final out = await showSubscribeSheet(
                            context,
                            ref,
                            titleRef: t.ref,
                          );
                          if (!context.mounted || out == null) return;
                          ref
                              .read(discoverSubscriptionIndexProvider.notifier)
                              .refresh();
                          if (out == SubscribeSheetOutcome.created) {
                            McToast.success('已加入追更订阅');
                          } else if (out == SubscribeSheetOutcome.managed) {
                            context.push('/subscriptions');
                          }
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          )
        else
          SizedBox(height: topBarClearance),
        for (final row in shelfRows)
          _DiscoverSectionShelf(row: row, source: state.source),
        // 院线地区页脚：仅在电影 × TMDB 视角展示
        if (state.mediaType == 'movie' && state.source == 'tmdb')
          _DiscoverRegionFooter(region: state.region),
      ],
    );
  }
}

/// 上游数据源不可达 / 发现页错误态（对齐 iOS `DiscoverErrorView`）：
/// 识别 `UPSTREAM_UNREACHABLE`，展示地球图标 + 后端 `details[0].hint` 代理诊断提示 +
/// 管理员专属「前往网络设置」（`/settings/system?section=network`）。
class _DiscoverErrorView extends StatelessWidget {
  const _DiscoverErrorView({
    required this.failure,
    required this.isAdmin,
    required this.onRetry,
  });

  final DiscoverFailure failure;
  final bool isAdmin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final showNetworkBtn = failure.unreachable && isAdmin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
          border: Border.all(
            color: failure.unreachable
                ? McTokens.warning.withValues(alpha: 0.35)
                : McTokens.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failure.unreachable) ...[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: McTokens.warning.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  McIcons.globe,
                  size: 24,
                  color: McTokens.warning,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              failure.unreachable ? '上游数据源不可达' : '发现内容暂时无法加载',
              textAlign: TextAlign.center,
              style: McText.titleSm,
            ),
            const SizedBox(height: 8),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: McText.sub,
            ),
            if (failure.unreachable &&
                failure.hint != null &&
                failure.hint!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: McTokens.line),
                ),
                child: Text(
                  failure.hint!,
                  textAlign: TextAlign.center,
                  style: McText.caption.muted,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (showNetworkBtn)
                  McActionPill(
                    label: '前往网络设置',
                    icon: McIcons.setting1,
                    primary: true,
                    onTap: () =>
                        context.push('/settings/system?section=network'),
                  ),
                McActionPill(
                  label: '重试',
                  icon: McIcons.refreshS,
                  primary: !showNetworkBtn,
                  onTap: onRetry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 院线地区页脚（仅在电影 × TMDB 底部显示，对齐 iOS `DiscoverRegionFooter`）。
class _DiscoverRegionFooter extends ConsumerWidget {
  const _DiscoverRegionFooter({required this.region});

  final DiscoverRegionState region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = region.region;
    if (code == null || code.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Center(
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Text('院线地区', style: McText.caption.faint),
            if (region.canEdit)
              PopupMenuButton<String>(
                tooltip: '切换院线地区',
                onSelected: (next) async {
                  final err = await ref
                      .read(discoverProvider.notifier)
                      .setRegion(next);
                  if (err != null) McToast.error(err);
                },
                itemBuilder: (_) => [
                  for (final r in discoverRegions)
                    PopupMenuItem(
                      value: r.key,
                      child: Row(
                        children: [
                          Expanded(child: Text(r.value)),
                          if (r.key == code)
                            const Icon(
                              McIcons.check,
                              size: 16,
                              color: McTokens.accentStrong,
                            ),
                        ],
                      ),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      discoverRegionName(code),
                      style: McText.caption.copyWith(
                        color: McTokens.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      McIcons.arrowUpDown,
                      size: 12,
                      color: McTokens.textMuted,
                    ),
                  ],
                ),
              )
            else
              Text(
                discoverRegionName(code),
                style: McText.caption.muted,
              ),
            if (region.saving)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else if (region.justSaved)
              Text(
                '已保存',
                style: McText.caption.copyWith(color: McTokens.ok),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverSectionShelf extends ConsumerWidget {
  const _DiscoverSectionShelf({required this.row, required this.source});

  final DiscoverRowData row;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final perms = ref.watch(permissionsProvider);
    final canOpenFull = row.supportsFullListing && row.collectionRef.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: row.title,
            trailingText: canOpenFull ? '查看全部' : null,
            onTap: canOpenFull
                ? () => feat_discover.pushCollection(
                      context,
                      collectionRef: row.collectionRef,
                      title: row.title,
                      source: source,
                    )
                : null,
          ),
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
                final sub = subs.findByTitle(t);
                final badge =
                    t.owned ? '已入库' : (sub != null ? '已订阅' : null);
                final badgeColor = t.owned
                    ? McTokens.ok
                    : (sub != null ? McTokens.info : null);

                return McFocusRing(
                  borderRadius: McTokens.posterRadius,
                  child: McPosterCard(
                    title: t.title,
                    posterUrl: t.posterUrl,
                    width: 122,
                    subtitle: [
                      if (t.year != null) '${t.year}',
                      if (t.extentLabel.isNotEmpty)
                        t.extentLabel
                      else if (t.genres.isNotEmpty)
                        t.genres.first,
                    ].join(' · '),
                    rating: (t.rating ?? 0) > 0 ? t.rating : null,
                    badge: badge,
                    badgeDotColor: badgeColor,
                    onTap: () =>
                        feat_discover.pushTitle(context, t.ref, seed: t),
                    onQuickPlay: t.owned &&
                            t.libraryId != null &&
                            t.mediaItemId != null
                        ? () => context.push(
                              '/detail/${t.libraryId}/${t.mediaItemId}',
                            )
                        : null,
                    contextActions: [
                      McPosterMenuAction(
                        icon: McIcons.film,
                        label: '查看详情',
                        onTap: () =>
                            feat_discover.pushTitle(context, t.ref, seed: t),
                      ),
                      if (t.owned &&
                          t.libraryId != null &&
                          t.mediaItemId != null)
                        McPosterMenuAction(
                          icon: McIcons.play2Fill,
                          label: '前往媒体库观看',
                          onTap: () => context.push(
                            '/detail/${t.libraryId}/${t.mediaItemId}',
                          ),
                        ),
                      if (perms.canSubscribe)
                        McPosterMenuAction(
                          icon: McIcons.bookmarkFill,
                          label: sub != null ? '管理订阅' : '订阅影片',
                          onTap: () async {
                            final out = await showSubscribeSheet(
                              context,
                              ref,
                              titleRef: t.ref,
                            );
                            if (!context.mounted || out == null) return;
                            ref
                                .read(
                                  discoverSubscriptionIndexProvider.notifier,
                                )
                                .refresh();
                            if (out == SubscribeSheetOutcome.created) {
                              McToast.success('已加入追更订阅');
                            } else if (out == SubscribeSheetOutcome.managed) {
                              context.push('/subscriptions');
                            }
                          },
                        ),
                    ],
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
