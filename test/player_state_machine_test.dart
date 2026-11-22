import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/player_service.dart';

/// 内存假后端：只实现状态机（idle→opening→ready→idle / failed），
/// 不碰任何平台通道。用于验证 [PlaybackState] 流转与接口契约。
class FakePlayerService implements PlayerService {
  final _states = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);
  String? _selectedAudioTrack;
  QualityOption? _selectedQuality;

  String? get selectedAudioTrack => _selectedAudioTrack;
  QualityOption? get selectedQuality => _selectedQuality;

  void _emit(PlaybackState next) {
    _state = next;
    _states.add(next);
  }

  @override
  PlayerBackendKind get kind => PlayerBackendKind.generic;

  @override
  PlayerCapability get capabilities => const PlayerCapability(
        inEngineAudioTrackSwitch: true,
        qualitySelection: true,
      );

  @override
  Stream<PlaybackState> get stateStream => _states.stream;

  @override
  PlaybackState get state => _state;

  @override
  Future<void> open(PlayerRequest request) async {
    _emit(_state.copyWith(status: PlayerStatus.opening, clearError: true));
    await Future<void>.delayed(Duration.zero);
    if (request.url.isEmpty) {
      _emit(_state.copyWith(
        status: PlayerStatus.failed,
        error: 'empty url',
      ));
      throw StateError('empty url');
    }
    _duration.value = const Duration(minutes: 10);
    _position.value = request.startPosition ?? Duration.zero;
    _playing.value = true;
    _emit(PlaybackState(
      status: PlayerStatus.ready,
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
    _emit(_state.copyWith(speed: speed));
  }

  @override
  Future<void> close() async {
    _position.value = Duration.zero;
    _playing.value = false;
    _duration.value = null;
    _emit(const PlaybackState(status: PlayerStatus.idle));
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
  Widget buildView({BoxFit fit = BoxFit.contain}) =>
      const SizedBox.expand();

  @override
  Future<void> selectAudioTrack(String trackId) async {
    _selectedAudioTrack = trackId;
  }

  @override
  Future<void> selectSubtitleTrack(String trackId) async {
    throw UnsupportedError('fake: no subtitle tracks');
  }

  @override
  Future<List<PlayerTrack>> getAudioTracks() async => const [
        PlayerTrack(id: '0', label: '中文', isDefault: true),
        PlayerTrack(id: '1', label: 'English'),
      ];

  @override
  Future<List<SubtitleTrack>> getSubtitleTracks() async => const [];

  @override
  Future<void> setQuality(QualityOption quality) async {
    _selectedQuality = quality;
  }

  @override
  Future<void> loadExternalSubtitle(Uri url) async {
    throw UnsupportedError('fake: no external subtitles');
  }

  @override
  Future<PlayerDiagnostics> collectDiagnostics({String? sessionId}) async {
    return PlayerDiagnostics(
      engine: 'fake',
      position: _position.value,
      duration: _duration.value,
      playing: _playing.value,
      sessionId: sessionId,
    );
  }
}

void main() {
  test('状态机：open→ready→pause→seek→倍速→close→idle 全流程', () async {
    final service = FakePlayerService();
    final seen = <PlayerStatus>[];
    final sub = service.stateStream.listen((s) => seen.add(s.status));

    expect(service.state.status, PlayerStatus.idle);

    await service.open(const PlayerRequest(
      url: 'https://example.com/a.mp4',
      startPosition: Duration(seconds: 30),
    ));
    expect(service.state.status, PlayerStatus.ready);
    expect(service.state.playing, isTrue);
    expect(service.state.position, const Duration(seconds: 30));
    expect(service.state.duration, const Duration(minutes: 10));
    expect(service.position.value, const Duration(seconds: 30));
    expect(service.playing.value, isTrue);

    await service.pause();
    expect(service.state.playing, isFalse);
    expect(service.playing.value, isFalse);

    await service.play();
    expect(service.state.playing, isTrue);

    // seek 超出时长钳制到 duration，负值钳制到 0。
    await service.seekTo(const Duration(minutes: 99));
    expect(service.state.position, const Duration(minutes: 10));
    await service.seekTo(const Duration(seconds: -5));
    expect(service.state.position, Duration.zero);

    await service.setSpeed(2.0);
    expect(service.state.speed, 2.0);

    await service.close();
    expect(service.state.status, PlayerStatus.idle);
    expect(service.state.playing, isFalse);
    expect(service.position.value, Duration.zero);
    // 广播流事件异步投递：等一个 microtask 再断言收到的顺序。
    await Future<void>.delayed(Duration.zero);

    // 流里出现过 opening → ready → idle 的顺序。
    expect(seen, containsAllInOrder([
      PlayerStatus.opening,
      PlayerStatus.ready,
      PlayerStatus.idle,
    ]));
    await sub.cancel();
  });

  test('状态机：空 url 起播失败进 failed 态并带 error', () async {
    final service = FakePlayerService();
    await expectLater(
      service.open(const PlayerRequest(url: '')),
      throwsA(isA<StateError>()),
    );
    expect(service.state.status, PlayerStatus.failed);
    expect(service.state.error, 'empty url');
  });

  test('接口契约：切音轨/画质记录选择；字幕轨与外挂字幕抛错', () async {
    final service = FakePlayerService();
    await service.open(
      const PlayerRequest(url: 'https://example.com/a.mp4'),
    );
    final tracks = await service.getAudioTracks();
    expect(tracks.map((t) => t.label), ['中文', 'English']);

    await service.selectAudioTrack('1');
    expect(service.selectedAudioTrack, '1');

    await service.setQuality(QualityOption.p720);
    expect(service.selectedQuality, QualityOption.p720);

    await expectLater(
      service.selectSubtitleTrack('0'),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      service.loadExternalSubtitle(
        Uri.parse('https://example.com/a.vtt'),
      ),
      throwsA(isA<UnsupportedError>()),
    );

    final diag = await service.collectDiagnostics(sessionId: 'sess-1');
    expect(diag.engine, 'fake');
    expect(diag.sessionId, 'sess-1');
    expect(diag.droppedFrames, isNull);
    await service.close();
  });
}
