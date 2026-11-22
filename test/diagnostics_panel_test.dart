// P2：播放设置面板的诊断页（最小版）：显示 `collectDiagnostics()` 已有
// 字段，拿不到的字段（掉帧/码率/解码器）明确标“未实现”，不编数字。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/player_service.dart';
import 'package:mc_flutter/features/player/widgets/player_settings_panel.dart';

Widget _panel({required Future<PlayerDiagnostics> Function()? onRequest}) {
  return MaterialApp(
    home: Scaffold(
      body: PlayerSettingsPanel(
        visible: true,
        speed: 1.0,
        displayMode: 'fit',
        onSelectSpeed: (_) {},
        onSelectDisplayMode: (_) {},
        onNotice: (_) {},
        onDismiss: () {},
        onRequestDiagnostics: onRequest,
      ),
    ),
  );
}

Future<void> _openDiagnostics(WidgetTester tester) async {
  await tester.tap(find.text('播放诊断'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('诊断页：已有字段显示真实值，拿不到的标“未实现”', (tester) async {
    await tester.pumpWidget(_panel(
      onRequest: () async => const PlayerDiagnostics(
        engine: 'AVPlayer (video_player_avfoundation)',
        position: Duration(minutes: 10, seconds: 30),
        duration: Duration(hours: 2),
        playing: true,
        buffering: false,
        bufferedSeconds: 42.5,
        sessionId: 'sess-1',
        rebufferCount: 3,
        rebufferMs: 1200,
      ),
    ));
    await _openDiagnostics(tester);
    expect(find.textContaining('AVPlayer'), findsOneWidget);
    expect(find.textContaining('sess-1'), findsOneWidget);
    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.textContaining('42.5'), findsOneWidget);
    // 掉帧/总帧数/码率/解码器/硬件加速：后端拿不到，标“未实现”。
    expect(find.text('未实现'), findsNWidgets(5));
  });

  testWidgets('诊断页：后端不支持采集时显示错误，不崩', (tester) async {
    await tester.pumpWidget(_panel(onRequest: null));
    await _openDiagnostics(tester);
    expect(find.textContaining('不支持诊断采集'), findsOneWidget);
  });

  testWidgets('画质页：四档 + hint 文案可点选', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerSettingsPanel(
            visible: true,
            speed: 1.0,
            displayMode: 'fit',
            onSelectSpeed: (_) {},
            onSelectDisplayMode: (_) {},
            onNotice: (_) {},
            onDismiss: () {},
            quality: QualityOption.original,
            onSelectQuality: (q) => picked = q.label,
          ),
        ),
      ),
    );
    await tester.tap(find.text('画质'));
    await tester.pumpAndSettle();
    expect(find.text('原画'), findsWidgets);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);
    expect(find.text('480p'), findsOneWidget);
    await tester.tap(find.text('720p'));
    await tester.pump();
    expect(picked, '720p');
  });
}
