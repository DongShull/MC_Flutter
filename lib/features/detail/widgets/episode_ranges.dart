import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 长剧集分段选集的一段（1:1 对齐 iOS `Shared/Library/EpisodeRanges.swift`）：
/// 按集号每 50 集一段，段名用段内实际首末集号（`1–50`, `51–100`…）。
class EpisodeRange {
  const EpisodeRange({
    required this.index,
    required this.first,
    required this.last,
  });

  final int index;
  final int first;
  final int last;

  String get label => '$first–$last';

  bool contains(int episodeNumber) => EpisodeRangesHelper.indexOf(episodeNumber) == index;
}

abstract final class EpisodeRangesHelper {
  static const int chunkSize = 50;

  static int indexOf(int episodeNumber) =>
      math.max(0, episodeNumber - 1) ~/ chunkSize;

  /// 超过 50 集才分段，否则返回空列表；空段不出现。
  static List<EpisodeRange> buildRanges(List<EpisodeEntry> episodes) {
    if (episodes.length <= chunkSize) return const [];
    final nums = episodes.map((e) => e.episodeNumber).toList()..sort();
    final result = <EpisodeRange>[];
    for (final number in nums) {
      final idx = indexOf(number);
      if (result.isNotEmpty && result.last.index == idx) {
        final prev = result.last;
        result[result.length - 1] = EpisodeRange(
          index: idx,
          first: prev.first,
          last: number,
        );
      } else {
        result.add(EpisodeRange(index: idx, first: number, last: number));
      }
    }
    return result;
  }

  static EpisodeRange? rangeContaining(
    int episodeNumber,
    List<EpisodeRange> ranges,
  ) {
    for (final r in ranges) {
      if (r.contains(episodeNumber)) return r;
    }
    return null;
  }

  /// 进某一段时落在哪一集：段里有锚点落锚点，否则段首。
  static int entryOf(EpisodeRange range, {int? anchor}) {
    if (anchor != null && range.contains(anchor)) return anchor;
    return range.first;
  }
}

/// 缺集区间提示（连续分集号之间有空洞时列出缺集区间）。
List<String> missingRanges(List<EpisodeEntry> episodes) {
  final numbers = episodes
      .where((e) => e.owned)
      .map((e) => e.episodeNumber)
      .where((n) => n > 0)
      .toList()
    ..sort();
  if (numbers.length < 2) return const [];
  final ranges = <String>[];
  for (var i = 1; i < numbers.length; i++) {
    final gapStart = numbers[i - 1] + 1;
    final gapEnd = numbers[i] - 1;
    if (gapEnd >= gapStart) {
      ranges.add(
        gapStart == gapEnd ? '缺 $gapStart 集' : '缺 $gapStart-$gapEnd 集',
      );
    }
  }
  return ranges;
}

/// 缺集提示条（保留向后兼容导出）。
class EpisodeRanges extends StatelessWidget {
  const EpisodeRanges({super.key, required this.episodes});

  final List<EpisodeEntry> episodes;

