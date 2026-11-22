import 'package:flutter/material.dart';

import '../state/player_controller.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/player/player_service.dart';

enum _SettingsPage { root, quality, speed, display, diagnostics }

/// 播放器的 ⋮ 设置面板（Android PlayerSettingsPanel）：横屏从右侧滑出、占满高度，
/// 同 B 站 / 腾讯视频的横屏侧边栏。
/// 画质（P2）：服务端 `max_height` 上限语义，改档走会话重开续播；
/// 播放诊断（P2 最小版）：显示 `collectDiagnostics()` 已有字段，
/// 引擎拿不到的字段标“未实现”。倍速 / 画面缩放真实可用。
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
    this.quality,
    this.qualityFromMemory = false,
    this.onSelectQuality,
    this.onRequestDiagnostics,
  });

  final bool visible;
  final double speed;
  /// 画面缩放：fit（完整显示）/ fill（铺满裁切）/ stretch（拉伸铺满）。
  final String displayMode;
  final ValueChanged<double> onSelectSpeed;
  final ValueChanged<String> onSelectDisplayMode;
  final ValueChanged<String> onNotice;
  final VoidCallback onDismiss;

  /// 当前画质档（null = 未起播，面板显示“原画”默认值）。
  final QualityOption? quality;

  /// 当前画质是否来自记忆（面板显示“已沿用上次的选择”）。
  final bool qualityFromMemory;

  /// 选画质：控制器记入记忆 + 服务端重开续播；失败时调用方提示。
  final ValueChanged<QualityOption>? onSelectQuality;

  /// 采集诊断快照（控制器透传引擎 `collectDiagnostics()`）。
  final Future<PlayerDiagnostics> Function()? onRequestDiagnostics;

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

  /// 画质档说明（安卓 `QualityOption` hint 同口径；上限语义）。
  static const _qualityHints = <int?, String>{
    null: '不限画质：能直通就播原文件，放不了时按原分辨率转码',
    1080: '约 6 Mbps',
    720: '约 3 Mbps，网络一般时选它',
    480: '约 1.5 Mbps，弱网救急',
  };

  /// 诊断快照（进诊断页时采一次；null = 未采集）。
  PlayerDiagnostics? _diagnostics;
  bool _diagnosticsLoading = false;
  String? _diagnosticsError;

  String get _displayLabel =>
      _displayModes.firstWhere((m) => m.$1 == widget.displayMode).$2;

  String get _qualityLabel => widget.quality?.label ?? QualityOption.original.label;

  Future<void> _loadDiagnostics() async {
    final request = widget.onRequestDiagnostics;
    if (request == null) {
      setState(() => _diagnosticsError = '当前后端不支持诊断采集');
      return;
    }
    setState(() {
      _diagnosticsLoading = true;
      _diagnosticsError = null;
    });
    try {
      final d = await request();
      if (mounted) setState(() => _diagnostics = d);
    } catch (e) {
      if (mounted) setState(() => _diagnosticsError = '采集失败：$e');
    } finally {
      if (mounted) setState(() => _diagnosticsLoading = false);
    }
  }

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
            value: _qualityLabel,
            onTap: () => setState(() => _page = _SettingsPage.quality),
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
            onTap: () {
              setState(() => _page = _SettingsPage.diagnostics);
              _loadDiagnostics();
            },
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
        body = Column(children: [
          if (widget.qualityFromMemory)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('已沿用上次的选择（按影片 × 网络记忆）',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          for (final q in QualityOption.all)
            ListTile(
              leading: Icon(
                widget.quality?.maxHeight == q.maxHeight
                    ? McIcons.check
                    : McIcons.hq,
                color: widget.quality?.maxHeight == q.maxHeight
                    ? accent
                    : Colors.white38,
              ),
              title: Text(
                q.label,
                style: TextStyle(
                    color: widget.quality?.maxHeight == q.maxHeight
                        ? accent
                        : Colors.white),
              ),
              subtitle: Text(
                _qualityHints[q.maxHeight] ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                widget.onSelectQuality?.call(q);
                widget.onDismiss();
              },
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('画质是上限：源不超所选档就照常直通；改档需重开播放会话。',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ]);
      case _SettingsPage.diagnostics:
        body = _DiagnosticsBody(
          diagnostics: _diagnostics,
          loading: _diagnosticsLoading,
          error: _diagnosticsError,
          onRetry: _loadDiagnostics,
        );
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
            // ListTile 的水波纹画在最近的 Material 上：面板是带背景色的
            // Container，必须在里面放一层透明 Material，否则 debug 下断言
            // “ListTile background color or ink splashes may be invisible”。
            child: Material(
              color: Colors.transparent,
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
      ),
    );
  }
}

/// 诊断面板最小版：只显示 `PlayerDiagnostics` 已有字段；
/// 引擎拿不到的字段（掉帧/码率/解码器）值为 null，明确标“未实现”，不编数字。
/// 对照安卓 `DiagnosticsReport` / web `diagnostics-panel.tsx` 的两节结构
/// （源是什么 → 做了什么），Flutter 侧目前只有引擎可读字段。
class _DiagnosticsBody extends StatelessWidget {
  const _DiagnosticsBody({
    required this.diagnostics,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final PlayerDiagnostics? diagnostics;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  static String _fmtDuration(Duration? d) {
    if (d == null) return '未实现';
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading && diagnostics == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && diagnostics == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }
    final d = diagnostics;
    if (d == null) return const SizedBox.shrink();
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('源是什么',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        row('引擎', d.engine),
        row('会话', d.sessionId ?? '未实现'),
        row('位置 / 时长', '${_fmtDuration(d.position)} / ${_fmtDuration(d.duration)}'),
        row('播放中', d.playing ? '是' : '否'),
        row('缓冲中', d.buffering ? '是' : '否'),
        row('已缓冲', '${d.bufferedSeconds.toStringAsFixed(1)} 秒'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('做了什么（引擎读数）',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        row('掉帧', d.droppedFrames?.toString() ?? '未实现'),
        row('总帧数', d.totalFrames?.toString() ?? '未实现'),
        row('码率', d.bitrateBps == null ? '未实现' : '${(d.bitrateBps! / 1000).toStringAsFixed(0)} kbps'),
        row('解码器', d.decoderName ?? '未实现'),
        row('硬件加速',
            d.hardwareAccelerated == null ? '未实现' : (d.hardwareAccelerated! ? '是' : '否')),
        row('卡顿次数', '${d.rebufferCount} 次'),
        row('卡顿时长', '${d.rebufferMs} 毫秒'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextButton(onPressed: onRetry, child: const Text('刷新')),
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
