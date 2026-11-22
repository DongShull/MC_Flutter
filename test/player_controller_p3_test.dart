import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/api/session_providers.dart';
import 'package:mc_flutter/core/player/playback_memory.dart';
import 'package:mc_flutter/core/player/player_service.dart' as ps;
import 'package:mc_flutter/core/player/session/playback_session_api.dart';
import 'package:mc_flutter/core/session/session_store.dart';
import 'package:mc_flutter/features/player/state/player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P3 假后端：在 P1 `FakePlayerService` 的基础上加
/// - `failOpens`：接下来 N 次 open 失败（抛错 + failed 态），再成功；
/// - `failNow()`：播放中引擎失败（走 `_onEngineState` → 重连回路）；
/// - `setPosition`：直接拨动位置通知器，模拟自然播放前进；
/// - 记录 `setQuality` / `setSpeed` 调用（记忆应用断言用）。
class P3FakePlayerService implements ps.PlayerService {
  final _states = StreamController<ps.PlaybackState>.broadcast();
  ps.PlaybackState _state = const ps.PlaybackState();
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration =
      ValueNotifier<Duration?>(const Duration(milliseconds: 2700000));

  int failOpens = 0;
  final qualities = <ps.QualityOption>[];
  final speeds = <double>[];

  void _emit(ps.PlaybackState next) {
    _state = next;
    _states.add(next);
  }

  /// 播放中引擎失败（与 open 失败不同：走重连回路）。
  void failNow([String error = 'fake engine failure']) {
    _emit(_state.copyWith(
      status: ps.PlayerStatus.failed,
      error: error,
    ));
  }

  /// 直接拨动位置（模拟自然播放前进；触发控制器的 `_onPosition`）。
  void setPosition(Duration position) {
    _position.value = position;
    _emit(_state.copyWith(position: position));
  }

  @override
  ps.PlayerBackendKind get kind => ps.PlayerBackendKind.generic;

  @override
  ps.PlayerCapability get capabilities => const ps.PlayerCapability(
        inEngineAudioTrackSwitch: true,
        qualitySelection: true,
      );

  @override
  Stream<ps.PlaybackState> get stateStream => _states.stream;

  @override
  ps.PlaybackState get state => _state;

  @override
  Future<void> open(ps.PlayerRequest request) async {
    if (failOpens > 0) {
      failOpens--;
      _emit(_state.copyWith(
        status: ps.PlayerStatus.failed,
        error: 'fake engine failure',
      ));
      throw StateError('fake engine failure');
    }
    _emit(_state.copyWith(status: ps.PlayerStatus.opening, clearError: true));
    await Future<void>.delayed(Duration.zero);
    _duration.value = const Duration(milliseconds: 2700000);
    _position.value = request.startPosition ?? Duration.zero;
    _playing.value = true;
    _emit(ps.PlaybackState(
      status: ps.PlayerStatus.ready,
      playing: true,
      position: _position.value,
      duration: _duration.value,
    ));
  }

