import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/player/player_page_args.dart';
import '../state/models.dart';

/// LibraryItemView → 海报卡片（支持悬停快播、右键与长按菜单）。
Widget mcItemCard(
  BuildContext context,
  LibraryItemView item, {
  double? width = 120,
  int? fallbackLibraryId,
  List<McPosterMenuAction> extraActions = const [],
}) {
  final lid = item.libraryId ?? fallbackLibraryId;
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
      rating: (item.rating ?? 0) > 0 ? item.rating : null,
      favorite: item.isFavorite,
      badge: badge,
      width: width,
      onTap: () {
        if (lid != null) context.push('/detail/$lid/${item.mediaItemId}');
      },
      onQuickPlay: () => context.push(
        '/player',
        extra: PlayerPageArgs(
          mediaItemId: item.mediaItemId,
          title: item.title,
          isEpisode: item.kind == 'tv',
        ),
      ),
      contextActions: [
        McPosterMenuAction(
          icon: McIcons.play2Fill,
          label: '立即播放',
          onTap: () => context.push(
            '/player',
            extra: PlayerPageArgs(
              mediaItemId: item.mediaItemId,
              title: item.title,
              isEpisode: item.kind == 'tv',
            ),
          ),
        ),
        if (lid != null)
          McPosterMenuAction(
            icon: McIcons.film,
            label: '查看详情',
            onTap: () => context.push('/detail/$lid/${item.mediaItemId}'),
          ),
        ...extraActions,
      ],
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
