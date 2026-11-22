import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/backends/avplayer_backend.dart';
import 'package:mc_flutter/core/player/backends/exoplayer_backend.dart';
import 'package:mc_flutter/core/player/backends/harmony_backend.dart';
import 'package:mc_flutter/core/player/backends/video_player_backend.dart';
import 'package:mc_flutter/core/player/backends/web_backend.dart';
import 'package:mc_flutter/core/player/player_service.dart';

void main() {
  group('PlayerService.create 工厂按 kind 选后端', () {
    test('avPlayer → AvPlayerBackend（Apple AVPlayer）', () {
      final service = PlayerService.create(kind: PlayerBackendKind.avPlayer);
      expect(service, isA<AvPlayerBackend>());
      expect(service.kind, PlayerBackendKind.avPlayer);
      // iOS/macOS 有引擎内切音轨与视频轨选择（video_player 2.14.1）。
      expect(service.capabilities.inEngineAudioTrackSwitch, isTrue);
      expect(service.capabilities.qualitySelection, isTrue);
      // 但字幕轨/外挂字幕/解码器信息/掉帧/码率一律没有。
      expect(service.capabilities.inEngineSubtitleTrackSwitch, isFalse);
      expect(service.capabilities.externalSubtitle, isFalse);
      expect(service.capabilities.decoderInfo, isFalse);
      expect(service.capabilities.droppedFrames, isFalse);
    });

    test('exoPlayer → ExoPlayerBackend（Media3 ExoPlayer）', () {
      final service =
          PlayerService.create(kind: PlayerBackendKind.exoPlayer);
      expect(service, isA<ExoPlayerBackend>());
      expect(service.kind, PlayerBackendKind.exoPlayer);
      expect(service.capabilities.inEngineAudioTrackSwitch, isTrue);
      expect(service.capabilities.qualitySelection, isTrue);
      expect(service.capabilities.inEngineSubtitleTrackSwitch, isFalse);
    });

    test('web → WebBackend（HTML5 video，无轨选择）', () {
      final service = PlayerService.create(kind: PlayerBackendKind.web);
      expect(service, isA<WebBackend>());
      expect(service.kind, PlayerBackendKind.web);
      expect(service.capabilities.inEngineAudioTrackSwitch, isFalse);
      expect(service.capabilities.qualitySelection, isFalse);
    });

    test('harmony → HarmonyBackend，且 open 直接抛错（未实现，不冒充）', () async {
      final service = PlayerService.create(kind: PlayerBackendKind.harmony);
      expect(service, isA<HarmonyBackend>());
      expect(service.kind, PlayerBackendKind.harmony);
      expect(service.capabilities.inEngineAudioTrackSwitch, isFalse);
      await expectLater(
        service.open(
          const PlayerRequest(url: 'https://example.com/a.mp4'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('无 kind 时按当前平台解析，不抛错', () {
      final service = PlayerService.create();
      expect(service, isA<PlayerService>());
      expect(service.kind, isNotNull);
    });
  });

  group('VideoPlayerBackend 未开会话时的能力诚实性', () {
    test('未开会话切音轨/切画质抛 UnsupportedError，不静默成功', () async {
      final backend = VideoPlayerBackend();
      await expectLater(
        backend.selectAudioTrack('0'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        backend.setQuality(QualityOption.p720),
        throwsA(isA<UnsupportedError>()),
      );
      // 字幕轨：video_player 无字幕 API，恒抛错。
      await expectLater(
        backend.selectSubtitleTrack('0'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        backend.loadExternalSubtitle(Uri.parse('https://example.com/a.vtt')),
        throwsA(isA<UnsupportedError>()),
      );
      // 轨列表：未开会话返回空，不抛错。
      expect(await backend.getAudioTracks(), isEmpty);
      expect(await backend.getSubtitleTracks(), isEmpty);
      // 诊断：引擎可读字段有默认值，拿不到的字段为 null（= 缺失，不是 0）。
      final diag = await backend.collectDiagnostics();
      expect(diag.engine, 'video_player');
      expect(diag.droppedFrames, isNull);
      expect(diag.bitrateBps, isNull);
      expect(diag.decoderName, isNull);
      await backend.close();
    });
  });

  group('PlaybackState / QualityOption / PlayerRequest 值语义', () {
    test('PlaybackState.copyWith 只改指定字段，error 可清除', () {
      const s = PlaybackState(
        status: PlayerStatus.ready,
        playing: true,
        position: Duration(seconds: 10),
        speed: 1.5,
        error: 'boom',
      );
      final next = s.copyWith(speed: 2.0, clearError: true);
      expect(next.status, PlayerStatus.ready);
      expect(next.playing, isTrue);
      expect(next.position, const Duration(seconds: 10));
      expect(next.speed, 2.0);
      expect(next.error, isNull);
    });

    test('QualityOption 档位与上限语义', () {
      expect(QualityOption.original.maxHeight, isNull);
      expect(QualityOption.p1080.maxHeight, 1080);
      expect(QualityOption.p720.maxHeight, 720);
      expect(QualityOption.p480.maxHeight, 480);
      expect(QualityOption.all, hasLength(4));
    });

    test('PlayerRequest 默认值：无轨、无画质、无外挂字幕', () {
      const r = PlayerRequest(url: 'https://example.com/a.mp4');
      expect(r.title, isNull);
      expect(r.startPosition, isNull);
      expect(r.headers, isEmpty);
      expect(r.audioTrack, isNull);
      expect(r.subtitleTrack, isNull);
      expect(r.quality, isNull);
      expect(r.externalSubtitleUrl, isNull);
    });
  });
}