  @override
  Future<void> play() async {
    _playing.value = true;
    _emit(_state.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    _playing.value = false;
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> seekTo(Duration position) async {
    final clamped = position.isNegative
        ? Duration.zero
        : (position > (_duration.value ?? position)
            ? _duration.value!
            : position);
    _position.value = clamped;
    _emit(_state.copyWith(position: clamped));
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
    _emit(_state.copyWith(speed: speed));
  }

  @override
  Future<void> close() async {
    _position.value = Duration.zero;
    _playing.value = false;
    _duration.value = null;
    _emit(const ps.PlaybackState(status: ps.PlayerStatus.idle));
  }

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration?> get duration => _duration;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) => const SizedBox.expand();

  @override
  Future<void> selectAudioTrack(String trackId) async {}

  @override
  Future<void> selectSubtitleTrack(String trackId) async {
    throw UnsupportedError('fake: no subtitle tracks');
  }

  @override
  Future<List<ps.PlayerTrack>> getAudioTracks() async => const [];

  @override
  Future<List<ps.SubtitleTrack>> getSubtitleTracks() async => const [];

  @override
  Future<void> setQuality(ps.QualityOption quality) async {
    qualities.add(quality);
  }

  @override
  Future<void> loadExternalSubtitle(Uri url) async {
    throw UnsupportedError('fake: no external subtitles');
  }

  @override
  Future<ps.PlayerDiagnostics> collectDiagnostics(
      {String? sessionId}) async {
    return ps.PlayerDiagnostics(
      engine: 'fake',
      position: _position.value,
      duration: _duration.value,
      playing: _playing.value,
      sessionId: sessionId,
    );
  }
}

/// flutter_test 默认把 HttpClient 换成返回 400 的假实现；
/// 会话测试要走回环真服务器，先换回真实 HttpClient。
/// （super 直接建真客户端；写 `HttpClient()` 会无限递归栈溢出。）
// ignore_for_file: unnecessary_overrides
class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

/// 等控制器的 unawaited 异步链跑完（假后端全是零延时 future）。
Future<void> settle([int rounds = 5]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer(
    P3FakePlayerService fake, {
    SessionStore? session,
  }) {
    return ProviderContainer(overrides: [
      playerServiceProvider.overrideWithValue(fake),
      if (session != null) sessionStoreProvider.overrideWithValue(session),
    ]);
  }

  group('自动跳过 / 手动跳过（直连路径）', () {
    late ProviderContainer container;
    late PlayerController controller;
    late P3FakePlayerService fake;

    setUp(() async {
      fake = P3FakePlayerService();
      container = makeContainer(fake);
      controller = container.read(playerControllerProvider.notifier);
      await controller.open(const PlayerPageArgs(
        url: 'https://example.com/a.mp4',
      ));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);
      addTearDown(() {
        controller.detach();
        container.dispose();
      });
    });

    test('广告段自然播进就跳过，提示“已跳过广告”', () async {
      controller.updateSkipSegments([
        const PlaybackSkipSegment(type: 'ad', startMs: 0, endMs: 20000),
        const PlaybackSkipSegment(
            type: 'intro', startMs: 60000, endMs: 150000),
      ]);
      // 先拨到 11 秒（大跳不触发），再自然前进到 12 秒（前进 1 秒触发）。
      fake.setPosition(const Duration(seconds: 11));
      await settle();
      expect(controller.state.position, const Duration(seconds: 11));
      fake.setPosition(const Duration(seconds: 12));
      await settle();
      expect(controller.state.position, const Duration(seconds: 20));
      expect(controller.state.skipNotice?.text, '已跳过广告');
    });

    test('片头不自动跳（没学过）；手动跳过后记“学过”', () async {
      controller.updateSkipSegments([
        const PlaybackSkipSegment(
            type: 'intro', startMs: 60000, endMs: 150000),
      ]);
      fake.setPosition(const Duration(seconds: 61));
      await settle();
      fake.setPosition(const Duration(seconds: 62));
      await settle();
      // 没学过：片头不自动跳。
      expect(controller.state.position, const Duration(seconds: 62));
      expect(controller.state.skipNotice, isNull);

      // 手动跳过：位置到段尾，提示“已跳过片头”。
      await controller.skipSegment(const PlaybackSkipSegment(
          type: 'intro', startMs: 60000, endMs: 150000));
      await settle();
      expect(controller.state.position, const Duration(seconds: 150));
      expect(controller.state.skipNotice?.text, '已跳过片头');
    });

    test('撤回：跳过提示的操作回到段首', () async {
      controller.updateSkipSegments([
        const PlaybackSkipSegment(
            type: 'intro', startMs: 60000, endMs: 150000),
      ]);
      fake.setPosition(const Duration(seconds: 70));
      await settle();
      await controller.skipSegment(const PlaybackSkipSegment(
          type: 'intro', startMs: 60000, endMs: 150000));
      await settle();
      expect(controller.state.position, const Duration(seconds: 150));
      await controller.handleSkipNoticeAction();
      await settle();
      expect(controller.state.position, const Duration(seconds: 60));
      expect(controller.state.skipNotice, isNull);
    });
  });

  group('重连（直连路径）', () {
    late ProviderContainer container;
    late PlayerController controller;
    late P3FakePlayerService fake;

    setUp(() async {
      fake = P3FakePlayerService();
      container = makeContainer(fake);
      controller = container.read(playerControllerProvider.notifier);
      await controller.open(const PlayerPageArgs(
        url: 'https://example.com/a.mp4',
      ));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);
      addTearDown(() {
        controller.detach();
        container.dispose();
      });
    });

    test('播放中失败一次：立即重开恢复 ready', () async {
      fake.failNow();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);
      expect(controller.state.reconnectAttempt, 0);
    });

