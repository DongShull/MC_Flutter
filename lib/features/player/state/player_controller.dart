import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/player/playback_memory.dart';
import '../../../core/player/player_page_args.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/player_service.dart' as ps;
import '../../../core/player/session/playback_session_api.dart';
import '../../../core/player/skip_segments.dart';
import '../../../core/player/watchdogs.dart';

// PlayerPageArgs / EpisodeItem 已下沉 core（detail 等入口可构造，禁跨 feature import）。
export '../../../core/player/player_page_args.dart';

enum PlayerStatus { idle, opening, ready, failed }

/// 服务器协商结果（decision != plan 时挂在状态上等 UI 弹窗）。
enum SessionDecision { plan, consent, rejected }

/// 跳过提示角标的操作：撤回本次跳过 / 以后不再自动跳过片头。
enum PlayerNoticeAction { undoSkip, unlearnIntro }

/// 跳过提示（「已跳过片头 · 撤回」「本剧以后自动跳过片头 · 不用」）。
/// [action] 为 null = 纯提示，无按钮。
@immutable
class PlayerSkipNotice {
  const PlayerSkipNotice({
    required this.text,
    this.action,
    this.segmentStartMs,
  });

  final String text;
  final PlayerNoticeAction? action;

  /// 撤回 = seek 回段首（仅 [PlayerNoticeAction.undoSkip] 用）。
  final int? segmentStartMs;
}

/// 播放页可观察状态（对应 Android PlaybackSessionHolder.State + 引擎 state 的 UI 子集）。
@immutable
class PlayerPlayback {
  const PlayerPlayback({
    this.status = PlayerStatus.idle,
    this.error,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.pendingDecision,
    this.skipSegments = const [],
    this.skipNotice,
    this.infoNotice,
    this.upNextVisible = false,
    this.upNextSecondsLeft,
    this.autoNextRequested = false,
    this.reconnectAttempt = 0,
  });

  final PlayerStatus status;
  final String? error;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;

  /// consent：需用户确认转码；rejected：服务器拒绝。null = 无待处理协商结果。
  final SessionDecision? pendingDecision;

  /// 服务器会话下发的可跳区间（片头/片尾；进度条琥珀色标出）。
  final List<PlaybackSkipSegment> skipSegments;

  /// 跳过提示角标（带撤回/不用按钮；null = 不显示）。
  final PlayerSkipNotice? skipNotice;

  /// 纯文字提示（「已沿用上次的选择」等；null = 不显示）。
  final String? infoNotice;

  /// 「即将播放下一集」卡片是否显示。
  final bool upNextVisible;

  /// 自动连播倒计时剩余秒数；null = 只显示卡片，不倒计时
  /// （最后 40 秒兜底或已认出片尾但未武装时）。
  final int? upNextSecondsLeft;

  /// true = 倒计时走完（或用户点了「立即播放」），播放页应切下一集。
  /// 切集开始（open）时清掉；页侧用 ref.listen 监听 false→true 的跳变。
  final bool autoNextRequested;

  /// 自动重连进行中是第几次（0 = 不在重连）。
  final int reconnectAttempt;

  PlayerPlayback copyWith({
    PlayerStatus? status,
    String? error,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    SessionDecision? pendingDecision,
    bool clearError = false,
    bool clearDecision = false,
    List<PlaybackSkipSegment>? skipSegments,
    bool clearSkipSegments = false,
    PlayerSkipNotice? skipNotice,
    bool clearSkipNotice = false,
    String? infoNotice,
    bool clearInfoNotice = false,
    bool? upNextVisible,
    int? upNextSecondsLeft,
    bool clearUpNextCountdown = false,
    bool? autoNextRequested,
    int? reconnectAttempt,
  }) {
    return PlayerPlayback(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      pendingDecision: clearDecision ? null : (pendingDecision ?? this.pendingDecision),
      skipSegments: clearSkipSegments ? const [] : (skipSegments ?? this.skipSegments),
      skipNotice: clearSkipNotice ? null : (skipNotice ?? this.skipNotice),
      infoNotice: clearInfoNotice ? null : (infoNotice ?? this.infoNotice),
      upNextVisible: upNextVisible ?? this.upNextVisible,
      upNextSecondsLeft: clearUpNextCountdown
          ? null
          : (upNextSecondsLeft ?? this.upNextSecondsLeft),
      autoNextRequested: autoNextRequested ?? this.autoNextRequested,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    );
  }
}

/// 全 App 唯一播放器实例（docs/design/03 §2.1：provider 挂全局单例）。
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService.create();
  ref.onDispose(service.close);
  return service;
});

/// 播放页控制器：只做「服务调用 + 状态搬运」，UI 全在 widgets/。
/// 对应 Android PlayerViewModel / PlaybackSessionHolder 的播放控制部分。
///
/// P3 接入的原生规则（纯 Dart 移植，见 `core/player/`）：
/// - 自动跳过片头片尾 + UpNext 自动连播（`SkipSegments`）；
/// - 断线重连 / 卡死看门狗（`ReconnectBackoff` / `StallWatch` /
///   `NetworkRestartBudget` / `PrematureEndGuard` / `NativeRetryBudget`）；
/// - 画质记忆 + 倍速记忆（`QualityMemory` / `SpeedMemory`）。
class PlayerController extends Notifier<PlayerPlayback> {
  static const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// 自动跳过总开关（Kotlin `SkipSegments.autoSkips` 的 enabled 入参）。
  /// 设置页尚未提供该开关（不改设置页，见任务范围），先默认开启；
  /// 开关落地后由设置注入。
  static const autoSkipEnabled = true;

