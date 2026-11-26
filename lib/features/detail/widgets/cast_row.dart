import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/detail_controller.dart';

/// 演职员圆形头像横滑行（对齐 iOS `CastShelf`：64dp 圆头像 + 1px 细描边 + 姓名与饰演角色）。
class CastRow extends StatelessWidget {
  const CastRow({super.key, required this.cast, this.onPersonTap});

  final List<CastMember> cast;
  final ValueChanged<CastMember>? onPersonTap;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    final count = cast.length.clamp(0, 40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const McSectionHeader(title: '演职员'),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final member = cast[i];
              final resolved = McImageUrls.resolve(
                member.profileUrl,
                widthPx: 180,
              );
              return McFocusRing(
                borderRadius: 12,
                child: McPressable(
                  onTap: onPersonTap == null ? null : () => onPersonTap!(member),
                  child: SizedBox(
                    width: 74,
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: McTokens.posterPlaceholder,
                            border: Border.all(color: McTokens.line, width: 1),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: resolved.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: resolved,
                                  httpHeaders: mcImageHeaders(),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const _FallbackAvatar(),
                                  errorWidget: (_, __, ___) =>
                                      const _FallbackAvatar(),
                                )
                              : const _FallbackAvatar(),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: McText.caption.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (member.role != null && member.role!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            member.role!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: McText.micro.copyWith(
                              fontWeight: FontWeight.w400,
                              color: McTokens.textFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: McTokens.posterPlaceholder,
      child: Center(
        child: Icon(McIcons.user, size: 24, color: McTokens.textFaint),
      ),
    );
  }
}
