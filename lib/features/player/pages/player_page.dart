import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/models/format.dart';
import '../../../core/api/episodes_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/player/session/playback_session.dart';
import '../../../core/player/session/playback_session_providers.dart';

import '../state/player_controller.dart';
import '../widgets/player_bottom_controls.dart';
import '../widgets/player_episode_picker.dart';
import '../widgets/player_gesture_layer.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_settings_panel.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../widgets/cast_sheet.dart';
import '../../../core/designsystem/mc_strings.dart';

/// 播放页（Android PlayerScreen 1:1）：强制横屏 + 沉浸式、黑底满屏画面、
/// 手势（横向定位 / 纵向亮度音量 / 双击 ±10s / 长按 2×）、锁屏、倍速、
/// ⋮ 面板（画质占位 / 倍速 / 画面缩放 / 诊断占位）、选集入口。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, this.args});

  /// go_router extra 传入；演示路径允许无参打开（用占位流验证 UI）。
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
  // 选集接口数据（播放侧 EpisodesApi.playbackItemEpisodes，切集真实重开会话）
  List<EpisodeItem> _pickerEpisodes = const [];
  List<int> _pickerSeasons = const [];
  int _pickerSeason = 1;
  bool _pickerLoading = false;
  String _displayMode = 'fit';
  String? _notice;
  static const _participantId = 'player-page';
  StreamSubscription<CoordinatorCommand>? _commandSub;
  DateTime _lastStateReport = DateTime.fromMillisecondsSinceEpoch(0);
  // 中断恢复（对齐飞牛 PlaybackInterruptionRecovery 口径）：
  // 系统级后台 → 自动暂停并记录；回前台且非用户手动暂停 → 自动恢复。
  AppLifecycleListener? _lifecycle;
  bool _pausedBySystem = false;
  bool? _lastReportedPlaying;
  Duration? _scrubPreview;
  ({bool brightness, double level})? _levelHud;
  double _brightnessLevel = 1.0;
  double _volumeLevel = 1.0;
  DateTime _lastUserActivity = DateTime.now();
  bool _tvForm = false; // TV 形态：常驻控制条、手势层停用（build 时同步）

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
    _args = widget.args ??
        const PlayerPageArgs(
          // 演示路径：直连一段公开测试流，验证 UI 全链路。
          url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
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
      // 播放中屏幕常亮（wakelock_plus，退出播放页在 dispose 释放）。
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

  /// 拉播放侧分集（GET /playback/items/{id}/episodes?season_number=），
  /// 供选集面板真实数据驱动；失败静默保留入口方传入的演示数据。
  Future<void> _loadPickerEpisodes() async {
    final id = _args.mediaItemId;
    if (id == null) return;
    setState(() => _pickerLoading = true);
    try {
      final season = await EpisodesApi(ref.read(mcClientProvider)).playbackItemEpisodes(id, _pickerSeason);
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

  /// 切集：detach 旧会话（DELETE /playback/sessions/{id}）→ 用新 fileId 重开。
  Future<void> _switchEpisode(int season, EpisodeItem episode) async {
    if (!episode.owned || episode.fileId == null) {
      _showNotice('第 ${episode.episode} 集缺文件，无法播放');
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

  /// 候选分集：播放侧实时拉到的优先，回退入口方传入的 episodes。
  List<EpisodeItem> get _episodeCandidates =>
      _pickerEpisodes.isNotEmpty ? _pickerEpisodes : _args.episodes;

  /// 下一集：按 (season, episode) 找当前之后的最小一集（需已拥有且有文件）。
  EpisodeItem? get _nextEpisode {
    final curSeason = _args.seasonNumber ?? 0;
    final curEpisode = _args.episodeNumber ?? 0;
    final list = _episodeCandidates
        .where((e) => e.owned && e.fileId != null)
        .toList()
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

  /// 播放会话协调（docs/design/08）：注册参与者 + 订阅协调器命令。
  /// 后到抢占时旧 active 收 pause；synchronize 下发 seek。
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

  /// 节流上报参与者状态（5s 心跳窗口内 1 次 + 播放态变化立即报）。
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
    _lifecycle?.dispose();
    WakelockPlus.disable();
    // reportUserStopped 口径：用户主动离开播放页，注销并清会话。
    ref.read(playbackCoordinatorProvider).reportUserStopped(_participantId);
    _controller.detach();
    _controller.exit();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _noteActivity() => _lastUserActivity = DateTime.now();

  /// DLNA 投屏：复用当前会话流地址直连渲染器（不走 MC 服务器）。
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
      context.go('/');
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
    final scrubTarget =
        _scrubPreview ?? playback.position;
    return [
      // 拖动预览（居中玻璃浮层：目标时间 + 迷你进度条），Android ScrubState 同款
      if (_scrubPreview != null)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mcFormatClock(scrubTarget.inSeconds),
                style: const TextStyle(
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${mcFormatClock(scrubTarget.inSeconds)} / ${mcFormatClock(duration.inSeconds)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  value: duration.inMilliseconds <= 0
                      ? 0
                      : (scrubTarget.inMilliseconds / duration.inMilliseconds)
                          .clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                ),
              ),
            ],
          ),
        ),
      // 亮度/音量 HUD（图标 + 条 + 百分比）
      if (_levelHud != null)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _levelHud!.brightness ? Icons.brightness_6 : McIcons.volumeUp,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 96,
                    child: LinearProgressIndicator(
                      value: _levelHud!.level.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '${(_levelHud!.level * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      // 长按 2× 角标（非正常速度时常驻，免得忘了自己开着倍速）
      if ((playback.speed != 1.0 || _holdSpeed) && !_locked)
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, top: 48),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                playback.speed == 2.0 && _holdSpeed ? '2x · 长按中' : '${playback.speed}x',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      // 操作提示（顶部玻璃胶囊，几秒自消）
      if (_notice != null)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_notice!,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ),
    ];
  }

  Widget _chrome(PlayerPlayback playback) {
    final isTv = _tvForm;
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedOpacity(
      opacity: (_chromeVisible || isTv) && !_locked ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: (!(_chromeVisible || isTv)) || _locked,
        child: Column(
          children: [
            // 顶栏：返回 / 标题 / 锁屏 / ⋮
            SafeArea(
              top: false,
              child: Row(
                children: [
                  McFocusRing(
                    child: BackButton(
                      color: Colors.white,
                      onPressed: () {
                        _controller.exit();
                        _exit();
                      },
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _args.title ?? '播放',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                        if (_args.subtitle != null)
                          Text(
                            _args.subtitle!,
                            maxLines: 1,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  McFocusRing(
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _locked = true;
                          _lockHint = true;
                          _chromeVisible = false;
                        });
                      },
                      icon: const Icon(McIcons.lock, color: Colors.white),
                      tooltip: '锁屏',
                    ),
                  ),
                  McFocusRing(
                    child: IconButton(
                      onPressed: () {
                        setState(() => _settingsOpen = true);
                        _noteActivity();
                      },
                      icon: const Icon(McIcons.more, color: Colors.white),
                      tooltip: '更多',
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 中央播放/暂停
            McFocusRing(
              borderRadius: 36,
              child: CenterGlassButton(
                playing: playback.playing,
                accent: accent,
                onTap: () {
                  _controller.togglePlay();
                  _noteActivity();
                },
              ),
            ),
            const Spacer(),
            // 工具行（音轨/字幕/下一集/选集/倍速）
            PlayerBottomControls(
              isEpisode: _args.isEpisode,
              // 下一集：分集数据可定位到当前之后的最小一集才显示按钮。
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
                // 'off' = 关闭字幕（switchTrack 里以 '' 传服务器）。
                _controller.switchTrack(
                    subtitleTrack: trackRef == 'off' ? '' : trackRef);
              },
              onEpisodes: () {
                setState(() => _episodePickerOpen = true);
                _loadPickerEpisodes();
                _noteActivity();
              },
              onCast: () => _showCastSheet(),
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
              onScrubPreview: (t) => setState(() => _scrubPreview = t),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// 协商结果弹窗（consent=转码确认；rejected=服务器拒绝提示）。
  void _maybeShowDecisionDialog(BuildContext context) {
    final controller = ref.read(playerControllerProvider);
    final decision = controller.pendingDecision;
    if (decision == null) return;
    ref.read(playerControllerProvider.notifier).acknowledgeDecision();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(decision == SessionDecision.rejected ? McStrings.rejectedByServer : McStrings.needTranscodeConfirm),
        content: Text(
          decision == SessionDecision.rejected
              ? McStrings.rejectedByServer
              : McStrings.needTranscodeConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(McStrings.continuePlay),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDecisionDialog(context));
    final playback = ref.watch(playerControllerProvider);
    // 播放会话：状态变化立即上报，位置推进按 4s 节流。
    ref.listen(playerControllerProvider, (_, next) => _reportSessionState(next));
    _tvForm = McFormWatch.of(context) == McDeviceForm.tv;
    final body = Scaffold(
      backgroundColor: Colors.black,
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
            // 画面（唯一引擎入口：PlayerService.buildView）
            if (playback.status == PlayerStatus.ready)
              _serviceView()
            else
              Center(
                child: playback.status == PlayerStatus.failed
                    ? _failedPane(playback)
                    : const McLoadingView(),
              ),
            // 手势层（控制层下方的兄弟节点）
            PlayerGestureLayer(
              // TV 形态停用手势层，全部操作走常驻控制条。
              enabled: !_tvForm && !_locked && playback.status == PlayerStatus.ready,
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
            // 亮度调层（纯 Flutter 无系统亮度通道：用黑色遮罩模拟播放页亮度）
            if (_brightnessLevel < 1.0)
              IgnorePointer(
                child: Container(
                  color: Colors.black
                      .withValues(alpha: (1 - _brightnessLevel) * 0.7),
                ),
              ),
            ..._overlays(playback),
            if (playback.status == PlayerStatus.ready) _chrome(playback),
            // 锁屏态：只留解锁按钮 + 提示
            if (_locked)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => setState(() {
                        _locked = false;
                        _chromeVisible = true;
                      }),
                      icon: const Icon(McIcons.lockOpen),
                      tooltip: '解锁',
                    ),
                    if (_lockHint)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('已锁定，点按钮解锁',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12)),
                      ),
                  ],
                ),
              ),
            // ⋮ 设置面板（右侧滑出）
            Align(
              alignment: Alignment.centerRight,
              child: PlayerSettingsPanel(
                visible: _settingsOpen,
                speed: playback.speed,
                displayMode: _displayMode,
                onSelectSpeed: (s) {
                  _controller.setSpeed(s);
                  _showNotice(s == 1.0 ? '已恢复常速' : '倍速 ${s}x');
                },
                onSelectDisplayMode: (m) =>
                    setState(() => _displayMode = m),
                onNotice: _showNotice,
                onDismiss: () => setState(() => _settingsOpen = false),
              ),
            ),
            // 选集面板
            if (_episodePickerOpen)
              PlayerEpisodePicker(
                asDrawer: McFormWatch.of(context) == McDeviceForm.tablet,
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

    // 常显/自动隐藏、HUD/提示自消的定时效果（Android LaunchedEffect 同款）。
    return _WithTimers(
      onTick: () {
        if (!mounted) return;
        final elapsed = DateTime.now().difference(_lastUserActivity);
        if (_notice != null &&
            elapsed >= _noticeHideAfter) {
          setState(() => _notice = null);
        }
        if (_levelHud != null && elapsed >= _hudHideAfter) {
          setState(() => _levelHud = null);
        }
        if (_chromeVisible &&
            !_tvForm && // TV 常驻控制条，不自动隐藏
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(playback.error ?? '播放失败',
            style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () => _controller.open(_args),
            child: const Text('重试'),
          ),
          TextButton(onPressed: _exit, child: const Text('返回')),
        ]),
      ],
    );
  }

}

/// 中央玻璃圆钮：播放/暂停（Android CenterGlassButton）。
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.38),
        ),
        child: Icon(
          playing ? McIcons.pauseS : McIcons.play2Fill,
          color: accent,
          size: 36,
        ),
      ),
    );
  }
}

/// 常显/自动隐藏的 500ms 心跳定时器外壳：把定时逻辑隔离在独立 State，
/// 避免整页播放器因心跳重建而闪断。
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
