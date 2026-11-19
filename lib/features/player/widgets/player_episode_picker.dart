import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';

import '../state/player_controller.dart';

/// 选集面板（Android PlayerEpisodePicker）：季 chips 横排 + 集网格，当前季高亮。
/// 数据由入口方经 PlayerPageArgs 传入；正式路径 TODO(playback-session)：
/// 用 McClient（Channel.playback）拉季/集列表。
/// [asDrawer] = true 时为平板横屏抽屉式（右侧滑出面板）；默认居中对话框。
class PlayerEpisodePicker extends StatefulWidget {
  const PlayerEpisodePicker({
    super.key,
    required this.args,
    required this.currentSeason,
    required this.currentEpisode,
    required this.onSelect,
    required this.onDismiss,
    this.asDrawer = false,
  });

  final PlayerPageArgs args;
  final int currentSeason;
  final int currentEpisode;
  final void Function(int season, EpisodeItem episode) onSelect;
  final VoidCallback onDismiss;

  /// 平板横屏：右侧抽屉式面板（不遮挡画面主体）；false = 居中对话框。
  final bool asDrawer;

  @override
  State<PlayerEpisodePicker> createState() => _PlayerEpisodePickerState();
}

class _PlayerEpisodePickerState extends State<PlayerEpisodePicker> {
  late int _season = widget.args.seasons.contains(widget.currentSeason) ||
          widget.args.seasons.isEmpty
      ? widget.currentSeason
      : widget.args.seasons.first;

  List<EpisodeItem> get _episodes => widget.args.episodes
      .where((e) => widget.args.seasons.isEmpty || e.season == _season)
      .toList();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final episodes = _episodes;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.args.seasons.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final number in widget.args.seasons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('第 $number 季'),
                      selected: number == _season,
                      labelStyle: TextStyle(
                          color: number == _season ? accent : Colors.white),
                      selectedColor: Colors.white24,
                      onSelected: (_) => setState(() => _season = number),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('本季暂无剧集数据（待会话接口接入）',
                  style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final e = episodes[index];
                final active = e.season == widget.currentSeason &&
                    e.episode == widget.currentEpisode;
                // TV：集条目 D-pad 聚焦环。
                return McFocusRing(
                  borderRadius: 10,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => widget.onSelect(e.season, e),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white24
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '第${e.episode}集 · ${e.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: active ? accent : Colors.white,
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

    if (widget.asDrawer) {
      // 平板横屏：右侧抽屉式选集面板（不遮挡画面主体）。
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 400,
          child: Material(
            color: const Color(0xFF17191F),
            elevation: 8,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        const Text('选集',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      backgroundColor: const Color(0xFF17191F),
      title: const Text('选集', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 420,
        child: content,
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismiss,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
