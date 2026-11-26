import 'dart:async';

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
import '../../../core/player/session/playback_session.dart';
import '../../../core/player/session/playback_session_api.dart';
import '../../../core/player/session/playback_session_providers.dart';
import '../state/player_controller.dart';
import '../widgets/cast_sheet.dart';
import '../widgets/player_bottom_controls.dart';
import '../widgets/player_episode_picker.dart';
import '../widgets/player_gesture_layer.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_settings_panel.dart';

/// 全屏播放器（1:1 对齐 `player.jpg` 液态玻璃控制层与手势规范）：
/// - 顶栏：左 40dp 玻璃返回圆钮 + 片名/集名；右锁屏与更多玻璃圆钮；
/// - 中区：三颗液态玻璃圆钮（快退 10s `52dp` · 播放/暂停 `72dp` · 快进 10s `52dp`）；
/// - 底栏：`[ 音轨 | 字幕 ]` 连体玻璃胶囊 + 片头/片尾亮白 `跳过片头` 浮钮 + 纯白进度条与等宽时间戳。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, this.args});

  final PlayerPageArgs? args;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _chromeHideAfter = Duration(milliseconds: 4000);
  static const _hudHideAfter = Duration(milliseconds: 1200);
  static const _noticeHideAfter = Duration(milliseconds: 4000);

  late PlayerPageArgs _args;
  bool _chromeVisible = true;
  bool _locked = false;
  bool _lockHint = false;
  bool _holdSpeed = false;
  bool _scrubbing = false;
  bool _adjusting = false;
  bool _settingsOpen = false;
  bool _episodePickerOpen = false;
  List<EpisodeItem> _pickerEpisodes = const [];
  List<int> _pickerSeasons = const [];
  int _pickerSeason = 1;
  bool _pickerLoading = false;
  String _displayMode = 'fit';
  String? _notice;
  static const _participantId = 'player-page';
  StreamSubscription<CoordinatorCommand>? _commandSub;
  DateTime _lastStateReport = DateTime.fromMillisecondsSinceEpoch(0);
  AppLifecycleListener? _lifecycle;
  bool _pausedBySystem = false;
  bool? _lastReportedPlaying;
  Duration? _scrubPreview;
  ({bool brightness, double level})? _levelHud;
  double _brightnessLevel = 1.0;
  double _volumeLevel = 1.0;
  DateTime _lastUserActivity = DateTime.now();
  bool _tvForm = false;

  PlayerController get _controller =>
      ref.read(playerControllerProvider.notifier);

  bool get _mustStayVisible =>
      !(ref.read(playerControllerProvider).playing) ||
      _scrubbing ||
      _adjusting ||
      _settingsOpen ||
      _episodePickerOpen;

  @override
  void initState() {
    super.initState();
    _args =
        widget.args ??
        const PlayerPageArgs(
          url:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          title: '演示片源（Big Buck Bunny）',
        );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.open(_args);
      _joinPlaybackSession();
      WakelockPlus.enable();
    });
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (ref.read(playerControllerProvider).playing) {
          _pausedBySystem = true;
          _controller.togglePlay();
        }
      },
      onShow: () {
        if (_pausedBySystem) {
          _pausedBySystem = false;
          _controller.togglePlay();
        }
      },
    );
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
            ),
        ];
        _pickerSeasons = _args.seasons.isNotEmpty
            ? _args.seasons
            : [season.seasonNumber];
        _pickerLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pickerLoading = false);
    }
  }

  Future<void> _switchEpisode(int season, EpisodeItem episode) async {
    if (!episode.owned || episode.fileId == null) {
      _showNotice('第 ${episode.episode} 集缺失文件，无法播放');
      return;
    }
    _controller.detach();
    final newArgs = PlayerPageArgs(
      mediaItemId: _args.mediaItemId,
      fileId: episode.fileId,
      seasonNumber: season,
      episodeNumber: episode.episode,
      title: _args.title,
      subtitle: 'S$season E${episode.episode} · ${episode.name}',
      isEpisode: true,
      seasons: _args.seasons,
      episodes: _pickerEpisodes,
    );
    setState(() {
      _args = newArgs;
      _pickerSeason = season;
    });
    await _controller.open(newArgs);
    _joinPlaybackSession();
    _showNotice('已切换到 S$season E${episode.episode}');
  }

  List<EpisodeItem> get _episodeCandidates =>
      _pickerEpisodes.isNotEmpty ? _pickerEpisodes : _args.episodes;

  EpisodeItem? get _nextEpisode {
    final curSeason = _args.seasonNumber ?? 0;
    final curEpisode = _args.episodeNumber ?? 0;
    final list =
        _episodeCandidates.where((e) => e.owned && e.fileId != null).toList()
          ..sort((a, b) {
            if (a.season != b.season) return a.season - b.season;
            return a.episode - b.episode;
          });
    for (final e in list) {
      if (e.season > curSeason ||
          (e.season == curSeason && e.episode > curEpisode)) {
        return e;
      }
    }
    return null;
  }

  PlaybackSkipSegment? _activeSkipSegment(PlayerPlayback playback) {
    final posMs = playback.position.inMilliseconds;
    for (final seg in playback.skipSegments) {
      if (posMs >= seg.startMs && posMs + 1500 < seg.endMs) {
        return seg;
      }
    }
    return null;
  }

  void _joinPlaybackSession() {
    final coordinator = ref.read(playbackCoordinatorProvider);
    coordinator.registerParticipant(_participantId);
    _commandSub = coordinator.commands.listen((cmd) {
      switch (cmd.type) {
        case 'pause':
          if (ref.read(playerControllerProvider).playing) {
            _controller.togglePlay();
          }
        case 'play':
          if (!ref.read(playerControllerProvider).playing) {
            _controller.togglePlay();
          }
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
      ref
          .read(playbackCoordinatorProvider)
          .reportParticipantState(
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
    _lifecycle?.dispose();
    WakelockPlus.disable();
    ref.read(playbackCoordinatorProvider).reportUserStopped(_participantId);
    _controller.detach();
    _controller.exit();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _noteActivity() => _lastUserActivity = DateTime.now();

  void _showCastSheet() {
    final url = _controller.lastStreamUrl;
    if (url == null || url.isEmpty) {
      _showNotice('当前无可投屏的媒体流');
      return;
    }
    CastSheet.show(context, streamUrl: url, title: _args.title);
    _noteActivity();
  }

  void _showNotice(String text) {
    setState(() => _notice = text);
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = _mustStayVisible || !_chromeVisible);
  }

  Future<void> _exit() async {
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
        ref.read(playerServiceProvider).setVolume(_volumeLevel);
      }
      _adjusting = true;
    });
  }

  List<Widget> _overlays(PlayerPlayback playback) {
    final duration = playback.duration ?? Duration.zero;
    final scrubTarget = _scrubPreview ?? playback.position;
    final activeSkip = _activeSkipSegment(playback);

    return [
      if (_scrubPreview != null)
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
                  '${mcFormatClock(scrubTarget.inSeconds)} / ${mcFormatClock(duration.inSeconds)}',
                  style: McText.caption.muted.tabular,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: duration.inMilliseconds <= 0
                          ? 0
                          : (scrubTarget.inMilliseconds /
                                    duration.inMilliseconds)
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
                    '${(_levelHud!.level * 100).toInt()}%',
                    style: McText.caption.copyWith(color: Colors.white).tabular,
                  ),
                ],
              ),
            ),
          ),
        ),
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
      if (_notice != null)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: McLiquidGlass(
              radius: McTokens.pillRadius,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _notice!,
                style: McText.caption.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      // 遇到可跳片头/片尾区间时自动浮出亮银白「跳过片头 / 跳过片尾」主胶囊
      if (activeSkip != null && !_locked && !_settingsOpen && !_episodePickerOpen)
        Positioned(
          right: 24,
          bottom: 112,
          child: McFocusRing(
            borderRadius: McTokens.pillRadius,
            child: McActionPill(
              label: activeSkip.type == 'outro' ? '跳过片尾' : '跳过片头',
              icon: McIcons.skipForwardFill,
              primary: true,
              height: 38,
              onTap: () {
                _controller.seekTo(Duration(milliseconds: activeSkip.endMs));
                _noteActivity();
              },
            ),
          ),
        ),
    ];
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
            // 上下柔和黑雾托字，不遮挡中心画面
            const Align(
              alignment: Alignment.topCenter,
              child: McPageFog(height: 110, opacity: 0.85),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Container(
                  height: 150,
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
                  // 顶栏：40dp 玻璃返回钮 + 标题/集名 + 锁屏 + 更多
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
                            tooltip: '返回',
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
                              Text(
                                _args.title ?? '播放',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: McText.titleSm,
                              ),
                              if (_args.subtitle != null &&
                                  _args.subtitle!.isNotEmpty)
                                Text(
                                  _args.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: McText.caption.muted,
                                ),
                            ],
                          ),
                        ),
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
                  // 中区三颗液态玻璃圆钮：快退 10s (52dp) · 播放/暂停 (72dp) · 快进 10s (52dp)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      McFocusRing(
                        borderRadius: 28,
                        child: McGlassIconButton(
                          icon: McIcons.replay10,
                          size: 52,
                          iconSize: 24,
                          tooltip: '快退 10 秒',
                          onTap: () {
                            _controller.seekByRelative(-10000);
                            _noteActivity();
                          },
                        ),
                      ),
                      const SizedBox(width: 36),
                      McFocusRing(
                        borderRadius: 38,
                        child: CenterGlassButton(
                          playing: playback.playing,
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
                          tooltip: '快进 10 秒',
                          onTap: () {
                            _controller.seekByRelative(10000);
                            _noteActivity();
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  PlayerBottomControls(
                    isEpisode: _args.isEpisode,
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
                      _controller.switchTrack(
                        subtitleTrack: trackRef == 'off' ? '' : trackRef,
                      );
                    },
                    onEpisodes: () {
                      setState(() => _episodePickerOpen = true);
                      _loadPickerEpisodes();
                      _noteActivity();
                    },
                    onCast: _showCastSheet,
                    speed: playback.speed,
                    onPickSpeed: (s) {
                      _controller.setSpeed(s);
                      _showNotice(s == 1.0 ? '已恢复常速' : '倍速 ${s}x');
                    },
                    onNotice: _showNotice,
                  ),
                  const SizedBox(height: 6),
                  PlayerProgressBar(
                    position: playback.position,
                    duration: playback.duration ?? Duration.zero,
                    skipSegments: playback.skipSegments,
                    onSeek: (t) {
                      _controller.seekTo(t);
                      _noteActivity();
                    },
                    onScrubPreview: (t) => setState(
                      () => _scrubPreview = t == playback.position ? null : t,
                    ),
                  ),
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
    final controller = ref.read(playerControllerProvider);
    final decision = controller.pendingDecision;
    if (decision == null) return;
    ref.read(playerControllerProvider.notifier).acknowledgeDecision();
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
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
            const SizedBox(height: 16),
            McActionPill(
              label: McStrings.continuePlay,
              primary: true,
              expanded: true,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowDecisionDialog(context),
    );
    final playback = ref.watch(playerControllerProvider);
    ref.listen(playerControllerProvider, (_, next) => _reportSessionState(next));
    _tvForm = McFormWatch.of(context) == McDeviceForm.tv;
    final body = Scaffold(
      backgroundColor: McTokens.bg,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_settingsOpen) {
            setState(() => _settingsOpen = false);
          } else if (_episodePickerOpen) {
            setState(() => _episodePickerOpen = false);
          } else {
            _controller.exit();
            _exit();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (playback.status == PlayerStatus.ready)
              _serviceView()
            else
              Center(
                child: playback.status == PlayerStatus.failed
                    ? _failedPane(playback)
                    : const McLoadingView(),
              ),
            PlayerGestureLayer(
              enabled:
                  !_tvForm && !_locked && playback.status == PlayerStatus.ready,
              canHold: playback.playing,
              onTap: () {
                _toggleChrome();
                _noteActivity();
              },
              onDoubleTap: (xRatio) {
                if (xRatio < 1 / 3) {
                  _controller.seekByRelative(-10000);
                } else if (xRatio > 2 / 3) {
                  _controller.seekByRelative(10000);
                } else {
                  _toggleChrome();
                }
                _noteActivity();
              },
              onScrubStart: () => setState(() {
                _scrubbing = true;
                _scrubPreview = playback.position;
                _chromeVisible = true;
              }),
              onScrubTo: (ratio) => setState(() {
                final duration = playback.duration?.inMilliseconds ?? 0;
                final base = playback.position.inMilliseconds;
                final target = (base + (ratio * kPlayerFullSweepSeekMs).round())
                    .clamp(0, duration <= 0 ? base : duration);
                _scrubPreview = Duration(milliseconds: target);
              }),
              onScrubEnd: () {
                final t = _scrubPreview;
                setState(() {
                  _scrubbing = false;
                  _scrubPreview = null;
                });
                if (t != null) _controller.seekTo(t);
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
            if (_brightnessLevel < 1.0)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: (1 - _brightnessLevel) * 0.7,
                  ),
                ),
              ),
            ..._overlays(playback),
            if (playback.status == PlayerStatus.ready) _chrome(playback),
            // 锁屏态：左中悬浮液态玻璃解锁圆钮
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
            PlayerSettingsPanel(
              visible: _settingsOpen,
              speed: playback.speed,
              displayMode: _displayMode,
              onSelectSpeed: (s) {
                _controller.setSpeed(s);
                _showNotice(s == 1.0 ? '已恢复常速' : '倍速 ${s}x');
              },
              onSelectDisplayMode: (m) => setState(() => _displayMode = m),
              onNotice: _showNotice,
              onDismiss: () => setState(() => _settingsOpen = false),
            ),
            if (_episodePickerOpen)
              PlayerEpisodePicker(
                asDrawer: McFormWatch.of(context) != McDeviceForm.tv,
                args: PlayerPageArgs(
                  mediaItemId: _args.mediaItemId,
                  isEpisode: _args.isEpisode,
                  seasons: _pickerSeasons,
                  episodes: _pickerEpisodes,
                ),
                currentSeason: _pickerSeason,
                currentEpisode: _args.episodeNumber ?? 1,
                loading: _pickerLoading,
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
    );

    return _WithTimers(
      onTick: () {
        if (!mounted) return;
        final elapsed = DateTime.now().difference(_lastUserActivity);
        if (_notice != null && elapsed >= _noticeHideAfter) {
          setState(() => _notice = null);
        }
        if (_levelHud != null && elapsed >= _hudHideAfter) {
          setState(() => _levelHud = null);
        }
        if (_chromeVisible &&
            !_tvForm &&
            !_mustStayVisible &&
            elapsed >= _chromeHideAfter) {
          setState(() => _chromeVisible = false);
        }
        if (_lockHint && elapsed >= const Duration(seconds: 3)) {
          setState(() => _lockHint = false);
        }
      },
      child: body,
    );
  }

  Widget _serviceView() {
    final service = ref.watch(playerServiceProvider);
    return service.buildView(fit: displayModeToBoxFit(_displayMode));
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
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              McActionPill(
                label: '重试',
                icon: McIcons.refreshS,
                primary: true,
                onTap: () => _controller.open(_args),
              ),
              const SizedBox(width: 12),
              McActionPill(
                label: '返回',
                primary: false,
                onTap: _exit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 中央 72dp 液态玻璃播放/暂停大圆钮（带 1px 冷白亮边与按压回弹）。
class CenterGlassButton extends StatelessWidget {
  const CenterGlassButton({
    super.key,
    required this.playing,
    required this.accent,
    required this.onTap,
  });

  final bool playing;
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
              playing ? McIcons.pauseS : McIcons.play2Fill,
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
