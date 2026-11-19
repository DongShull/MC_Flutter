// IMPLEMENTED — 1:1 重写自 MovieClaw feature/discover/DiscoverScreen.kt。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';
import '../widgets/discovery_filter.dart';
import 'discover_filtered_page.dart';

/// 发现页：搜索入口 + 电影/剧集 + 来源切换（TMDB/豆瓣）+ 筛选 + 服务端板块行。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    final notifier = ref.read(discoverProvider.notifier);
    final filtering = state.filtering;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          // 搜索入口
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            // TODO(player/detail): 跳 search 路由（导航意图）。
            onPressed: () => context.go(feat_discover.routeSearchEntry),
          ),
          if (state.source.toLowerCase() == 'tmdb')
            // 顶栏「全部」筛选入口：任何时候都能改条件。
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune),
              tooltip: '筛选',
              onSelected: (dim) => _openFilterDim(dim, state),
              itemBuilder: (_) => [
                for (final key in discoveryDimKeys)
                  PopupMenuItem(value: key, child: Text(discoveryDimTitle(key))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: '__clear__', child: Text('清空条件')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.pullRefresh,
        child: Column(
          children: [
            // 类型分段：电影 / 剧集
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _Segmented(
                    segments: const [MapEntry('movie', '电影'), MapEntry('tv', '剧集')],
                    value: state.mediaType,
                    onChanged: notifier.switchMediaType,
                  ),
                  const SizedBox(width: 12),
                  // 来源分段：TMDB / 豆瓣
                  _Segmented(
                    segments: const [MapEntry('tmdb', 'TMDB'), MapEntry('douban', '豆瓣')],
                    value: state.source,
                    onChanged: notifier.switchSource,
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtering
                  ? const DiscoverFilteredPage()
                  : _HomeBody(state: state),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterDim(String key, DiscoverState state) {
    if (key == '__clear__') {
      ref.read(discoverProvider.notifier).applyFilters(const DiscoveryFilter());
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: McColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
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
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<MapEntry<String, String>> segments;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            GestureDetector(
              onTap: () => onChanged(s.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: value == s.key
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value == s.key ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 常规态正文：板块行（hero 行 → 轮播；其余 → 横滚海报行）。
class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.state});

  final DiscoverState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) {
      return const McLoadingView();
    }
    if (state.error != null) {
      return McErrorView(
        text: state.error!,
        onRetry: () => ref.read(discoverProvider.notifier).load(),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final row in state.rows)
          if (row.presentation == 'hero') _HeroCarousel(row: row) else _SectionRow(row: row),
      ],
    );
  }
}

/// hero 六屏轮播（发现页当前这一屏的剧照做氛围底，此处做简化轮播 + 订阅态占位）。
class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({required this.row});

  final DiscoverRowData row;

  @override
  Widget build(BuildContext context) {
    final controller = PageController(viewportFraction: 0.92);
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: controller,
        itemCount: row.titles.length,
        itemBuilder: (context, i) {
          final t = row.titles[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: GestureDetector(
              // TODO(player/detail): 跳 title 详情路由（导航意图，不做播放）。
              onTap: () => feat_discover.pushTitle(context, t.ref),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (t.posterUrl != null && t.posterUrl!.isNotEmpty)
                      Image.network(t.posterUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: McColors.surfaceDark))
                    else
                      Container(color: McColors.surfaceDark),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 「标题 + 横滚海报」板块行。
class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.row});

  final DiscoverRowData row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              row.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: row.titles.length,
              itemBuilder: (context, i) {
                final t = row.titles[i];
                return SizedBox(
                  width: 110,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: McPosterCard(
                      title: t.title,
                      posterUrl: t.posterUrl,
                      width: null,
                      radius: 12,
                      subtitle: [
                        if (t.year != null) t.year.toString(),
                        if (t.genres.isNotEmpty) t.genres.first,
                      ].join(' · '),
                      rating: (t.rating ?? 0) > 0 ? t.rating : null,
                      badge: t.owned ? '在库' : null,
                      // TODO(player/detail): 跳 title 详情路由（导航意图，不做播放）。
                      onTap: () => feat_discover.pushTitle(context, t.ref),
                    ),
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
