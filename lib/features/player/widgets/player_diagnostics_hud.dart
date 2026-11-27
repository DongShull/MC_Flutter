import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';

/// 实时技术诊断浮窗（对齐 iOS `PlayerDiagnosticsPanel.swift`）：
/// - 打开期间每 2 秒自动轮询刷新；
/// - 展示引擎、交付模式、HDR/编码、码率/实时带宽、前方缓冲秒数、卡顿次数；
/// - 支持一键复制 Session ID。
class PlayerDiagnosticsHud extends StatefulWidget {
  const PlayerDiagnosticsHud({
    super.key,
    required this.onFetch,
    required this.onClose,
    this.sessionId,
  });

  final Future<Map<String, dynamic>> Function() onFetch;
  final VoidCallback onClose;
  final String? sessionId;

  @override
  State<PlayerDiagnosticsHud> createState() => _PlayerDiagnosticsHudState();
}

class _PlayerDiagnosticsHudState extends State<PlayerDiagnosticsHud> {
  Map<String, dynamic>? _diag;
  Timer? _pollTimer;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.onFetch();
      if (mounted) setState(() => _diag = data);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _copySessionId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sid = widget.sessionId ?? _diag?['会话 ID']?.toString();
    return McLiquidGlass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310, maxHeight: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  McIcons.cpu,
                  size: 14,
                  color: McTokens.accentStrong,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '实时技术诊断',
                    style: McText.caption.semibold.copyWith(color: Colors.white),
                  ),
                ),
                McGlassIconButton(
                  icon: McIcons.close,
                  size: 26,
                  iconSize: 13,
                  onTap: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_diag == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in _diag!.entries)
                        if (e.key != '会话 ID')
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    e.key,
                                    style: McText.micro.copyWith(
                                      color: McTokens.textMuted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${e.value}',
                                    style: McText.micro
                                        .copyWith(color: Colors.white)
                                        .tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (sid != null && sid.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, color: McTokens.line),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _copySessionId(sid),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Session: $sid',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: McText.micro
                                      .copyWith(color: McTokens.textMuted)
                                      .tabular,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _copied ? '已复制' : '复制',
                                style: McText.micro.copyWith(
                                  color: McTokens.accentStrong,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
