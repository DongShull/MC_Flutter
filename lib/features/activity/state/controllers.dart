import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/llm_capability_probe.dart';
import '../../../core/api/session_providers.dart';
import 'activity_api.dart';
import 'models.dart';

/// 活动总览的完整快照。
class ActivitySnapshot {
  const ActivitySnapshot({
    this.jobs = const [],
    this.downloads = const [],
    this.downloadSources = const [],
    this.downloadsError,
    this.boostPool,
    this.supportsBoostCleanup = false,
    this.playback,
    this.watchStats,
    this.watchStatsDays = 7,
    this.watchStatsMemberId,
    this.history,
    this.members = const [],
    this.scope = 'visible',
    this.statsForbidden = false,
    this.historyForbidden = false,
    this.initialLoaded = false,
    this.error,
  });

  final List<JobView> jobs;
  final List<DownloadTask> downloads;
  final List<DownloadTaskSource> downloadSources;
  final String? downloadsError;
  final BoostPoolView? boostPool;
  final bool supportsBoostCleanup;
  final PlaybackActivityView? playback;

  /// 管理员专属；非管理员（403）保持 null 且 statsForbidden=true。
  final PlaybackWatchStatsView? watchStats;
  final int watchStatsDays;
  final int? watchStatsMemberId;
  final PlaybackHistoryView? history;
  final List<ActivityMemberOption> members;

  /// `'visible'`（我的浏览范围）或 `'all'`（全部）。
  final String scope;
  final bool statsForbidden;
  final bool historyForbidden;
  final bool initialLoaded;
  final String? error;

  bool get loading => !initialLoaded;

  ActivitySnapshot copyWith({
    List<JobView>? jobs,
    List<DownloadTask>? downloads,
    List<DownloadTaskSource>? downloadSources,
    String? downloadsError,
    bool clearDownloadsError = false,
    BoostPoolView? boostPool,
    bool? supportsBoostCleanup,
    PlaybackActivityView? playback,
    bool clearPlayback = false,
    PlaybackWatchStatsView? watchStats,
    bool clearWatchStats = false,
    int? watchStatsDays,
    int? watchStatsMemberId,
    bool clearWatchStatsMember = false,
    PlaybackHistoryView? history,
    bool clearHistory = false,
    List<ActivityMemberOption>? members,
    String? scope,
    bool statsForbidden = false,
    bool historyForbidden = false,
    bool initialLoaded = false,
    String? error,
    bool clearError = false,
  }) {
    return ActivitySnapshot(
      jobs: jobs ?? this.jobs,
      downloads: downloads ?? this.downloads,
      downloadSources: downloadSources ?? this.downloadSources,
      downloadsError: clearDownloadsError
          ? null
          : (downloadsError ?? this.downloadsError),
      boostPool: boostPool ?? this.boostPool,
      supportsBoostCleanup: supportsBoostCleanup ?? this.supportsBoostCleanup,
      playback: clearPlayback ? null : (playback ?? this.playback),
      watchStats: clearWatchStats ? null : (watchStats ?? this.watchStats),
      watchStatsDays: watchStatsDays ?? this.watchStatsDays,
      watchStatsMemberId: clearWatchStatsMember
          ? null
          : (watchStatsMemberId ?? this.watchStatsMemberId),
      history: clearHistory ? null : (history ?? this.history),
      members: members ?? this.members,
      scope: scope ?? this.scope,
      statsForbidden: statsForbidden || this.statsForbidden,
      historyForbidden: historyForbidden || this.historyForbidden,
      initialLoaded: initialLoaded || this.initialLoaded,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 活动总览控制器：手动刷新 + SSE jobs/stream + 轮询 + 范围持久化。
class ActivityController extends Notifier<ActivitySnapshot> {
  static const _scopePrefKey = 'movieclaw.activity.scope';

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
    unawaited(_bootstrap());
    _startTimers();
    _observeJobsStream();
    return const ActivitySnapshot();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScope = prefs.getString(_scopePrefKey);
      if (!_disposed && savedScope == 'all') {
        state = state.copyWith(scope: 'all');
      }
    } catch (_) {}
    unawaited(refresh().then((_) {}, onError: (_) {}));
    unawaited(loadMembers());
  }

  /// jobs 增量流：ready→全量刷，job→120ms 防抖刷新。
  Future<void> _observeJobsStream() async {
    final sse = AgentSseClient(ref.read(sessionStoreProvider));
    try {
      final sub =
          sse.events('/api/v1/jobs/stream', terminalEvents: const {}).listen(
        (event) async {
          if (event.name == 'ready') {
            await _poll(_loadJobs());
          } else if (event.name == 'job') {
            _jobDebounce?.cancel();
            _jobDebounce = Timer(const Duration(milliseconds: 120), () {
              unawaited(_poll(_loadJobs()));
            });
          }
        },
        onError: (_) {},
      );
      _jobsStreamSub = sub;
      await sub.asFuture<void>();
      _fallbackJobsPolling();
    } catch (_) {
      _fallbackJobsPolling();
    }
  }

  void _fallbackJobsPolling() {
    if (_disposed || _jobsTimer != null) return;
    _jobsTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _poll(_loadJobs()));
  }