  /// 片头“学过”标记的存储键（值为 mediaItemId 的 JSON 列表）。
  static const introLearnedKey = 'player.intro-learned';

  PlayerService get _service => ref.read(playerServiceProvider);

  PlaybackSessionApi? _sessionApi;
  String? _serverSessionId;
  Timer? _pingTimer;
  DateTime _lastProgressReport = DateTime.fromMillisecondsSinceEpoch(0);
  PlayerPageArgs? _currentArgs;

  /// 画质 / 倍速记忆（P2；懒加载，加载失败 = 无记忆，仍可播放）。
  PlaybackMemories? _memories;
  PlaybackNetwork _network = PlaybackNetwork.unknown;

  /// 当前画质档（上限语义；null = 尚未起播/未选）。
  /// 起播时按影片 × 网络取记忆；用户改档后以用户选择为准。
  QualityOption? _selectedQuality;
  int? _qualityMediaItemId;
  bool _qualityFromMemory = false;

  /// 菜单倍速（长按 2× 只临时覆盖引擎，不动这一档；见 [setHoldSpeed]）。
  double _menuSpeed = 1.0;
  int? _speedMediaItemId;
  bool _speedFromMemory = false;

  /// 本次起播沿用了记忆的提示（null = 全部默认，无需提示）。
  String? _rememberedNotice;

  /// 当前画质档（播放设置面板显示用；null = 未起播）。
  QualityOption? get currentQuality => _selectedQuality;

  /// 当前画质是否来自记忆（面板显示“已沿用上次的选择”用）。
  bool get qualityFromMemory => _qualityFromMemory;

  /// 本次起播沿用了哪些记忆（供播放页开播提示；null = 无需提示）。
  String? get rememberedNotice => _rememberedNotice;

  /// 服务器会话给出的可选轨道（open 时刷新；空 = 服务器未提供轨道信息）。
  List<PlaybackAudioTrack> _audioTracks = const [];
  List<PlaybackSubtitleTrack> _subtitles = const [];
  String? _selectedAudioTrack;
  String? _selectedSubtitleTrack;

  List<PlaybackAudioTrack> get audioTracks => _audioTracks;
  List<PlaybackSubtitleTrack> get subtitles => _subtitles;
  String? get selectedAudioTrack => _selectedAudioTrack;
  String? get selectedSubtitleTrack => _selectedSubtitleTrack;

  // —— P3：看门狗 / 重连 ——
  StreamSubscription<PlaybackState>? _engineSub;
  final _stallWatch = StallWatch();
  final _networkRestarts = NetworkRestartBudget();
  final _prematureEnd = PrematureEndGuard();
  final _nativeRetries = NativeRetryBudget();
  final _reconnectBackoff = ReconnectBackoff();
  DateTime _lastStallSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastBufferedEndMs = 0;
  DateTime _seekingUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _everReady = false;
  bool _handlingFailure = false;
  bool _reopening = false;
  bool _userPaused = false;

  /// open/detach/exit 的代次：重连循环每轮都核对，代次变了就停
  /// （用户已退出或切集，不在后台继续重开）。
  int _generation = 0;

  // —— P3：自动跳过 / UpNext ——
  int? _lastPositionMs;
  PlaybackSkipSegment? _autoSkippedSegment;
  Timer? _upNextTimer;
  Timer? _noticeTimer;
  bool _upNextDismissed = false;
  int _autoNextStreak = 0;

  // —— P3：画质 / 倍速记忆 ——
  QualityMemory? _qualityMemory;
  SpeedMemory? _speedMemory;
  SharedPreferences? _prefs;
  Set<int> _learnedIntroIds = {};

