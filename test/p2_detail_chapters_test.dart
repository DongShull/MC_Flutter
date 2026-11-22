// P2 详情「章节 / 字幕」区纯 widget 渲染（字幕轨 / 预览图就绪态 / 空态）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/features/detail/widgets/chapters_subtitles.dart';

void main() {
  testWidgets('有字幕轨与就绪预览图时展示两者', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChaptersSubtitlesSection(
            subtitleTracks: const ['中文', 'English'],
            trickplay: const TrickplayView(
              ready: true,
              intervalMs: 10000,
              count: 5,
            ),
            trickplayLoading: false,
            regeneratingChapters: false,
            onGenerateSubtitle: () {},
            onRegenerateChapters: () {},
          ),
        ),
      ),
    );
    expect(find.text('章节 / 字幕'), findsOneWidget);
    expect(find.text('中文 / English'), findsOneWidget);
    expect(find.text('预览图已就绪 · 5 帧 · 每 10 秒一帧'), findsOneWidget);
    expect(find.text('生成字幕'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
  });

  testWidgets('无预览图时如实展示空态，不编造', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChaptersSubtitlesSection(
            subtitleTracks: const [],
            trickplay: null,
            trickplayLoading: false,
            regeneratingChapters: false,
            onGenerateSubtitle: () {},
            onRegenerateChapters: () {},
          ),
        ),
      ),
    );
    expect(find.text('暂无内嵌字幕轨'), findsOneWidget);
    expect(find.text('暂无章节预览图'), findsOneWidget);
  });
}