  @override
  Widget build(BuildContext context) {
    final ranges = missingRanges(episodes);
    if (ranges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        6,
        McTokens.pagePadding,
        4,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x1AF5C451),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x40F5C451), width: 1),
        ),
        child: Row(
          children: [
            const Icon(McIcons.alert1, size: 15, color: McTokens.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ranges.join('、'),
                style: McText.caption
                    .copyWith(color: McTokens.warning)
                    .tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 50 集分段胶囊条（选中的段亮白底黑字，续播锚点所在段右上角带橙点）。
class EpisodeRangeChips extends StatelessWidget {
  const EpisodeRangeChips({
    super.key,
    required this.ranges,
    required this.currentIndex,
    required this.onSelect,
    this.anchorEpisode,
    this.padding = const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
  });

  final List<EpisodeRange> ranges;
  final int currentIndex;
  final int? anchorEpisode;
  final ValueChanged<EpisodeRange> onSelect;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = ranges[i];
          final on = r.index == currentIndex;
          final hasAnchor =
              anchorEpisode != null && r.contains(anchorEpisode!);
          return McPressable(
            onTap: () => onSelect(r),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: on
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r.label,
                    style: McText.sub
                        .copyWith(
                          color: on ? Colors.black : McTokens.textMuted,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        )
                        .tabular,
                  ),
                ),
                if (hasAnchor)
                  Positioned(
                    right: 4,
                    top: 3,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 5 列数字宫格「全部分集」选集弹层（1:1 对齐 iOS `EpisodeGridSheet`）：
/// 顶部段胶囊 + 5 列数字格（已看绿勾、底部进度条、缺集虚线框、锚点橙边、选中白底）。
Future<int?> showEpisodeGridSheet({
  required BuildContext context,
  required List<EpisodeEntry> episodes,
  required List<EpisodeRange> ranges,
  int? anchorEpisode,
  int? selectedEpisode,
}) {
  return showMcSheet<int>(
    context: context,
    maxWidth: 620,
    builder: (_) => _EpisodeGridSheet(
      episodes: episodes,
      ranges: ranges,
      anchorEpisode: anchorEpisode,
      selectedEpisode: selectedEpisode,
    ),
  );
}

class _EpisodeGridSheet extends StatefulWidget {
  const _EpisodeGridSheet({
    required this.episodes,
    required this.ranges,
    this.anchorEpisode,
    this.selectedEpisode,
  });

  final List<EpisodeEntry> episodes;
  final List<EpisodeRange> ranges;
  final int? anchorEpisode;
  final int? selectedEpisode;

  @override
  State<_EpisodeGridSheet> createState() => _EpisodeGridSheetState();
}

class _EpisodeGridSheetState extends State<_EpisodeGridSheet> {
  late int _rangeIndex;

  @override
  void initState() {
    super.initState();
    final seed = widget.anchorEpisode ?? widget.selectedEpisode;
    final start = seed != null
        ? EpisodeRangesHelper.rangeContaining(seed, widget.ranges)
        : null;
    _rangeIndex =
        start?.index ?? (widget.ranges.isEmpty ? 0 : widget.ranges.first.index);
  }

  @override
  Widget build(BuildContext context) {
    EpisodeRange? current;
    for (final r in widget.ranges) {
      if (r.index == _rangeIndex) {
        current = r;
        break;
      }
    }
    final shown = current == null
        ? widget.episodes
        : widget.episodes
            .where((e) => current!.contains(e.episodeNumber))
            .toList();
    final ownedCount = widget.episodes.where((e) => e.owned).length;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
            child: Row(
              children: [
                const Text('全部分集', style: McText.title),
                const SizedBox(width: 8),
                Text(
                  '$ownedCount / ${widget.episodes.length}',
                  style: McText.caption.faint.tabular,
                ),
                const Spacer(),
                McPressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '完成',
                      style: McText.sub.copyWith(
                        color: McTokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.ranges.isNotEmpty) ...[
            EpisodeRangeChips(
              ranges: widget.ranges,
              currentIndex: _rangeIndex,
              anchorEpisode: widget.anchorEpisode,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              onSelect: (r) => setState(() => _rangeIndex = r.index),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 46,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final ep = shown[i];
                final isAnchor = ep.episodeNumber == widget.anchorEpisode;
                final isSelected = ep.episodeNumber == widget.selectedEpisode;
                final progress = ep.resumeMs > 0 ? ep.progressPercent : null;

                final fill = isSelected
                    ? Colors.white
                    : !ep.owned
                        ? Colors.transparent
                        : ep.played
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.white.withValues(alpha: 0.07);
                final ink = isSelected
                    ? Colors.black
                    : !ep.owned
                        ? McTokens.textFaint
                        : ep.played
                            ? McTokens.textMuted
                            : McTokens.text;

                return McPressable(
                  onTap: () => Navigator.of(context).pop(ep.episodeNumber),
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAnchor
                            ? Colors.orange
                            : !ep.owned
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.transparent,
                        width: isAnchor ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${ep.episodeNumber}',
                            style: McText.ui
                                .copyWith(
                                  color: ink,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                )
                                .tabular,
                          ),
                        ),
                        if (ep.played)
                          const Positioned(
                            right: 4,
                            top: 4,
                            child: Icon(
                              McIcons.check,
                              size: 10,
                              color: McTokens.ok,
                            ),
                          ),
                        if (progress != null && progress > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (progress / 100.0).clamp(0.04, 1.0),
                              child: Container(
                                height: 3,
                                color: isSelected
                                    ? Colors.black.withValues(alpha: 0.35)
                                    : McTokens.accentStrong,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
