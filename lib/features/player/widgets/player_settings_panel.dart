import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/player_controller.dart';

enum _SettingsPage { root, speed, display }

/// 播放器的右侧液态毛玻璃抽屉面板：倍速 / 画面比例 / 画质与诊断。
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

  String get _displayLabel => _displayModes
      .firstWhere((e) => e.$1 == widget.displayMode, orElse: () => _displayModes.first)
      .$2;

  @override
  void didUpdateWidget(covariant PlayerSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && oldWidget.visible) {
      _page = _SettingsPage.root;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final String title = switch (_page) {
      _SettingsPage.root => '播放设置',
      _SettingsPage.speed => '播放倍速',
      _SettingsPage.display => '画面比例',
    };

    final Widget body = switch (_page) {
      _SettingsPage.root => McInsetGroup(
        margin: EdgeInsets.zero,
        children: [
          McInsetRow(
            icon: McIcons.stopwatch,
            title: '播放倍速',
            valueText: widget.speed == 1.0 ? '正常' : '${widget.speed}x',
            showChevron: true,
            onTap: () => setState(() => _page = _SettingsPage.speed),
          ),
          McInsetRow(
            icon: McIcons.aspectRatio,
            title: '画面比例',
            valueText: _displayLabel,
            showChevron: true,
            onTap: () => setState(() => _page = _SettingsPage.display),
          ),
          McInsetRow(
            icon: McIcons.hd,
            title: '串流画质',
            valueText: '自动协商',
            onTap: () {
              widget.onNotice('画质由播放会话自动按带宽与解码能力协商');
              widget.onDismiss();
            },
          ),
        ],
      ),
      _SettingsPage.speed => McInsetGroup(
        margin: EdgeInsets.zero,
        children: [
          for (final s in _speeds)
            McInsetRow(
              title: s == 1.0 ? '1.0x（常速）' : '${s}x',
              trailing: s == widget.speed
                  ? const Icon(
                      McIcons.check,
                      size: 18,
                      color: McTokens.accentStrong,
                    )
                  : null,
              onTap: () {
                widget.onSelectSpeed(s);
                widget.onDismiss();
              },
            ),
        ],
      ),
      _SettingsPage.display => McInsetGroup(
        margin: EdgeInsets.zero,
        children: [
          for (final (mode, label) in _displayModes)
            McInsetRow(
              title: label,
              trailing: mode == widget.displayMode
                  ? const Icon(
                      McIcons.check,
                      size: 18,
                      color: McTokens.accentStrong,
                    )
                  : null,
              onTap: () {
                widget.onSelectDisplayMode(mode);
                widget.onDismiss();
              },
            ),
        ],
      ),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: const ColoredBox(color: Color(0x66000000)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(22),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                width: 316,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xE8131620),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(22),
                  ),
                  border: Border(
                    left: BorderSide(color: McTokens.lineStrong, width: 1),
                  ),
                ),
                child: SafeArea(
                  left: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                        child: Row(
                          children: [
                            if (_page != _SettingsPage.root) ...[
                              McGlassIconButton(
                                icon: McIcons.arrowLeftS,
                                size: 32,
                                iconSize: 18,
                                onTap: () =>
                                    setState(() => _page = _SettingsPage.root),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(child: Text(title, style: McText.titleSm)),
                            McGlassIconButton(
                              icon: McIcons.close2,
                              size: 32,
                              iconSize: 16,
                              onTap: widget.onDismiss,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                          child: body,
                        ),
                      ),
                    ],
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
