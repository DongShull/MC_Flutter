import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/session/playback_session_api.dart';
import 'models.dart';
import 'reels_api.dart';

class _ReelCue {
  const _ReelCue(this.startMs, this.endMs, this.text);

  final int startMs;
  final int endMs;
  final String text;
}

List<_ReelCue> _parseReelSubtitles(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final cues = <_ReelCue>[];

  if (normalized.contains('[Events]') && normalized.contains('Dialogue:')) {
    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('Dialogue:')) continue;
      final body = line.substring('Dialogue:'.length).trimLeft();
      final parts = <String>[];
      var cur = 0;
      for (var c = 0; c < 9; c++) {
        final idx = body.indexOf(',', cur);
        if (idx < 0) break;
        parts.add(body.substring(cur, idx));
        cur = idx + 1;
      }
      if (parts.length < 9) continue;
      final start = _assMs(parts[1]);
      final end = _assMs(parts[2]);
      if (start == null || end == null || end <= start) continue;
      final text = body
          .substring(cur)
          .replaceAll(r'\N', '\n')
          .replaceAll(r'\n', '\n')
          .replaceAll(RegExp(r'\{\\[^}]*\}'), '')
          .trim();
      if (text.isNotEmpty) cues.add(_ReelCue(start, end, text));
    }
    return cues;
  }

  final lines = normalized.split('\n');
  final timeRe = RegExp(
    r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})',
  );
  int toMs(String? h, String m, String s, String ms) =>
      ((((int.tryParse(h ?? '0') ?? 0) * 60 + (int.tryParse(m) ?? 0)) * 60) +
              (int.tryParse(s) ?? 0)) *
          1000 +
      (int.tryParse(ms) ?? 0);

  var i = 0;
  while (i < lines.length) {
    final m = timeRe.firstMatch(lines[i].trim());
    if (m != null) {
      final start = toMs(m.group(1), m.group(2)!, m.group(3)!, m.group(4)!);
      final end = toMs(m.group(5), m.group(6)!, m.group(7)!, m.group(8)!);
      i++;
      final buf = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        final cleaned = lines[i]
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll(RegExp(r'\{\\[^}]*\}'), '')
            .trim();
        if (cleaned.isNotEmpty) buf.add(cleaned);
        i++;
      }
      if (buf.isNotEmpty && end > start) {
        cues.add(_ReelCue(start, end, buf.join('\n')));
      }
    } else {
      i++;
    }
  }
  return cues;
}

int? _assMs(String s) {
  final p = s.trim().split(':');
  if (p.length != 3) return null;
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  final secParts = p[2].split(RegExp(r'[.,]'));
  final sec = int.tryParse(secParts[0]) ?? 0;
  final cs = secParts.length > 1
      ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
      : 0;
  return (((h * 60 + m) * 60) + sec) * 1000 + cs;
}

/// 单条刷片的内联视频播放器实例（不写任何观看记录，严格隔离在 `[startMs, endMs]` 内循环播放）。
class ReelInlineSession {
  ReelInlineSession({
    required this.item,
    required this.maxHeight,
    required this.mcClient,
    required this.reelsApi,
    this.onFirstFrame,
    this.onComplete,
    this.onFail,
    this.onNotice,
  }) : service = PlayerService.createDefault();

  final ReelItemView item;
  final int? maxHeight;
  final McClient mcClient;
  final ReelsApi reelsApi;
  final void Function(int waitMs)? onFirstFrame;
  final VoidCallback? onComplete;
  final void Function(String reason)? onFail;
  final void Function(String notice)? onNotice;

  final PlayerService service;

  final ValueNotifier<bool> hasFirstFrame = ValueNotifier(false);
  final ValueNotifier<bool> paused = ValueNotifier(false);
  final ValueNotifier<bool> buffering = ValueNotifier(true);
  final ValueNotifier<bool> holdSpeed = ValueNotifier(false);
  final ValueNotifier<double> progress = ValueNotifier(0.0);
  final ValueNotifier<String?> subtitleText = ValueNotifier(null);
  final ValueNotifier<String?> error = ValueNotifier(null);

  bool _destroyed = false;
  bool _isStandby = false;
  int _originMs = 0;
  String? _transcodeSessionId;
  PlaybackSessionApi? _sessionApi;
  Timer? _monitorTimer;
  Timer? _pingTimer;
  List<_ReelCue> _cues = const [];

  DateTime? _loadStartedAt;
  DateTime? _watchResumedAt;
  int _watchedMs = 0;
  int _currentFilePosMs = 0;
  bool _completedOnce = false;

