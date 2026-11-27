import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/player_controller.dart';

enum _SettingsPage { root, speed, display, quality, subtitleStyle, diagnostics }

/// 播放器右侧液态毛玻璃抽屉面板：
/// 倍速 / 画面比例 / 串流画质 / 字幕字号·位置·半透胶囊底·时间轴偏移 / 实时技术诊断。
class PlayerSettingsPanel extends StatefulWidget {
  const PlayerSettingsPanel({
    super.key,
    required this.visible,
    required this.speed,
    required this.displayMode,
    required this.qualityTier,
    required this.subtitleScale,
    required this.subtitleBottomMarginPercent,
    required this.subtitleBackgroundPill,
    required this.subtitleOffsetMs,
    required this.onSelectSpeed,
    required this.onSelectDisplayMode,
    required this.onSelectQuality,
    required this.onSelectSubtitleScale,
    required this.onSelectSubtitleBottomMargin,
    required this.onToggleSubtitleBackgroundPill,
    required this.onAdjustSubtitleOffset,
    required this.onLoadDiagnostics,
    required this.onNotice,
    required this.onDismiss,
  });

  final bool visible;
  final double speed;
  final String displayMode;
  final String qualityTier;
  final double subtitleScale;
  final double subtitleBottomMarginPercent;
  final bool subtitleBackgroundPill;
  final int subtitleOffsetMs;
  final ValueChanged<double> onSelectSpeed;
  final ValueChanged<String> onSelectDisplayMode;
  final ValueChanged<String> onSelectQuality;
  final ValueChanged<double> onSelectSubtitleScale;
  final ValueChanged<double> onSelectSubtitleBottomMargin;
  final ValueChanged<bool> onToggleSubtitleBackgroundPill;
  final ValueChanged<int> onAdjustSubtitleOffset;
  final Future<Map<String, dynamic>> Function() onLoadDiagnostics;
  final ValueChanged<String> onNotice;
  final VoidCallback onDismiss;

  @override
  State<PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends State<PlayerSettingsPanel> {
  _SettingsPage _page = _SettingsPage.root;
  Map<String, dynamic>? _diag;

  static const _speeds = PlayerController.speeds;
  static const _displayModes = <(String, String)>[
    ('fit', '原始比例（完整显示）'),
    ('fill', '铺满屏幕（居中裁切）'),
    ('16:9', '锁定 16:9 宽屏'),
    ('21:9', '锁定 21:9 影院超宽'),
    ('4:3', '锁定 4:3 经典画幅'),
    ('stretch', '拉伸铺满'),
  ];
  static const _qualities = <(String, String)>[
    ('original', '原画直连（自动协商）'),
    ('1080p', '1080P 高清转码'),
    ('720p', '720P 流畅省流'),
    ('480p', '480P 极速弱网'),
  ];

  String get _displayLabel => _displayModes
      .firstWhere(
        (e) => e.$1 == widget.displayMode,
        orElse: () => _displayModes.first,
      )
      .$2;

  String get _qualityLabel => _qualities
      .firstWhere(
        (e) => e.$1 == widget.qualityTier,
        orElse: () => _qualities.first,
      )
      .$2;

  @override
  void didUpdateWidget(covariant PlayerSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && oldWidget.visible) {
      _page = _SettingsPage.root;
      _diag = null;
    }
  }

