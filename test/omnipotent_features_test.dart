import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/session/permissions.dart';
import 'package:mc_flutter/core/session/session_store.dart';
import 'package:mc_flutter/features/agent/state/agent_state.dart';
import 'package:mc_flutter/features/agent/state/models.dart';
import 'package:mc_flutter/features/agent/widgets/bubble.dart';
import 'package:mc_flutter/features/search/pages/search_page.dart';
import 'package:mc_flutter/features/settings/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appSession.debugSeed(
      baseUrl: 'https://mc.local',
      token: 'tok',
      permissions: const McPermissions(
        username: 'admin',
        role: 'admin',
        isAdmin: true,
        allowSubscribe: true,
        allowSearch: true,
        allowDirectDownload: true,
        allowVideoDownload: true,
      ),
    );
  });

  tearDown(() {
    appSession.logoutForTest();
  });

  testWidgets('SearchPage exposes all 3 search verticals (影视 / 站点资源 / 媒体库)',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SearchPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('影视'), findsWidgets);
    expect(find.text('站点资源'), findsWidgets);
    expect(find.text('媒体库'), findsWidgets);

    await tester.tap(find.text('站点资源').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('搜索 PT 站点资源'), findsWidgets);
  });

  testWidgets('SettingsPage renders full native admin catalog on wide desktop viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('设置与控制中心'), findsWidgets);
    expect(find.text('自动化流水线巡检'), findsWidgets);
    expect(find.text('PT 索引站点与插件同步'), findsWidgets);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('MovieClaw Cloud'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('MovieClaw Cloud'), findsWidgets);
    expect(find.text('MCP 服务'), findsWidgets);
  });

  testWidgets('SettingsPage hides admin sections for non-admin member',
      (tester) async {
    appSession.debugSeed(
      baseUrl: 'https://mc.local',
      token: 'member-tok',
      permissions: const McPermissions(
        username: 'alice',
        role: 'member',
        isAdmin: false,
      ),
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('通知偏好'), findsWidgets);
    expect(find.text('语言设置'), findsWidgets);
    expect(find.text('关于 MovieClaw'), findsWidgets);
    expect(find.text('自动化流水线巡检'), findsNothing);
    expect(find.text('MCP 服务'), findsNothing);
  });

  testWidgets('Agent BubbleView renders structured Markdown & show_media_cards_v1',
      (tester) async {
    final cardsPayload = jsonEncode(<String, dynamic>{
      'cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': '星际穿越',
          'year': 2014,
          'rating': 9.4,
          'title_ref': 'tmdb:movie:157336',
          'overview': '穿越虫洞寻找人类新家园的硬核科幻史诗。',
        },
      ],
    });
    final toolCall = ToolCall(
      id: 'tc-1',
      name: 'show_media_cards_v1',
      arguments: cardsPayload,
    );
    final extracted = AgentMediaCard.extractFromToolCalls(<ToolCall>[toolCall]);
    expect(extracted, hasLength(1));
    expect(extracted.first.title, '星际穿越');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                BubbleView(
                  bubble: Bubble(
                    id: 'proc-1',
                    role: 'process',
                    text: '',
                    toolCalls: <ToolCall>[toolCall],
                    mediaCards: extracted,
                    processSummary: '调用 1 次工具',
                  ),
                ),
                const BubbleView(
                  bubble: Bubble(
                    id: 'msg-1',
                    role: 'assistant',
                    text: '## 今晚科幻片单\n- **星际穿越** `4K HDR`\n```bash\nmc subscribe 157336\n```',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('星际穿越'), findsOneWidget);
    expect(find.text('一键订阅'), findsOneWidget);
    expect(find.text('今晚科幻片单'), findsOneWidget);
    expect(find.text('mc subscribe 157336'), findsOneWidget);
  });
}