  void _startTimers() {
    _tasksTimer ??=
        Timer.periodic(const Duration(seconds: 10), (_) => _poll(_loadTasks()));
    _playbackTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _poll(_loadPlayback()),
    );
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

  Future<void> _poll(Future<void> load) async {
    try {
      await load;
    } on ApiException {
      // 轮询静默失败，等下一轮。
    } catch (_) {}
  }

  /// 手动下拉刷新：并行全量拉一遍；首个失败抛给 UI 展示。
  Future<void> refresh() async {
    try {
      await Future.wait([
        _loadJobs(),
        _loadTasks(),
        _loadPlayback(),
        _loadWatchStats(),
        _loadHistory(),
      ]);
      if (!_disposed && state.downloads.any((t) => t.source == 'boost')) {
        unawaited(loadBoostPool());
      }
      if (!_disposed) {
        state = state.copyWith(initialLoaded: true, clearError: true);
      }
    } on ApiException catch (e) {
      if (!_disposed) {
        state = state.copyWith(initialLoaded: true, error: e.friendlyMessage);
      }
      rethrow;
    }
  }

  Future<void> _loadJobs() async {
    final jobs = await _api.jobsMerged();
    if (_disposed) return;
    state = state.copyWith(jobs: jobs);
  }

  Future<void> _loadTasks() async {
    try {
      final snap = await _api.downloadTaskSnapshot();
      if (_disposed) return;
      final hadBoost = state.downloads.any((t) => t.source == 'boost');
      final hasBoost = snap.items.any((t) => t.source == 'boost');
      state = state.copyWith(
        downloads: snap.items,
        downloadSources: snap.sources,
        clearDownloadsError: true,
      );
      if (hasBoost && (!hadBoost || state.boostPool == null)) {
        unawaited(loadBoostPool());
      }
    } on ApiException catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        downloadsError: e.friendlyMessage.isNotEmpty
            ? e.friendlyMessage
            : '下载器快照读取失败',
      );
    }
  }

  Future<void> _loadPlayback() async {
    final targetScope = state.scope;
    final activity = await _api.playbackActivity(scope: targetScope);
    if (_disposed || state.scope != targetScope) return;
    state = state.copyWith(playback: activity);
  }

  Future<void> _loadWatchStats() async {
    if (state.statsForbidden) return;
    final targetScope = state.scope;
    try {
      final stats = await _api.playbackWatchStats(
        days: state.watchStatsDays,
        memberId: state.watchStatsMemberId,
        scope: targetScope,
      );
      if (_disposed || state.scope != targetScope) return;
      state = state.copyWith(watchStats: stats);
    } on ApiException catch (e) {
      if (e.code == 'auth.forbidden' || e.httpStatus == 403) {
        state = state.copyWith(statsForbidden: true, clearWatchStats: true);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _loadHistory() async {
    if (state.historyForbidden) return;
    final targetScope = state.scope;
    try {
      final history = await _api.playbackHistory(limit: 6, scope: targetScope);
      if (_disposed || state.scope != targetScope) return;
      state = state.copyWith(history: history);
    } on ApiException catch (e) {
      if (e.code == 'auth.forbidden' || e.httpStatus == 403) {
        state = state.copyWith(historyForbidden: true, clearHistory: true);
      } else {
        rethrow;
      }
    }
  }

  Future<void> loadBoostPool() async {
    final loaded = await _api.loadBoostPool();
    if (_disposed || loaded == null) return;
    state = state.copyWith(
      boostPool: loaded.pool,
      supportsBoostCleanup: loaded.supportsCleanup,
    );
  }

  Future<void> loadMembers() async {
    try {
      final list = await _api.members();
      if (_disposed) return;
      state = state.copyWith(members: list);
    } catch (_) {}
  }

  /// 切换浏览范围（`'visible'` / `'all'`），记住本机偏好并重拉播放/历史/统计。
  Future<void> setScope(String next) async {
    final normalized = next == 'all' ? 'all' : 'visible';
    if (state.scope == normalized) return;
    state = state.copyWith(scope: normalized);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (normalized == 'all') {
        await prefs.setString(_scopePrefKey, 'all');
      } else {
        await prefs.remove(_scopePrefKey);
      }
    } catch (_) {}
    await Future.wait([
      _poll(_loadPlayback()),
      _poll(_loadHistory()),
      _poll(_loadWatchStats()),
    ]);
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

  void _upsertJob(JobView? job) {
    if (job == null || _disposed) return;
    final next = [job, ...state.jobs.where((j) => j.id != job.id)];
    state = state.copyWith(jobs: next);
  }

  Future<void> _afterAction() async {
    await Future.wait([
      _poll(_loadJobs()),
      _poll(_loadTasks()),
    ]);
  }

  Future<void> cancelJob(String id) async {
    final updated = await _api.cancelJob(id);
    _upsertJob(updated);
    await _afterAction();
  }

  Future<void> retryJob(String id) async {
    final updated = await _api.retryJob(id);
    _upsertJob(updated);
    await _afterAction();
  }

  Future<void> dismissJob(String id, {bool? muteSource}) async {
    final updated = await _api.dismissJob(id, muteSource: muteSource);
    _upsertJob(updated);
    await _afterAction();
  }

  Future<void> undismissJob(String id) async {
    final updated = await _api.undismissJob(id);
    _upsertJob(updated);
    await _afterAction();
  }

  Future<int> dismissAllJobs() async {
    final jobs = await _api.dismissAllJobs();
    for (final j in jobs) {
      _upsertJob(j);
    }
    await _afterAction();
    return jobs.length;
  }

  Future<void> deleteDownloadTask(
    DownloadTask task, {
    bool deleteFiles = false,
  }) async {
    final downloaderId = task.downloaderId;
    if (downloaderId == null) return;
    await _api.deleteDownloadTask(
      downloaderId,
      task.infoHash,
      deleteFiles: deleteFiles,
    );
    await _afterAction();
  }

  Future<void> replaceDownloadTask(DownloadTask task) async {
    final downloaderId = task.downloaderId;
    if (downloaderId == null) return;
    await _api.replaceDownloadTask(downloaderId, task.infoHash);
    await _afterAction();
  }

  Future<String> endPlaybackSession(String deviceId) async {
    final msg = await _api.endPlaybackSession(deviceId);
    await _poll(_loadPlayback());
    return msg;
  }

  Future<String> revokePlaybackDevice(String deviceId) async {
    final msg = await _api.revokePlaybackDevice(deviceId);
    await _poll(_loadPlayback());
    return msg;
  }

  Future<BoostCleanupResult> cleanupBoostPool({bool force = false}) async {
    final result = await _api.cleanupBoostPool(
      disableBoost: true,
      force: force,
    );
    await _poll(_loadTasks());
    await loadBoostPool();
    return result;
  }

  /// 将失败任务一键移交 AI 助手自动诊断排障（统一走 core `AgentHandoffApi`）。
  Future<String?> handoffJobToAi(JobView job) async {
    try {
      return await AgentHandoffApi.handoff(
        ref.read(mcClientProvider),
        kind: 'job',
        ref: job.id,
      );
    } catch (_) {
      return null;
    }
  }
}

final activityControllerProvider =
    NotifierProvider<ActivityController, ActivitySnapshot>(
  ActivityController.new,
);
