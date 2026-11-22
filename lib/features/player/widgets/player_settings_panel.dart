import 'package:flutter/material.dart';

import '../state/player_controller.dart';
import '../../../core/designsystem/mc_icons.dart';

enum _SettingsPage { root, quality, speed, display }

/// 播放器的 ⋮ 设置面板（Android PlayerSettingsPanel）：横屏从右侧滑出、占满高度，
/// 同 B 站 / 腾讯视频的横屏侧边栏。一级每项行尾写当前值，点进二级选，选了就收起；
/// 二级「←」或返回键回到一级；点面板外面收起。
/// 画质选择 / 播放诊断未实现（见 docs/PLAYER_MATRIX.md），倍速 / 画面缩放真实可用。
class PlayerSettingsPanel extends StatefulWidget {
  const PlayerSettingsPanel({
    super.key,
    required this.visible,
    required this.speed,
    required this.displayMode,
    required this.onSelectSpeed,
    required this.onSelectDisplayMode,
    required this.onNotice,
    required this.onDismiss,
  });

  final bool visible;
  final double speed;
  /// 画面缩放：fit（完整显示）/ fill（铺满裁切）/ stretch（拉伸铺满）。
  final String displayMode;
  final ValueChanged<double> onSelectSpeed;
  final ValueChanged<String> onSelectDisplayMode;
  final ValueChanged<String> onNotice;
  final VoidCallback onDismiss;

  @override
  State<PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends State<PlayerSettingsPanel> {
  _SettingsPage _page = _SettingsPage.root;

  static const _speeds = PlayerController.speeds;
  static const _displayModes = <(String, String)>[
    ('fit', '完整显示'),
    ('fill', '铺满裁切'),
    ('stretch', '拉伸铺满'),
  ];

  String get _displayLabel =>
      _displayModes.firstWhere((m) => m.$1 == widget.displayMode).$2;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    Widget row({
      required IconData icon,
      required String label,
      String? value,
      VoidCallback? onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Text(value,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 4),
            if (onTap != null)
              const Icon(McIcons.chevronRight, color: Colors.white38),
          ],
        ),
        onTap: onTap,
      );
    }

    Widget body;
    switch (_page) {
      case _SettingsPage.root:
        body = Column(children: [
          row(
            icon: McIcons.hq,
            label: '画质',
            value: '未实现',
            onTap: () => widget.onNotice('画质选择未实现：会话未提供画质档（见 docs/PLAYER_MATRIX.md）'),
          ),
          row(
            icon: Icons.speed,
            label: '倍速',
            value: widget.speed == 1.0 ? '常速' : '${widget.speed}x',
            onTap: () => setState(() => _page = _SettingsPage.speed),
          ),
          row(
            icon: McIcons.aspectRatio,
            label: '画面缩放',
            value: _displayLabel,
            onTap: () => setState(() => _page = _SettingsPage.display),
          ),
          row(
            icon: Icons.monitor_heart,
            label: '播放诊断',
            onTap: () => widget.onNotice('播放诊断未实现（见 docs/PLAYER_MATRIX.md）'),
          ),
        ]);
      case _SettingsPage.speed:
        body = Column(children: [
          for (final s in _speeds)
            ListTile(
              leading: Icon(
                s == widget.speed ? McIcons.check : Icons.speed,
                color: s == widget.speed ? accent : Colors.white38,
              ),
              title: Text(
                s == 1.0 ? '常速' : '${s}x',
                style: TextStyle(
                    color: s == widget.speed ? accent : Colors.white),
              ),
              onTap: () {
                widget.onSelectSpeed(s);
                widget.onDismiss();
              },
            ),
        ]);
      case _SettingsPage.display:
        body = Column(children: [
          for (final (mode, label) in _displayModes)
            ListTile(
              leading: Icon(
                mode == widget.displayMode ? McIcons.check : McIcons.aspectRatio,
                color: mode == widget.displayMode ? accent : Colors.white38,
              ),
              title: Text(label,
                  style: TextStyle(
                      color:
                          mode == widget.displayMode ? accent : Colors.white)),
              onTap: () {
                widget.onSelectDisplayMode(mode);
                widget.onDismiss();
              },
            ),
        ]);
      case _SettingsPage.quality:
        body = const SizedBox.shrink();
    }

    return AnimatedSlide(
      offset: widget.visible ? Offset.zero : const Offset(1, 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Visibility(
        visible: widget.visible,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Color(0xE610121A),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_page != _SettingsPage.root)
                  BackButton(
                    color: Colors.white70,
                    onPressed: () => setState(() => _page = _SettingsPage.root),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 画面缩放字符串 → BoxFit（PlayerService.buildView 的 fit 参数）。
BoxFit displayModeToBoxFit(String mode) {
  switch (mode) {
    case 'fill':
      return BoxFit.cover;
    case 'stretch':
      return BoxFit.fill;
    case 'fit':
    default:
      return BoxFit.contain;
  }
}