    test('连续失败 2 次：预算内重开失败后走 2 秒退避再恢复', () async {
      fake.failOpens = 2;
      fake.failNow();
      // 预算内的两次立即重开很快失败，随后进入第一次 2 秒退避：
      // 退避等待期间 reconnectAttempt 为 1（重开成功后 open() 会清零，
      // 所以只能在等待期间断言）。
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await settle();
      expect(controller.state.reconnectAttempt, 1);
      await Future<void>.delayed(const Duration(seconds: 3));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);
    });

    test('一直失败：退避耗尽后落 failed（fakeAsync 驱动 70 秒）', () {
      // 注意：容器、open、failNow 全要在 fakeAsync 内完成——
      // 引擎失败回调的 microtask 挂在 listen 注册时的 zone，
      // setUp 里（真实时间）注册的监听在 fakeAsync 的 elapse 里
      // 冲不动，会卡在 opening（实测）。
      fakeAsync((async) {
        final localFake = P3FakePlayerService();
        final localContainer = ProviderContainer(overrides: [
          playerServiceProvider.overrideWithValue(localFake),
        ]);
        final localController =
            localContainer.read(playerControllerProvider.notifier);
        unawaited(localController.open(const PlayerPageArgs(
          url: 'https://example.com/a.mp4',
        )));
        async.elapse(const Duration(seconds: 1));
        expect(localController.state.status, PlayerStatus.ready);
        localFake.failOpens = 100;
        localFake.failNow();
        // 2+4+8+15+15+15 = 59 秒退避走完，再放 10 秒余量。
        async.elapse(const Duration(seconds: 70));
        expect(localController.state.status, PlayerStatus.failed);
        expect(localController.state.error, contains('fake engine failure'));
        localController.detach();
        localContainer.dispose();
      });
    });
  });

  group('会话路径（本地服务器桩）', () {
    late HttpServer server;
    late SessionStore session;
    late ProviderContainer container;
    late PlayerController controller;
    late P3FakePlayerService fake;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl =
          'http://${server.address.address}:${server.port}';
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/playback/sessions')) {
          request.response.write(jsonEncode({
            'code': 'OK',
            'data': {
              'decision': 'plan',
              'session_id': 'sess-1',
              'stream_url': 'https://example.com/s.mp4',
              'start_ms': 0,
              'segments': [
                {
                  'type': 'ad',
                  'start_ms': 0,
                  'end_ms': 20000,
                },
                {
                  'type': 'intro',
                  'start_ms': 60000,
                  'end_ms': 150000,
                },
                {
                  'type': 'outro',
                  'start_ms': 2550000,
                  'end_ms': 2700000,
                  'to_end': true,
                },
              ],
            },
          }));
        } else {
          request.response.write(jsonEncode({'code': 'OK', 'data': {}}));
        }
        await request.response.close();
      });
      session = SessionStore()..debugSeed(baseUrl: baseUrl, token: 't');
      fake = P3FakePlayerService();
      container = makeContainer(fake, session: session);
      controller = container.read(playerControllerProvider.notifier);
      addTearDown(() async {
        controller.detach();
        container.dispose();
        await server.close(force: true);
      });
    });

    test('会话返回的 segments 进状态；片尾播进启动 8 秒 UpNext 倒计时',
        () async {
      await controller.open(const PlayerPageArgs(
        url: 'https://example.com/a.mp4',
        mediaItemId: 42,
      ));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);
      expect(controller.state.skipSegments.length, 3);

      fake.setPosition(const Duration(milliseconds: 2560000));
      await settle();
      expect(controller.state.upNextVisible, isTrue);
      expect(controller.state.upNextSecondsLeft, 8);

      controller.requestAutoNext();
      expect(controller.state.autoNextRequested, isTrue);
    });

    test('手动跳过片头：学过并持久化；5 秒后追加提示；“不用”取消学习',
        () async {
      await controller.open(const PlayerPageArgs(
        url: 'https://example.com/a.mp4',
        mediaItemId: 42,
      ));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);

      fake.setPosition(const Duration(seconds: 70));
      await settle();
      await controller.skipSegment(const PlaybackSkipSegment(
          type: 'intro', startMs: 60000, endMs: 150000));
      await settle();
      expect(controller.state.position, const Duration(seconds: 150));
      expect(controller.state.skipNotice?.text, '已跳过片头');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PlayerController.introLearnedKey),
          contains('42'));

      // 提示 5 秒后追加“本剧以后自动跳过片头 · 不用”。
      await Future<void>.delayed(const Duration(milliseconds: 5500));
      expect(controller.state.skipNotice?.text, '本剧以后自动跳过片头');
      expect(controller.state.skipNotice?.action,
          PlayerNoticeAction.unlearnIntro);

      await controller.handleSkipNoticeAction();
      await settle();
      expect(controller.state.infoNotice, '本剧不再自动跳过片头');
      expect(prefs.getString(PlayerController.introLearnedKey),
          isNot(contains('42')));
    });

    test('画质/倍速记忆：会话开播沿用上次的选择并提示', () async {
      final prefs = await SharedPreferences.getInstance();
      // stream_url 的 host 是 example.com → 外网环境。
      await QualityMemory(SharedPreferencesStringStore(prefs))
          .remember(720, 42, PlaybackNetwork.away);
      await SpeedMemory(SharedPreferencesStringStore(prefs))
          .remember(1.5, 42);

      await controller.open(const PlayerPageArgs(
        url: 'https://example.com/a.mp4',
        mediaItemId: 42,
      ));
      await settle();
      expect(controller.state.status, PlayerStatus.ready);
      expect(fake.qualities.map((q) => q.maxHeight), [720]);
      expect(fake.speeds, [1.5]);
      expect(controller.state.speed, 1.5);
      expect(controller.state.infoNotice,
          '已沿用上次的选择：画质 720p（外网）、倍速 1.5×');
    });
  });
}
