import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/player/player_page_args.dart';
import '../state/models.dart';
import 'library_shared.dart';

/// LibraryItemView → 媒体库海报卡片（对齐 iOS `LibraryInventoryCell`）：
/// - `posterBlur` base64 微缩模糊占位渐进加载；
/// - 克制角标：仅在 `showRating == true` 时展示评分，避免满墙角标噪音；
/// - 库存概况（`inventorySummary`）、`probePendingCount` 蓝色脉冲、缺失提示（`missingCount` / `isDead` 置灰）；
/// - 支持悬停快播、右键与长按上下文菜单。
Widget mcItemCard(
  BuildContext context,
  LibraryItemView item, {
  double? width = 120,
  double frameAspect = McTokens.posterAspect,
  int? fallbackLibraryId,
  bool showRating = false,
  String? workingLabel,
  String? cornerLabel,
  List<McPosterMenuAction> extraActions = const [],
}) {
  final lid = item.libraryId ?? fallbackLibraryId;
  final effectiveWorking = workingLabel ??
      (item.probePendingCount > 0 ? '正在读取规格…' : null);

  final String? badge = cornerLabel ??
      (item.inventorySummary != null
          ? formatInventorySummary(item.inventorySummary!)
          : (item.kind == 'episode' && item.seasons.isNotEmpty
              ? 'S${item.seasons.first}'
              : null));

  final String? abnormalLabel = item.isDead
      ? '文件缺失'
      : (item.missingCount > 0 ? '缺失 ${item.missingCount} 个文件' : null);

  final subtitleParts = <String>[
    if (item.year != null) '${item.year}',
    if (item.kind == 'tv' && item.inventorySummary == null && item.seasons.isNotEmpty)
      '${item.seasons.length} 季',
  ];

  void openDetail() {
    if (lid != null && lid > 0) {
      context.push('/detail/$lid/${item.mediaItemId}');
    }
  }

  void quickPlay() {
    context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: item.mediaItemId,
        title: item.title,
        isEpisode: item.kind == 'tv',
      ),
    );
  }

  final actions = <McPosterMenuAction>[
    if (item.kind != 'photo')
      McPosterMenuAction(
        icon: McIcons.play2Fill,
        label: '立即播放',
        onTap: quickPlay,
      ),
    if (lid != null && lid > 0)
      McPosterMenuAction(
        icon: McIcons.film,
        label: '查看详情',
        onTap: openDetail,
      ),
    ...extraActions,
  ];

  // 有 posterBlur 时走自绘渐进占位卡片，否则走全站统一 McPosterCard（两者视觉完全一致）
  final blurBytes = decodePosterBlur(item.posterBlur);
  if (blurBytes != null) {
    return McFocusRing(
      borderRadius: McTokens.posterRadius,
      child: _BlurBackedItemCard(
        item: item,
        blurBytes: blurBytes,
        width: width,
        frameAspect: frameAspect,
        subtitle: subtitleParts.join(' · '),
        badge: badge,
        rating: showRating && (item.rating ?? 0) > 0 ? item.rating : null,
        workingLabel: effectiveWorking,
        abnormalLabel: abnormalLabel,
        probePulse: item.probePendingCount > 0,
        onTap: openDetail,
        contextActions: actions,
      ),
    );
  }

  return McFocusRing(
    borderRadius: McTokens.posterRadius,
    child: McPosterCard(
      title: item.title,
      posterUrl: item.posterUrl,
      aspect: frameAspect,
      imageAspect: item.primaryAspect,
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      rating: showRating && (item.rating ?? 0) > 0 ? item.rating : null,
      favorite: item.isFavorite,
      badge: badge,
      badgeDotColor: item.probePendingCount > 0 ? McTokens.info : null,
      dead: item.isDead,
      workingLabel: effectiveWorking,
      abnormalLabel: abnormalLabel,
      width: width,
      onTap: openDetail,
      onQuickPlay: item.kind == 'photo' ? null : quickPlay,
      contextActions: actions,
    ),
  );
}

class _BlurBackedItemCard extends StatelessWidget {
  const _BlurBackedItemCard({
    required this.item,
    required this.blurBytes,
    required this.width,
    required this.frameAspect,
    required this.subtitle,
    required this.badge,
    required this.rating,
    required this.workingLabel,
    required this.abnormalLabel,
    required this.probePulse,
    required this.onTap,
    required this.contextActions,
  });

  final LibraryItemView item;
  final List<int> blurBytes;
  final double? width;
  final double frameAspect;
  final String subtitle;
  final String? badge;
  final double? rating;
  final String? workingLabel;
  final String? abnormalLabel;
  final bool probePulse;
  final VoidCallback onTap;
  final List<McPosterMenuAction> contextActions;

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(
      item.posterUrl,
      widthPx: frameAspect > 1.0 ? 640 : 480,
    );
    final blurPlaceholder = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Transform.scale(
        scale: 1.08,
        child: Image.memory(
          decodePosterBlur(item.posterBlur)!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );

    Widget art = AspectRatio(
      aspectRatio: frameAspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          blurPlaceholder,
          if (resolved.isNotEmpty)
            CachedNetworkImage(
              imageUrl: resolved,
              httpHeaders: mcImageHeaders(),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
        ],
      ),
    );

    if (item.isDead) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.5, 0,
        ]),
        child: art,
      );
    }

    Widget card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(McTokens.posterRadius),
            border: Border.all(
              color: workingLabel != null ? McTokens.info : McTokens.line,
              width: workingLabel != null ? 1.6 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(McTokens.posterRadius - 0.5),
            child: Stack(
              children: [
                art,
                if (badge != null && badge!.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _CardPill(
                      text: badge!,
                      dotColor: probePulse ? McTokens.info : null,
                    ),
                  ),
                if (rating != null || item.isFavorite || probePulse)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (probePulse)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: _PulseDot(color: McTokens.info),
                          ),
                        if (rating != null)
                          _CardPill(text: '★ ${rating!.toStringAsFixed(1)}'),
                        if (item.isFavorite) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x94000000),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              McIcons.heart2Fill,
                              size: 12,
                              color: McTokens.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (workingLabel != null && workingLabel!.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      color: const Color(0xEB070C14),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: McTokens.info,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              workingLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.copyWith(color: McTokens.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: McText.posterTitle,
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.caption,
          ),
        ],
        if (abnormalLabel != null && abnormalLabel!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: item.isDead ? McTokens.textFaint : McTokens.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  abnormalLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (width != null) card = SizedBox(width: width, child: card);

    final hasMenu = contextActions.isNotEmpty;
    return McPressable(
      hoverScale: 1.03,
      onTap: onTap,
      onSecondaryTapUp: hasMenu
          ? (details) => showMcContextActions(
                context: context,
                title: item.title,
                subtitle: subtitle.isEmpty ? null : subtitle,
                actions: contextActions,
                globalPosition: details.globalPosition,
              )
          : null,
      onLongPress: hasMenu
          ? () => showMcContextActions(
                context: context,
                title: item.title,
                subtitle: subtitle.isEmpty ? null : subtitle,
                actions: contextActions,
              )
          : null,
      child: card,
    );
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({required this.text, this.dotColor});

  final String text;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xA6000000),
        borderRadius: BorderRadius.circular(McTokens.pillRadius),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: McText.micro.copyWith(color: const Color(0xF2FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.65),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
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
