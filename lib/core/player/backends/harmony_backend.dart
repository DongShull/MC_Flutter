import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../player_service.dart';

/// 鸿蒙后端：**未实现，不要当成已支持鸿蒙**。
///
/// 现状核查（2026-11-22）：
/// - 本仓库的 Flutter SDK（`work/flutter-sdk`）没有鸿蒙目标平台，
///   Dart 侧也没有对应的 `TargetPlatform`，`PlayerService.create()`
///   永远不会自动选中本后端；只能显式 `PlayerService.create(kind:
///   PlayerBackendKind.harmony)` 构造，而构造出来 `open()` 就会抛错。
/// - 社区有 `flutter_ohos`（Flutter 鸿蒙化）方案，但**未在本仓库验证**：
///   能否跑通本项目、video_player 有无鸿蒙实现、包体积与性能如何，
///   全部未知。没有验证结果之前，本文件不写任何“实现方式”。
/// - 鸿蒙原生端用的是 ArkTS `ohos.multimedia.media` 的 `AVPlayer`
///   （`apps/harmonyos/.../common/AvPlayerEngine.ets`），与 Apple
///   AVPlayer 只是**同名**，没有共用代码。不要把“AVPlayer 体系”
///   理解成能覆盖鸿蒙。
///
/// 要真正支持鸿蒙，先决条件（二选一，需另立任务验证）：
/// 1. 验证 `flutter_ohos` 能构建并运行本项目，且有可用的
///    video_player（或 media_kit）鸿蒙后端；或
/// 2. 鸿蒙端不走 Flutter，用 ArkTS 原生壳 + `media.AVPlayer`
///    实现播放器，再与 Flutter 侧用同一套服务端会话协议对接
///    （即“Flutter 统一三端 + 鸿蒙原生壳”的折中路线）。
/// 在其中一条被验证之前，鸿蒙在能力矩阵中全部标“未确认/缺失”，
/// 本后端保持抛错桩。
class HarmonyBackend implements PlayerService {
  static const _message = '鸿蒙播放器未实现：Flutter 鸿蒙目标未验证，'
      '本仓库 SDK 无鸿蒙 target；原生鸿蒙用 ArkTS media.AVPlayer'
      '（与 Apple AVPlayer 同名不同物）。见 docs/PLAYER_MATRIX.md 与小结。';

  @override
  PlayerBackendKind get kind => PlayerBackendKind.harmony;

  @override
  PlayerCapability get capabilities => const PlayerCapability();

  @override
  Stream<PlaybackState> get stateStream => const Stream.empty();

  @override
  PlaybackState get state => const PlaybackState();

  @override
  Future<void> open(PlayerRequest request)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> play()  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> pause()  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> seekTo(Duration position)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> setSpeed(double speed)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> close() async {}

  @override
  ValueListenable<Duration> get position =>
      throw UnsupportedError(_message);

  @override
  ValueListenable<bool> get playing => throw UnsupportedError(_message);

  @override
  ValueListenable<Duration?> get duration =>
      throw UnsupportedError(_message);

  @override
  Future<void> setVolume(double volume)  async {
    throw UnsupportedError(_message);
  }

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> selectAudioTrack(String trackId)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> selectSubtitleTrack(String trackId)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<List<PlayerTrack>> getAudioTracks() async => const [];

  @override
  Future<List<SubtitleTrack>> getSubtitleTracks() async => const [];

  @override
  Future<void> setQuality(QualityOption quality)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> loadExternalSubtitle(Uri url)  async {
    throw UnsupportedError(_message);
  }

  @override
  Future<PlayerDiagnostics> collectDiagnostics({String? sessionId})  async {
    throw UnsupportedError(_message);
  }
}
