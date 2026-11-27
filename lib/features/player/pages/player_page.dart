import 'dart:async';
import 'dart:io';
import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/episodes_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../../../core/player/player_system_bridge.dart';
import '../../../core/player/session/playback_session.dart';
import '../../../core/player/session/playback_session_providers.dart';
import '../state/player_controller.dart';
import '../widgets/cast_sheet.dart';
import '../widgets/player_bottom_controls.dart';
import '../widgets/player_diagnostics_hud.dart';
import '../widgets/player_episode_picker.dart';
import '../widgets/player_gesture_layer.dart';
import '../widgets/player_overlays.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_settings_panel.dart';
import '../widgets/player_subtitle_overlay.dart';

/// 影院级全屏播放器（100% 对齐 iOS PlayerScreen）：
/// - 全 5 端原生 `media_kit` (libmpv) 全格式解码 + AVPlayer 自动兜底；
/// - 真实系统亮度/系统音量/硬件音量键 KVO HUD/AirPlay/Now Playing/方向自由切换（退出恢复 `'all'`）；
/// - 后台音频无缝延续（不再切后台强停）；
/// - ASS `\an1..9` 字幕叠加 + Trickplay 雪碧图预览 + 智能跳片头/广告/预告学习与撤回；
/// - 仅在片尾 `outro(toEnd)` 或真播完出下一集卡片（连播 3 集止步问「还在看吗？」；无下一集播完自动返回详情）；
/// - 片段模式（`PlaybackClip`）与折叠屏半折桌面模式（`PlayerTabletopDeck`）。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, this.args});

  final PlayerPageArgs? args;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _chromeHideAfter = Duration(milliseconds: 3800);
  static const _hudHideAfter = Duration(milliseconds: 1200);
  static const _noticeHideAfter = Duration(milliseconds: 3500);
  static const _participantId = 'player-page';

  final FocusNode _keyFocus = FocusNode(debugLabel: 'McPlayerKeyFocus');
  late PlayerPageArgs _args;

  bool _chromeVisible = true;
  bool _locked = false;
  bool _lockHint = false;
  bool _holdSpeed = false;
  bool _scrubbing = false;
  bool _adjusting = false;
  bool _settingsOpen = false;
  bool _episodePickerOpen = false;
  bool _diagnosticsHudOpen = false;

  // 下一集连播控制
  bool _autoNextCancelled = false;
  bool _autoNextTriggered = false;
  int _autoNextStreak = 0;
  double _autoNextElapsedMs = 0;
  bool _autoExitTriggered = false;

  // 选集抽屉数据
  List<EpisodeItem> _pickerEpisodes = const [];
  List<int> _pickerSeasons = const [];
  int _pickerSeason = 1;
  bool _pickerLoading = false;

  String _displayMode = 'fit';
  String? _notice;
  int? _seekRippleDir;
  bool _manualLandscape = true;
  bool _usingNativeBrightness = false;
  bool _usingNativeVolume = false;

  StreamSubscription<CoordinatorCommand>? _commandSub;
  StreamSubscription<double>? _systemVolumeSub;
  StreamSubscription<PlayerRemoteCommand>? _remoteCmdSub;
  DateTime _lastStateReport = DateTime.fromMillisecondsSinceEpoch(0);
  AppLifecycleListener? _lifecycle;
  bool? _lastReportedPlaying;
  Duration? _scrubPreview;
  ({bool brightness, double level})? _levelHud;
  double _brightnessLevel = 1.0;
  double _volumeLevel = 1.0;
  double _volumeBeforeMute = 1.0;
  bool _muted = false;
  DateTime _lastUserActivity = DateTime.now();
  bool _tvForm = false;
  bool _decisionDialogOpen = false;

  PlayerController get _controller =>
      ref.read(playerControllerProvider.notifier);

  bool get _isPhonePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  bool get _mustStayVisible =>
      _scrubbing || _adjusting || _settingsOpen || _episodePickerOpen;

  @override
  void initState() {
    super.initState();
    _args = widget.args ??
        const PlayerPageArgs(
          url:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          title: '演示片源（Big Buck Bunny）',
        );
    _pickerSeason = _args.seasonNumber ?? 1;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initSystemBridges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isCompactPhone =
          _isPhonePlatform && MediaQuery.sizeOf(context).shortestSide < 600;
      if (isCompactPhone) {
        _manualLandscape = true;
        unawaited(PlayerSystemBridge.instance.setOrientationMask('landscape'));
      }
      _controller.open(_args);
      _joinPlaybackSession();
      WakelockPlus.enable();
      if (_args.isEpisode && _args.episodes.isEmpty) {
        _loadPickerEpisodes();
      }
      _keyFocus.requestFocus();
    });

    // 不强制切后台暂停：支持后台音频与锁屏控制，仅通知控制器做进度落盘与活性探针
    _lifecycle = AppLifecycleListener(
      onHide: () => _controller.onBackgroundChanged(true),
      onShow: () => _controller.onBackgroundChanged(false),
    );
  }

  Future<void> _initSystemBridges() async {
    final bridge = PlayerSystemBridge.instance;
    final b = await bridge.getBrightness();
    if (b != null && mounted) {
      setState(() {
        _brightnessLevel = b;
        _usingNativeBrightness = true;
      });
    }
    final v = await bridge.getVolume();
    if (v != null && mounted) {
      setState(() {
        _volumeLevel = v;
        _usingNativeVolume = true;
      });
    }

    _systemVolumeSub = bridge.onVolumeChanged.listen((vol) {
      if (!mounted) return;
      setState(() {
        _volumeLevel = vol;
        _usingNativeVolume = true;
        if (!_adjusting) {
          _levelHud = (brightness: false, level: vol);
        }
      });
      _noteActivity();
    });

    _remoteCmdSub = bridge.onRemoteCommand.listen((cmd) {
      if (!mounted) return;
      switch (cmd.command) {
        case 'play':
          _controller.play();
        case 'pause':
          _controller.pause();
        case 'togglePlayPause':
          _controller.togglePlay();
        case 'skipForward':
          _controller.seekByRelative(10000);
        case 'skipBackward':
          _controller.seekByRelative(-10000);
        case 'changePosition':
          if (cmd.positionMs != null) {
            _controller.seekToTimeline(Duration(milliseconds: cmd.positionMs!));
          }
        case 'nextTrack':
          final next = _nextEpisode;
          if (next != null) _switchEpisode(next.season, next);
        case 'previousTrack':
          final prev = _previousEpisode;
          if (prev != null) _switchEpisode(prev.season, prev);
      }
    });
  }

  Future<void> _loadPickerEpisodes() async {
    final id = _args.mediaItemId;
    if (id == null) return;
    setState(() => _pickerLoading = true);
    try {
      final season = await EpisodesApi(
        ref.read(mcClientProvider),
      ).playbackItemEpisodes(id, _pickerSeason);
      if (!mounted) return;
      setState(() {
        _pickerSeason = season.seasonNumber;
        _pickerEpisodes = [
          for (final e in season.episodes)
            EpisodeItem(
              season: season.seasonNumber,
              episode: e.episodeNumber,
              name: e.name ?? '第 ${e.episodeNumber} 集',
              fileId: e.playFileId,
              owned: e.owned,
              stillUrl: e.stillUrl,
              overview: e.overview,
              played: e.played,
              progressPercent: e.progressPercent,
              positionMs: e.positionMs,
              airDate: e.airDate,
            ),
        ];
        _pickerSeasons = _args.seasons.isNotEmpty
            ? _args.seasons
            : [season.seasonNumber];
        _pickerLoading = false;
      });
      _controller.updateNowPlayingNavigation(
        hasNext: _nextEpisode != null,
        hasPrevious: _previousEpisode != null,
      );
    } catch (_) {
      if (mounted) setState(() => _pickerLoading = false);
    }
  }

  Future<void> _switchEpisode(
    int season,
    EpisodeItem episode, {
    bool isAutoNext = false,
  }) async {
    if (!episode.owned || episode.fileId == null) {
      _showNotice('第 ${episode.episode} 集缺失文件，无法播放');
      return;
    }
    final newArgs = _args.copyWith(
      fileId: episode.fileId,
      seasonNumber: season,
      episodeNumber: episode.episode,
      subtitle: '${episode.code} · ${episode.name}',
      episodeSubtitle: '${episode.code} · ${episode.name}',
      artworkUrl: episode.stillUrl ?? _args.artworkUrl,
      clearStartPosition: true,
      clearClip: true,
      isEpisode: true,
      episodes: _episodeCandidates,
    );
    setState(() {
      _args = newArgs;
      _pickerSeason = season;
      _autoNextCancelled = false;
      _autoNextTriggered = false;
      _autoNextElapsedMs = 0;
      _autoExitTriggered = false;
      _autoNextStreak = isAutoNext ? _autoNextStreak + 1 : 0;
    });
    await _controller.open(newArgs);
    _joinPlaybackSession();
    _controller.updateNowPlayingNavigation(
      hasNext: _nextEpisode != null,
      hasPrevious: _previousEpisode != null,
    );
    _showNotice('正在播放 ${episode.code}');
  }

  List<EpisodeItem> get _episodeCandidates =>
      _pickerEpisodes.isNotEmpty ? _pickerEpisodes : _args.episodes;

  List<EpisodeItem> get _sortedPlayableEpisodes =>
      _episodeCandidates.where((e) => e.owned && e.fileId != null).toList()
        ..sort((a, b) {
          if (a.season != b.season) return a.season - b.season;
          return a.episode - b.episode;
        });

  EpisodeItem? get _nextEpisode {
    if (ref.read(playerControllerProvider).isClip) return null;
    final curSeason = _args.seasonNumber ?? 0;
    final curEpisode = _args.episodeNumber ?? 0;
    for (final e in _sortedPlayableEpisodes) {
      if (e.season > curSeason ||
          (e.season == curSeason && e.episode > curEpisode)) {
        return e;
      }
    }
    return null;
  }

  EpisodeItem? get _previousEpisode {
    if (ref.read(playerControllerProvider).isClip) return null;
    final curSeason = _args.seasonNumber ?? 0;
    final curEpisode = _args.episodeNumber ?? 0;
    EpisodeItem? prev;
    for (final e in _sortedPlayableEpisodes) {
      if (e.season < curSeason ||
          (e.season == curSeason && e.episode < curEpisode)) {
        prev = e;
      }
    }
    return prev;
  }

  void _joinPlaybackSession() {
    _commandSub?.cancel();
    final coordinator = ref.read(playbackCoordinatorProvider);
    coordinator.registerParticipant(_participantId);
    _commandSub = coordinator.commands.listen((cmd) {
      switch (cmd.type) {
        case 'pause':
          _controller.pause();
        case 'play':
          _controller.play();
        case 'seek':
          if (cmd.position != null) _controller.seekTo(cmd.position!);
        case 'stop':
          _exit();
      }
    });
  }

  void _reportSessionState(PlayerPlayback playback) {
    final now = DateTime.now();
    if (!playback.playing != !(_lastReportedPlaying ?? false) ||
        now.difference(_lastStateReport) >= const Duration(seconds: 4)) {
      _lastStateReport = now;
      _lastReportedPlaying = playback.playing;
      ref.read(playbackCoordinatorProvider).reportParticipantState(
            _participantId,
            ParticipantState(
              playing: playback.playing,
              position: playback.position,
              duration: playback.duration,
              speed: playback.speed,
            ),
          );
    }
  }

  @override
  void dispose() {
    _commandSub?.cancel();
    _systemVolumeSub?.cancel();
    _remoteCmdSub?.cancel();
    _lifecycle?.dispose();
    _keyFocus.dispose();
    WakelockPlus.disable();
    unawaited(PlayerSystemBridge.instance.restoreBrightness());
    // 退出恢复 `'all'` 方向（绝不强锁竖屏，iPad / 桌面端不受破坏）
    unawaited(PlayerSystemBridge.instance.setOrientationMask('all'));
    ref.read(playbackCoordinatorProvider).reportUserStopped(_participantId);
    _controller.exit();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _noteActivity({bool userInitiated = true}) {
    _lastUserActivity = DateTime.now();
    if (userInitiated && _autoNextStreak > 0) {
      _autoNextStreak = 0;
    }
  }

  void _triggerSeekRipple(int dir) {
    setState(() => _seekRippleDir = dir);
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (mounted && _seekRippleDir == dir) {
        setState(() => _seekRippleDir = null);
      }
    });
  }

  void _toggleOrientation() {
    final nextLandscape = !_manualLandscape;
    setState(() => _manualLandscape = nextLandscape);
    unawaited(
      PlayerSystemBridge.instance.setOrientationMask(
        nextLandscape ? 'landscape' : 'portrait',
      ),
    );
    _noteActivity();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    _noteActivity();
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.escape) {
      if (_settingsOpen) {
        setState(() => _settingsOpen = false);
      } else if (_episodePickerOpen) {
        setState(() => _episodePickerOpen = false);
      } else if (_diagnosticsHudOpen) {
        setState(() => _diagnosticsHudOpen = false);
      } else {
        _controller.exit();
        _exit();
      }
      return KeyEventResult.handled;
    }
    if (_locked) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _controller.togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _controller.seekByRelative(shift ? -30000 : -10000);
      _triggerSeekRipple(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _controller.seekByRelative(shift ? 30000 : 10000);
      _triggerSeekRipple(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _muted = false;
      _adjust(false, 0.1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _muted = false;
      _adjust(false, -0.1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      setState(() {
        if (_muted) {
          _muted = false;
          _volumeLevel = _volumeBeforeMute;
        } else {
          _volumeBeforeMute = _volumeLevel;
          _muted = true;
          _volumeLevel = 0;
        }
      });
      _controller.activeService.setVolume(_volumeLevel);
      _showNotice(_muted ? '已静音' : '已恢复音量');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft ||
        key == LogicalKeyboardKey.bracketRight) {
      final cur = ref.read(playerControllerProvider).speed;
      final idx = PlayerController.speeds.indexOf(cur);
      final nextIdx = key == LogicalKeyboardKey.bracketRight
          ? (idx + 1).clamp(0, PlayerController.speeds.length - 1)
          : (idx - 1).clamp(0, PlayerController.speeds.length - 1);
      final nextSpeed = PlayerController.speeds[nextIdx];
      _controller.setSpeed(nextSpeed);
      _showNotice('倍速 ${nextSpeed}x');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.keyS) {
      final subs = _controller.subtitles;
      if (subs.isNotEmpty) {
        final cur = _controller.selectedSubtitleTrack ?? '';
        final refs = ['', for (final s in subs) if (s.isAvailable) s.trackRef];
        final next = refs[(refs.indexOf(cur) + 1) % refs.length];
        _controller.switchTrack(subtitleTrack: next.isEmpty ? 'off' : next);
        _showNotice(next.isEmpty ? '字幕已关闭' : '已切换字幕轨');
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyI) {
      setState(() => _diagnosticsHudOpen = !_diagnosticsHudOpen);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showChaptersSheet() {
    final chapters = _controller.sessionInfo?.chapters ?? const [];
    if (chapters.isEmpty) return;
    _noteActivity();
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text('影片章节快速跳转', style: McText.title),
              ),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  for (final ch in chapters)
                    McInsetRow(
                      icon: McIcons.playCircle,
                      iconColor: McTokens.accent,
                      title: ch.title,
                      subtitle: mcFormatClock(ch.startMs ~/ 1000),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _controller.seekTo(Duration(milliseconds: ch.startMs));
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCastSheet() {
    final url = _controller.lastStreamUrl;
    if (url == null || url.isEmpty) {
      _showNotice('当前无可投屏的媒体流');
      return;
    }
    CastSheet.show(context, streamUrl: url, title: _args.displayTitle);
    _noteActivity();
  }

  void _showNotice(String text) {
    setState(() => _notice = text);
    _noteActivity(userInitiated: false);
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = _mustStayVisible || !_chromeVisible);
  }

  Future<void> _exit() async {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _adjust(bool brightness, double delta) {
    setState(() {
      if (brightness) {
        _brightnessLevel = (_brightnessLevel + delta).clamp(0.0, 1.0);
        _levelHud = (brightness: true, level: _brightnessLevel);
      } else {
        _volumeLevel = (_volumeLevel + delta).clamp(0.0, 1.0);
        _levelHud = (brightness: false, level: _volumeLevel);
      }
      _adjusting = true;
    });
    if (brightness) {
      unawaited(
        PlayerSystemBridge.instance.setBrightness(_brightnessLevel).then((ok) {
          if (mounted && ok != _usingNativeBrightness) {
            setState(() => _usingNativeBrightness = ok);
          }
        }),
      );
    } else {
      unawaited(
        PlayerSystemBridge.instance.setVolume(_volumeLevel).then((ok) {
          if (mounted && ok != _usingNativeVolume) {
            setState(() => _usingNativeVolume = ok);
          }
          if (!ok) {
            _controller.activeService.setVolume(_volumeLevel);
          }
        }),
      );
    }
  }

  /// 检测折叠屏是否处于水平半折桌面姿态。
  Rect? _horizontalHingeBounds(BuildContext context) {
    final features = MediaQuery.displayFeaturesOf(context);
    for (final f in features) {
      if ((f.type == DisplayFeatureType.hinge ||
              f.type == DisplayFeatureType.fold) &&
          f.state == DisplayFeatureState.postureHalfOpened &&
          f.bounds.width > f.bounds.height) {
        return f.bounds;
      }
    }
    return null;
  }

  void _onTick500ms() {
    if (!mounted) return;
    final playback = ref.read(playerControllerProvider);
    final elapsed = DateTime.now().difference(_lastUserActivity);

    if (_notice != null && elapsed >= _noticeHideAfter) {
      setState(() => _notice = null);
    }
    if (_levelHud != null && !_adjusting && elapsed >= _hudHideAfter) {
      setState(() => _levelHud = null);
    }
    if (_chromeVisible &&
        !_tvForm &&
        !_mustStayVisible &&
        playback.playing &&
        elapsed >= _chromeHideAfter) {
      setState(() => _chromeVisible = false);
    }
    if (_lockHint && elapsed >= const Duration(seconds: 3)) {
      setState(() => _lockHint = false);
    }

    // 下一集片尾 / 完播倒计时推进（仅在 outro(toEnd) 或真播完时启用，连播上限 3 集）
    final nextEp = _nextEpisode;
    final showUpNext = !playback.isClip &&
        nextEp != null &&
        !_autoNextCancelled &&
        SkipSegmentsHelper.shouldShowUpNext(
          playback.skipSegments,
          playback.position.inMilliseconds,
          ended: playback.completed,
        );
    final armed = showUpNext &&
        SkipSegmentsHelper.autoNextArmed(
          playback.skipSegments,
          playback.position.inMilliseconds,
          streak: _autoNextStreak,
          ended: playback.completed,
        );

    if (armed && !_autoNextTriggered) {
      setState(() {
        _autoNextElapsedMs = (_autoNextElapsedMs + 500)
            .clamp(0.0, SkipSegmentsHelper.autoNextMs.toDouble());
      });
      if (_autoNextElapsedMs >= SkipSegmentsHelper.autoNextMs) {
        _autoNextTriggered = true;
        _switchEpisode(nextEp.season, nextEp, isAutoNext: true);
      }
    } else if (!showUpNext && _autoNextElapsedMs > 0) {
      setState(() => _autoNextElapsedMs = 0);
    }

    // 电影或剧集最后一集播完（无下一集且非片段模式）：自动退出回到详情页
    if (playback.completed &&
        !playback.isClip &&
        nextEp == null &&
        !_autoExitTriggered) {
      _autoExitTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.exit();
          _exit();
        }
      });
    }
  }

  List<Widget> _overlays(PlayerPlayback playback) {
    final timelineDur = playback.timelineDuration;
    final scrubTarget = _scrubPreview ?? playback.timelinePosition;
    final activeSkip = playback.isClip
        ? null
        : SkipSegmentsHelper.active(
            playback.skipSegments,
            playback.position.inMilliseconds,
          );
    final nextEp = _nextEpisode;
    final showUpNext = !playback.isClip &&
        nextEp != null &&
        !_autoNextCancelled &&
        SkipSegmentsHelper.shouldShowUpNext(
          playback.skipSegments,
          playback.position.inMilliseconds,
          ended: playback.completed,
        );
    final upNextArmed = showUpNext &&
        SkipSegmentsHelper.autoNextArmed(
          playback.skipSegments,
          playback.position.inMilliseconds,
          streak: _autoNextStreak,
          ended: playback.completed,
        );
    final mergedNotice = _notice ?? playback.controllerNotice;

    return [
      // ASS \an1..9 字幕叠加层
      PlayerSubtitleOverlay(
        cues: playback.activeSubtitleCues,
        fontScale: playback.subtitleScale,
        bottomMarginPercent: playback.subtitleBottomMarginPercent,
        backgroundPill: playback.subtitleBackgroundPill,
        chromeVisible: _chromeVisible && !_locked,
      ),

      // 暂停且控制层隐藏时展示 Netflix 风格暂停信息遮罩
      if (playback.status == PlayerStatus.ready &&
          !playback.playing &&
          !playback.buffering &&
          !playback.clipEnded &&
          !_chromeVisible &&
          !_locked &&
          !_settingsOpen &&
          !_episodePickerOpen)
        PausedOverlay(
          title: _args.displayTitle,
          episodeLabel: _args.displaySubtitle,
        ),

      // 缓冲转圈 + 实时下载速率
      if (playback.status == PlayerStatus.ready &&
          playback.buffering &&
          !playback.clipEnded)
        Center(
          child: IgnorePointer(
            child: McLiquidGlass(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  if (playback.speedLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '↓ ${playback.speedLabel}',
                      style: McText.micro
                          .copyWith(color: const Color(0xCCFFFFFF))
                          .tabular,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

      // 双击左/右 ±10s 玻璃涟漪指示
      if (_seekRippleDir != null)
        Align(
          alignment: _seekRippleDir! < 0
              ? const Alignment(-0.62, 0)
              : const Alignment(0.62, 0),
          child: IgnorePointer(
            child: McLiquidGlass(
              radius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _seekRippleDir! < 0 ? McIcons.replay10 : McIcons.forward10,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _seekRippleDir! < 0 ? '-10 秒' : '+10 秒',
                    style: McText.sub.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

      // 实时流媒体技术诊断 HUD（每 2 秒自动轮询 + 复制 Session ID）
      if (_diagnosticsHudOpen)
        Positioned(
          top: 66,
          right: 20,
          child: PlayerDiagnosticsHud(
            sessionId: _controller.serverSessionId,
            onFetch: _controller.fetchDiagnostics,
            onClose: () => setState(() => _diagnosticsHudOpen = false),
          ),
        ),

      // 手势横滑定位中央预览卡
      if (_scrubPreview != null && _scrubbing)
        Center(
          child: McLiquidGlass(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mcFormatClock(scrubTarget.inSeconds),
                  style: McText.titleLg.tabular,
                ),
                const SizedBox(height: 4),
                Text(
                  '${mcFormatClock(scrubTarget.inSeconds)} / ${mcFormatClock(timelineDur.inSeconds)}',
                  style: McText.caption.muted.tabular,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: timelineDur.inMilliseconds <= 0
                          ? 0
                          : (scrubTarget.inMilliseconds /
                                  timelineDur.inMilliseconds)
                              .clamp(0.0, 1.0),
                      minHeight: 3,
                      color: Colors.white,
                      backgroundColor: const Color(0x3DFFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

      // 亮度 / 音量调节胶囊 HUD
      if (_levelHud != null)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 44),
            child: McLiquidGlass(
              radius: McTokens.pillRadius,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _levelHud!.brightness ? McIcons.sun : McIcons.volumeUp,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _levelHud!.level.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: const Color(0x3DFFFFFF),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(_levelHud!.level * 100).round()}%',
                    style: McText.caption.copyWith(color: Colors.white).tabular,
                  ),
                ],
              ),
            ),
          ),
        ),

      // 倍速角标
      if ((playback.speed != 1.0 || _holdSpeed) && !_locked)
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, top: 64),
            child: McLiquidGlass(
              radius: McTokens.pillRadius,
              withShadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                playback.speed == 2.0 && _holdSpeed
                    ? '▶▶ 2.0x 倍速中'
                    : '${playback.speed}x',
                style: McText.micro.copyWith(color: Colors.white).tabular,
              ),
            ),
          ),
        ),

      // 顶部状态提示胶囊
      if (mergedNotice != null)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: McLiquidGlass(
              radius: McTokens.pillRadius,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                mergedNotice,
                style: McText.caption.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),

      // 弱网降档建议卡
      if (playback.qualityOffer != null && !_locked && !_settingsOpen)
        Positioned(
          left: 20,
          bottom: 112,
          child: QualityOfferCard(
            offer: playback.qualityOffer!,
            onAccept: _controller.acceptQualityOffer,
            onDismiss: _controller.dismissQualityOffer,
          ),
        ),

      // 跳过片头 / 广告 / 预告 / 撤回与学习提示胶囊
      if (playback.skipNotice != null && !_locked && !_settingsOpen)
        Positioned(
          right: 24,
          bottom: 112,
          child: SkipNoticePill(
            notice: playback.skipNotice!,
            onUndo: _controller.undoAutoSkip,
            onDecline: _controller.declineIntroAutoSkip,
          ),
        )
      else if (activeSkip != null &&
          !showUpNext &&
          !_locked &&
          !_settingsOpen &&
          !_episodePickerOpen)
        Positioned(
          right: 24,
          bottom: 112,
          child: SkipSegmentPill(
            segment: activeSkip,
            onSkip: () {
              _controller.skipCurrentSegment();
              _noteActivity();
            },
          ),
        ),

      // 片段模式结束卡片（重播片段 / 看全片）
      if (playback.isClip && playback.clipEnded && !_locked)
        Positioned(
          right: 24,
          bottom: 112,
          child: ClipEndCard(
            onReplay: _controller.replayClip,
            onWatchFull: () {
              _controller.leaveClip();
              _showNotice('已切换为完整正片播放');
            },
          ),
        ),

      // 剧集片尾 / 完播「即将播放下一集」卡片
      if (showUpNext && !_locked && !_settingsOpen && !_episodePickerOpen)
        Positioned(
          right: 24,
          bottom: 112,
          child: UpNextCard(
            nextEpisode: nextEp,
            countdownProgress: upNextArmed
                ? (_autoNextElapsedMs / SkipSegmentsHelper.autoNextMs)
                    .clamp(0.0, 1.0)
                : null,
            stillWatchingPrompt:
                !upNextArmed && _autoNextStreak >= SkipSegmentsHelper.autoNextMaxStreak,
            onPlayNow: () => _switchEpisode(nextEp.season, nextEp),
            onDismiss: () => setState(() => _autoNextCancelled = true),
          ),
        ),
    ];
  }

  Widget _buildProgressBar(PlayerPlayback playback) {
    return PlayerProgressBar(
      position: playback.timelinePosition,
      duration: playback.timelineDuration,
      bufferedEnd: playback.timelineBufferedEnd,
      skipSegments: playback.isClip ? const [] : playback.skipSegments,
      chapters: _controller.sessionInfo?.chapters ?? const [],
      trickplay: playback.isClip ? null : playback.trickplay,
      timelineOffsetMs: playback.isClip ? (playback.clipStartMs ?? 0) : 0,
      onSeek: (t) {
        _controller.seekToTimeline(t);
        _noteActivity();
      },
      onScrubPreview: (t) => setState(() => _scrubPreview = t),
    );
  }

  Widget _buildBottomControls(PlayerPlayback playback) {
    final isCompactPhone =
        _isPhonePlatform && MediaQuery.sizeOf(context).shortestSide < 600;
    return PlayerBottomControls(
      isEpisode: _args.isEpisode && !playback.isClip,
      hasNext: _nextEpisode != null,
      onNext: () {
        final next = _nextEpisode;
        if (next != null) _switchEpisode(next.season, next);
      },
      audioTracks: _controller.audioTracks,
      subtitles: _controller.subtitles,
      selectedAudioTrack: _controller.selectedAudioTrack,
      selectedSubtitleTrack: _controller.selectedSubtitleTrack,
      onPickAudio: (trackRef) {
        _noteActivity();
        _controller.switchTrack(audioTrack: trackRef);
      },
      onPickSubtitle: (trackRef) {
        _noteActivity();
        _controller.switchTrack(subtitleTrack: trackRef);
      },
      onEpisodes: () {
        setState(() => _episodePickerOpen = true);
        _loadPickerEpisodes();
        _noteActivity();
      },
      onAirPlay: PlayerSystemBridge.instance.supportsAirPlay
          ? () {
              PlayerSystemBridge.instance.showAirPlayPicker();
              _noteActivity();
            }
          : null,
      onCast: _showCastSheet,
      showOrientationToggle: isCompactPhone,
      isLandscape: _manualLandscape,
      onToggleOrientation: _toggleOrientation,
      speed: playback.speed,
      onPickSpeed: (s) {
        _controller.setSpeed(s);
        _showNotice(s == 1.0 ? '已恢复常速' : '倍速 ${s}x');
      },
      onNotice: _showNotice,
    );
  }

  Widget _chrome(PlayerPlayback playback) {
    final isTv = _tvForm;
    final visible = (_chromeVisible || isTv) && !_locked;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Align(
              alignment: Alignment.topCenter,
              child: McPageFog(height: 110, opacity: 0.85),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Container(
                  height: 156,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x8A000000),
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        McFocusRing(
                          borderRadius: 22,
                          child: McGlassIconButton(
                            icon: McIcons.arrowLeftS,
                            size: 40,
                            iconSize: 22,
                            tooltip: '返回 (Esc)',
                            onTap: () {
                              _controller.exit();
                              _exit();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _args.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: McText.titleSm,
                                    ),
                                  ),
                                  if (playback.isClip) ...[
                                    const SizedBox(width: 8),
                                    McChip(
                                      label: '看全片',
                                      compact: true,
                                      selected: true,
                                      onTap: () {
                                        _controller.leaveClip();
                                        _showNotice('已切换为完整正片播放');
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              if (_args.displaySubtitle != null)
                                Text(
                                  _args.displaySubtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: McText.caption.muted,
                                ),
                            ],
                          ),
                        ),
                        if (playback.speedLabel != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              '↓ ${playback.speedLabel}',
                              style: McText.micro.muted.tabular,
                            ),
                          ),
                        ],
                        if (_controller.sessionInfo != null &&
                            _controller.sessionInfo!.chapters.isNotEmpty) ...[
                          McFocusRing(
                            borderRadius: 22,
                            child: McGlassIconButton(
                              icon: McIcons.list2,
                              size: 38,
                              tooltip: '章节列表',
                              onTap: _showChaptersSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        McFocusRing(
                          borderRadius: 22,
                          child: McGlassIconButton(
                            icon: McIcons.cpu,
                            size: 38,
                            tooltip: '实时技术诊断 (I)',
                            onTap: () => setState(
                              () => _diagnosticsHudOpen = !_diagnosticsHudOpen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        McFocusRing(
                          borderRadius: 22,
                          child: McGlassIconButton(
                            icon: McIcons.lock,
                            size: 38,
                            tooltip: '锁屏防误触',
                            onTap: () {
                              setState(() {
                                _locked = true;
                                _lockHint = true;
                                _chromeVisible = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        McFocusRing(
                          borderRadius: 22,
                          child: McGlassIconButton(
                            icon: McIcons.more,
                            size: 38,
                            tooltip: '播放设置',
                            onTap: () {
                              setState(() => _settingsOpen = true);
                              _noteActivity();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      McFocusRing(
                        borderRadius: 28,
                        child: McGlassIconButton(
                          icon: McIcons.replay10,
                          size: 52,
                          iconSize: 24,
                          tooltip: '快退 10 秒 (←)',
                          onTap: () {
                            _controller.seekByRelative(-10000);
                            _triggerSeekRipple(-1);
                            _noteActivity();
                          },
                        ),
                      ),
                      const SizedBox(width: 36),
                      McFocusRing(
                        borderRadius: 38,
                        child: CenterGlassButton(
                          playing: playback.playing,
                          replay: playback.clipEnded,
                          accent: Colors.white,
                          onTap: () {
                            _controller.togglePlay();
                            _noteActivity();
                          },
                        ),
                      ),
                      const SizedBox(width: 36),
                      McFocusRing(
                        borderRadius: 28,
                        child: McGlassIconButton(
                          icon: McIcons.forward10,
                          size: 52,
                          iconSize: 24,
                          tooltip: '快进 10 秒 (→)',
                          onTap: () {
                            _controller.seekByRelative(10000);
                            _triggerSeekRipple(1);
                            _noteActivity();
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildBottomControls(playback),
                  const SizedBox(height: 6),
                  _buildProgressBar(playback),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _maybeShowDecisionDialog(BuildContext context) {
    if (_decisionDialogOpen) return;
    final playback = ref.read(playerControllerProvider);
    final decision = playback.pendingDecision;
    if (decision == null) return;
    _decisionDialogOpen = true;
    _controller.acknowledgeDecision();

    var saving = false;
    String? inlineError;

    showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                decision == SessionDecision.rejected
                    ? McStrings.rejectedByServer
                    : McStrings.needTranscodeConfirm,
                style: McText.titleSm,
              ),
              const SizedBox(height: 8),
              Text(
                playback.pendingReason ??
                    (decision == SessionDecision.rejected
                        ? '服务器管理员当前关闭了转码许可。'
                        : '当前片源需要服务器启用 CPU 软件转码后才能播放。'),
                style: McText.caption.copyWith(color: const Color(0xCCFFFFFF)),
              ),
              if (playback.pendingCostHint != null &&
                  playback.pendingCostHint!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '开销提示：${playback.pendingCostHint}',
                  style: McText.micro.muted,
                ),
              ],
              if (inlineError != null) ...[
                const SizedBox(height: 10),
                Text(
                  inlineError!,
                  style: McText.caption.copyWith(color: McTokens.danger),
                ),
              ],
              if (decision == SessionDecision.consent &&
                  !playback.pendingCanSelfEnable) ...[
                const SizedBox(height: 10),
                Text(
                  '当前账号无权修改服务器转码策略，请联系管理员在「播放设置」中开启软件转码。',
                  style: McText.caption.muted,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: McActionPill(
                      label: '返回',
                      primary: false,
                      expanded: true,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _exit();
                      },
                    ),
                  ),
                  if (decision == SessionDecision.consent &&
                      playback.pendingCanSelfEnable) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: McActionPill(
                        label: saving ? '正在开启…' : '开启软件转码并播放',
                        primary: true,
                        expanded: true,
                        onTap: saving
                            ? null
                            : () async {
                                setSheetState(() {
                                  saving = true;
                                  inlineError = null;
                                });
                                final err =
                                    await _controller.acceptTranscodeConsent();
                                if (!ctx.mounted) return;
                                if (err == null) {
                                  Navigator.of(ctx).pop();
                                } else {
                                  setSheetState(() {
                                    saving = false;
                                    inlineError = err;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _decisionDialogOpen = false;
    });
  }

  Widget _buildVideoStage(PlayerPlayback playback) {
    final screen = MediaQuery.sizeOf(context);
    final isLandscape = screen.width > screen.height;
    final drawerOpen = _episodePickerOpen && !_tvForm;

    final Widget stage = playback.status == PlayerStatus.ready
        ? KeyedSubtree(
            key: ValueKey('engine-${playback.engineRevision}'),
            child: _controller.activeService.buildView(
              fit: displayModeToBoxFit(_displayMode),
              aspectRatioOverride: displayModeToAspectRatio(_displayMode),
            ),
          )
        : Center(
            child: playback.status == PlayerStatus.failed
                ? _failedPane(playback)
                : const McLoadingView(),
          );

    // 选集抽屉打开时平滑让位缩放画面（对齐 iOS `PlayerEpisodeStage.swift`）
    if (drawerOpen) {
      final drawerW = (screen.width * 0.38).clamp(310.0, 400.0);
      final targetPad = isLandscape
          ? EdgeInsets.fromLTRB(20, 28, drawerW + 18, 28)
          : EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 8, 12,
              screen.height * 0.56 + 10);
      return Stack(
        fit: StackFit.expand,
        children: [
          DeckAmbienceBackdrop(artworkUrl: _args.artworkUrl),
          AnimatedPadding(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: targetPad,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: stage,
            ),
          ),
        ],
      );
    }

    return stage;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowDecisionDialog(context),
    );
    final playback = ref.watch(playerControllerProvider);
    ref.listen(playerControllerProvider, (_, next) => _reportSessionState(next));
    _tvForm = McFormWatch.of(context) == McDeviceForm.tv;

    final hinge = _horizontalHingeBounds(context);

    Widget playerCanvas;
    if (hinge != null && !_episodePickerOpen && !_settingsOpen) {
      // 折叠屏半折桌面模式：上半屏播片，下半屏独立控制台
      playerCanvas = Column(
        children: [
          SizedBox(
            height: hinge.top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideoStage(playback),
                PlayerSubtitleOverlay(
                  cues: playback.activeSubtitleCues,
                  fontScale: playback.subtitleScale,
                  bottomMarginPercent: playback.subtitleBottomMarginPercent,
                  backgroundPill: playback.subtitleBackgroundPill,
                  chromeVisible: false,
                ),
              ],
            ),
          ),
          Expanded(
            child: PlayerTabletopDeck(
              title: _args.displayTitle,
              subtitle: _args.displaySubtitle,
              artworkUrl: _args.artworkUrl,
              playing: playback.playing,
              speed: playback.speed,
              progressBar: _buildProgressBar(playback),
              bottomControls: _buildBottomControls(playback),
              onTogglePlay: _controller.togglePlay,
              onSeekBack: () => _controller.seekByRelative(-10000),
              onSeekForward: () => _controller.seekByRelative(10000),
              onOpenSettings: () => setState(() => _settingsOpen = true),
              onBack: () {
                _controller.exit();
                _exit();
              },
            ),
          ),
        ],
      );
    } else {
      playerCanvas = Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoStage(playback),
          PlayerGestureLayer(
            enabled: !_tvForm &&
                !_locked &&
                !_episodePickerOpen &&
                !_settingsOpen &&
                playback.status == PlayerStatus.ready,
            canHold: playback.playing,
            onTap: () {
              _toggleChrome();
              _noteActivity();
            },
            onDoubleTap: (xRatio) {
              if (xRatio < 1 / 3) {
                _controller.seekByRelative(-10000);
                _triggerSeekRipple(-1);
              } else if (xRatio > 2 / 3) {
                _controller.seekByRelative(10000);
                _triggerSeekRipple(1);
              } else {
                _controller.togglePlay();
              }
              _noteActivity();
            },
            onPinchMode: (mode) {
              if (_displayMode != mode) {
                setState(() => _displayMode = mode);
                _showNotice(mode == 'fill' ? '画面：铺满屏幕' : '画面：原始比例');
              }
            },
            onScrubStart: () => setState(() {
              _scrubbing = true;
              _scrubPreview = playback.timelinePosition;
              _chromeVisible = true;
            }),
            onScrubTo: (ratio) => setState(() {
              final totalMs = playback.timelineDuration.inMilliseconds;
              final base = playback.timelinePosition.inMilliseconds;
              final target = (base + (ratio * kPlayerFullSweepSeekMs).round())
                  .clamp(0, totalMs <= 0 ? base : totalMs);
              _scrubPreview = Duration(milliseconds: target);
            }),
            onScrubEnd: () {
              final t = _scrubPreview;
              setState(() {
                _scrubbing = false;
                _scrubPreview = null;
              });
              if (t != null) _controller.seekToTimeline(t);
            },
            onAdjustStart: (_) {},
            onAdjust: _adjust,
            onAdjustEnd: () => setState(() {
              _adjusting = false;
              _levelHud = null;
            }),
            onHoldStart: () {
              setState(() => _holdSpeed = true);
              _controller.setHoldSpeed(true);
            },
            onHoldEnd: () {
              setState(() => _holdSpeed = false);
              _controller.setHoldSpeed(false);
            },
            child: const SizedBox.expand(),
          ),
          // 仅当原生屏幕亮度不可用（桌面端）时使用柔和暗幕降级模拟
          if (!_usingNativeBrightness && _brightnessLevel < 1.0)
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: (1 - _brightnessLevel) * 0.65,
                ),
              ),
            ),
          if (playback.status == PlayerStatus.ready && !_episodePickerOpen)
            _chrome(playback),
          if (!_episodePickerOpen) ..._overlays(playback),
          if (_locked)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    McGlassIconButton(
                      icon: McIcons.lockOpen,
                      size: 46,
                      iconSize: 22,
                      tooltip: '点击解锁屏幕',
                      onTap: () => setState(() {
                        _locked = false;
                        _chromeVisible = true;
                      }),
                    ),
                    if (_lockHint) ...[
                      const SizedBox(width: 10),
                      McLiquidGlass(
                        radius: McTokens.pillRadius,
                        withShadow: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          '屏幕已锁定，点左侧解锁',
                          style: McText.caption.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    }

    final body = Focus(
      focusNode: _keyFocus,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: _chromeVisible || !_locked
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        onHover: (_) {
          if (!_locked && !_chromeVisible) {
            setState(() => _chromeVisible = true);
          }
          _noteActivity(userInitiated: false);
        },
        child: Scaffold(
          backgroundColor: McTokens.bg,
          body: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_settingsOpen) {
                setState(() => _settingsOpen = false);
              } else if (_episodePickerOpen) {
                setState(() => _episodePickerOpen = false);
              } else if (_diagnosticsHudOpen) {
                setState(() => _diagnosticsHudOpen = false);
              } else {
                _controller.exit();
                _exit();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                playerCanvas,
                PlayerSettingsPanel(
                  visible: _settingsOpen,
                  speed: playback.speed,
                  displayMode: _displayMode,
                  qualityTier: playback.qualityTier,
                  subtitleScale: playback.subtitleScale,
                  subtitleBottomMarginPercent:
                      playback.subtitleBottomMarginPercent,
                  subtitleBackgroundPill: playback.subtitleBackgroundPill,
                  subtitleOffsetMs: playback.subtitleOffsetMs,
                  onSelectSpeed: (s) {
                    _controller.setSpeed(s);
                    _showNotice(s == 1.0 ? '已恢复常速' : '倍速 ${s}x');
                  },
                  onSelectDisplayMode: (m) => setState(() => _displayMode = m),
                  onSelectQuality: (tier) {
                    _controller.setQualityTier(tier);
                    _showNotice('画质已切换为 $tier');
                  },
                  onSelectSubtitleScale: _controller.setSubtitleScale,
                  onSelectSubtitleBottomMargin:
                      _controller.setSubtitleBottomMargin,
                  onToggleSubtitleBackgroundPill:
                      _controller.setSubtitleBackgroundPill,
                  onAdjustSubtitleOffset: _controller.adjustSubtitleOffset,
                  onLoadDiagnostics: _controller.fetchDiagnostics,
                  onNotice: _showNotice,
                  onDismiss: () => setState(() => _settingsOpen = false),
                ),
                if (_episodePickerOpen)
                  PlayerEpisodePicker(
                    asDrawer: McFormWatch.of(context) != McDeviceForm.tv,
                    args: _args.copyWith(
                      seasons: _pickerSeasons,
                      episodes: _episodeCandidates,
                    ),
                    currentSeason: _pickerSeason,
                    currentEpisode: _args.episodeNumber ?? 1,
                    loading: _pickerLoading,
                    livePosition: playback.timelinePosition,
                    liveDuration: playback.timelineDuration,
                    artworkUrl: _args.artworkUrl,
                    onSelect: (season, episode) {
                      setState(() => _episodePickerOpen = false);
                      _switchEpisode(season, episode);
                    },
                    onDismiss: () => setState(() => _episodePickerOpen = false),
                    onSeasonChanged: (season) {
                      _pickerSeason = season;
                      _loadPickerEpisodes();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return _WithTimers(onTick: _onTick500ms, child: body);
  }

  Widget _failedPane(PlayerPlayback playback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(McIcons.alert1, size: 32, color: McTokens.danger),
          const SizedBox(height: 12),
          Text(
            playback.error ?? '播放失败',
            textAlign: TextAlign.center,
            style: McText.sub.copyWith(color: McTokens.text),
          ),
          if (playback.errorSuggestion != null &&
              playback.errorSuggestion!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              playback.errorSuggestion!,
              textAlign: TextAlign.center,
              style: McText.caption.muted,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!playback.endedByAdmin) ...[
                McActionPill(
                  label: '重试',
                  icon: McIcons.refreshS,
                  primary: true,
                  onTap: () => _controller.open(_args),
                ),
                const SizedBox(width: 12),
              ],
              McActionPill(
                label: '返回',
                primary: playback.endedByAdmin,
                onTap: _exit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 中央 72dp 液态玻璃播放/暂停/重播大圆钮。
class CenterGlassButton extends StatelessWidget {
  const CenterGlassButton({
    super.key,
    required this.playing,
    required this.accent,
    required this.onTap,
    this.replay = false,
  });

  final bool playing;
  final bool replay;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      haptic: true,
      child: SizedBox(
        width: 72,
        height: 72,
        child: McLiquidGlass(
          radius: 36,
          blurSigma: 24,
          child: Center(
            child: Icon(
              replay
                  ? McIcons.refreshS
                  : (playing ? McIcons.pauseS : McIcons.play2Fill),
              color: accent,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _WithTimers extends StatefulWidget {
  const _WithTimers({required this.onTick, required this.child});

  final VoidCallback onTick;
  final Widget child;

  @override
  State<_WithTimers> createState() => _WithTimersState();
}

class _WithTimersState extends State<_WithTimers> {
  @override
  void initState() {
    super.initState();
    _loop();
  }

  Future<void> _loop() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      widget.onTick();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
