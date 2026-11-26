import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/player_controller.dart';

/// 选集面板（右侧液态毛玻璃抽屉 / 居中毛玻璃弹框）：`McChip` 季切换 + 冷银高亮集网格。
class PlayerEpisodePicker extends StatefulWidget {
  const PlayerEpisodePicker({
    super.key,
    required this.args,
    required this.currentSeason,
    required this.currentEpisode,
    required this.onSelect,
    required this.onDismiss,
    this.onSeasonChanged,
    this.loading = false,
    this.asDrawer = false,
  });

  final PlayerPageArgs args;
  final int currentSeason;
  final int currentEpisode;
  final void Function(int season, EpisodeItem episode) onSelect;
  final VoidCallback onDismiss;
  final ValueChanged<int>? onSeasonChanged;
  final bool loading;
  final bool asDrawer;

  @override
  State<PlayerEpisodePicker> createState() => _PlayerEpisodePickerState();
}

class _PlayerEpisodePickerState extends State<PlayerEpisodePicker> {
  late int _season =
      widget.args.seasons.contains(widget.currentSeason) ||
          widget.args.seasons.isEmpty
      ? widget.currentSeason
      : widget.args.seasons.first;

  List<EpisodeItem> get _episodes => widget.args.episodes
      .where((e) => widget.args.seasons.isEmpty || e.season == _season)
      .toList();

  @override
  Widget build(BuildContext context) {
    final episodes = _episodes;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.args.seasons.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.args.seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final number = widget.args.seasons[i];
                return McChip(
                  label: number == 0 ? '特别篇' : '第 $number 季',
                  selected: number == _season,
                  onTap: () {
                    setState(() => _season = number);
                    widget.onSeasonChanged?.call(number);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (episodes.isEmpty)
          SizedBox(
            height: 140,
            child: widget.loading
                ? const McLoadingView()
                : Center(child: Text('本季暂无剧集数据', style: McText.caption.muted)),
          )
        else
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.9,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final e = episodes[index];
                final active =
                    e.season == widget.currentSeason &&
                    e.episode == widget.currentEpisode;
                return Opacity(
                  opacity: e.owned ? 1.0 : 0.45,
                  child: McFocusRing(
                    borderRadius: 12,
                    child: McPressable(
                      onTap: () => widget.onSelect(e.season, e),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: active
                              ? McTokens.accentStrong
                              : McTokens.surfaceInset,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? Colors.transparent : McTokens.line,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'E${e.episode.toString().padLeft(2, '0')} · ${e.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.caption
                              .copyWith(
                                color: active
                                    ? McTokens.onAccent
                                    : McTokens.text,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              )
                              .tabular,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: const ColoredBox(color: Color(0x66000000)),
        ),
        Align(
          alignment: widget.asDrawer ? Alignment.centerRight : Alignment.center,
          child: ClipRRect(
            borderRadius: widget.asDrawer
                ? const BorderRadius.horizontal(left: Radius.circular(22))
                : BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                width: widget.asDrawer ? 380 : 440,
                height: widget.asDrawer ? double.infinity : null,
                constraints: widget.asDrawer
                    ? null
                    : const BoxConstraints(maxHeight: 340),
                decoration: BoxDecoration(
                  color: const Color(0xEB131620),
                  borderRadius: widget.asDrawer
                      ? const BorderRadius.horizontal(left: Radius.circular(22))
                      : BorderRadius.circular(22),
                  border: Border.all(color: McTokens.lineStrong, width: 1),
                ),
                child: SafeArea(
                  left: !widget.asDrawer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 18),
                    child: Column(
                      mainAxisSize: widget.asDrawer
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('选集', style: McText.titleSm),
                            ),
                            McGlassIconButton(
                              icon: McIcons.close,
                              size: 32,
                              iconSize: 16,
                              onTap: widget.onDismiss,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (widget.asDrawer)
                          Expanded(child: body)
                        else
                          Flexible(child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
