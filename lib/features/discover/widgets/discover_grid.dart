// IMPLEMENTED — 1:1 重写自 MovieClaw feature/discover/DiscoverFilteredGrid.kt。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/image/cover_preloader.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/discover_controller.dart';
import '../routes.dart' as feat_discover;
import '../widgets/discovery_filter.dart';

class _DimSheetBody extends ConsumerWidget {
  const _DimSheetBody({
    required this.dimKey,
    required this.mediaType,
    required this.onApply,
  });

  final String dimKey;
  final String mediaType;
  final ValueChanged<DiscoveryFilter> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(discoverProvider).filters;
    return DiscoveryFilterOptionsPanel(
      dimKey: dimKey,
      filter: filters,
      mediaType: mediaType,
      onApply: (f) {
        Navigator.of(context).pop();
        onApply(f);
      },
    );
  }
}

/// 组合筛选的结果网格：头（TMDB DISCOVER / 计数 + 清空条件）+ 条件胶囊 + 两列海报网格
/// + 滚到底自动翻页 + 空态 / 出错重试 / 到底提示（文案照原 Kotlin）。
class DiscoverFilteredGrid extends ConsumerStatefulWidget {
  const DiscoverFilteredGrid({super.key});

  @override
  ConsumerState<DiscoverFilteredGrid> createState() => _DiscoverFilteredGridState();
}

class _DiscoverFilteredGridState extends ConsumerState<DiscoverFilteredGrid> {
  int? _preloadedSig;

  void _openDim(String key) {
    final state = ref.read(discoverProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: McColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _DimSheetBody(
            dimKey: key,
            mediaType: state.mediaType,
            onApply: (f) => ref.read(discoverProvider.notifier).applyFilters(f),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    // 封面预取（docs/design/09）：结果集变化（翻页追加）后把全部海报喂进预取队列。
    final sig = state.filtered.length;
    if (sig > 0 && sig != _preloadedSig) {
      _preloadedSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CoverPreloader.preload(context, state.filtered.map((t) => t.posterUrl));
        }
      });
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 翻页判定跟着网格的可见项走：滚到距底不足一屏时自动翻页。
        if (n.metrics.extentAfter < 600) {
          ref.read(discoverProvider.notifier).loadMoreFiltered();
        }
        return false;
      },
      // 平板/TV 用 mcGridCrossAxisCount 自适应列数（TV 条目稍大）；
      // 手机保持现有 maxCrossAxisExtent 密度不变。
      child: LayoutBuilder(builder: (context, constraints) {
        final form = McFormWatch.of(context);
        final gridDelegate = form == McDeviceForm.phone
            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 24,
                crossAxisSpacing: 12,
                childAspectRatio: 0.52,
              )
            : SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    mcGridCrossAxisCount(form, constraints, cellExtent: 200),
                mainAxisSpacing: 24,
                crossAxisSpacing: 12,
                childAspectRatio: 0.52,
              );
        return GridView.custom(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        gridDelegate: gridDelegate,
        childrenDelegate: SliverChildListDelegate([
          _header(state, ref),
          DiscoverFilterChipsRow(
            filters: state.filters,
            mediaType: state.mediaType,
            onOpenDim: _openDim,
          ),
          if (state.filteredLoading && state.filtered.isEmpty)
            for (var i = 0; i < 6; i++)
              Container(
                height: 228,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          if (state.filtered.isEmpty && !state.filteredLoading && state.filteredError == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  '没有符合条件的影片',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ),
          if (state.filteredError != null)
            McErrorView(
              text: state.filteredError!,
              onRetry: () => ref.read(discoverProvider.notifier).loadFiltered(),
            ),
          for (final t in state.filtered)
            McFocusRing(
              borderRadius: 12,
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
                onTap: () => feat_discover.pushTitle(context, t.ref),
              ),
            ),
          if (state.filteredLoading && state.filtered.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (state.filteredPage >= state.filteredTotalPages && state.filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '已加载全部 ${state.filtered.length} 部影片',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)),
                ),
              ),
            ),
        ]),
        );
      }),
    );
  }

  Widget _header(DiscoverState state, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TMDB DISCOVER',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: McColors.accent,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '筛选结果',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.filteredTotal > 0
                        ? '找到 ${state.filteredTotal} 部，已加载 ${state.filtered.length} 部'
                        : '已启用 ${state.filters.activeCount} 项筛选',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(discoverProvider.notifier).applyFilters(const DiscoveryFilter()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '清空条件',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
