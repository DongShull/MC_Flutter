// P2 字幕生成页：FakeMcApi 预设预检与提交，验证整页走通类型化 McApi。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/mc_api.dart';
import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/features/detail/pages/subtitle_gen_page.dart';

import 'p2_fakes.dart';

void main() {
  late FakeMcApi api;

  setUp(() {
    api = FakeMcApi();
    api.subtitlePreview = const SubtitleGenPreviewView(
      candidates: [
        SubtitleGenCandidateView(
          kind: 'ai',
          key: 'c1',
          language: 'chs',
          format: 'srt',
          selectable: true,
        ),
      ],
      chosenKey: 'c1',
      eventCount: 10,
      estimatedTokens: 100,
      outputFilename: 'test.chs.srt',
    );
  });

  Widget page() => ProviderScope(
        overrides: [mcApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: SubtitleGenPage(fileId: 7, title: '测试影片'),
        ),
      );

  testWidgets('预检展示候选与目标语言，提交后显示任务号', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('测试影片'), findsOneWidget);
    expect(find.text('目标语言'), findsOneWidget);
    expect(find.text('字幕来源'), findsOneWidget);
    expect(find.text('ai · chs · srt'), findsOneWidget);
    expect(find.text('输出：test.chs.srt · 约 10 条 · 约 100 tokens'),
        findsOneWidget);
    expect(find.text('开始生成'), findsOneWidget);
    expect(api.requests, contains('preview:7'));

    await tester.tap(find.text('开始生成'));
    await tester.pumpAndSettle();

    expect(find.text('已提交生成任务'), findsOneWidget);
    expect(find.text('任务号：job-1'), findsOneWidget);
    expect(find.text('在活动页查看进度'), findsOneWidget);
    expect(api.requests, contains('submit:7'));
  });

  testWidgets('blocker 预检如实展示且不可提交', (tester) async {
    api.subtitlePreview = const SubtitleGenPreviewView(
      blocker: SubtitleGenBlockerView(
        code: 'no_audio',
        title: '无法生成字幕',
        message: '该文件没有可识别的音轨',
        suggestions: ['换一个带音轨的文件重试'],
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('无法生成字幕'), findsOneWidget);
    expect(find.text('该文件没有可识别的音轨'), findsOneWidget);
    expect(find.text('· 换一个带音轨的文件重试'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始生成'),
    );
    expect(button.onPressed, isNull);
    expect(api.requests, isNot(contains('submit:7')));
  });
}
