import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/playback_report_queue.dart';
import '../../../core/player/playback_watchdogs.dart';
import '../../../core/player/player_page_args.dart';
import '../../../core/player/player_preferences.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/player_system_bridge.dart';
import '../../../core/player/session/playback_session_api.dart';

export '../../../core/player/player_page_args.dart';

enum PlayerStatus { idle, opening, ready, failed }

/// 服务器协商结果（decision != plan 时挂在状态上等 UI 弹窗，绝不置为 failed 盖在背后）。
enum SessionDecision { plan, consent, rejected }

/// 解析后的字幕条目：支持 WebVTT / SRT / ASS，并保留 ASS `\an1..9` 九宫格对齐位置。
@immutable
class SubtitleCue {
  const SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.alignment = 2, // 默认底居中（ASS \an2）
  });

  final int startMs;
  final int endMs;
  final String text;

  /// ASS 九宫格对齐：1左下 2底中 3右下 / 4左中 5正中 6右中 / 7左上 8顶中 9右上
  final int alignment;
}

/// 轻量级全格式字幕解析器（支持 WebVTT / SRT / ASS(SSA)，提取 `\an1..9` 定位标签）。
List<SubtitleCue> parseSubtitleText(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.contains('[Events]') && normalized.contains('Dialogue:')) {
    return _parseAssSubtitle(normalized);
  }
  return _parseVttOrSrtSubtitle(normalized);
}

final RegExp _anTagRe = RegExp(r'\{\\[^}]*\\an([1-9])[^}]*\}|\{\\an([1-9])\}');

int _extractAlignment(String rawLine) {
  final m = _anTagRe.firstMatch(rawLine);
  if (m == null) return 2;
  final g = m.group(1) ?? m.group(2);
  return int.tryParse(g ?? '2') ?? 2;
}

String _cleanCueLine(String rawLine) {
  return rawLine
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(RegExp(r'\{\\[^}]*\}'), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

List<SubtitleCue> _parseVttOrSrtSubtitle(String normalized) {
  final lines = normalized.split('\n');
  final cues = <SubtitleCue>[];
  final timeRe = RegExp(
    r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})',
  );
  int toMs(String? h, String m, String s, String ms) {
    final hh = int.tryParse(h ?? '0') ?? 0;
    final mm = int.tryParse(m) ?? 0;
    final ss = int.tryParse(s) ?? 0;
    final mmm = int.tryParse(ms) ?? 0;
    return (((hh * 60 + mm) * 60) + ss) * 1000 + mmm;
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();
    final match = timeRe.firstMatch(line);
    if (match != null) {
      final start = toMs(
        match.group(1),
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final end = toMs(
        match.group(5),
        match.group(6)!,
        match.group(7)!,
        match.group(8)!,
      );
      i++;
      final buf = <String>[];
      var alignment = 2;
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        final rawLine = lines[i];
        final foundAn = _extractAlignment(rawLine);
        if (foundAn != 2) alignment = foundAn;
        final cleaned = _cleanCueLine(rawLine);
        if (cleaned.isNotEmpty) buf.add(cleaned);
        i++;
      }
      if (buf.isNotEmpty && end > start) {
        cues.add(
          SubtitleCue(
            startMs: start,
            endMs: end,
            text: buf.join('\n'),
            alignment: alignment,
          ),
        );
      }
    } else {
      i++;
    }
  }
  cues.sort((a, b) => a.startMs.compareTo(b.startMs));
  return cues;
}

List<SubtitleCue> _parseAssSubtitle(String normalized) {
  final lines = normalized.split('\n');
  final cues = <SubtitleCue>[];
  var startIdx = 1;
  var endIdx = 2;
  var textIdx = 9;
  var inEvents = false;

  int? assTimeToMs(String s) {
    final parts = s.trim().split(':');
    if (parts.length != 3) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split(RegExp(r'[.,]'));
    final sec = int.tryParse(secParts[0]) ?? 0;
    final cs = secParts.length > 1
        ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
        : 0;
    return (((h * 60 + m) * 60) + sec) * 1000 + cs;
  }

  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      inEvents = line.toLowerCase() == '[events]';
      continue;
    }
    if (!inEvents) continue;
    if (line.startsWith('Format:')) {
      final cols = line
          .substring('Format:'.length)
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();
      final si = cols.indexOf('start');
      final ei = cols.indexOf('end');
      final ti = cols.indexOf('text');
      if (si >= 0) startIdx = si;
      if (ei >= 0) endIdx = ei;
      if (ti >= 0) textIdx = ti;
      continue;
    }
    if (!line.startsWith('Dialogue:')) continue;
    final body = line.substring('Dialogue:'.length).trimLeft();
    final fields = <String>[];
    var cursor = 0;
    for (var col = 0; col < textIdx; col++) {
      final comma = body.indexOf(',', cursor);
      if (comma < 0) break;
      fields.add(body.substring(cursor, comma));
      cursor = comma + 1;
    }
    if (fields.length < textIdx) continue;
    final rawText = body.substring(cursor);
    final start = assTimeToMs(fields[startIdx]);
    final end = assTimeToMs(fields[endIdx]);
    if (start == null || end == null || end <= start) continue;
    final alignment = _extractAlignment(rawText);
    final cleaned = _cleanCueLine(rawText);
    if (cleaned.isEmpty) continue;
    cues.add(
      SubtitleCue(
        startMs: start,
        endMs: end,
        text: cleaned,
        alignment: alignment,
      ),
    );
  }
  cues.sort((a, b) => a.startMs.compareTo(b.startMs));
  return cues;
}

/// 二分查找当前时间点命中的字幕条目（支持最多 3 条同时重叠显示）。
List<SubtitleCue> activeSubtitleCuesAt(List<SubtitleCue> cues, int timeMs) {
  if (cues.isEmpty) return const [];
  var low = 0;
  var high = cues.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (cues[mid].startMs <= timeMs) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  final result = <SubtitleCue>[];
  var index = low - 1;
  while (index >= 0 && result.length < 3) {
    final cue = cues[index];
    if (cue.endMs > timeMs) {
      result.insert(0, cue);
    }
    if (timeMs - cue.startMs > 30000) break;
    index -= 1;
  }
  return result;
}

/// 跳过段逻辑（1:1 对齐 iOS `SkipSegments.swift`）。
abstract final class SkipSegmentsHelper {
  static const int tailMs = 3000;
  static const int autoNextMs = 8000;
  static const int autoNextMaxStreak = 3;
  static const int skipNoticeMs = 5000;
  static const int infoNoticeMs = 3000;

  static PlaybackSkipSegment? active(
    List<PlaybackSkipSegment> segments,
    int positionMs,
  ) {
    for (final s in segments) {
      if (s.type == 'outro' && s.toEnd) continue;
      if (positionMs >= s.startMs && positionMs < s.endMs - tailMs) {
        return s;
      }
    }
    return null;
  }

  static bool isInOutro(List<PlaybackSkipSegment> segments, int positionMs) {
    return segments.any(
      (s) => s.type == 'outro' && s.toEnd && positionMs >= s.startMs,
    );
  }

  static bool shouldShowUpNext(
    List<PlaybackSkipSegment> segments,
    int positionMs, {
    bool ended = false,
  }) {
    if (ended) return true;
    if (active(segments, positionMs) != null) return false;
    return isInOutro(segments, positionMs);
  }

  static bool autoNextArmed(
    List<PlaybackSkipSegment> segments,
    int positionMs, {
    required int streak,
    bool ended = false,
  }) {
    return streak < autoNextMaxStreak &&
        (ended || isInOutro(segments, positionMs));
  }

  static bool autoSkips(
    PlaybackSkipSegment segment, {
    required bool enabled,
    required bool introLearned,
    bool adEnabled = true,
    bool previewEnabled = true,
  }) {
    if (!enabled) return false;
    return switch (segment.type) {
      'ad' => adEnabled,
      'preview' => previewEnabled,
      'intro' => introLearned,
      _ => false,
    };
  }

  static String label(PlaybackSkipSegment segment) => switch (segment.type) {
        'intro' => '跳过片头',
        'outro' => '跳过片尾',
        'ad' => '跳过广告',
        'preview' => '跳过预告',
        _ => '跳过此段',
      };

  static String name(PlaybackSkipSegment segment) => switch (segment.type) {
        'intro' => '片头',
        'outro' => '片尾',
        'ad' => '广告',
        'preview' => '预告',
        _ => '此段',
      };
}

enum SkipNoticeKind { skipped, learned, forgot }

@immutable
class SkipNotice {
  const SkipNotice({
    required this.id,
    required this.kind,
    this.segment,
    this.previousPositionMs,
  });

  final int id;
  final SkipNoticeKind kind;
  final PlaybackSkipSegment? segment;
  final int? previousPositionMs;

  String get message => switch (kind) {
        SkipNoticeKind.skipped =>
          '已跳过${segment != null ? SkipSegmentsHelper.name(segment!) : '此段'}',
        SkipNoticeKind.learned => '本剧以后自动跳过片头',
        SkipNoticeKind.forgot => '本剧不再自动跳过片头',
      };

  String? get actionLabel => switch (kind) {
        SkipNoticeKind.skipped => '撤回',
        SkipNoticeKind.learned => '不用',
        SkipNoticeKind.forgot => null,
      };
}

/// 播放页可观察状态。
@immutable
class PlayerPlayback {
  const PlayerPlayback({
    this.status = PlayerStatus.idle,
    this.error,
    this.errorSuggestion,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration,
    this.bufferedEnd = Duration.zero,
    this.speed = 1.0,
    this.qualityTier = 'original',
    this.subtitleScale = 1.0,
    this.subtitleBottomMarginPercent = 8.0,
    this.subtitleBackgroundPill = true,
    this.subtitleOffsetMs = 0,
    this.activeSubtitleCues = const [],
    this.completed = false,
    this.pendingDecision,
    this.pendingCanSelfEnable = false,
    this.pendingCostHint,
    this.pendingReason,
    this.skipSegments = const [],
    this.autoSkipEnabled = true,
    this.introAutoSkip = false,
    this.skipNotice,
    this.qualityOffer,
    this.trickplay,
    this.speedLabel,
    this.isClip = false,
    this.clipStartMs,
    this.clipEndMs,
    this.clipEnded = false,
    this.endedByAdmin = false,
    this.usingFallbackEngine = false,
    this.cloudRelayActive = false,
    this.engineRevision = 0,
    this.stallCount = 0,
    this.controllerNotice,
  });

