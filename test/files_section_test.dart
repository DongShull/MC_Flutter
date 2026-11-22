// P2：详情页文件区（`FilesSection`，对齐安卓 `FilesSection`）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/features/detail/state/detail_controller.dart';
import 'package:mc_flutter/features/detail/widgets/files_section.dart';

void main() {
  const files = [
    DetailFile(
      id: 11,
      fileName: 'Dune.2021.2160p.mkv',
      filePath: '/media/movies/Dune.2021.2160p.mkv',
      sizeBytes: 20 * 1024 * 1024 * 1024,
      container: 'mkv',
      resolution: '2160p',
      videoCodec: 'hevc',
      hdr: 'HDR10',
      durationSeconds: 9300,
      bitRate: 45000000,
      frameRate: 23.976,
      bitDepth: 10,
    ),
    DetailFile(
      id: 12,
      fileName: 'Dune.2021.1080p.mkv',
      sizeBytes: 8 * 1024 * 1024 * 1024,
      missing: true,
    ),
  ];

  testWidgets('文件区：列出文件名与大小，缺失文件标注', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilesSection(files: files, onDelete: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text('文件（2）'), findsOneWidget);
    expect(find.text('Dune.2021.2160p.mkv'), findsOneWidget);
    expect(find.text('Dune.2021.1080p.mkv'), findsOneWidget);
    expect(find.textContaining('20.0 GB'), findsOneWidget);
    expect(find.textContaining('已缺失'), findsOneWidget);
  });

  testWidgets('展开一行：显示规格详情；点删除回调带回文件', (tester) async {
    DetailFile? deleted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilesSection(
              files: files,
              onDelete: (f) => deleted = f,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dune.2021.2160p.mkv'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2160p'), findsWidgets);
    expect(find.textContaining('hevc'), findsOneWidget);
    expect(find.textContaining('/media/movies/Dune.2021.2160p.mkv'),
        findsOneWidget);
    await tester.tap(find.text('删除文件').first);
    await tester.pump();
    expect(deleted?.id, 11);
  });

  testWidgets('空文件列表不渲染任何内容', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilesSection(files: [], onDelete: _noop),
        ),
      ),
    );
    expect(find.textContaining('文件'), findsNothing);
  });
}

void _noop(DetailFile _) {}
