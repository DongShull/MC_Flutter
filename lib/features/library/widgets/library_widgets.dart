import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../state/models.dart';

/// LibraryItemView → 海报卡片。
Widget mcItemCard(
  BuildContext context,
  LibraryItemView item, {
  double width = 120,
}) {
  final badge = item.kind == 'episode'
      ? (item.seasons.isNotEmpty ? 'S1' : null)
      : (item.resolutions.isNotEmpty ? item.resolutions.first : null);
  return McFocusRing(
    borderRadius: McTokens.posterRadius,
    child: McPosterCard(
      title: item.title,
      posterUrl: item.posterUrl,
      aspect: item.primaryAspect,
      subtitle: [
        item.year?.toString(),
        if (item.kindLabel.isNotEmpty) item.kindLabel,
      ].nonNulls.join(' · '),
      badge: badge,
      width: width,
      onTap: () {
        final lid = item.libraryId;
        if (lid != null) context.push('/detail/$lid/${item.mediaItemId}');
      },
    ),
  );
}

/// 横滑行：银玻璃统一 `McSectionHeader` + 120 宽海报横滑。
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
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: McSectionHeader(
            title: title,
            trailingText: meta ?? (onMore != null ? '查看全部' : null),
            onTap: onMore,
          ),
        ),
        SizedBox(
          height: 224,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            children: [
              for (final c in children)
                Padding(padding: const EdgeInsets.only(right: 12), child: c),
            ],
          ),
        ),
      ],
    );
  }
}