  int get startMs => item.segment.startMs;
  int get endMs =>
      item.segment.endMs > startMs ? item.segment.endMs : startMs + 45000;
  int get currentFilePosMs =>
      _currentFilePosMs > 0 ? _currentFilePosMs : startMs;
  int get watchedMs {
    var total = _watchedMs;
    if (_watchResumedAt != null) {
      total += DateTime.now().difference(_watchResumedAt!).inMilliseconds;
    }
    return total;
  }

  String _resolveUrl(String raw) {
    if (raw.startsWith('/')) {
      final origin = ServerRoutes.instance.currentOrigin(mcClient.baseUrl);
      if (origin.isNotEmpty) return '$origin$raw';
    }
    return raw;
  }

  Future<void> start({required bool autoplay, int? fromFileMs}) async {
    if (_destroyed) return;
    _isStandby = !autoplay;
    _loadStartedAt = DateTime.now();
    _currentFilePosMs = fromFileMs ?? startMs;
    buffering.value = true;
    error.value = null;

    // 并行拉取片段外挂字幕文本
    final subUrl = item.play.subtitle?.url;
    if (subUrl != null && subUrl.isNotEmpty) {
      unawaited(_loadSubtitles(subUrl));
    }

    String? playableUrl;
    int engineStartMs = 0;

    if (item.play.isClip &&
        item.play.clipUrl != null &&
        item.play.clipUrl!.isNotEmpty) {
      // 服务端预切片段文件：第 0 秒即原片 startMs
      _originMs = startMs;
      playableUrl = _resolveUrl(item.play.clipUrl!);
      engineStartMs = math.max(0, (fromFileMs ?? startMs) - _originMs);
    } else if (maxHeight != null && item.segment.fileId > 0) {
      // 限了画质：开一个不写观看记录的转码会话
      final negotiated = await _negotiateTranscode(fromFileMs ?? startMs);
      if (_destroyed) return;
      if (negotiated != null) {
        playableUrl = negotiated.$1;
        _originMs = negotiated.$2;
        engineStartMs = math.max(0, (fromFileMs ?? startMs) - _originMs);
      }
    }

    if (playableUrl == null) {
      final raw = item.play.streamUrl ?? item.play.clipUrl;
      if (raw == null || raw.isEmpty) {
        error.value = '缺少片段媒体流地址';
        onFail?.call('missing_stream');
        return;
      }
      _originMs = item.play.isClip ? startMs : 0;
      playableUrl = _resolveUrl(raw);
      engineStartMs = math.max(0, (fromFileMs ?? startMs) - _originMs);
    }

    if (_destroyed) return;

    service.position.addListener(_onServicePos);
    service.playing.addListener(_onServicePlaying);
    service.buffering.addListener(_onServiceBuffering);
    service.engineError.addListener(_onServiceError);

    try {
      await service.open(
        PlayerRequest(
          url: playableUrl,
          title: item.title.name,
          startPosition:
              engineStartMs > 0 ? Duration(milliseconds: engineStartMs) : null,
          autoplay: autoplay,
        ),
      );
      if (_destroyed) {
        await service.close();
        return;
      }
      // 禁掉引擎默认内嵌字幕，改由我们自己的片段字幕叠加层统一渲染（位置清晰不压底栏）
      unawaited(service.setExternalSubtitle(null).catchError((_) {}));
      if (item.play.audioOrdinal != null && service.isUniversalEngine) {
        unawaited(
          service
              .setAudioTrack('embedded:${item.play.audioOrdinal}')
              .catchError((_) {}),
        );
      }

      _startMonitorLoop();
    } catch (e) {
      if (_destroyed) return;
      error.value = '片段加载失败';
      buffering.value = false;
      onFail?.call(e.toString());
    }
  }

  Future<(String, int)?> _negotiateTranscode(int targetFileMs) async {
    final api = PlaybackSessionApi(mcClient);
    _sessionApi = api;
    try {
      final session = await api.start(
        fileId: item.segment.fileId,
        mediaItemId: item.title.mediaItemId > 0 ? item.title.mediaItemId : null,
        seasonNumber: item.title.episode?.season ?? 0,
        episodeNumber: item.title.episode?.episode ?? 0,
        universalEngine: false,
        maxHeightOverride: maxHeight,
        startMs: targetFileMs,
        subtitleTrack: 'off',
        attemptId: null, // 不写播放记录
      );
      if (_destroyed) {
        if (session.sessionId != null) {
          unawaited(api.stop(session.sessionId!).catchError((_) {}));
        }
        return null;
      }
      if (!session.playable || session.tier == 0) {
        if (session.sessionId != null) {
          unawaited(api.stop(session.sessionId!).catchError((_) {}));
        }
        if (session.decision == 'consent' || session.decision == 'rejected') {
          onNotice?.call('转码不可用，已切换原画播放');
        }
        return null;
      }
      _transcodeSessionId = session.sessionId;
      final origin = session.isSessionTimeline ? session.startMs : 0;
      _pingTimer?.cancel();
      if (_transcodeSessionId != null) {
        final sid = _transcodeSessionId!;
        _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          api.ping(sid);
        });
      }
      return (_resolveUrl(session.streamUrl!), origin);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSubtitles(String url) async {
    final raw = await reelsApi.fetchSnippetSubtitles(url);
    if (_destroyed || raw == null || raw.isEmpty) return;
    _cues = _parseReelSubtitles(raw);
    _syncSubtitle(_currentFilePosMs);
  }

