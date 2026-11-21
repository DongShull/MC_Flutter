import '../../../core/image/image_urls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../state/detail_controller.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 演职员横滚（cast 前 40，人物卡点进人物页；人物页属于 library 域，这里只留导航意图）。
class CastRow extends StatelessWidget {
  const CastRow({super.key, required this.cast, this.onPersonTap});

  final List<CastMember> cast;
  final ValueChanged<CastMember>? onPersonTap;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cast.length.clamp(0, 40),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final member = cast[i];
          return McFocusRing(
            borderRadius: 10,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onPersonTap?.call(member),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    ClipOval(
                      child: member.profileUrl != null
                          ? CachedNetworkImage(
                              imageUrl: McImageUrls.resolve(member.profileUrl,
                                  widthPx: 160),
                              httpHeaders: mcImageHeaders(),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const _FallbackAvatar(),
                            )
                          : const _FallbackAvatar(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (member.role != null && member.role!.isNotEmpty)
                      Text(
                        member.role!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.white38),
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

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar();

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(McIcons.user, size: 28),
      );
}