  final PlayerStatus status;
  final String? error;
  final String? errorSuggestion;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration? duration;
  final Duration bufferedEnd;
  final double speed;
  final String qualityTier;
  final double subtitleScale;
  final double subtitleBottomMarginPercent;
  final bool subtitleBackgroundPill;
  final int subtitleOffsetMs;
  final List<SubtitleCue> activeSubtitleCues;
  final bool completed;
  final SessionDecision? pendingDecision;
  final bool pendingCanSelfEnable;
  final String? pendingCostHint;
  final String? pendingReason;
  final List<PlaybackSkipSegment> skipSegments;
  final bool autoSkipEnabled;
  final bool introAutoSkip;
  final SkipNotice? skipNotice;
  final QualityOffer? qualityOffer;
  final PlaybackTrickplay? trickplay;
  final String? speedLabel;
  final bool isClip;
  final int? clipStartMs;
  final int? clipEndMs;
  final bool clipEnded;
  final bool endedByAdmin;
  final bool usingFallbackEngine;
  final bool cloudRelayActive;
  final int engineRevision;
  final int stallCount;
  final String? controllerNotice;

  String? get activeSubtitleText => activeSubtitleCues.isEmpty
      ? null
      : activeSubtitleCues.map((e) => e.text).join('\n');

  /// UI 时间轴当前位置（片段模式以片段起点为 0）。
  Duration get timelinePosition {
    if (!isClip || clipStartMs == null || clipEndMs == null) return position;
    final rel = (position.inMilliseconds - clipStartMs!)
        .clamp(0, math.max(0, clipEndMs! - clipStartMs!))
        .toInt();
    return Duration(milliseconds: rel);
  }

  /// UI 时间轴总时长（片段模式为片段时长，正片为总时长）。
  Duration get timelineDuration {
    if (isClip && clipStartMs != null && clipEndMs != null) {
      return Duration(milliseconds: math.max(0, clipEndMs! - clipStartMs!));
    }
    return duration ?? Duration.zero;
  }

  /// UI 时间轴已缓冲位置。
  Duration get timelineBufferedEnd {
    if (!isClip || clipStartMs == null || clipEndMs == null) return bufferedEnd;
    final rel = (bufferedEnd.inMilliseconds - clipStartMs!)
        .clamp(0, math.max(0, clipEndMs! - clipStartMs!))
        .toInt();
    return Duration(milliseconds: rel);
  }

  PlayerPlayback copyWith({
    PlayerStatus? status,
    String? error,
    String? errorSuggestion,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? bufferedEnd,
    double? speed,
    String? qualityTier,
    double? subtitleScale,
    double? subtitleBottomMarginPercent,
    bool? subtitleBackgroundPill,
    int? subtitleOffsetMs,
    List<SubtitleCue>? activeSubtitleCues,
    bool clearActiveSubtitle = false,
    bool? completed,
    SessionDecision? pendingDecision,
    bool? pendingCanSelfEnable,
    String? pendingCostHint,
    String? pendingReason,
    bool clearError = false,
    bool clearDecision = false,
    List<PlaybackSkipSegment>? skipSegments,
    bool clearSkipSegments = false,
    bool? autoSkipEnabled,
    bool? introAutoSkip,
    SkipNotice? skipNotice,
    bool clearSkipNotice = false,
    QualityOffer? qualityOffer,
    bool clearQualityOffer = false,
    PlaybackTrickplay? trickplay,
    bool clearTrickplay = false,
    String? speedLabel,
    bool clearSpeedLabel = false,
    bool? isClip,
    int? clipStartMs,
    int? clipEndMs,
    bool clearClip = false,
    bool? clipEnded,
    bool? endedByAdmin,
    bool? usingFallbackEngine,
    bool? cloudRelayActive,
    int? engineRevision,
    int? stallCount,
    String? controllerNotice,
    bool clearControllerNotice = false,
  }) {
    return PlayerPlayback(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      errorSuggestion:
          clearError ? null : (errorSuggestion ?? this.errorSuggestion),
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedEnd: bufferedEnd ?? this.bufferedEnd,
      speed: speed ?? this.speed,
      qualityTier: qualityTier ?? this.qualityTier,
      subtitleScale: subtitleScale ?? this.subtitleScale,
      subtitleBottomMarginPercent:
          subtitleBottomMarginPercent ?? this.subtitleBottomMarginPercent,
      subtitleBackgroundPill:
          subtitleBackgroundPill ?? this.subtitleBackgroundPill,
      subtitleOffsetMs: subtitleOffsetMs ?? this.subtitleOffsetMs,
      activeSubtitleCues: clearActiveSubtitle
          ? const []
          : (activeSubtitleCues ?? this.activeSubtitleCues),
      completed: completed ?? this.completed,
      pendingDecision:
          clearDecision ? null : (pendingDecision ?? this.pendingDecision),
      pendingCanSelfEnable: clearDecision
          ? false
          : (pendingCanSelfEnable ?? this.pendingCanSelfEnable),
      pendingCostHint:
          clearDecision ? null : (pendingCostHint ?? this.pendingCostHint),
      pendingReason:
          clearDecision ? null : (pendingReason ?? this.pendingReason),
      skipSegments:
          clearSkipSegments ? const [] : (skipSegments ?? this.skipSegments),
      autoSkipEnabled: autoSkipEnabled ?? this.autoSkipEnabled,
      introAutoSkip: introAutoSkip ?? this.introAutoSkip,
      skipNotice: clearSkipNotice ? null : (skipNotice ?? this.skipNotice),
      qualityOffer:
          clearQualityOffer ? null : (qualityOffer ?? this.qualityOffer),
      trickplay: clearTrickplay ? null : (trickplay ?? this.trickplay),
      speedLabel: clearSpeedLabel ? null : (speedLabel ?? this.speedLabel),
      isClip: clearClip ? false : (isClip ?? this.isClip),
      clipStartMs: clearClip ? null : (clipStartMs ?? this.clipStartMs),
      clipEndMs: clearClip ? null : (clipEndMs ?? this.clipEndMs),
      clipEnded: clearClip ? false : (clipEnded ?? this.clipEnded),
      endedByAdmin: endedByAdmin ?? this.endedByAdmin,
      usingFallbackEngine: usingFallbackEngine ?? this.usingFallbackEngine,
      cloudRelayActive: cloudRelayActive ?? this.cloudRelayActive,
      engineRevision: engineRevision ?? this.engineRevision,
      stallCount: stallCount ?? this.stallCount,
      controllerNotice: clearControllerNotice
          ? null
          : (controllerNotice ?? this.controllerNotice),
    );
  }
}

/// 全 App 唯一默认播放器服务实例（全 5 大原生平台默认 `media_kit` / `libmpv`）。
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService.createDefault();
  ref.onDispose(service.close);
  return service;
});

/// 影院级播放控制器（全协议对齐 iOS `PlaybackController.swift`）：
/// - 单调 `attempt` 令牌取消孤儿会话；
/// - 串行进度上报队列（`start` -> 10s `progress` -> `stop`，解析 `ended_by_admin`）；
/// - `timeline == 'session'` 双向时间轴换算与跨缓冲自动重开；
/// - `onDrive` `&fallback=1` -> `&relay=1` 自动网盘中转切换；
/// - 15 秒三态 `ping()` 检测 404 死会话自动重连；
/// - 软字幕零重启切换（仅 PGS 烧录切会话）；
/// - `PlaybackClip` 片段模式无痕播放 + 原地 `leaveClip()` 展开看全片；
/// - `StallWatch` / `PrematureEndGuard` / `QualitySuggestion` / `PlaybackReportQueue` / `NowPlaying` 全链路接入。
class PlayerController extends Notifier<PlayerPlayback> {
  static const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  PlayerService? _fallbackService;
  PlayerService get activeService =>
      _fallbackService ?? ref.read(playerServiceProvider);

  PlaybackSessionApi? _sessionApi;
  PlaybackSession? _lastSession;
  String? _serverSessionId;
  bool _deadSession = false;
  bool _playsOriginalFile = true;
  int _originMs = 0;

  Timer? _pingTimer;
  Timer? _progressTimer;
  Timer? _watchdogTimer;
  Timer? _skipNoticeTimer;
  Timer? _noticeTimer;
  Timer? _qualityOfferTimer;

  PlayerPageArgs? _currentArgs;
  int _attempt = 0;
  double _speedBeforeHold = 1.0;
  bool _allowSoftwareTranscode = false;
  bool _consentGranted = false;
  bool _cloudRelay = false;
  bool _reportedStart = false;
  bool _backgrounded = false;
  bool _seeking = false;
  bool _adAutoSkip = true;
  bool _previewAutoSkip = true;
  final Set<int> _handledSkipStarts = {};
  int _skipNoticeSeq = 0;

  // 串行进度上报链
  Future<void> _reportChain = Future<void>.value();

  // 看门狗与 QoE
  final StallWatch _stallWatch = StallWatch();
  final PrematureEndGuard _prematureEndGuard = PrematureEndGuard();
  final ReconnectBackoff _reconnectBackoff = ReconnectBackoff();
  final NetworkRestartBudget _networkRestartBudget = NetworkRestartBudget();
  final LoadingSpeedMeter _loadingSpeedMeter = LoadingSpeedMeter();
  final QualitySuggestion _qualitySuggestion = QualitySuggestion();
  final List<int> _failedTiers = [];