  /// 30s 心跳（服务器口径；本地协调器心跳独立 5s）。
  void _startPing() {
    _pingTimer?.cancel();
    final id = _serverSessionId;
    if (id == null) return;
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sessionApi?.ping(id).catchError((_) {});
    });
  }

  Future<void> _stopSession() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    final id = _serverSessionId;
    _serverSessionId = null;
    if (id != null) {
      await _sessionApi?.stop(id).catchError((_) {});
    }
  }

  @override
  PlayerPlayback build() => const PlayerPlayback(status: PlayerStatus.idle);

  /// 当前后端的能力开关（画质/诊断等是否支持，先查这里再调对应方法）。
  PlayerCapability get capabilities => _service.capabilities;

  /// 采集诊断快照（引擎可读字段；拿不到的字段为 null = 缺失）。
  /// 诊断面板 UI 未实现，本方法先供调试/后续面板使用。
  Future<PlayerDiagnostics> collectDiagnostics() =>
      _service.collectDiagnostics(sessionId: _serverSessionId);

  /// 当前/最近一次播放的流地址（cast 投屏复用；DLNA 直连不走会话）。
  String? get lastStreamUrl => _lastUrl;
  String? _lastUrl;

  Future<void> open(PlayerPageArgs args) async {
    _currentArgs = args;
    _lastUrl = args.url;
    // 重连循环里的重开不算新代次（否则循环第一轮就被自己的 open 停掉）；
    // 用户主动开播/切集才换代，正在跑的重连循环随即停下。
    if (!_reopening) _generation += 1;
    _everReady = false;
    _upNextDismissed = false;
    _upNextTimer?.cancel();
    _upNextTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _stallWatch.reset();
    _prematureEnd.reset();
    _nativeRetries.reset();
    _lastPositionMs = null;
    _autoSkippedSegment = null;
    _lastBufferedEndMs = 0;
    // 重开（断线重连/换轨）不经过 detach：先摘掉上一轮的监听与订阅，
    // 否则 _onPosition 会被重复挂多次。
    _service.position.removeListener(_onPosition);
    _service.playing.removeListener(_onPlaying);
    _service.duration.removeListener(_onDuration);
    _engineSub?.cancel();
    _engineSub = null;
    // 切集/重开时清掉上一集的可跳区间（新会话响应再刷新）。
    state = state.copyWith(
      status: PlayerStatus.opening,
      clearError: true,
      clearSkipSegments: true,
      clearSkipNotice: true,
      clearInfoNotice: true,
      upNextVisible: false,
      clearUpNextCountdown: true,
      autoNextRequested: false,
      reconnectAttempt: 0,
    );
    try {
      // 服务器会话协商（正式路径）：mediaItemId/fileId 在才走；演示路径直连 url。
      var url = args.url;
      var startPosition = args.startPosition;
      if (args.mediaItemId != null || args.fileId != null) {
        _sessionApi = PlaybackSessionApi(McClient(session: ref.read(sessionStoreProvider)));
        // 画质 / 倍速记忆（P2，安卓 PlaybackController.init 同款）：
        // 起播前按影片 × 网络取上次的选择，换片时重新取，换轨/改画质重开时沿用当前选择。
        try {
          _memories ??= await PlaybackMemories.load();
        } catch (_) {
          _memories = null; // 记忆读不到 = 无记忆，不阻塞起播。
        }
        _network =
            PlaybackNetwork.ofServerUrl(ref.read(sessionStoreProvider).baseUrl);
        final mediaId = args.mediaItemId;
        if (mediaId != null &&
            (mediaId != _qualityMediaItemId || _selectedQuality == null)) {
          final remembered =
              _memories?.quality.quality(mediaId, _network);
          _selectedQuality = remembered == null
              ? QualityOption.original
              : QualityOption.all.firstWhere(
                  (o) => o.maxHeight == remembered,
                  orElse: () => QualityOption.original,
                );
          _qualityMediaItemId = mediaId;
          _qualityFromMemory = remembered != null;
        }
        if (mediaId != null && mediaId != _speedMediaItemId) {
          final rememberedSpeed = _memories?.speed.speed(mediaId);
          _menuSpeed = rememberedSpeed ?? 1.0;
          _speedMediaItemId = mediaId;
          _speedFromMemory = rememberedSpeed != null;
        }
        _rememberedNotice = RememberedChoices.notice(
          quality: _qualityFromMemory ? _selectedQuality?.maxHeight : null,
          network: _qualityFromMemory ? _network : null,
          speed: _speedFromMemory ? _menuSpeed : null,
        );
        final session = await _sessionApi!.start(
          fileId: args.fileId,
          mediaItemId: args.mediaItemId,
          seasonNumber: args.seasonNumber,
          episodeNumber: args.episodeNumber,
          startMs: args.startPosition?.inMilliseconds,
          audioTrack: _selectedAudioTrack,
          subtitleTrack: _selectedSubtitleTrack,
          // 画质上限走服务端会话（`max_height`，转码上限语义），
          // 不是引擎内视频轨选择——见 docs/PLAYER_MATRIX.md P2 决策。
          maxHeight: _selectedQuality?.maxHeight,
        );
        if (session.playable) {
          _serverSessionId = session.sessionId;
          url = session.streamUrl!;
          _audioTracks = session.audioTracks;
          _subtitles = session.subtitles;
          state = state.copyWith(skipSegments: session.skipSegments);
          _selectedAudioTrack ??= _firstDefault(
              [for (final t in session.audioTracks) if (t.isDefault) t.ref]);
          _selectedSubtitleTrack ??= _subtitles.isEmpty
              ? null
              : (_firstDefault(
                    [for (final t in _subtitles) if (t.isDefault) t.trackRef],
                  ) ??
                  _subtitles.first.trackRef);
          if (args.startPosition == null && session.startMs > 0) {
            startPosition = Duration(milliseconds: session.startMs);
          }
          _startPing();
        } else {
          // consent = 需用户确认转码；rejected = 服务器拒绝。挂状态给 UI 弹窗，
          // 同时先按原 url 兜底直播（不因协商失败黑屏）。
          debugPrint('playback session decision=${session.decision}');
          state = state.copyWith(
            pendingDecision: session.decision == 'rejected'
                ? SessionDecision.rejected
                : SessionDecision.consent,
          );
        }
      }
      await _service.open(PlayerRequest(
        url: url,
        title: args.title,
        startPosition: startPosition,
        headers: args.headers,
        sessionId: _serverSessionId,
      ));
      state = state.copyWith(status: PlayerStatus.ready);
      // 引擎是新开的：把菜单倍速（记忆或用户刚选的）重新应用到引擎。
      // 长按 2× 不走这里（setHoldSpeed 只临时覆盖引擎，不动 _menuSpeed）。
      await _service.setSpeed(_menuSpeed);
      if (_menuSpeed != 1.0) state = state.copyWith(speed: _menuSpeed);
      _everReady = true;
      _networkRestarts.reachedPlaying();
      _reconnectBackoff.reset();
      // 位置/时长/播放态直接消费服务的稳定通知器（UI 不轮询引擎）。
      _service.position.addListener(_onPosition);
      _service.playing.addListener(_onPlaying);
      _service.duration.addListener(_onDuration);
      // 引擎失败回调：open 成功后才订阅（起播失败直接落 failed 态，
      // 不进重连回路；播放中失败才重连）。
      _engineSub = _service.stateStream.listen(_onEngineState);
      _onPosition();
      _onPlaying();
      _onDuration();
      // 画质/倍速记忆：按片沿用上次的选择（记忆不存在时什么都不做）。
      await _applyRememberedChoices(url);
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.failed,
        error: '播放失败：$e',
      );
    }
  }

  /// 引擎状态流回调：播放中引擎失败 → 重连回路。
  /// 注意：`PlaybackState.status` 是 `player_service.dart` 的
  /// `PlayerStatus`，与本文件的同名 enum 是两个类型，必须用
  /// 前缀 `ps.` 区分，不能直接比 `PlayerStatus.failed`。
  void _onEngineState(PlaybackState s) {
    if (s.status != ps.PlayerStatus.failed) return;
    if (!_everReady || _handlingFailure) return;
    unawaited(_handleEngineFailure(s.error ?? '播放失败', decode: false));
  }

  /// 断线重连回路（对照 Kotlin `PlaybackController.engineFailed`）：
  /// 网络归因先同档原地重开（最多 2 次），再按 2/4/8/15/15/15 秒退避，
  /// 约 1 分钟仍不行才落错误页。解码归因（卡死）3 分钟内只原位重开一次。
  /// 重开失败由本循环自己驱动下一轮（不依赖引擎失败事件：重开时的失败
  /// 事件在 [_handlingFailure] 保护期内会被吞掉）。用户退出/切集时
  /// [_generation] 变化，循环立即停，不在后台继续重开。
  Future<void> _handleEngineFailure(String reason,
      {required bool decode}) async {
    if (_handlingFailure) return;
    _handlingFailure = true;
    final generation = _generation;
    try {
      if (decode) {
        if (_nativeRetries.allowRetry(DateTime.now().millisecondsSinceEpoch) &&
            await _reopenAtCurrentPosition()) {
          return;
        }
        state = state.copyWith(
          status: PlayerStatus.failed,
          error: StallWatch.reason(
              StallVerdict.decodeStalled, StallWatch.serverDeadSeconds),
        );
        return;
      }
      while (_networkRestarts.allowRestart()) {
        if (generation != _generation) return;
        if (await _reopenAtCurrentPosition()) return;
      }
      while (true) {
        final nextDelay = _reconnectBackoff.nextDelayMs();
        if (nextDelay == null) break;
        if (generation != _generation) return;
        state = state.copyWith(
            reconnectAttempt: state.reconnectAttempt + 1);
        await Future<void>.delayed(Duration(milliseconds: nextDelay));
        if (generation != _generation) return;
        if (await _reopenAtCurrentPosition()) return;
      }
      state = state.copyWith(status: PlayerStatus.failed, error: reason);
    } finally {
      _handlingFailure = false;
    }
  }

  /// 从当前位置重开（新会话 = 新 token；重开时不重置重连预算，
  /// 预算由 open 成功后的 reachedPlaying / reset 清掉）。
  /// 返回是否恢复到 ready。
  Future<bool> _reopenAtCurrentPosition() async {
    if (_reopening) return false;
    final args = _currentArgs;
    if (args == null) return false;
    _reopening = true;
    try {
      final pos = _service.position.value;
      _stallWatch.reset();
      await open(_copyArgsAt(args, pos));
      return state.status == PlayerStatus.ready;
    } finally {
      _reopening = false;
    }
  }

  void _onPosition() {
    final prevMs = _lastPositionMs;
    final posMs = _service.position.value.inMilliseconds;
    _lastPositionMs = posMs;
    state = state.copyWith(position: _service.position.value);
    // 观看进度上报：15s 节流（POST /playback/progress）。
    final args = _currentArgs;
    final now = DateTime.now();
    if (args?.mediaItemId != null &&
        state.status == PlayerStatus.ready &&
        now.difference(_lastProgressReport) >= const Duration(seconds: 15)) {
      _lastProgressReport = now;
      _sessionApi
          ?.reportProgress(
            mediaItemId: args!.mediaItemId!,
            seasonNumber: args.seasonNumber,
            episodeNumber: args.episodeNumber,
            event: 'progress',
            positionMs: state.position.inMilliseconds,
            paused: !state.playing,
          )
          .catchError((_) {});
    }
    if (state.status == PlayerStatus.ready) {
      // 卡死看门狗：每秒采样一次。
      if (now.difference(_lastStallSampleAt) >= const Duration(seconds: 1)) {
        _lastStallSampleAt = now;
        _sampleStall();
      }
      unawaited(_maybeAutoSkip(prevMs));
      _evaluateUpNext();
    }
  }

  /// 每秒喂一次 [StallWatch]：缓冲末端是否在推进近似“字节还在进来”
  /// （video_player 不暴露字节级接收信号；见 watchdogs.dart 注释）。
  /// 判定出卡死/断线时走 [_handleEngineFailure]；Nudge 是原地推一把。
  void _sampleStall() {
    final pos = _service.position.value;
    final buffered = _service.state.buffered;
    final bufferedEndMs = buffered.inMilliseconds;
    final receiving = bufferedEndMs > _lastBufferedEndMs;
    _lastBufferedEndMs = bufferedEndMs;
    final verdict = _stallWatch.sample(
      time: pos.inMilliseconds / 1000.0,
      bufferedAhead: (buffered - pos).inMilliseconds / 1000.0,
      paused: !state.playing,
      ended: false,
      seeking: DateTime.now().isBefore(_seekingUntil),
      receiving: receiving,
      // 直出/转码分不清（会话不暴露档位来源）：按服务端流 45 秒算，
      // 误判只会晚一点报断线，不会早报。
      deadLimit: StallWatch.serverDeadSeconds,
    );
    switch (verdict) {
      case StallVerdict.nudge:
        unawaited(_service.seekTo(
            pos + const Duration(milliseconds: StallWatch.nudgeStepMs)));
      case StallVerdict.decodeStalled:
        unawaited(_handleEngineFailure(
          StallWatch.reason(
              StallVerdict.decodeStalled, StallWatch.serverDeadSeconds),
          decode: true,
        ));
      case StallVerdict.dead:
        unawaited(_handleEngineFailure(
          StallWatch.reason(
              StallVerdict.dead, StallWatch.serverDeadSeconds),
          decode: false,
        ));
      case StallVerdict.ok:
        break;
    }
  }

  /// 自然播进可跳区间时直接跳过（广告/预告直接跳；片头要这部剧学过才跳）。
  /// seek 跳进、大跳、回退不触发；同一段只触发一次（撤回后不再反复跳）。
  Future<void> _maybeAutoSkip(int? prevMs) async {
    final segments = state.skipSegments;
    if (segments.isEmpty ||
        !state.playing ||
        state.status != PlayerStatus.ready) {
      return;
    }
    final posMs = state.position.inMilliseconds;
    final active = SkipSegments.active(segments, posMs);
    if (active == null || prevMs == null) return;
    final delta = posMs - prevMs;
    if (delta <= 0 || delta > 5000) return;
    if (_autoSkippedSegment == active) return;
    final id = _currentArgs?.mediaItemId;
    final learned = id != null && _learnedIntroIds.contains(id);
    if (!SkipSegments.autoSkips(active, autoSkipEnabled, learned)) return;
    _autoSkippedSegment = active;
    await _service.seekTo(Duration(milliseconds: active.endMs));
    state = state.copyWith(position: Duration(milliseconds: active.endMs));
    _showSkipNotice(
      SkipNotice(
        DateTime.now().microsecondsSinceEpoch,
        SkipNoticeKind.skipped,
        segment: active,
      ),
    );
  }

  /// 手动跳过当前区间（跳过按钮入口）：seek 到段尾；片头第一次手动跳过
  /// 就记为“这部剧学过”，提示过期后追加“本剧以后自动跳过片头 · 不用”。
  Future<void> skipSegment(PlaybackSkipSegment segment) async {
    final id = _currentArgs?.mediaItemId;
    var justLearned = false;
    if (segment.type == 'intro' &&
        id != null &&
        !_learnedIntroIds.contains(id)) {
      await _markIntroLearned(id);
      justLearned = true;
    }
    _noteUserActivity();
    await _service.seekTo(Duration(milliseconds: segment.endMs));
    state = state.copyWith(position: Duration(milliseconds: segment.endMs));
    _showSkipNotice(
      SkipNotice(
        DateTime.now().microsecondsSinceEpoch,
        SkipNoticeKind.skipped,
        segment: segment,
      ),
      followUpLearned: justLearned,
    );
  }

  /// 跳过提示角标的操作：撤回 = seek 回段首；不用 = 取消本剧自动跳过片头。
  Future<void> handleSkipNoticeAction() async {
    final notice = state.skipNotice;
    if (notice == null) return;
    switch (notice.action) {
      case PlayerNoticeAction.undoSkip:
        _noticeTimer?.cancel();
        state = state.copyWith(clearSkipNotice: true);
        final startMs = notice.segmentStartMs;
        if (startMs != null) {
          await _service.seekTo(Duration(milliseconds: startMs));
          state = state.copyWith(position: Duration(milliseconds: startMs));
        }
      case PlayerNoticeAction.unlearnIntro:
        _noticeTimer?.cancel();
        state = state.copyWith(clearSkipNotice: true);
        final id = _currentArgs?.mediaItemId;
        if (id != null) await _unmarkIntroLearned(id);
        _showInfoNotice(
          const SkipNotice(0, SkipNoticeKind.forgot).text,
          SkipSegments.infoNoticeMs,
        );
      case null:
        break;
    }
  }

  void dismissSkipNotice() {
    _noticeTimer?.cancel();
    state = state.copyWith(clearSkipNotice: true);
  }

  void _showSkipNotice(SkipNotice notice, {bool followUpLearned = false}) {
    _noticeTimer?.cancel();
    state = state.copyWith(
      skipNotice: PlayerSkipNotice(
        text: notice.text,
        action: PlayerNoticeAction.undoSkip,
        segmentStartMs: notice.segment?.startMs,
      ),
    );
    _noticeTimer = Timer(Duration(milliseconds: notice.durationMs), () {
      if (state.skipNotice?.text != notice.text) return;
      if (followUpLearned) {
        // 片头刚学会：追加“本剧以后自动跳过片头 · 不用”。
        state = state.copyWith(
          skipNotice: const PlayerSkipNotice(
            text: '本剧以后自动跳过片头',
            action: PlayerNoticeAction.unlearnIntro,
          ),
        );
        _noticeTimer = Timer(
            const Duration(milliseconds: SkipSegments.skipNoticeMs), () {
          if (state.skipNotice?.text == '本剧以后自动跳过片头') {
            state = state.copyWith(clearSkipNotice: true);
          }
        });
      } else {
        state = state.copyWith(clearSkipNotice: true);
      }
    });
  }

  void _showInfoNotice(String text, int durationMs) {
    _noticeTimer?.cancel();
    state = state.copyWith(infoNotice: text);
    _noticeTimer = Timer(Duration(milliseconds: durationMs), () {
      if (state.infoNotice == text) {
        state = state.copyWith(clearInfoNotice: true);
      }
    });
  }

  /// UpNext 卡片评估（每位置更新跑一次）：
  /// 认出的片尾 → 8 秒倒计时自动播；最后 40 秒兜底 → 只显示卡片。
  void _evaluateUpNext() {
    final segments = state.skipSegments;
    final posMs = state.position.inMilliseconds;
    final durMs = state.duration?.inMilliseconds;
    if (_upNextDismissed) return;
    if (SkipSegments.autoNextArmed(segments, posMs, _autoNextStreak)) {
      if (_upNextTimer == null) _startUpNextCountdown();
      return;
    }
    if (SkipSegments.shouldShowUpNext(segments, posMs, durMs)) {
      _upNextTimer?.cancel();
      _upNextTimer = null;
      if (!state.upNextVisible) {
        state = state.copyWith(
            upNextVisible: true, clearUpNextCountdown: true);
      }
      return;
    }
    // 既不在片尾也不在最后 40 秒：倒计时中途被 seek 走也要取消，
    // 否则倒计时走完会误切下一集。
    _upNextTimer?.cancel();
    _upNextTimer = null;
    if (state.upNextVisible) {
      state = state.copyWith(upNextVisible: false);
    }
  }

  void _startUpNextCountdown() {
    _upNextTimer?.cancel();
    var left = SkipSegments.autoNextMs ~/ 1000;
    state = state.copyWith(upNextVisible: true, upNextSecondsLeft: left);
    _upNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      left -= 1;
      if (left <= 0) {
        timer.cancel();
        _upNextTimer = null;
        _fireAutoNext();
      } else {
        state = state.copyWith(upNextSecondsLeft: left);
      }
    });
  }

  /// 倒计时走完或用户点「立即播放」：页侧监听 [PlayerPlayback.autoNextRequested]
  /// 的 false→true 跳变后切下一集；连续自动播 3 集后不再自动播。
  void _fireAutoNext() {
    _autoNextStreak += 1;
    state = state.copyWith(
      upNextVisible: false,
      clearUpNextCountdown: true,
      autoNextRequested: true,
    );
  }

  void requestAutoNext() {
    if (!state.upNextVisible) return;
    _upNextTimer?.cancel();
    _upNextTimer = null;
    _noteUserActivity();
    _fireAutoNext();
  }

  void dismissUpNext() {
    _upNextTimer?.cancel();
    _upNextTimer = null;
    _upNextDismissed = true;
    _noteUserActivity();
    state = state.copyWith(upNextVisible: false, clearUpNextCountdown: true);
  }

  /// 用户碰过播放器：连续自动播计数清零（Kotlin 口径：连续自动播期间
  /// 没人碰过播放器才继续自动播）。
  void _noteUserActivity() {
    _autoNextStreak = 0;
  }

  void _onPlaying() {
    final wasPlaying = state.playing;
    final nowPlaying = _service.playing.value;
    state = state.copyWith(playing: nowPlaying);
    if (wasPlaying && !nowPlaying && state.status == PlayerStatus.ready) {
      final posMs = state.position.inMilliseconds;
      final durMs = state.duration?.inMilliseconds;
      if (_userPaused || durMs == null) return;
      // 引擎“播完”时离片尾还远 = 取流断了，从当前位置重开一次；
      // 原地附近又报播完就认定真到了结尾，不反复重开。
      if (_prematureEnd.shouldResume(posMs, durMs)) {
        unawaited(_reopenAtCurrentPosition());
      } else if (durMs - posMs <= 0) {
        // 真播完了：UpNext 卡片兜底（ended 口径）。
        if (SkipSegments.shouldShowUpNext(
            state.skipSegments, posMs, durMs,
            ended: true)) {
          state = state.copyWith(
              upNextVisible: true, clearUpNextCountdown: true);
        }
      }
    }
  }

  void _onDuration() =>
      state = state.copyWith(duration: _service.duration.value);

  void detach() {
    _generation += 1;
    _stopSession();
    _engineSub?.cancel();
    _engineSub = null;
    _upNextTimer?.cancel();
    _upNextTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _everReady = false;
    _handlingFailure = false;
    _service.position.removeListener(_onPosition);
    _service.playing.removeListener(_onPlaying);
    _service.duration.removeListener(_onDuration);
  }

  /// 取第一个默认轨引用（不引 collection 包，手写 firstOrNull 口径）。
  String? _firstDefault(List<String> refs) =>
      refs.isEmpty ? null : refs.first;

  /// 换音轨/字幕轨：**服务端重开续播**（P2 决策，见 docs/PLAYER_MATRIX.md）。
  /// 不走引擎内切轨：video_player 的引擎轨 id 与服务端轨引用（`embedded:N`）
  /// 没有定义的映射关系，且转码档/烧录字幕只在服务端会话里，
  /// 引擎切轨可能与服务端转码档不一致；字幕轨 video_player 根本没有 API。
  /// 与安卓原生同策略的引擎优先分支不同——安卓有 ExoPlayer 轨组 +
  /// `embeddedIndexOf(ref)` 映射，Flutter 没有。subtitleTrack 传 '' 表示
  /// 关闭字幕；null 表示保持不变。
  Future<void> switchTrack({String? audioTrack, String? subtitleTrack}) async {
    final args = _currentArgs;
    if (args == null || _sessionApi == null) return;
    final pos = _service.position.value;
    detach();
    if (audioTrack != null) _selectedAudioTrack = audioTrack;
    if (subtitleTrack != null) _selectedSubtitleTrack = subtitleTrack;
    _noteUserActivity();
    await open(_copyArgsAt(args, pos));
  }

  /// 以当前进度续播复制 args（换轨/换集共用口径：startPosition = 当前进度）。
  PlayerPageArgs _copyArgsAt(PlayerPageArgs args, Duration position) {
    return PlayerPageArgs(
      url: args.url,
      mediaItemId: args.mediaItemId,
      fileId: args.fileId,
      seasonNumber: args.seasonNumber,
      episodeNumber: args.episodeNumber,
      title: args.title,
      subtitle: args.subtitle,
      startPosition: position,
      headers: args.headers,
      isEpisode: args.isEpisode,
      seasons: args.seasons,
      episodes: args.episodes,
    );
  }

  /// 用户在协商弹窗点了「继续播放」（consent 确认，或 rejected 仍要看）。
  Future<void> acknowledgeDecision() async {
    state = state.copyWith(clearDecision: true);
  }

  Future<void> togglePlay() async {
    if (state.playing) {
      _userPaused = true;
      await _service.pause();
    } else {
      _userPaused = false;
      _noteUserActivity();
      await _service.play();
    }
  }

  /// 拖动条点按 / 拖动松手 / 章节跳播统一入口（钳制在 [0, duration]）。
  Future<void> seekTo(Duration target) async {
    final duration = state.duration;
    final clamped = duration == null
        ? (target.isNegative ? Duration.zero : target)
        : target < Duration.zero
            ? Duration.zero
            : (target > duration ? duration : target);
    _noteUserActivity();
    _seekingUntil = DateTime.now().add(const Duration(seconds: 2));
    await _service.seekTo(clamped);
    state = state.copyWith(position: clamped);
  }

  /// 手势横向滑动：满屏一划 = 90 秒（Android PlayerGestureMath）。
  Future<void> seekByRelative(int deltaMs) async {
    final base = _service.position.value;
    await seekTo(base + Duration(milliseconds: deltaMs));
  }

  /// 改画质档（上限语义；对齐安卓 `PlaybackController.selectQuality`）。
  /// 记入画质记忆（原画 = 删掉记忆），然后**服务端重开续播**：
  /// 画质上限是转码参数，必须带 `max_height` 重开会话；
  /// 引擎内视频轨选择只是 HLS/DASH 变体选择，与转码上限不是同一语义，
  /// 且 web 上没有该 API。无服务端会话的直连播放（演示/本地直链）没有
  /// 会话可重开，退到引擎变体选择（后端不支持时抛 UnsupportedError，
  /// 调用方提示用户；这是“无会话”的唯一路径，不是第二套切轨策略）。
  /// 注意：安卓在“直通原文件且源不超上限”时可不重开；Flutter 拿不到
  /// 片源高度，改档一律重开（多一次重开，换来行为确定）。
  Future<void> setQuality(QualityOption quality) async {
    if (_selectedQuality?.maxHeight == quality.maxHeight) return;
    final args = _currentArgs;
    final mediaId = args?.mediaItemId;
    final memories = _memories;
    if (mediaId != null && memories != null) {
      unawaited(memories.quality
          .remember(quality.maxHeight, mediaId, _network)
          .catchError((_) {}));
    }
    _selectedQuality = quality;
    if (mediaId != null) _qualityMediaItemId = mediaId;
    _qualityFromMemory = false;
    _rememberedNotice = null;
    if (args == null || _sessionApi == null) {
      // 无会话直连：只能调引擎变体（见方法注释）。
      await _service.setQuality(quality);
      return;
    }
    final pos = _service.position.value;
    detach();
    await open(_copyArgsAt(args, pos));
  }

  /// 菜单选倍速：按这部片记（换会话、换集都保持；选回常速就删掉记忆）。
  /// 长按 2× 不走这里（见 [setHoldSpeed]）。
  Future<void> setSpeed(double speed) async {
    _menuSpeed = speed;
    await _service.setSpeed(speed);
    state = state.copyWith(speed: speed);
    final mediaId = _currentArgs?.mediaItemId;
    final memories = _memories;
    if (mediaId != null && memories != null) {
      unawaited(memories.speed.remember(speed, mediaId).catchError((_) {}));
    }
  }

  /// 长按 2× 变速（Android HOLD_SPEED = 2f）：按住升到 2×，松手回原速。
  /// 只临时覆盖引擎：不动 [_menuSpeed]、不写倍速记忆（P2 修正：
  /// 旧实现调 [setSpeed]，松手会把 1.0 写进记忆，污染“按片记的倍速”）。
  Future<void> setHoldSpeed(bool holding) async {
    final target = holding ? 2.0 : _menuSpeed;
    await _service.setSpeed(target);
    state = state.copyWith(speed: target);
  }

  Future<void> exit() async {
    detach();
    await _service.close();
    state = const PlayerPlayback(status: PlayerStatus.idle);
  }

  /// 注入可跳区间（会话之外的来源，如离线本地播放；测试也用它）。
  void updateSkipSegments(List<PlaybackSkipSegment> segments) {
    state = state.copyWith(skipSegments: segments);
  }

  // —— P3：画质 / 倍速记忆 ——

  Future<void> _ensureMemories() async {
    if (_qualityMemory != null) return;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    // 统一用 P2 的 PlaybackMemories（PrefsStringStore 抽象）作为唯一记忆源，
    // 与 open() 内联加载和 setQuality/setSpeed 共用同一份 store，避免双系统读写不一致。
    _memories ??= await PlaybackMemories.load();
    _qualityMemory = _memories?.quality;
    _speedMemory = _memories?.speed;
    _learnedIntroIds = _loadLearnedIntros(prefs);
  }

  static Set<int> _loadLearnedIntros(SharedPreferences prefs) {
    final raw = prefs.getString(introLearnedKey);
    if (raw == null) return {};
    try {
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toSet();
      return decoded;
    } catch (_) {
      return {};
    }
  }

  Future<void> _markIntroLearned(int mediaItemId) async {
    await _ensureMemories();
    _learnedIntroIds.add(mediaItemId);
    await _prefs?.setString(
        introLearnedKey, jsonEncode(_learnedIntroIds.toList()));
  }

  Future<void> _unmarkIntroLearned(int mediaItemId) async {
    await _ensureMemories();
    _learnedIntroIds.remove(mediaItemId);
    await _prefs?.setString(
        introLearnedKey, jsonEncode(_learnedIntroIds.toList()));
  }

  /// 开播时沿用记忆：画质（引擎变体选择；不支持时忽略，会话画质为准，
  /// 与服务端转码上限不是同一语义，见 `docs/PLAYER_MATRIX.md`）与倍速。
  /// 沿用了非默认选择时提示一次「已沿用上次的选择」。
  Future<void> _applyRememberedChoices(String url) async {
    final mediaId = _currentArgs?.mediaItemId;
    if (mediaId == null) return;
    await _ensureMemories();
    final network = PlaybackNetwork.ofHost(Uri.tryParse(url)?.host);
    final rememberedQuality = _qualityMemory!.quality(mediaId, network);
    final rememberedSpeed = _speedMemory!.speed(mediaId);
    if (rememberedQuality != null) {
      try {
        await _service.setQuality(QualityOption(
            maxHeight: rememberedQuality, label: '${rememberedQuality}p'));
      } on UnsupportedError {
        // 引擎不支持变体选择（web / 非自适应流）：会话画质为准，不报错。
      }
    }
    if (rememberedSpeed != null && rememberedSpeed != state.speed) {
      await _service.setSpeed(rememberedSpeed);
      state = state.copyWith(speed: rememberedSpeed);
    }
    final notice = RememberedChoices.notice(
      quality: rememberedQuality,
      network: network,
      speed: rememberedSpeed,
    );
    if (notice != null) {
      _showInfoNotice(notice, SkipSegments.skipNoticeMs);
    }
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerPlayback>(PlayerController.new);
