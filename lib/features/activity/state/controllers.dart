import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import 'activity_api.dart';
import 'models.dart';

/// 活动总览的完整快照（对应 ActivityViewModel.kt 的 UiState 字段子集，
/// Android 端拆成多个 StateFlow，Flutter 端一个不可变对象整存整取）。
class ActivitySnapshot {
  ActivitySnapshot({
    this.jobs = const [],
    this.downloads = const [],
    this.playback,
    this.watchStats,
    this.watchStatsDays = 7,
    this.watchStatsMemberId,
    this.history,
    this.statsForbidden = false,
    this.historyForbidden = false,
    this.initialLoaded = false,
    this.error,
  });

  final List<JobView> jobs;
  final List<DownloadTask> downloads;
  final PlaybackActivityView? playback;

  /// 管理员专属；非管理员（403）保持 null 且 statsForbidden=true。
  final PlaybackWatchStatsView? watchStats;
  final int watchStatsDays;
  final int? watchStatsMemberId;
  final PlaybackHistoryView? history;
  final bool statsForbidden;
  final bool historyForbidden;
  final bool initialLoaded;
  final String? error;

  bool get loading => !initialLoaded;

  ActivitySnapshot copyWith({
    List<JobView>? jobs,
    List<DownloadTask>? downloads,
    PlaybackActivityView? playback,
    bool clearPlayback = false,
    PlaybackWatchStatsView? watchStats,
    int? watchStatsDays,
    int? watchStatsMemberId,
    bool clearWatchStatsMember = false,
    PlaybackHistoryView? history,
    bool statsForbidden = false,
    bool historyForbidden = false,
    bool initialLoaded = false,
    String? error,
    bool clearError = false,
  }) {
    return ActivitySnapshot(
      jobs: jobs ?? this.jobs,
      downloads: downloads ?? this.downloads,
      playback: clearPlayback ? null : (playback ?? this.playback),
      watchStats: watchStats ?? this.watchStats,
      watchStatsDays: watchStatsDays ?? this.watchStatsDays,
      watchStatsMemberId:
          clearWatchStatsMember ? null : (watchStatsMemberId ?? this.watchStatsMemberId),
      history: history ?? this.history,
      statsForbidden: statsForbidden || this.statsForbidden,
      historyForbidden: historyForbidden || this.historyForbidden,
      initialLoaded: initialLoaded || this.initialLoaded,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 活动总览控制器：手动刷新 + 三路轮询。
///
/// Android 端下载 10s、播放活动 8s，任务走 SSE jobs/stream（120ms 防抖）。
/// Flutter 端：jobs 接 SSE（ready/job 事件，120ms 防抖后拉增量）；
/// SSE 不可用（未登录/端点 404/重试耗尽）时回退 15s 低频轮询。
class ActivityController extends Notifier<ActivitySnapshot> {
  Timer? _jobsTimer;
  Timer? _tasksTimer;
  Timer? _playbackTimer;
  StreamSubscription? _jobsStreamSub;
  Timer? _jobDebounce;
  bool _disposed = false;

  ActivityApi get _api => ref.watch(activityApiProvider);
  @override
  ActivitySnapshot build() {
    ref.onDispose(_stopTimers);
    unawaited(refresh().then((_) {}, onError: (_) {})); // 初始加载失败不冒泡（UI 已显示 error 态）
    _startTimers();
    _observeJobsStream();
    // build() 阶段 state 尚未初始化，读它直接抛 Bad state（IndexedStack 全页构建时必炸）。
    return ActivitySnapshot();
  }

  /// jobs 增量流（对齐 Kotlin observeJobsStream：ready→全量刷，job→防抖刷新）。
  Future<void> _observeJobsStream() async {
    final sse = AgentSseClient(ref.read(sessionStoreProvider));
    try {
      final sub = sse.events('/api/v1/jobs/stream', terminalEvents: const {}).listen(
        (event) async {
          if (event.name == 'ready') {
            await _loadJobs();
          } else if (event.name == 'job') {
            // 120ms 防抖对齐 iOS/Kotlin：合并密集事件为一次拉取。
            _jobDebounce?.cancel();
            _jobDebounce = Timer(const Duration(milliseconds: 120), () {
              unawaited(_poll(_loadJobs()));
            });
          }
        },
        onError: (_) {}, // 由 onDone 分支统一处理回退
      );
      _jobsStreamSub = sub;
      // 流结束（服务器关闭/网络中断且重试耗尽）→ 回退轮询。
      await sub.asFuture<void>();
      _fallbackJobsPolling();
    } catch (_) {
      _fallbackJobsPolling();
    }
  }

  /// SSE 不可用：jobs 回落 15s 轮询（保持旧行为）。
  void _fallbackJobsPolling() {
    if (_disposed || _jobsTimer != null) return;
    _jobsTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll(_loadJobs()));
  }

  void _startTimers() {
    _tasksTimer ??= Timer.periodic(const Duration(seconds: 10), (_) => _poll(_loadTasks()));
    _playbackTimer ??= Timer.periodic(const Duration(seconds: 8), (_) => _poll(_loadPlayback()));
  }

  void _stopTimers() {
    _disposed = true;
    _jobsTimer?.cancel();
    _tasksTimer?.cancel();
    _playbackTimer?.cancel();
    _jobDebounce?.cancel();
    _jobsStreamSub?.cancel();
    _jobsTimer = _tasksTimer = _playbackTimer = _jobDebounce = null;
    _jobsStreamSub = null;
  }

  /// 轮询失败静默（保持上一帧数据），仅首载失败才落 error。
  Future<void> _poll(Future<void> load) async {
    try {
      await load;
    } on ApiException {
      // 轮询静默失败，等下一轮。
    } catch (_) {
      // 网络层异常同样静默。
    }
  }

  /// 手动下拉刷新：全量拉一遍；首个失败抛给 UI 展示。
  Future<void> refresh() async {
    try {
      await _loadJobs();
      await _loadTasks();
      await _loadPlayback();
      await _loadWatchStats();
      await _loadHistory();
      state = state.copyWith(initialLoaded: true, clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(initialLoaded: true, error: e.friendlyMessage);
      rethrow;
    }
  }

  Future<void> _loadJobs() async {
    final jobs = await _api.jobs();
    if (_disposed) return;
    state = state.copyWith(jobs: jobs);
  }

  Future<void> _loadTasks() async {
    final tasks = await _api.downloadTasks();
    if (_disposed) return;
    state = state.copyWith(downloads: tasks);
  }

  Future<void> _loadPlayback() async {
    final activity = await _api.playbackActivity();
    if (_disposed) return;
    state = state.copyWith(playback: activity);
  }

  /// 统计/历史管理员专属：403 时记 forbidden 标记并置空，UI 不再请求。
  Future<void> _loadWatchStats() async {
    if (state.statsForbidden) return;
    try {
      final stats = await _api.playbackWatchStats(
        days: state.watchStatsDays,
        memberId: state.watchStatsMemberId,
      );
      if (_disposed) return;
      state = state.copyWith(watchStats: stats);
    } on ApiException catch (e) {
      if (e.code == 'auth.forbidden' || e.httpStatus == 403) {
        state = state.copyWith(statsForbidden: true, watchStats: null);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _loadHistory() async {
    if (state.historyForbidden) return;
    try {
      final history = await _api.playbackHistory();
      if (_disposed) return;
      state = state.copyWith(history: history);
    } on ApiException catch (e) {
      if (e.code == 'auth.forbidden' || e.httpStatus == 403) {
        state = state.copyWith(historyForbidden: true, history: null);
      } else {
        rethrow;
      }
    }
  }

  /// 切统计窗口（7/30/90 天）并重拉统计。
  Future<void> setWatchStatsDays(int days) async {
    if (state.statsForbidden || state.watchStatsDays == days) return;
    state = state.copyWith(watchStatsDays: days);
    await _poll(_loadWatchStats());
  }

  /// 按成员钻取统计（传 null 取消钻取）。
  Future<void> setWatchStatsMember(int? memberId) async {
    if (state.statsForbidden || memberId == state.watchStatsMemberId) return;
    state = state.copyWith(
      watchStatsMemberId: memberId,
      clearWatchStatsMember: memberId == null,
    );
    await _poll(_loadWatchStats());
  }

  Future<void> _afterAction() async {
    // 动作成功后立即刷新任务轴（Android 端同样只刷受影响的快照）。
    await _poll(_loadJobs());
    await _poll(_loadTasks());
  }

  Future<void> cancelJob(String id) async {
    await _api.cancelJob(id);
    await _afterAction();
  }

  Future<void> retryJob(String id) async {
    await _api.retryJob(id);
    await _afterAction();
  }

  Future<void> dismissJob(String id) async {
    await _api.dismissJob(id);
    await _afterAction();
  }

  Future<void> undismissJob(String id) async {
    await _api.undismissJob(id);
    await _afterAction();
  }

  Future<void> dismissAllJobs() async {
    await _api.dismissAllJobs();
    await _afterAction();
  }

  Future<void> deleteDownloadTask(DownloadTask task) async {
    final downloaderId = task.downloaderId;
    if (downloaderId == null) return;
    await _api.deleteDownloadTask(downloaderId, task.infoHash);
    await _afterAction();
  }

  Future<void> replaceDownloadTask(DownloadTask task) async {
    final downloaderId = task.downloaderId;
    if (downloaderId == null) return;
    await _api.replaceDownloadTask(downloaderId, task.infoHash);
    await _afterAction();
  }

  Future<void> endPlaybackSession(String deviceId) async {
    await _api.endPlaybackSession(deviceId);
    await _poll(_loadPlayback());
  }

  Future<void> revokePlaybackDevice(String deviceId) async {
    await _api.revokePlaybackDevice(deviceId);
    await _poll(_loadPlayback());
  }

  /// 将失败任务一键移交 AI 助手自动诊断排障（POST /api/v1/agent-handoff）。
  Future<String?> handoffJobToAi(JobView job) async {
    try {
      final res = await ref.read(mcClientProvider).unwrap<Map<String, dynamic>>(
            Channel.general,
            'POST',
            '/api/v1/agent-handoff',
            body: {
              'kind': 'job',
              'job_id': job.id,
              'id': job.id,
              'title': job.jobTypeLabel ?? job.jobType,
              'detail': job.progress.message,
            },
          );
      return (res['session_id'] ?? res['sessionId'])?.toString();
    } catch (_) {
      return null;
    }
  }
}

final activityControllerProvider =
    NotifierProvider<ActivityController, ActivitySnapshot>(ActivityController.new);
