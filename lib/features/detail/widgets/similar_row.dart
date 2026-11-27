import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 详情页相似推荐海报横滑行（统一 `McSectionHeader` + `McPosterCard` 12dp 圆角）。
class SimilarRow extends StatelessWidget {
  const SimilarRow({
    super.key,
    required this.title,
    required this.entries,
    required this.onTap,
  });

  final String title;
  final List<DetailEntry> entries;
  final ValueChanged<DetailEntry> onTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        McSectionHeader(title: title),
        const SizedBox(height: 12),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final e = entries[i];
              return McPosterCard(
                title: e.title,
                subtitle: e.year?.toString(),
                posterUrl: e.posterUrl,
                rating: e.rating,
                width: 112,
                onTap: () => onTap(e),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 作品系列一行（1:1 对齐 iOS `LibrarySeriesSection` + `MissingPartCell`）：
/// - 标题旁显示「已有 X / 共 Y」；
/// - 当前条目带「本片」角标；
/// - 库里已有的其他作品点击进入详情；
/// - 未入库缺片渲染压暗海报 `MissingPartCell`（「未入库」/「追踪中」），点击弹起 `SubscribeSheet`！
class SeriesSectionRow extends StatelessWidget {
  const SeriesSectionRow({
    super.key,
    required this.series,
    required this.currentItemId,
    required this.onOwnedTap,
    required this.onMissingTap,
  });

  final CollectionSeriesInfo series;
  final int currentItemId;
  final ValueChanged<int> onOwnedTap;
  final ValueChanged<SeriesPartEntry> onMissingTap;

  @override
  Widget build(BuildContext context) {
    if (series.parts.length <= 1) return const SizedBox.shrink();
    final title = (series.seriesName != null && series.seriesName!.isNotEmpty)
        ? '系列 · ${series.seriesName}'
        : '作品系列';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        McSectionHeader(
          title: title,
          trailingText: '已有 ${series.ownedCount} / 共 ${series.total}',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            itemCount: series.parts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final part = series.parts[i];
              if (part.isOwned) {
                final isCurrent = part.mediaItemId == currentItemId;
                return McPosterCard(
                  title: part.title,
                  subtitle: part.year?.toString(),
                  posterUrl: part.posterUrl,
                  badge: isCurrent ? '本片' : null,
                  width: 112,
                  onTap: isCurrent ? null : () => onOwnedTap(part.mediaItemId!),
                );
              }
              return MissingPartCell(
                part: part,
                onTap: () => onMissingTap(part),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 系列中尚未入库的缺片卡片（压暗海报，不压暗片名；点开订阅弹层）。
class MissingPartCell extends StatelessWidget {
  const MissingPartCell({
    super.key,
    required this.part,
    required this.onTap,
    this.width = 112,
  });

  final SeriesPartEntry part;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final badgeText = part.subscribed ? '追踪中' : '未入库';
    return McPressable(
      onTap: onTap,
      scaleDown: 0.97,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: width * 1.5,
              decoration: BoxDecoration(
                color: McTokens.posterPlaceholder,
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.42,
                    child: McArtwork(
                      url: part.posterUrl,
                      widthPx: 320,
                      fallbackText: part.title,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: part.subscribed
                            ? McTokens.info.withValues(alpha: 0.85)
                            : const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badgeText,
                        style: McText.micro.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              part.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.copyWith(
                color: McTokens.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (part.year != null) ...[
              const SizedBox(height: 1),
              Text(
                part.year.toString(),
                style: McText.micro.faint.tabular,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
