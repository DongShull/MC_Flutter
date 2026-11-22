// P2 DetailController.loadTrickplay：本地服务器模拟详情 + trickplay。
//
// 纯 test（不用 testWidgets）：TestWidgetsFlutterBinding 会把 HttpClient
// 换成 400 mock，含 widget 测试的文件里真实 Dio 请求必然失败，
// 故控制器网络测试单独放本文件（见 P1 mc_api_envelope_test 同款做法）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/mc_api.dart';
import 'package:mc_flutter/core/api/mc_client.dart';
import 'package:mc_flutter/core/api/session_providers.dart';
import 'package:mc_flutter/core/session/session_store.dart';
import 'package:mc_flutter/features/detail/state/detail_controller.dart';

void main() {
  late HttpServer server;
  late McApi api;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://${server.address.host}:${server.port}';
    api = McApi(
      McClient(session: SessionStore(), baseUrlOverride: base),
    );
    server.listen((req) async {
      final data = switch (req.uri.path) {
        '/api/v1/libraries/2/items/5' => {
            'id': 5,
            'library_id': 2,
            'kind': 'movie',
            'title': 'T',
            'files': [
              {'id': 9},
            ],
          },
        '/api/v1/playback/files/9/trickplay' => {
            'ready': true,
            'interval_ms': 10000,
            'tile_width': 160,
            'tile_height': 90,
            'columns': 10,
            'rows': 10,
            'count': 3,
            'sheets': [],
          },
        _ => {},
      };
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        jsonEncode({'code': 0, 'message': 'ok', 'data': data}),
      );
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('load() 后 trickplay 就绪并带帧数', () async {
    final session = SessionStore()
      ..debugSeed(
        baseUrl: 'http://${server.address.host}:${server.port}',
        token: 'test',
      );
    final container = ProviderContainer(
      overrides: [
        mcApiProvider.overrideWithValue(api),
        sessionStoreProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    final notifier =
        container.read(detailControllerProvider('2:5').notifier);
    await notifier.load();
    final state = container.read(detailControllerProvider('2:5'));
    expect(state.entry?.title, 'T');
    expect(state.trickplay?.ready, isTrue);
    expect(state.trickplay?.count, 3);
    expect(state.trickplay?.intervalMs, 10000);
  });
}
