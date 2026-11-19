import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/poster_card.dart';
import '../state/models.dart';

/// LibraryItemView → 海报卡片（详情导航 TODO：跳 detail/player 路由名）。
Widget mcItemCard(BuildContext context, LibraryItemView item, {double width = 120}) {
  final badge = item.kind == 'episode'
      ? (item.seasons.isNotEmpty ? 'S1' : null)
      : (item.resolutions.isNotEmpty ? item.resolutions.first : null);
  // TV 形态下海报卡包焦点环；非 TV 原样返回 child，零开销。
  return McFocusRing(
    borderRadius: 12,
    child: McPosterCard(
      title: item.title,
      posterUrl: item.posterUrl,
      aspect: item.primaryAspect,
      subtitle: [item.year?.toString(), if (item.kindLabel.isNotEmpty) item.kindLabel].nonNulls.join(' · '),
      badge: badge,
      width: width,
      onTap: () {
        // TODO(播放导航): 跳 detail/player 路由名（播放相关一律只做导航意图）。
      },
    ),
  );
}

/// 横滑行：标题行（含 meta）+ 120 宽海报横滑（对齐 Kotlin HomeRow）。
class McHomeRowSection extends StatelessWidget {
  const McHomeRowSection({
    super.key,
    required this.title,
    this.meta,
    this.onMore,
    required this.children,
  });

  final String title;
  final String? meta;
  final VoidCallback? onMore;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              if (meta != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    meta!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              if (onMore != null)
                GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.chevron_right, size: 20),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in children) Padding(padding: const EdgeInsets.only(right: 10), child: c),
            ],
          ),
        ),
      ],
    );
  }
}

