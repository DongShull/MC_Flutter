import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 详情页轨道与关联标签胶囊行（对齐 iOS `LibraryItemDetailView` 版本/音轨/字幕胶囊）：
/// 使用克制的 `surfaceInset` 圆角小胶囊展示音轨与字幕，系列与合集展示可点击冷银标签。
class MetaLinks extends StatelessWidget {
  const MetaLinks({
    super.key,
    required this.entry,
    this.onSeriesTap,
    this.onCollectionTap,
  });

  final DetailEntry entry;
  final ValueChanged<int>? onSeriesTap;
  final ValueChanged<String>? onCollectionTap;

  Widget _groupRow({
    required String label,
    required IconData icon,
    required List<Widget> pills,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 52,
              child: Row(
                children: [
                  Icon(icon, size: 13, color: McTokens.textFaint),
                  const SizedBox(width: 4),
                  Text(label, style: McText.caption.faint),
                ],
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pills,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Text(
        text,
        style: McText.micro.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: McTokens.textMuted,
        ),
      ),
    );
  }

  Widget _linkPill(String text, VoidCallback? onTap) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: McTokens.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: McTokens.lineStrong, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: McText.micro.copyWith(
              fontSize: 12,
              color: McTokens.accentStrong,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Icon(
              McIcons.chevronRight,
              size: 12,
              color: McTokens.textMuted,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return pill;
    return McPressable(onTap: onTap, child: pill);
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = entry.audioTracks.isNotEmpty ||
        entry.subtitleTracks.isNotEmpty ||
        (entry.seriesName != null && entry.seriesCollectionId != null) ||
        entry.collections.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    final shownCollections = entry.collections.take(3).toList();
    final extraCollections = entry.collections.length - shownCollections.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.audioTracks.isNotEmpty)
          _groupRow(
            label: '音轨',
            icon: McIcons.equalizer,
            pills: [
              for (final t in entry.audioTracks.take(4)) _trackPill(t),
              if (entry.audioTracks.length > 4)
                _trackPill('+${entry.audioTracks.length - 4}'),
            ],
          ),
        if (entry.subtitleTracks.isNotEmpty)
          _groupRow(
            label: '字幕',
            icon: McIcons.closedCaptioning,
            pills: [
              for (final t in entry.subtitleTracks.take(4)) _trackPill(t),
              if (entry.subtitleTracks.length > 4)
                _trackPill('+${entry.subtitleTracks.length - 4}'),
            ],
          ),
        if (entry.seriesName != null && entry.seriesCollectionId != null)
          _groupRow(
            label: '系列',
            icon: McIcons.film,
            pills: [
              _linkPill(
                entry.seriesName!,
                onSeriesTap == null
                    ? null
                    : () => onSeriesTap!(entry.seriesCollectionId!),
              ),
            ],
          ),
        if (shownCollections.isNotEmpty)
          _groupRow(
            label: '合集',
            icon: McIcons.stack,
            pills: [
              for (final c in shownCollections)
                _linkPill(
                  c,
                  onCollectionTap == null ? null : () => onCollectionTap!(c),
                ),
              if (extraCollections > 0) _trackPill('+$extraCollections'),
            ],
          ),
      ],
    );
  }
}