  void _startMonitorLoop() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_destroyed || _isStandby) return;
      if (service.playing.value && _currentFilePosMs >= endMs) {
        if (!_completedOnce) {
          _completedOnce = true;
          onComplete?.call();
        }
        // 自动无缝循环当前片段 `[startMs, endMs]`
        unawaited(
          service.seekTo(
            Duration(milliseconds: math.max(0, startMs - _originMs)),
          ),
        );
      }
    });
  }

  void _onServicePos() {
    if (_destroyed) return;
    final posMs = _originMs + service.position.value.inMilliseconds;
    _currentFilePosMs = posMs;
    if (!hasFirstFrame.value &&
        (service.playing.value || service.position.value > Duration.zero)) {
      hasFirstFrame.value = true;
      buffering.value = false;
      if (!_isStandby) {
        final wait = _loadStartedAt != null
            ? DateTime.now().difference(_loadStartedAt!).inMilliseconds
            : 0;
        onFirstFrame?.call(wait);
      }
    }
    final span = math.max(1, endMs - startMs);
    progress.value = ((posMs - startMs) / span).clamp(0.0, 1.0);
    _syncSubtitle(posMs);
  }

  void _onServicePlaying() {
    if (_destroyed) return;
    final isPl = service.playing.value;
    paused.value = !isPl && hasFirstFrame.value;
    if (isPl && !_isStandby) {
      _watchResumedAt ??= DateTime.now();
    } else if (_watchResumedAt != null) {
      _watchedMs += DateTime.now().difference(_watchResumedAt!).inMilliseconds;
      _watchResumedAt = null;
    }
  }

  void _onServiceBuffering() {
    if (_destroyed) return;
    buffering.value = service.buffering.value;
  }

  void _onServiceError() {
    if (_destroyed) return;
    final err = service.engineError.value;
    if (err != null && err.isNotEmpty) {
      error.value = '播放出错';
      buffering.value = false;
      onFail?.call(err);
    }
  }

  void _syncSubtitle(int fileMs) {
    if (_cues.isEmpty) {
      if (subtitleText.value != null) subtitleText.value = null;
      return;
    }
    String? hit;
    for (final c in _cues) {
      if (fileMs >= c.startMs && fileMs <= c.endMs) {
        hit = c.text;
        break;
      }
    }
    if (subtitleText.value != hit) {
      subtitleText.value = hit;
    }
  }

  /// 将预热的 standby 会话转正并立即开播。
  Future<void> promoteFromStandby() async {
    if (_destroyed) return;
    _isStandby = false;
    _loadStartedAt = DateTime.now();
    if (hasFirstFrame.value) {
      onFirstFrame?.call(0);
    }
    await service.play();
  }

  Future<void> togglePause() async {
    if (_destroyed) return;
    if (service.playing.value) {
      await service.pause();
      paused.value = true;
    } else {
      await service.play();
      paused.value = false;
    }
  }

  Future<void> pause() async {
    if (_destroyed) return;
    await service.pause();
    paused.value = true;
  }

  Future<void> resume() async {
    if (_destroyed) return;
    await service.play();
    paused.value = false;
  }

  Future<void> setHoldSpeed(bool holding) async {
    if (_destroyed) return;
    holdSpeed.value = holding;
    await service.setSpeed(holding ? 2.0 : 1.0);
  }

  Widget buildVideoView() => service.buildView(fit: BoxFit.contain);

  Future<void> dispose() async {
    if (_destroyed) return;
    _destroyed = true;
    _monitorTimer?.cancel();
    _pingTimer?.cancel();
    if (_watchResumedAt != null) {
      _watchedMs += DateTime.now().difference(_watchResumedAt!).inMilliseconds;
      _watchResumedAt = null;
    }
    service.position.removeListener(_onServicePos);
    service.playing.removeListener(_onServicePlaying);
    service.buffering.removeListener(_onServiceBuffering);
    service.engineError.removeListener(_onServiceError);

    final sid = _transcodeSessionId;
    _transcodeSessionId = null;
    if (sid != null && _sessionApi != null) {
      unawaited(_sessionApi!.stop(sid).catchError((_) {}));
    }
    await service.close();
  }
}
