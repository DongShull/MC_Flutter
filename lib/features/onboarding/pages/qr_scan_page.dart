import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/qr_connect.dart';

/// 扫码连服务器 / 批准配对码：全屏暗场相机 + 浮动银玻璃顶栏 + 冷银角标取景框。
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, this.popRaw = false});

  /// true = 设备登录配对扫码（严格按 `PairingQrParser` 校验，原样带回完整原始二维码/配对码）；
  /// false = 服务器连接扫码（走 `parseServerQr` 提取服务器地址）。
  final bool popRaw;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  DateTime? _lastInvalidToastAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notifyInvalidPairingQr() {
    final now = DateTime.now();
    if (_lastInvalidToastAt != null &&
        now.difference(_lastInvalidToastAt!) < const Duration(milliseconds: 2400)) {
      return;
    }
    _lastInvalidToastAt = now;
    McToast.error('这不是 MovieClaw 的登录二维码');
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = (barcode.rawValue ?? '').trim();
      if (raw.isEmpty) continue;

      if (widget.popRaw) {
        // 配对扫码模式：绝不走 `parseServerQr`（会截断 `?code=`），只认 MovieClaw 登录二维码。
        final parsed = PairingQrParser.parse(raw);
        if (parsed != null) {
          _handled = true;
          Navigator.of(context).pop(raw);
          return;
        }
        _notifyInvalidPairingQr();
        continue;
      }

      final info = parseServerQr(raw);
      if (info != null) {
        _handled = true;
        Navigator.of(context).pop(info.baseUrl);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      McIcons.cameraOff,
                      size: 36,
                      color: McTokens.textFaint,
                    ),
                    const SizedBox(height: 12),
                    const Text('无法开启相机', style: McText.titleSm),
                    const SizedBox(height: 6),
                    Text(
                      '请检查相机权限（${error.errorCode.name}）',
                      textAlign: TextAlign.center,
                      style: McText.caption.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 四周暗角聚焦取景框
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 248,
                height: 248,
                child: CustomPaint(painter: _ReticlePainter()),
              ),
            ),
          ),
          // 顶部浮动液态玻璃栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: () => Navigator.of(context).pop(),
              title: widget.popRaw ? '扫码配对' : '扫码连接',
              titleVisible: true,
              trailing: [
                McGlassIconButton(
                  icon: McIcons.lightning,
                  tooltip: '手电筒',
                  onTap: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),
          // 底部玻璃胶囊提示
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 28,
            child: Center(
              child: McLiquidGlass(
                radius: McTokens.pillRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Text(
                  widget.popRaw
                      ? '将取景框对准电视或新设备上的登录二维码'
                      : '将取景框对准服务器分享二维码即可自动填入地址',
                  textAlign: TextAlign.center,
                  style: McText.caption.copyWith(color: McTokens.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = McTokens.lineStrong,
    );

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = McTokens.accentStrong;

    const len = 26.0;
    const r = 22.0;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(len, 0)
      ..moveTo(w - len, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, len)
      ..moveTo(w, h - len)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - len, h)
      ..moveTo(len, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - len);

    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
