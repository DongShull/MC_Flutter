// P2：下载目标弹层（`DownloadTargetSheet`，对齐安卓 `DownloadTargetSheet`）：
// 保存位置单选 + “记住本次选择”（仅管理员）+ 候选识别搜索框 + 确认提交。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/features/search/state/torrent_models.dart';
import 'package:mc_flutter/features/search/widgets/torrent_sheets.dart';

DownloadTargetSheet _sheet({
  DownloadFlow? flow,
  List<TargetOption>? options,
  bool isAdmin = true,
  void Function(String)? onSelectOption,
  void Function(ManualDownloadCandidateView)? onSelectCandidate,
  void Function()? onConfirm,
}) {
  return DownloadTargetSheet(
    flow: flow ??
        const DownloadFlow(
          request: DownloadTargetRequest(
            siteId: 's1',
            downloadUrl: 'https://tracker.example/t1',
            identityTitle: '沙丘',
            hitKey: 's1:t1',
          ),
          selected: 'smart',
        ),
    options: options ??
        const [
          TargetOption(
              id: 'smart',
              kind: TargetOptionKind.smart,
              label: '智能入库',
              detail: '自动识别后入库'),
          TargetOption(
              id: 'default',
              kind: TargetOptionKind.fallback,
              label: '下载器默认位置'),
        ],
    isAdmin: isAdmin,
    onSelectOption: onSelectOption ?? (_) {},
    onToggleRemember: (_) {},
    onShowOther: () {},
    onSelectDownloader: (_) {},
    onHintChanged: (_) {},
    onSearchHint: () {},
    onSelectCandidate: onSelectCandidate ?? (_) {},
    onConfirm: onConfirm ?? () {},
  );
}

void main() {
  testWidgets('弹层：标题 + 保存位置单选 + 管理员可见“记住本次选择”',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _sheet())),
    );
    expect(find.text('沙丘'), findsOneWidget);
    expect(find.text('保存位置'), findsOneWidget);
    expect(find.text('智能入库'), findsOneWidget);
    expect(find.text('下载器默认位置'), findsOneWidget);
    expect(find.text('记住本次选择'), findsOneWidget);
    expect(find.text('确认下载'), findsOneWidget);
  });

  testWidgets('成员看不到“记住本次选择”', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _sheet(isAdmin: false))),
    );
    expect(find.text('记住本次选择'), findsNothing);
  });

  testWidgets('未选保存位置时确认按钮禁用；选后回调带回选项 id', (tester) async {
    String? picked;
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _sheet(
            flow: const DownloadFlow(
              request: DownloadTargetRequest(
                siteId: 's1',
                downloadUrl: 'https://tracker.example/t1',
                hint: 'dune',
                hitKey: 's1:t1',
              ),
            ),
            onSelectOption: (id) => picked = id,
            onConfirm: () => confirmed = true,
          ),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('智能入库'));
    await tester.pump();
    expect(picked, 'smart');
    expect(confirmed, isFalse);
  });

  testWidgets('识别失败时显示候选搜索框与候选列表', (tester) async {
    ManualDownloadCandidateView? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _sheet(
            flow: const DownloadFlow(
              request: DownloadTargetRequest(
                siteId: 's1',
                downloadUrl: 'https://tracker.example/t1',
                hint: 'dune',
                hitKey: 's1:t1',
              ),
              picking: true,
              hintDraft: 'dune',
              candidates: [
                ManualDownloadCandidateView(
                    tmdbId: 123, kind: 'movie', title: '沙丘', year: 2021),
              ],
              selected: 'smart',
            ),
            onSelectOption: (_) {},
            onSelectCandidate: (c) => selected = c,
          ),
        ),
      ),
    );
    expect(find.text('这是哪部作品？'), findsOneWidget);
    expect(find.text('沙丘 (2021)'), findsOneWidget);
    await tester.tap(find.text('沙丘 (2021)'));
    await tester.pump();
    expect(selected?.tmdbId, 123);
  });
}