  String? _attemptId;
  DateTime? _openStartedAt;
  DateTime? _firstFrameAt;
  int _watchedMs = 0;
  int _rebufferMs = 0;
  int _rebufferCount = 0;
  int _seekCount = 0;
  int _watchdogSecondTick = 0;
  DateTime? _bufferingSince;
  DateTime? _lastWatchedTick;
  double? _lastDownlinkBps;

  List<SubtitleCue> _subtitleCues = const [];
  List<PlaybackAudioTrack> _audioTracks = const [];
  List<PlaybackSubtitleTrack> _subtitles = const [];
  String? _selectedAudioTrack;
  String? _selectedSubtitleTrack;
  bool _audioUserSelected = false;
  bool _subtitleUserSelected = false;

  String? _lastUrl;
  bool _listenersAttached = false;

  List<PlaybackAudioTrack> get audioTracks => _audioTracks;
  List<PlaybackSubtitleTrack> get subtitles => _subtitles;
  String? get selectedAudioTrack => _selectedAudioTrack;
  String? get selectedSubtitleTrack => _selectedSubtitleTrack;
  PlaybackSession? get sessionInfo => _lastSession;
  String? get lastStreamUrl => _lastUrl;
  String? get serverSessionId => _serverSessionId;
  int get originMs => _originMs;
  bool get playsOriginalFile => _playsOriginalFile;

  @override
  PlayerPlayback build() => const PlayerPlayback(status: PlayerStatus.idle);

  String _resolveHttpUrl(String raw) {
    if (raw.startsWith('/')) {
      final base = ServerRoutes.instance.currentOrigin(
        ref.read(sessionStoreProvider).baseUrl ?? '',
      );
      if (base.isNotEmpty) return '$base$raw';
    }
    return raw;
  }

  String get _serverOrigin => ServerRoutes.instance.currentOrigin(
        ref.read(sessionStoreProvider).baseUrl ?? '',
      );

  // ── 生命周期主入口 ──────────────────────────────────────────────────────

