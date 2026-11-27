import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 详情页关联系列与合集标签胶囊行（轨道行已由 `MediaTrackSection` 接管；无 files 时兜底展示顶层音轨/字幕）。
class MetaLinks extends StatelessWidget {
  const MetaLinks({
    super.key,
    required this.entry,
    this.showLegacyTracks = false,
    this.onSeriesTap,
    this.onCollectionTap,
  });

  final DetailEntry entry;
  final bool showLegacyTracks;
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
    final showAudio = showLegacyTracks && entry.audioTracks.isNotEmpty;
    final showSub = showLegacyTracks && entry.subtitleTracks.isNotEmpty;
    final hasSeries = entry.seriesName != null && entry.seriesName!.isNotEmpty;
    final hasAny =
        showAudio || showSub || hasSeries || entry.collections.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    final shownCollections = entry.collections.take(3).toList();
    final extraCollections = entry.collections.length - shownCollections.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAudio)
          _groupRow(
            label: '音轨',
            icon: McIcons.equalizer,
            pills: [
              for (final t in entry.audioTracks.take(4)) _trackPill(t),
              if (entry.audioTracks.length > 4)
                _trackPill('+${entry.audioTracks.length - 4}'),
            ],
          ),
        if (showSub)
          _groupRow(
            label: '字幕',
            icon: McIcons.closedCaptioning,
            pills: [
              for (final t in entry.subtitleTracks.take(4)) _trackPill(t),
              if (entry.subtitleTracks.length > 4)
                _trackPill('+${entry.subtitleTracks.length - 4}'),
            ],
          ),
        if (hasSeries)
          _groupRow(
            label: '系列',
            icon: McIcons.film,
            pills: [
              _linkPill(
                entry.seriesName!,
                (entry.seriesCollectionId != null && onSeriesTap != null)
                    ? () => onSeriesTap!(entry.seriesCollectionId!)
                    : null,
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
              if (extraCollections > 0)
                _linkPill(
                  '+$extraCollections',
                  onCollectionTap == null ? null : () => onCollectionTap!(''),
                ),
            ],
          ),
      ],
    );
  }
}