  Future<void> _openDiagnostics() async {
    setState(() {
      _page = _SettingsPage.diagnostics;
      _diag = null;
    });
    final d = await widget.onLoadDiagnostics();
    if (mounted) setState(() => _diag = d);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final String title = switch (_page) {
      _SettingsPage.root => '播放设置',
      _SettingsPage.speed => '播放倍速',
      _SettingsPage.display => '画面比例',
      _SettingsPage.quality => '串流画质',
      _SettingsPage.subtitleStyle => '字幕样式与时间轴',
      _SettingsPage.diagnostics => '实时技术诊断',
    };

    final offsetSec = (widget.subtitleOffsetMs / 1000).toStringAsFixed(1);

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
              valueText: _qualityLabel,
              showChevron: true,
              onTap: () => setState(() => _page = _SettingsPage.quality),
            ),
            McInsetRow(
              icon: McIcons.fontSetting,
              title: '字幕外观与偏移',
              valueText: widget.subtitleOffsetMs == 0 ? '同步' : '${offsetSec}s',
              showChevron: true,
              onTap: () => setState(() => _page = _SettingsPage.subtitleStyle),
            ),
            McInsetRow(
              icon: McIcons.cpu,
              title: '实时流媒体诊断 (快捷键 I)',
              showChevron: true,
              onTap: _openDiagnostics,
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
      _SettingsPage.quality => McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            for (final (tier, label) in _qualities)
              McInsetRow(
                title: label,
                trailing: tier == widget.qualityTier
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  widget.onSelectQuality(tier);
                  widget.onDismiss();
                },
              ),
          ],
        ),
      _SettingsPage.subtitleStyle => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('字号大小', style: McText.caption.muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (sc, lb) in const [
                  (0.85, '小'),
                  (1.0, '标准'),
                  (1.2, '大'),
                  (1.4, '特大'),
                ])
                  McChip(
                    label: lb,
                    compact: true,
                    selected: (widget.subtitleScale - sc).abs() < 0.05,
                    onTap: () => widget.onSelectSubtitleScale(sc),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '距底高度（${widget.subtitleBottomMarginPercent.round()}%）',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (pct, lb) in const [
                  (4.0, '偏低'),
                  (8.0, '标准'),
                  (14.0, '偏高'),
                  (20.0, '较高'),
                ])
                  McChip(
                    label: lb,
                    compact: true,
                    selected: (widget.subtitleBottomMarginPercent - pct).abs() < 1.5,
                    onTap: () => widget.onSelectSubtitleBottomMargin(pct),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  title: '字幕半透黑底胶囊',
                  subtitle: '关闭后使用柔和阴影，减少画面遮挡',
                  trailing: Switch.adaptive(
                    value: widget.subtitleBackgroundPill,
                    onChanged: widget.onToggleSubtitleBackgroundPill,
                  ),
                  onTap: () => widget.onToggleSubtitleBackgroundPill(
                    !widget.subtitleBackgroundPill,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('时间轴微调（当前：${offsetSec}s）', style: McText.caption.muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                McChip(
                  label: '-0.5s',
                  compact: true,
                  onTap: () => widget.onAdjustSubtitleOffset(-500),
                ),
                McChip(
                  label: '-0.1s',
                  compact: true,
                  onTap: () => widget.onAdjustSubtitleOffset(-100),
                ),
                McChip(
                  label: '归零',
                  compact: true,
                  selected: widget.subtitleOffsetMs == 0,
                  onTap: () => widget.onAdjustSubtitleOffset(0),
                ),
                McChip(
                  label: '+0.1s',
                  compact: true,
                  onTap: () => widget.onAdjustSubtitleOffset(100),
                ),
                McChip(
                  label: '+0.5s',
                  compact: true,
                  onTap: () => widget.onAdjustSubtitleOffset(500),
                ),
              ],
            ),
          ],
        ),
      _SettingsPage.diagnostics => _diag == null
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final e in _diag!.entries)
                  McInsetRow(
                    title: e.key,
                    valueText: '${e.value}',
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
                width: 332,
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
                              icon: McIcons.close,
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

/// 画面缩放字符串 → BoxFit。
BoxFit displayModeToBoxFit(String mode) {
  switch (mode) {
    case 'fill':
      return BoxFit.cover;
    case 'stretch':
      return BoxFit.fill;
    default:
      return BoxFit.contain;
  }
}

/// 画面比例预设 → 强制宽高比（null 表示使用片源原始比例）。
double? displayModeToAspectRatio(String mode) => switch (mode) {
      '16:9' => 16 / 9,
      '21:9' => 21 / 9,
      '4:3' => 4 / 3,
      _ => null,
    };