  Future<void> open(
    PlayerPageArgs args, {
    bool isReconnect = false,
    bool preserveTracks = false,
  }) async {
    final myAttempt = ++_attempt;
    await PlayerPreferences.instance.ensureLoaded();

    if (!isReconnect) {
      await _finishCurrentUnit(sendStop: _reportedStart);
      _cloudRelay = false;
      _consentGranted = false;
      _failedTiers.clear();
      _handledSkipStarts.clear();
      _stallWatch.reset();
      _prematureEndGuard.reset();
      _reconnectBackoff.reset();
      _networkRestartBudget.reset();
      _loadingSpeedMeter.reset();
      _qualitySuggestion.reset();
      if (!preserveTracks) {
        _selectedAudioTrack = null;
        _selectedSubtitleTrack = null;
        _audioUserSelected = false;
        _subtitleUserSelected = false;
        _audioTracks = const [];
        _subtitles = const [];
      }
      _beginQoeRecord(args);
      await _restorePreferencesForUnit(args);
    } else {
      _cancelTimersOnly();
      _detachServiceListeners();
    }

    if (myAttempt != _attempt) return;

    _currentArgs = args;
    _deadSession = false;
    _subtitleCues = const [];

    final style = PlayerPreferences.instance.subtitleStyle;
    state = state.copyWith(
      status: PlayerStatus.opening,
      completed: false,
      endedByAdmin: false,
      clearError: true,
      clearDecision: true,
      clearActiveSubtitle: true,
      clearSkipSegments: !isReconnect,
      clearSkipNotice: !isReconnect,
      clearQualityOffer: !isReconnect,
      clearTrickplay: !isReconnect,
      subtitleScale: style.fontScale,
      subtitleBottomMarginPercent: style.bottomMarginPercent,
      subtitleBackgroundPill: style.backgroundPill,
      subtitleOffsetMs: isReconnect ? state.subtitleOffsetMs : 0,
      isClip: args.isClip,
      clipStartMs: args.clipStartMs,
      clipEndMs: args.clipEndMs,
      clipEnded: false,
      cloudRelayActive: _cloudRelay,
    );

    try {
      var url = args.url;
      var startPosition = args.startPosition;
      final isLocalFile = args.isOffline ||
          url.startsWith('file://') ||
          (url.startsWith('/') &&
              !url.startsWith('/api/') &&
              !url.startsWith('/s/'));

      if (!isLocalFile && (args.mediaItemId != null || args.fileId != null)) {
        final api = PlaybackSessionApi(
          McClient(session: ref.read(sessionStoreProvider)),
          shareSlug: args.shareSlug,
        );
        _sessionApi = api;

        // 访客分享：读取本机上次续播点与轨道记忆
        if (args.isShare &&
            args.mediaItemId != null &&
            startPosition == null &&
            !isReconnect) {
          final localShare = await PlayerPreferences.instance.readShareProgress(
            shareSlug: args.shareSlug!,
            mediaItemId: args.mediaItemId!,
            season: args.seasonNumber ?? 0,
            episode: args.episodeNumber ?? 0,
          );
          if (localShare != null) {
            if (localShare.positionMs > 0) {
              startPosition = Duration(milliseconds: localShare.positionMs);
            }
            if (!_audioUserSelected && localShare.audioTrack != null) {
              _selectedAudioTrack = localShare.audioTrack;
            }
            if (!_subtitleUserSelected && localShare.subtitleTrack != null) {
              _selectedSubtitleTrack = localShare.subtitleTrack;
            }
          }
        }

        final desiredStartMs = startPosition?.inMilliseconds ??
            (args.isClip ? args.clipStartMs : null);
        final isMobile = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android);

        final session = await api.start(
          fileId: args.fileId,
          mediaItemId: args.mediaItemId,
          seasonNumber: args.seasonNumber,
          episodeNumber: args.episodeNumber,
          universalEngine: activeService.isUniversalEngine,
          isMobile: isMobile,
          deviceId: PlayerPreferences.instance.deviceId,
          startMs: desiredStartMs,
          failedTiers: _failedTiers.isEmpty ? null : List.of(_failedTiers),
          maxTier: state.qualityTier,
          maxHeightOverride:
              args.isClip && !isReconnect ? args.initialMaxHeight : null,
          allowSoftwareTranscode: _allowSoftwareTranscode,
          audioTrack: _audioUserSelected ? _selectedAudioTrack : null,
          subtitleTrack: _subtitleUserSelected ? _selectedSubtitleTrack : null,
          downlinkBps: _lastDownlinkBps?.round(),
          attemptId: args.isClip ? null : _attemptId,
          shareSlug: args.shareSlug,
        );

        // 单调 attempt 校验：快速切集/退出时立即销毁孤儿会话
        if (myAttempt != _attempt) {
          if (session.sessionId != null) {
            unawaited(api.stop(session.sessionId!).catchError((_) {}));
          }
          return;
        }

        _lastSession = session;

        // 处理 consent / rejected
        if (session.decision == 'consent') {
          // 若 PGS 图形字幕烧录触发软件转码同意，自动退回关闭字幕并重协商，不打断观看
          if (_selectedSubtitleTrack != null &&
              _selectedSubtitleTrack!.isNotEmpty &&
              _selectedSubtitleTrack != 'off') {
            final dropped = _subtitles.where(
              (t) => t.trackRef == _selectedSubtitleTrack,
            );
            final isPgs = dropped.isNotEmpty && dropped.first.isBitmap;
            _selectedSubtitleTrack = 'off';
            _subtitleUserSelected = true;
            if (isPgs) {
              _flashNotice('图形字幕需软件转码，已自动关闭以直接播放');
            }
            unawaited(open(args, isReconnect: true, preserveTracks: true));
            return;
          }

          if (_consentGranted) {
            state = state.copyWith(
              status: PlayerStatus.failed,
              error: session.transcodeReason ?? '已启用软件转码但会话仍需确认',
              errorSuggestion: session.suggestion,
            );
            return;
          }

          // 保持 opening 状态，不把背后翻成 failed
          state = state.copyWith(
            status: PlayerStatus.opening,
            pendingDecision: SessionDecision.consent,
            pendingCanSelfEnable: session.canSelfEnable ?? false,
            pendingCostHint: session.costHint,
            pendingReason:
                session.transcodeReason ?? '当前片源需要服务器开启软件转码才能播放',
          );
          return;
        }

        if (session.decision == 'rejected') {
          state = state.copyWith(
            status: PlayerStatus.failed,
            pendingDecision: SessionDecision.rejected,
            pendingReason: session.transcodeReason,
            error: session.transcodeReason ?? '服务器策略拒绝此次转码会话',
            errorSuggestion: session.suggestion ?? '可在「设置 → 播放设置」中调整转码策略',
          );
          return;
        }

        _consentGranted = false;

        if (!session.playable) {
          state = state.copyWith(
            status: PlayerStatus.failed,
            error: session.transcodeReason ?? '未获取到可播放的媒体流地址',
          );
          return;
        }

        // 停掉旧会话
        final prevSessionId = _serverSessionId;
        if (prevSessionId != null && prevSessionId != session.sessionId) {
          unawaited(api.stop(prevSessionId).catchError((_) {}));
        }

        _serverSessionId = session.sessionId;
        _playsOriginalFile =
            session.tier == 0 || session.deliveryMode == 'direct_play';
        _originMs =
            (_playsOriginalFile || !session.isSessionTimeline)
                ? 0
                : session.startMs;

        // onDrive 网盘直连 `&fallback=1` -> 失败自动切 `&relay=1`
        var resolvedStream = _resolveHttpUrl(session.streamUrl!);
        if (session.onDrive && _playsOriginalFile) {
          resolvedStream = _applyDriveQuery(
            resolvedStream,
            relay: _cloudRelay,
          );
        }
        url = resolvedStream;

        _audioTracks = session.audioTracks;
        _subtitles = session.subtitles;

        if (!_audioUserSelected) {
          _selectedAudioTrack = session.watchAudioTrack ??
              _firstDefault([
                for (final t in session.audioTracks)
                  if (t.isDefault) t.ref,
              ]);
        }

        if (!_subtitleUserSelected) {
          if (session.burnSubtitle != null &&
              session.burnSubtitle!.isNotEmpty) {
            _selectedSubtitleTrack = session.burnSubtitle;
          } else {
            final remembered = session.watchSubtitleTrack;
            if (remembered == 'off') {
              _selectedSubtitleTrack = '';
            } else if (remembered != null &&
                _subtitles.any((s) => s.trackRef == remembered)) {
              _selectedSubtitleTrack = remembered;
            } else {
              _selectedSubtitleTrack = _subtitles.isEmpty
                  ? ''
                  : (_firstDefault([
                        for (final t in _subtitles)
                          if (t.isDefault && t.isAvailable && !t.isBitmap)
                            t.trackRef,
                      ]) ??
                      _firstDefault([
                        for (final t in _subtitles)
                          if (t.isAvailable && !t.isBitmap) t.trackRef,
                      ]) ??
                      '');
            }
          }
        }

        if (session.autoSkip != null) {
          _adAutoSkip = session.autoSkip!.ad;
          _previewAutoSkip = session.autoSkip!.preview;
        }

        final targetPosMs = desiredStartMs ?? session.startMs;
        final engineStartMs = math.max(0, targetPosMs - _originMs);
        startPosition = engineStartMs > 0
            ? Duration(milliseconds: engineStartMs)
            : null;

        state = state.copyWith(
          position: Duration(milliseconds: targetPosMs),
          skipSegments: session.skipSegments,
          autoSkipEnabled: session.autoSkip?.enabled ?? true,
          introAutoSkip: session.autoSkip?.intro ?? false,
          duration: (session.durationMs != null && session.durationMs! > 0)
              ? Duration(milliseconds: session.durationMs!)
              : state.duration,
        );

        _startPingLoop();
        unawaited(_loadSelectedSubtitleCues(session, myAttempt));
        if (session.fileId != null && !args.isClip) {
          unawaited(_loadTrickplay(session.fileId!, session.streamToken, myAttempt));
        }
      } else {
        // 本地离线文件 / 直连演示流
        _playsOriginalFile = true;
        _originMs = 0;
        _serverSessionId = null;
        _lastSession = null;
      }

      if (myAttempt != _attempt) return;

      _lastUrl = _resolveHttpUrl(url);
      await activeService.open(
        PlayerRequest(
          url: _lastUrl!,
          title: args.displayTitle,
          startPosition: startPosition,
          headers: args.headers,
        ),
      );

      if (myAttempt != _attempt) return;

      if (state.speed != 1.0) {
        await activeService.setSpeed(state.speed);
      }
      // 软字幕由 Flutter 叠加层统一绘制，避免引擎重复双字幕
      unawaited(activeService.setExternalSubtitle(null).catchError((_) {}));

      _attachServiceListeners();
      _startWatchdogLoop();
      state = state.copyWith(status: PlayerStatus.ready);
      _syncFromService();
      _pushNowPlayingMeta();
    } catch (e) {
      if (myAttempt != _attempt) return;
      await _handleOpenOrEngineError(e.toString(), myAttempt);
    }
  }

  Future<void> _restorePreferencesForUnit(PlayerPageArgs args) async {
    final itemId = args.mediaItemId;
    if (itemId == null) return;
    if (args.isClip) {
      if (args.initialMaxHeight != null) {
        state = state.copyWith(qualityTier: '${args.initialMaxHeight}p');
      } else {
        state = state.copyWith(qualityTier: 'original');
      }
      state = state.copyWith(speed: 1.0);
      return;
    }

    if (!args.isShare) {
      final route = PlaybackRouteEnv.current();
      final memQuality = await PlayerPreferences.instance.getQualityTier(
        mediaItemId: itemId,
        route: route,
      );
      final memSpeed = await PlayerPreferences.instance.getSpeed(
        mediaItemId: itemId,
      );
      state = state.copyWith(
        qualityTier: memQuality ?? 'original',
        speed: memSpeed ?? 1.0,
      );
      _speedBeforeHold = state.speed;
    }
  }

  String _applyDriveQuery(String url, {required bool relay}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final q = Map<String, String>.from(uri.queryParameters);
    q.remove('fallback');
    q.remove('relay');
    q[relay ? 'relay' : 'fallback'] = '1';
    return uri.replace(queryParameters: q).toString();
  }

  // ── 引擎监听与看门狗 ────────────────────────────────────────────────────

  void _attachServiceListeners() {
    _detachServiceListeners();
    final svc = activeService;
    svc.position.addListener(_onPosition);
    svc.playing.addListener(_onPlaying);
    svc.duration.addListener(_onDuration);
    svc.bufferedEnd.addListener(_onBufferedEnd);
    svc.buffering.addListener(_onBuffering);
    svc.completed.addListener(_onCompleted);
    svc.engineError.addListener(_onEngineError);
    _listenersAttached = true;
  }

  void _detachServiceListeners() {
    if (!_listenersAttached) return;
    final svc = activeService;
    svc.position.removeListener(_onPosition);
    svc.playing.removeListener(_onPlaying);
    svc.duration.removeListener(_onDuration);
    svc.bufferedEnd.removeListener(_onBufferedEnd);
    svc.buffering.removeListener(_onBuffering);
    svc.completed.removeListener(_onCompleted);
    svc.engineError.removeListener(_onEngineError);
    _listenersAttached = false;
  }

  void _syncFromService() {
    _onDuration();
    _onBufferedEnd();
    _onBuffering();
    _onPlaying();
    _onPosition();
  }

  void _onPosition() {
    final svcPos = activeService.position.value;
    final fileMs = _originMs + svcPos.inMilliseconds;
    // 起播 seek 落地前忽略瞬时 0，防止进度条闪烁回片头
    if (svcPos.inMilliseconds < 50 &&
        state.position.inMilliseconds > 2000 &&
        state.buffering) {
      return;
    }
    final filePos = Duration(milliseconds: fileMs);

    if (state.isClip &&
        state.clipEndMs != null &&
        fileMs >= state.clipEndMs! &&
        state.playing &&
        !state.clipEnded) {
      unawaited(_reachClipEnd());
      return;
    }

    state = state.copyWith(position: filePos);
    _syncSubtitleAt(filePos);
    _evaluateAutoSkip(fileMs);
  }

  void _onPlaying() {
    final isPlaying = activeService.playing.value;
    final wasPlaying = state.playing;
    if (isPlaying) {
      if (_firstFrameAt == null) {
        _firstFrameAt = DateTime.now();
        _networkRestartBudget.reachedPlaying();
        _reconnectBackoff.reset();
        _qualitySuggestion.restartGrace();
      }
      _lastWatchedTick ??= DateTime.now();
      if (!_reportedStart && !state.isClip) {
        _reportStart();
      }
    } else {
      _flushWatchedMs();
    }

    state = state.copyWith(playing: isPlaying);

    if (wasPlaying != isPlaying) {
      _pushNowPlayingPosition();
      if (!isPlaying && _reportedStart && !state.isClip) {
        // 暂停即上报 stop/progress（对齐 iOS 串行进度协议）
        _enqueueProgress(event: 'stop', paused: true);
      }
    }
  }

  void _onDuration() {
    final svcDur = activeService.duration.value;
    if (svcDur != null && svcDur > Duration.zero) {
      final totalMs = _originMs + svcDur.inMilliseconds;
      // 光盘源或尚无时长时以引擎实测为准
      if (state.duration == null || _lastSession?.disc != null) {
        state = state.copyWith(duration: Duration(milliseconds: totalMs));
      }
    }
  }

  void _onBufferedEnd() {
    final svcBuf = activeService.bufferedEnd.value;
    final fileBuf = Duration(milliseconds: _originMs + svcBuf.inMilliseconds);
    if (fileBuf != state.bufferedEnd) {
      state = state.copyWith(bufferedEnd: fileBuf);
    }
  }

  void _onBuffering() {
    final isBuf = activeService.buffering.value;
    if (isBuf && _bufferingSince == null && _firstFrameAt != null && !_seeking) {
      _bufferingSince = DateTime.now();
      _rebufferCount += 1;
      state = state.copyWith(buffering: true, stallCount: _rebufferCount);
    } else if (!isBuf && _bufferingSince != null) {
      _rebufferMs += DateTime.now().difference(_bufferingSince!).inMilliseconds;
      _bufferingSince = null;
      state = state.copyWith(buffering: false);
    } else if (isBuf != state.buffering) {
      state = state.copyWith(buffering: isBuf);
    }
  }

  void _onCompleted() {
    if (!activeService.completed.value) return;
    if (state.isClip) {
      unawaited(_reachClipEnd());
      return;
    }
    final posMs = state.position.inMilliseconds;
    final durMs = state.duration?.inMilliseconds;
    if (_prematureEndGuard.shouldResume(
      positionMs: posMs,
      durationMs: durMs,
    )) {
      _flashNotice('检测到意外断流，正在自动续接…');
      final args = _currentArgs;
      if (args != null) {
        unawaited(
          open(
            args.copyWith(startPosition: Duration(milliseconds: posMs)),
            isReconnect: true,
            preserveTracks: true,
          ),
        );
      }
      return;
    }

    state = state.copyWith(completed: true, playing: false);
    if (_reportedStart) {
      _enqueueProgress(event: 'stop', paused: true);
    }
  }

  void _onEngineError() {
    final err = activeService.engineError.value;
    if (err == null || err.isEmpty || state.status != PlayerStatus.ready) return;
    unawaited(_handleOpenOrEngineError(err, _attempt));
  }

  Future<void> _handleOpenOrEngineError(String rawError, int myAttempt) async {
    if (myAttempt != _attempt) return;
    final args = _currentArgs;
    final session = _lastSession;

    // 1. 网盘文件直连失败：自动切到 `&relay=1` 走家庭服务器中转
    if (session != null &&
        session.onDrive &&
        _playsOriginalFile &&
        !_cloudRelay &&
        args != null) {
      _cloudRelay = true;
      _flashNotice('网盘直连受阻，已切换服务器中转播放');
      _submitClientLog('cloud-relay-fallback', {'reason': rawError});
      await open(
        args.copyWith(startPosition: state.position),
        isReconnect: true,
        preserveTracks: true,
      );
      return;
    }

    // 2. 先做单字节片源探活区分「网络断连 / 404 缺失 / 引擎解码失败」
    if (_lastUrl != null &&
        (_lastUrl!.startsWith('http://') || _lastUrl!.startsWith('https://')) &&
        _sessionApi != null) {
      final probe = await _sessionApi!.probeSourceHead(
        _lastUrl!,
        headers: mcImageHeaders(),
      );
      if (myAttempt != _attempt) return;
      if (probe.verdict == SourceProbeVerdict.missing) {
        state = state.copyWith(
          status: PlayerStatus.failed,
          error: '媒体文件不存在或已被移除 (HTTP 404)',
          errorSuggestion: '请检查 NAS 存储路径或刷新媒体库',
        );
        return;
      }
      if (probe.verdict == SourceProbeVerdict.unreachable) {
        final delay = _reconnectBackoff.nextDelaySeconds();
        if (delay != null && args != null && _firstFrameAt != null) {
          _flashNotice('网络连接中断，$delay 秒后自动重连…');
          await Future<void>.delayed(Duration(seconds: delay));
          if (myAttempt != _attempt) return;
          await open(
            args.copyWith(startPosition: state.position),
            isReconnect: true,
            preserveTracks: true,
          );
          return;
        }
      }
    }

    // 3. Universal libmpv 解码失败 -> 自动回退到系统 AVPlayer/ExoPlayer 兜底引擎
    if (activeService.isUniversalEngine &&
        _fallbackService == null &&
        args != null) {
      _flashNotice('硬件解码异常，正在切换兼容播放引擎…');
      _submitClientLog('engine-fallback', {'reason': rawError});
      await _switchToFallbackEngine();
      if (myAttempt != _attempt) return;
      await open(
        args.copyWith(startPosition: state.position),
        isReconnect: true,
        preserveTracks: true,
      );
      return;
    }

    // 4. 服务端转码档位失败 -> 记入 failed_tiers 尝试降档
    if (session?.tier != null &&
        !_failedTiers.contains(session!.tier!) &&
        args != null) {
      _failedTiers.add(session.tier!);
      _flashNotice('当前流无法播放，正在尝试降档兼容流…');
      await open(
        args.copyWith(startPosition: state.position),
        isReconnect: true,
        preserveTracks: true,
      );
      return;
    }

    state = state.copyWith(
      status: PlayerStatus.failed,
      error: '播放失败：$rawError',
      errorSuggestion: '请检查网络连接或点击重试',
    );
  }

  Future<void> _switchToFallbackEngine() async {
    _detachServiceListeners();
    await activeService.close();
    _fallbackService = PlayerService.createFallback();
    state = state.copyWith(
      usingFallbackEngine: true,
      engineRevision: state.engineRevision + 1,
    );
  }

  // ── 1 秒看门狗与 QoE 采样 ──────────────────────────────────────────────

  void _startWatchdogLoop() {
    _watchdogTimer?.cancel();
    _watchdogSecondTick = 0;
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickWatchdogSecond();
    });
  }

  void _tickWatchdogSecond() {
    if (state.status != PlayerStatus.ready) return;
    _watchdogSecondTick += 1;

    final bps = _loadingSpeedMeter.sample(activeService.estimatedBandwidthBps);
    if (bps != null && bps > 0) _lastDownlinkBps = bps;
    final label = LoadingSpeedMeter.formatLoadingSpeed(bps);
    if (label != state.speedLabel) {
      state = label == null
          ? state.copyWith(clearSpeedLabel: true)
          : state.copyWith(speedLabel: label);
    }

    if (state.playing && !_backgrounded) {
      _flushWatchedMs();
      _lastWatchedTick = DateTime.now();
    }

    if (!_backgrounded) {
      final streamPosSec = activeService.position.value.inMilliseconds / 1000.0;
      final streamBufSec =
          activeService.bufferedEnd.value.inMilliseconds / 1000.0;
      final aheadSec = math.max(0.0, streamBufSec - streamPosSec);
      final deadLimit = _playsOriginalFile
          ? StallWatch.directDeadSeconds
          : StallWatch.serverDeadSeconds;

      final verdict = _stallWatch.sample(
        timeSeconds: streamPosSec,
        bufferedAheadSeconds: aheadSec,
        paused: !state.playing,
        ended: state.completed || state.clipEnded,
        seeking: _seeking,
        receiving: (bps ?? 0) > 0,
        deadLimitSeconds: deadLimit,
      );

      switch (verdict) {
        case StallVerdict.ok:
          break;
        case StallVerdict.nudge:
          _submitClientLog('stall-nudge', {
            'position_ms': state.position.inMilliseconds,
          });
          unawaited(
            activeService
                .seekTo(
                  Duration(
                    milliseconds: activeService.position.value.inMilliseconds +
                        (StallWatch.nudgeStepSeconds * 1000).round(),
                  ),
                )
                .then((_) => activeService.play()),
          );
        case StallVerdict.decodeStalled:
          unawaited(
            _handleOpenOrEngineError(
              StallWatch.describeReason(verdict, deadLimit),
              _attempt,
            ),
          );
          return;
        case StallVerdict.dead:
          if (_networkRestartBudget.allowRestart() && _currentArgs != null) {
            _flashNotice('取流中断，正在重新连接…');
            unawaited(
              open(
                _currentArgs!.copyWith(startPosition: state.position),
                isReconnect: true,
                preserveTracks: true,
              ),
            );
          } else {
            unawaited(
              _handleOpenOrEngineError(
                StallWatch.describeReason(verdict, deadLimit),
                _attempt,
              ),
            );
          }
          return;
      }

      // 弱网画质降档建议（仅提示不强切）
      if (state.playing || state.buffering) {
        _qualitySuggestion.tick(
          stalled: state.buffering || _seeking,
          seeking: _seeking,
          loadingBps: bps,
        );
        if (state.qualityOffer == null && !_qualitySuggestion.offered) {
          final requiredBps = _lastSession?.bitRate?.toDouble();
          final currentHeight = _parseCurrentHeight();
          final offer = _qualitySuggestion.offer(
            streamBitrateBps: requiredBps,
            currentHeight: currentHeight,
          );
          if (offer != null) {
            state = state.copyWith(qualityOffer: offer);
            _qualityOfferTimer?.cancel();
            _qualityOfferTimer = Timer(const Duration(seconds: 20), () {
              if (state.qualityOffer != null) {
                state = state.copyWith(clearQualityOffer: true);
              }
            });
          }
        }
      }
    }

    _pushNowPlayingPosition();

    // 每 10 秒刷新一次闪退恢复标记 active.json
    if (_watchdogSecondTick % 10 == 0 && !state.isClip) {
      _markQoeActive();
    }
  }

  int? _parseCurrentHeight() {
    final tierHeight = switch (state.qualityTier) {
      '1080p' => 1080,
      '720p' => 720,
      '480p' => 480,
      _ => null,
    };
    final res = _lastSession?.resolution;
    int? srcHeight;
    if (res != null && res.isNotEmpty) {
      final m = RegExp(r'[x×](\d{3,4})').firstMatch(res);
      if (m != null) {
        srcHeight = int.tryParse(m.group(1)!);
      } else {
        srcHeight = int.tryParse(res.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }
    if (tierHeight != null && srcHeight != null) {
      return math.min(tierHeight, srcHeight);
    }
    return tierHeight ?? srcHeight;
  }

  void acceptQualityOffer() {
    final offer = state.qualityOffer;
    if (offer == null) return;
    dismissQualityOffer();
    unawaited(setQualityTier(offer.tier));
  }

  void dismissQualityOffer() {
    _qualityOfferTimer?.cancel();
    _qualityOfferTimer = null;
    state = state.copyWith(clearQualityOffer: true);
  }

  // ── 15 秒心跳与串行进度上报 ────────────────────────────────────────────

  void _startPingLoop() {
    _pingTimer?.cancel();
    final id = _serverSessionId;
    if (id == null || _sessionApi == null) return;
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _pingSession(id);
    });
  }

  Future<void> _pingSession(String id) async {
    final api = _sessionApi;
    if (api == null || id != _serverSessionId) return;
    final alive = await api.ping(id);
    // null = 瞬时网络错误，不误杀；false = 服务端明确 404 死会话
    if (alive == false && id == _serverSessionId) {
      if (!state.playing) {
        _deadSession = true;
        return;
      }
      final args = _currentArgs;
      if (args != null) {
        _flashNotice('会话已过期，正在无缝重连…');
        await open(
          args.copyWith(startPosition: state.position),
          isReconnect: true,
          preserveTracks: true,
        );
      }
    }
  }

  void _reportStart() {
    if (_reportedStart || state.isClip) return;
    final args = _currentArgs;
    if (args?.mediaItemId == null || _sessionApi == null) return;
    _reportedStart = true;
    _enqueueProgress(event: 'start', paused: false, includePosition: false);
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.status == PlayerStatus.ready && state.playing) {
        _enqueueProgress(event: 'progress', paused: false);
      }
    });
  }

  void _enqueueProgress({
    required String event,
    bool? paused,
    bool includePosition = true,
  }) {
    final args = _currentArgs;
    final api = _sessionApi;
    if (args?.mediaItemId == null || api == null || state.isClip) return;

    final itemId = args!.mediaItemId!;
    final season = args.seasonNumber ?? 0;
    final episode = args.episodeNumber ?? 0;
    final posMs = includePosition ? state.position.inMilliseconds : null;
    final durMs = state.duration?.inMilliseconds;
    final fileId = _lastSession?.fileId ?? args.fileId;
    final audio = _audioUserSelected ? _selectedAudioTrack : null;
    final subtitle = _subtitleUserSelected
        ? ((_selectedSubtitleTrack == null || _selectedSubtitleTrack!.isEmpty)
            ? 'off'
            : _selectedSubtitleTrack)
        : null;
    final deviceId = PlayerPreferences.instance.deviceId;
    final shareSlug = args.shareSlug;

    _reportChain = _reportChain.then((_) async {
      if (shareSlug != null && shareSlug.isNotEmpty) {
        await PlayerPreferences.instance.writeShareProgress(
          shareSlug: shareSlug,
          mediaItemId: itemId,
          season: season,
          episode: episode,
          positionMs: posMs,
          durationMs: durMs,
          audioTrack: audio,
          subtitleTrack: subtitle,
        );
      }
      try {
        final result = await api.reportProgress(
          mediaItemId: itemId,
          seasonNumber: season,
          episodeNumber: episode,
          event: event,
          positionMs: posMs,
          paused: paused,
          fileId: fileId,
          audioTrack: audio,
          subtitleTrack: subtitle,
          deviceId: deviceId,
          shareSlug: shareSlug,
        );
        if (result != null && result.endedByAdmin) {
          _handleEndedByAdmin();
        }
      } catch (_) {}
    });
  }

  void _handleEndedByAdmin() {
    if (state.endedByAdmin) return;
    unawaited(activeService.pause());
    _cancelTimersOnly();
    final sid = _serverSessionId;
    _serverSessionId = null;
    if (sid != null) {
      unawaited(_sessionApi?.stop(sid).catchError((_) {}));
    }
    state = state.copyWith(
      status: PlayerStatus.failed,
      playing: false,
      endedByAdmin: true,
      error: '管理员已在活动页结束本次播放',
      errorSuggestion: '如需继续观看，请返回后重新发起播放',
    );
  }

  // ── 字幕零重启切换 & 加载 ───────────────────────────────────────────────

  Future<void> _loadSelectedSubtitleCues(
    PlaybackSession session,
    int myAttempt,
  ) async {
    final sel = _selectedSubtitleTrack;
    if (sel == null || sel.isEmpty || sel == 'off') {
      _subtitleCues = const [];
      state = state.copyWith(clearActiveSubtitle: true);
      return;
    }

    PlaybackSubtitleTrack? track;
    for (final t in session.subtitles) {
      if (t.trackRef == sel) {
        track = t;
        break;
      }
    }
    if (track != null && track.isBitmap) {
      // PGS 图形字幕由服务端烧录或引擎自身绘制，不走纯文本解析
      _subtitleCues = const [];
      state = state.copyWith(clearActiveSubtitle: true);
      return;
    }

    String? subUrl = track?.url;
    if ((subUrl == null || subUrl.isEmpty) && session.subtitleUrls.isNotEmpty) {
      final idx = session.subtitles.indexWhere((t) => t.trackRef == sel);
      if (idx >= 0 && idx < session.subtitleUrls.length) {
        subUrl = session.subtitleUrls[idx];
      } else {
        subUrl = session.subtitleUrls.first;
      }
    }
    if (subUrl == null || subUrl.isEmpty) return;

    // 软字幕统一追加 &format=vtt（若尚未指定）及片段模式窗口裁剪参数
    var full = _resolveHttpUrl(subUrl);
    final uri = Uri.tryParse(full);
    if (uri != null) {
      final q = Map<String, String>.from(uri.queryParameters);
      if (!q.containsKey('format') &&
          (track == null || track.kind.toLowerCase() != 'ass')) {
        q['format'] = 'vtt';
      }
      if (state.isClip &&
          state.clipStartMs != null &&
          state.clipEndMs != null &&
          sel.startsWith('embedded:')) {
        q['start_ms'] = '${math.max(0, state.clipStartMs! - 10000)}';
        q['end_ms'] = '${state.clipEndMs! + 5000}';
      }
      full = uri.replace(queryParameters: q).toString();
    }

    try {
      final resp = await Dio().get<String>(
        full,
        options: Options(
          headers: mcImageHeaders(),
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      if (myAttempt != _attempt) return;
      final body = resp.data;
      if ((resp.statusCode ?? 0) >= 200 &&
          (resp.statusCode ?? 0) < 300 &&
          body != null) {
        _subtitleCues = parseSubtitleText(body);
        _syncSubtitleAt(state.position);
      }
    } catch (_) {}
  }

  void _syncSubtitleAt(Duration pos) {
    if (_subtitleCues.isEmpty) {
      if (state.activeSubtitleCues.isNotEmpty) {
        state = state.copyWith(clearActiveSubtitle: true);
      }
      return;
    }
    final adjustedMs = pos.inMilliseconds - state.subtitleOffsetMs;
    final matched = activeSubtitleCuesAt(_subtitleCues, adjustedMs);
    final same = matched.length == state.activeSubtitleCues.length &&
        List.generate(
          matched.length,
          (i) => matched[i].text == state.activeSubtitleCues[i].text &&
              matched[i].alignment == state.activeSubtitleCues[i].alignment,
        ).every((e) => e);
    if (!same) {
      state = matched.isEmpty
          ? state.copyWith(clearActiveSubtitle: true)
          : state.copyWith(activeSubtitleCues: matched);
    }
  }

  /// 切换音轨或字幕轨：
  /// - 软字幕切换/关闭：零会话重启，直接重拉字幕轨并即时生效！
  /// - 仅 PGS 烧录开关或非原地音轨切换才重建会话。
  Future<void> switchTrack({String? audioTrack, String? subtitleTrack}) async {
    final args = _currentArgs;
    if (args == null) return;

    if (subtitleTrack != null && audioTrack == null) {
      final normalized = subtitleTrack == 'off' ? '' : subtitleTrack;
      _selectedSubtitleTrack = normalized;
      _subtitleUserSelected = true;

      final target = _subtitles
          .where((t) => t.trackRef == normalized)
          .cast<PlaybackSubtitleTrack?>()
          .firstOrNull;
      final wantBurn = target?.isBitmap == true;
      final currentlyBurned = _lastSession?.burnSubtitle != null &&
          _lastSession!.burnSubtitle!.isNotEmpty;

      if (!wantBurn && !currentlyBurned) {
        // 零重启软字幕切换
        if (normalized.isEmpty) {
          _subtitleCues = const [];
          state = state.copyWith(clearActiveSubtitle: true);
        } else if (_lastSession != null) {
          await _loadSelectedSubtitleCues(_lastSession!, _attempt);
        }
        if (_reportedStart && !state.isClip) {
          _enqueueProgress(event: 'progress', paused: !state.playing);
        }
        return;
      }

      // PGS 烧录开关需要重开服务端会话
      final pos = state.position;
      await open(
        args.copyWith(startPosition: pos),
        isReconnect: true,
        preserveTracks: true,
      );
      return;
    }

    if (audioTrack != null) {
      _selectedAudioTrack = audioTrack;
      _audioUserSelected = true;
      if (_playsOriginalFile && activeService.isUniversalEngine) {
        await activeService.setAudioTrack(audioTrack);
        if (_reportedStart && !state.isClip) {
          _enqueueProgress(event: 'progress', paused: !state.playing);
        }
        return;
      }
      final pos = state.position;
      await open(
        args.copyWith(startPosition: pos),
        isReconnect: true,
        preserveTracks: true,
      );
    }
  }

  // ── 画质、倍速与字幕样式持久化 ──────────────────────────────────────────

  Future<void> setQualityTier(String tier) async {
    if (tier == state.qualityTier) return;
    state = state.copyWith(qualityTier: tier);
    final args = _currentArgs;
    if (args?.mediaItemId != null && !args!.isShare && !state.isClip) {
      await PlayerPreferences.instance.rememberQualityTier(
        mediaItemId: args.mediaItemId!,
        route: PlaybackRouteEnv.current(),
        tier: tier == 'original' ? null : tier,
      );
    }
    if (args == null || _sessionApi == null) return;
    _failedTiers.clear();
    await open(
      args.copyWith(startPosition: state.position),
      isReconnect: true,
      preserveTracks: true,
    );
  }

  void setSubtitleScale(double scale) {
    final clamped = scale.clamp(0.75, 1.6);
    state = state.copyWith(subtitleScale: clamped);
    unawaited(
      PlayerPreferences.instance.saveSubtitleStyle(
        PlayerPreferences.instance.subtitleStyle.copyWith(fontScale: clamped),
      ),
    );
  }

  void setSubtitleBottomMargin(double percent) {
    final clamped = percent.clamp(2.0, 28.0);
    state = state.copyWith(subtitleBottomMarginPercent: clamped);
    unawaited(
      PlayerPreferences.instance.saveSubtitleStyle(
        PlayerPreferences.instance.subtitleStyle
            .copyWith(bottomMarginPercent: clamped),
      ),
    );
  }

  void setSubtitleBackgroundPill(bool enabled) {
    state = state.copyWith(subtitleBackgroundPill: enabled);
    unawaited(
      PlayerPreferences.instance.saveSubtitleStyle(
        PlayerPreferences.instance.subtitleStyle
            .copyWith(backgroundPill: enabled),
      ),
    );
  }

  void adjustSubtitleOffset(int deltaMs) {
    final next = deltaMs == 0
        ? 0
        : (state.subtitleOffsetMs + deltaMs).clamp(-30000, 30000);
    state = state.copyWith(subtitleOffsetMs: next);
    _syncSubtitleAt(state.position);
  }

  /// 用户确认允许软件转码：先调用 `PUT/POST /api/v1/playback/policy` 写入策略，再无痕重连。
  Future<String?> acceptTranscodeConsent() async {
    final api = _sessionApi;
    final args = _currentArgs;
    if (api == null || args == null) return '播放会话未初始化';
    try {
      final ok = await api.enableSoftwareTranscode();
      if (!ok) return '服务器未能开启软件转码开关';
      _allowSoftwareTranscode = true;
      _consentGranted = true;
      state = state.copyWith(clearDecision: true);
      await open(
        args.copyWith(startPosition: state.position),
        isReconnect: true,
        preserveTracks: true,
      );
      return null;
    } catch (e) {
      return '开启软件转码失败：$e';
    }
  }

  Future<void> acknowledgeDecision() async {
    state = state.copyWith(clearDecision: true);
  }

  // ── 跳过片头 / 广告 / 预告与自动跳过学习 ────────────────────────────────

  void _evaluateAutoSkip(int fileMs) {
    if (state.isClip || state.status != PlayerStatus.ready || !state.playing) {
      return;
    }
    final seg = SkipSegmentsHelper.active(state.skipSegments, fileMs);
    if (seg == null || _handledSkipStarts.contains(seg.startMs)) return;

    if (SkipSegmentsHelper.autoSkips(
      seg,
      enabled: state.autoSkipEnabled,
      introLearned: state.introAutoSkip,
      adEnabled: _adAutoSkip,
      previewEnabled: _previewAutoSkip,
    )) {
      _handledSkipStarts.add(seg.startMs);
      unawaited(seekTo(Duration(milliseconds: seg.endMs), markSkip: false));
      _showSkipNotice(
        SkipNotice(
          id: ++_skipNoticeSeq,
          kind: SkipNoticeKind.skipped,
          segment: seg,
          previousPositionMs: fileMs,
        ),
        durationMs: SkipSegmentsHelper.skipNoticeMs,
      );
    }
  }

  Future<void> skipCurrentSegment() async {
    final posMs = state.position.inMilliseconds;
    final seg = SkipSegmentsHelper.active(state.skipSegments, posMs);
    if (seg == null) return;
    _handledSkipStarts.add(seg.startMs);
    await seekTo(Duration(milliseconds: seg.endMs), markSkip: false);

    final args = _currentArgs;
    if (seg.type == 'intro' &&
        state.autoSkipEnabled &&
        !state.introAutoSkip &&
        args?.mediaItemId != null &&
        !args!.isShare) {
      state = state.copyWith(introAutoSkip: true);
      unawaited(
        _sessionApi
            ?.setAutoSkipIntro(args.mediaItemId!, true)
            .catchError((_) {}),
      );
      _showSkipNotice(
        SkipNotice(
          id: ++_skipNoticeSeq,
          kind: SkipNoticeKind.learned,
          segment: seg,
        ),
        durationMs: SkipSegmentsHelper.skipNoticeMs,
      );
    }
  }

  Future<void> undoAutoSkip() async {
    final notice = state.skipNotice;
    if (notice == null || notice.previousPositionMs == null) return;
    if (notice.segment != null) {
      _handledSkipStarts.add(notice.segment!.startMs);
    }
    dismissSkipNotice();
    await seekTo(
      Duration(milliseconds: notice.previousPositionMs!),
      markSkip: false,
    );
  }

  Future<void> declineIntroAutoSkip() async {
    final itemId = _currentArgs?.mediaItemId;
    state = state.copyWith(introAutoSkip: false);
    if (itemId != null && !(_currentArgs?.isShare ?? false)) {
      unawaited(
        _sessionApi?.setAutoSkipIntro(itemId, false).catchError((_) {}),
      );
    }
    _showSkipNotice(
      SkipNotice(id: ++_skipNoticeSeq, kind: SkipNoticeKind.forgot),
      durationMs: SkipSegmentsHelper.infoNoticeMs,
    );
  }

  void dismissSkipNotice() {
    _skipNoticeTimer?.cancel();
    _skipNoticeTimer = null;
    state = state.copyWith(clearSkipNotice: true);
  }

  void _showSkipNotice(SkipNotice notice, {required int durationMs}) {
    _skipNoticeTimer?.cancel();
    state = state.copyWith(skipNotice: notice);
    _skipNoticeTimer = Timer(Duration(milliseconds: durationMs), () {
      if (state.skipNotice?.id == notice.id) {
        state = state.copyWith(clearSkipNotice: true);
      }
    });
  }

  // ── 片段模式（PlaybackClip） ───────────────────────────────────────────

  Future<void> _reachClipEnd() async {
    await activeService.pause();
    state = state.copyWith(playing: false, clipEnded: true);
  }

  Future<void> replayClip() async {
    if (!state.isClip || state.clipStartMs == null) return;
    state = state.copyWith(clipEnded: false);
    await seekTo(Duration(milliseconds: state.clipStartMs!));
    await activeService.play();
  }

  /// 「看全片」：原地退出片段模式，不重启会话无缝接着播整部并开始正常进度上报！
  Future<void> leaveClip() async {
    if (!state.isClip) return;
    final args = _currentArgs;
    if (args != null) {
      _currentArgs = args.copyWith(clearClip: true);
    }
    state = state.copyWith(clearClip: true);
    _pushNowPlayingMeta();

    // 若之前在片段终点停住，则恢复播放
    if (!state.playing) {
      await activeService.play();
    }
    if (!_reportedStart) {
      _reportStart();
    }
    if (_lastSession?.fileId != null && state.trickplay == null) {
      unawaited(
        _loadTrickplay(
          _lastSession!.fileId!,
          _lastSession!.streamToken,
          _attempt,
        ),
      );
    }
  }

  // ── Trickplay 雪碧图索引 ───────────────────────────────────────────────

  Future<void> _loadTrickplay(int fileId, String? token, int myAttempt) async {
    final api = _sessionApi;
    if (api == null) return;
    for (var i = 0; i < 4; i++) {
      if (myAttempt != _attempt) return;
      try {
        final tp = await api.trickplay(
          fileId,
          token: token,
          shareSlug: _currentArgs?.shareSlug,
        );
        if (myAttempt != _attempt) return;
        if (tp != null && tp.usable) {
          state = state.copyWith(trickplay: tp);
          return;
        }
      } catch (_) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 25));
    }
  }

  // ── 播放控制（含 timeline == 'session' 双向换算 & 死会话复活） ───────────

  Future<void> togglePlay() async {
    if (state.clipEnded) {
      await replayClip();
      return;
    }
    if (state.playing) {
      await activeService.pause();
    } else {
      if (_deadSession && _currentArgs != null) {
        _deadSession = false;
        await open(
          _currentArgs!.copyWith(startPosition: state.position),
          isReconnect: true,
          preserveTracks: true,
        );
        return;
      }
      _qualitySuggestion.restartGrace();
      await activeService.play();
    }
  }

  Future<void> play() async {
    if (!state.playing) await togglePlay();
  }

  Future<void> pause() async {
    if (state.playing) await activeService.pause();
  }

  /// 按 UI 时间轴位置 seek（片段模式传入片段内偏移量；正片模式直接为文件时间）。
  Future<void> seekToTimeline(Duration timelineTarget) async {
    if (state.isClip && state.clipStartMs != null) {
      await seekTo(
        Duration(milliseconds: state.clipStartMs! + timelineTarget.inMilliseconds),
      );
      return;
    }
    await seekTo(timelineTarget);
  }

  Future<void> seekTo(Duration target, {bool markSkip = true}) async {
    final dur = state.duration;
    var targetMs = target.inMilliseconds;
    if (state.isClip && state.clipStartMs != null && state.clipEndMs != null) {
      targetMs = targetMs.clamp(
        state.clipStartMs!,
        math.max(state.clipStartMs!, state.clipEndMs! - 500),
      );
    } else if (dur != null && dur > Duration.zero) {
      targetMs = targetMs.clamp(0, dur.inMilliseconds);
    } else {
      targetMs = math.max(0, targetMs);
    }

    if (markSkip) {
      final seg = SkipSegmentsHelper.active(state.skipSegments, targetMs);
      if (seg != null) _handledSkipStarts.add(seg.startMs);
    }

    _seekCount += 1;
    _qualitySuggestion.restartGrace();

    // timeline == 'session' 跨缓冲区跳转：需以目标时间重开服务端会话
    final session = _lastSession;
    if (session != null &&
        session.isSessionTimeline &&
        !_playsOriginalFile &&
        _currentArgs != null) {
      final withinBuf = targetMs >= _originMs &&
          targetMs <=
              math.max(
                state.bufferedEnd.inMilliseconds,
                state.position.inMilliseconds + 5000,
              );
      if (!withinBuf) {
        state = state.copyWith(
          position: Duration(milliseconds: targetMs),
          completed: false,
          clipEnded: false,
        );
        await open(
          _currentArgs!.copyWith(startPosition: Duration(milliseconds: targetMs)),
          isReconnect: true,
          preserveTracks: true,
        );
        return;
      }
    }

    _seeking = true;
    final engineTarget = Duration(milliseconds: math.max(0, targetMs - _originMs));
    await activeService.seekTo(engineTarget);
    _seeking = false;
    final clampedDur = Duration(milliseconds: targetMs);
    state = state.copyWith(
      position: clampedDur,
      completed: false,
      clipEnded: false,
    );
    _syncSubtitleAt(clampedDur);
    _pushNowPlayingPosition();
  }

  Future<void> seekByRelative(int deltaMs) async {
    final base = state.position.inMilliseconds;
    await seekTo(Duration(milliseconds: base + deltaMs));
  }

  Future<void> setSpeed(double speed) async {
    _speedBeforeHold = speed;
    await activeService.setSpeed(speed);
    state = state.copyWith(speed: speed);
    final args = _currentArgs;
    if (args?.mediaItemId != null && !args!.isShare && !state.isClip) {
      await PlayerPreferences.instance.rememberSpeed(
        mediaItemId: args.mediaItemId!,
        speed: speed,
      );
    }
    _pushNowPlayingPosition();
  }

  Future<void> setHoldSpeed(bool holding) async {
    if (holding) {
      _speedBeforeHold = state.speed;
      await activeService.setSpeed(2.0);
      state = state.copyWith(speed: 2.0);
    } else {
      await activeService.setSpeed(_speedBeforeHold);
      state = state.copyWith(speed: _speedBeforeHold);
    }
  }

  /// App 进入后台 / 回到前台（不强制暂停音频，确保后台音频与锁屏控制正常工作）。
  void onBackgroundChanged(bool background) {
    _backgrounded = background;
    if (background) {
      _flushWatchedMs();
      if (_reportedStart && !state.isClip) {
        _enqueueProgress(event: 'progress', paused: !state.playing);
      }
      _markQoeActive();
    } else {
      _stallWatch.reset();
      _qualitySuggestion.restartGrace();
      if (_serverSessionId != null) {
        unawaited(_pingSession(_serverSessionId!));
      }
    }
  }

  // ── Now Playing 桥接 ────────────────────────────────────────────────────

  void _pushNowPlayingMeta({bool hasNext = false, bool hasPrevious = false}) {
    final args = _currentArgs;
    if (args == null) return;
    final artwork = args.artworkUrl != null && args.artworkUrl!.isNotEmpty
        ? McImageUrls.resolve(args.artworkUrl, widthPx: 480)
        : null;
    unawaited(
      PlayerSystemBridge.instance.updateNowPlaying(
        title: args.displayTitle,
        subtitle: args.displaySubtitle,
        artworkUrl: artwork,
        artworkHeaders: mcImageHeaders(),
        positionMs: state.timelinePosition.inMilliseconds,
        durationMs: state.timelineDuration.inMilliseconds,
        isPlaying: state.playing,
        rate: state.speed,
        hasNext: hasNext && !state.isClip,
        hasPrevious: hasPrevious && !state.isClip,
      ),
    );
  }

  void updateNowPlayingNavigation({
    required bool hasNext,
    required bool hasPrevious,
  }) {
    _pushNowPlayingMeta(hasNext: hasNext, hasPrevious: hasPrevious);
  }

  void _pushNowPlayingPosition() {
    unawaited(
      PlayerSystemBridge.instance.updateNowPlayingPosition(
        positionMs: state.timelinePosition.inMilliseconds,
        durationMs: state.timelineDuration.inMilliseconds,
        isPlaying: state.playing,
        rate: state.speed,
      ),
    );
  }

  // ── 诊断面板数据 ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchDiagnostics() async {
    final s = _lastSession;
    Map<String, dynamic> remote = const {};
    if (_serverSessionId != null && _sessionApi != null) {
      try {
        remote = await _sessionApi!.diagnostics(
          _serverSessionId!,
          token: s?.streamToken,
          shareSlug: _currentArgs?.shareSlug,
        );
      } catch (_) {}
    }
    final mbps = s?.bitRate != null && s!.bitRate! > 0
        ? '${(s.bitRate! / 1000000).toStringAsFixed(1)} Mbps'
        : null;
    final resHdr = [
      if (s?.resolution != null && s!.resolution!.isNotEmpty) s.resolution!,
      if (s?.hdr != null && s!.hdr!.isNotEmpty) s.hdr!,
    ].join(' · ');
    final aheadSec = math.max(
      0.0,
      (state.bufferedEnd.inMilliseconds - state.position.inMilliseconds) /
          1000.0,
    );
    final downlinkStr =
        LoadingSpeedMeter.formatBandwidth(_lastDownlinkBps) ??
            state.speedLabel ??
            '-';
    return {
      '播放引擎': activeService.isUniversalEngine
          ? 'MediaKit (libmpv 全格式)'
          : 'System Fallback (AVPlayer / ExoPlayer)',
      '交付模式': s?.deliveryMode == 'direct_play'
          ? (_cloudRelay ? 'Direct Play (服务器中转)' : 'Direct Play (原盘直连)')
          : (s?.deliveryMode ?? remote['processing_mode'] ?? 'Direct / Local'),
      '封装容器': (s?.container ?? remote['container'] ?? '-')
          .toString()
          .toUpperCase(),
      '视频规格': resHdr.isEmpty ? '-' : resHdr,
      '视频编码': (s?.videoCodec ?? remote['video_codec'] ?? '-')
          .toString()
          .toUpperCase(),
      '音频编码': (s?.audioCodec ?? remote['audio_codec'] ?? '-')
          .toString()
          .toUpperCase(),
      if (mbps != null) '源文件码率': mbps,
      if (s?.frameRate != null) '帧率': '${s!.frameRate} fps',
      '实时带宽': downlinkStr,
      '前方缓冲': '${aheadSec.toStringAsFixed(1)} 秒',
      '卡顿次数': '$_rebufferCount 次 (${(_rebufferMs / 1000).toStringAsFixed(1)}s)',
      '转码加速': s?.hwBackend ?? remote['backend'] ?? '无需转码 (直通)',
      '画质档位': state.qualityTier,
      if (remote['job_speed'] != null) '转码速度': remote['job_speed'],
      if (_serverSessionId != null) '会话 ID': _serverSessionId!,
    };
  }

  // ── QoE 指标落盘上报 ────────────────────────────────────────────────────

  void _beginQoeRecord(PlayerPageArgs args) {
    _attemptId = 'mc-${DateTime.now().millisecondsSinceEpoch}';
    _openStartedAt = DateTime.now();
    _firstFrameAt = null;
    _watchedMs = 0;
    _rebufferMs = 0;
    _rebufferCount = 0;
    _seekCount = 0;
    _bufferingSince = null;
    _lastWatchedTick = null;
    if (!args.isClip && !args.isShare) {
      unawaited(PlaybackReportQueue.instance.recoverAbnormalExit());
    }
  }

  void _flushWatchedMs() {
    if (_lastWatchedTick != null) {
      final delta = DateTime.now().difference(_lastWatchedTick!).inMilliseconds;
      if (delta > 0 && delta < 30000) _watchedMs += delta;
      _lastWatchedTick = null;
    }
  }

  Map<String, dynamic> _buildQoePayload({required String outcome}) {
    _flushWatchedMs();
    final args = _currentArgs;
    final s = _lastSession;
    final ttff = (_openStartedAt != null && _firstFrameAt != null)
        ? _firstFrameAt!.difference(_openStartedAt!).inMilliseconds
        : null;
    return <String, dynamic>{
      'attempt_id': _attemptId,
      'outcome': outcome,
      'media_item_id': args?.mediaItemId,
      'season_number': args?.seasonNumber ?? 0,
      'episode_number': args?.episodeNumber ?? 0,
      'library_file_id': s?.fileId ?? args?.fileId,
      'tier': s?.tier ?? 0,
      if (s?.degradedFrom != null) 'degraded_from': s!.degradedFrom,
      'engine': activeService.isUniversalEngine ? 'media_kit' : 'system',
      'hw_backend': s?.hwBackend ?? '',
      if (ttff != null) 'ttff_ms': ttff,
      if (ttff != null) 'first_frame_ms': ttff,
      'rebuffer_ms': _rebufferMs,
      'rebuffer_count': _rebufferCount,
      'seek_count': _seekCount,
      'watched_ms': _watchedMs,
      'network_class': PlaybackRouteEnv.current().name,
      'client': 'mc-flutter',
      'app_version': McClient.appVersion,
    };
  }

  void _markQoeActive() {
    final args = _currentArgs;
    if (args == null || args.isClip || args.isShare || _attemptId == null) {
      return;
    }
    final outcome = _backgrounded && !state.playing ? 'exited' : 'abnormal_exit';
    unawaited(
      PlaybackReportQueue.instance.markActive(
        serverOrigin: _serverOrigin,
        payload: _buildQoePayload(outcome: outcome),
      ),
    );
  }

  void _submitClientLog(String event, Map<String, dynamic> detail) {
    final api = _sessionApi;
    if (api == null || (_currentArgs?.isShare ?? false)) return;
    unawaited(
      api
          .submitClientLog({
            'event': event,
            'detail': {
              ...detail,
              if (_attemptId != null) 'attempt_id': _attemptId,
            },
          })
          .catchError((_) {}),
    );
  }

  // ── 清理与退出 ──────────────────────────────────────────────────────────

  void _cancelTimersOnly() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _skipNoticeTimer?.cancel();
    _skipNoticeTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _qualityOfferTimer?.cancel();
    _qualityOfferTimer = null;
  }

  Future<void> _finishCurrentUnit({required bool sendStop}) async {
    _cancelTimersOnly();
    _detachServiceListeners();

    if (sendStop && _reportedStart && !state.isClip) {
      _enqueueProgress(event: 'stop', paused: true);
    }
    _reportedStart = false;

    final args = _currentArgs;
    final api = _sessionApi;
    if (args != null &&
        api != null &&
        !args.isClip &&
        !args.isShare &&
        _attemptId != null) {
      final outcome = state.status == PlayerStatus.failed
          ? 'failed'
          : (state.completed ? 'completed' : 'exited');
      unawaited(
        PlaybackReportQueue.instance.submit(
          serverOrigin: _serverOrigin,
          payload: _buildQoePayload(outcome: outcome),
          api: api,
        ),
      );
      _attemptId = null;
    }

    final sid = _serverSessionId;
    _serverSessionId = null;
    if (sid != null && api != null) {
      unawaited(api.stop(sid).catchError((_) {}));
    }
  }

  void _flashNotice(String text) {
    _noticeTimer?.cancel();
    state = state.copyWith(controllerNotice: text);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (state.controllerNotice == text) {
        state = state.copyWith(clearControllerNotice: true);
      }
    });
  }

  String? _firstDefault(List<String> refs) => refs.isEmpty ? null : refs.first;

  void detach() {
    _attempt += 1;
    unawaited(_finishCurrentUnit(sendStop: true));
  }

  Future<void> exit() async {
    _attempt += 1;
    await _finishCurrentUnit(sendStop: true);
    await activeService.close();
    if (_fallbackService != null) {
      await _fallbackService!.close();
      _fallbackService = null;
    }
    unawaited(PlayerSystemBridge.instance.clearNowPlaying());
    state = const PlayerPlayback(status: PlayerStatus.idle);
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerPlayback>(PlayerController.new);
