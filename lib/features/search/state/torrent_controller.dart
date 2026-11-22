import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/mc_error.dart';
import '../../../core/api/models.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/api/sse_client.dart';
import 'search_mode_memory.dart';
import 'torrent_models.dart';

/// 种子搜索状态（安卓 `SearchViewModel.UiState` 的种子搜索部分）。
class TorrentSearchState {
  const TorrentSearchState({
    this.query = '',
    this.category,
    this.activeTab,
    this.searchTabs = const [],
    this.searching = false,
    this.error,
    this.notice,
    this.blocks = const [],
    this.done,
    this.history = const [],
    this.actionHit,
    this.download = const DownloadFlow(),
    this.downloadStates = const {},
    this.grabStates = const {},
    this.grabTarget,
    this.keyword = '',
    this.isAdmin,
  });

  final String query;
  final TorrentCategory? category;
  final SearchTabView? activeTab;

  /// 搜索分类栏（服务端 /search/presets 的可见项；失败时回退到内置分类）。
  final List<SearchTabView> searchTabs;
  final bool searching;
  final String? error;
  final String? notice;
  final List<SiteBlock> blocks;
  final SearchStreamDone? done;
  final List<String> history;

  /// 资源操作面板的那一条（null = 面板关着）。
  final TorrentHit? actionHit;
  final DownloadFlow download;

  /// 按行记的下载 / 投递状态：终态不可再点，error 可重试。
  final Map<String, TorrentSubmitState> downloadStates;
  final Map<String, TorrentSubmitState> grabStates;

  /// 手动选种目标订阅（`search?forSub=` 进来时写入）：(订阅 id, 标题)。
  final (int, String)? grabTarget;

  /// 本页的搜索关键词（种子身份识别失败时给候选当线索）。
  final String keyword;

  /// 是否管理员（null = 还没问过服务端；成员走可见库两层候选）。
  final bool? isAdmin;

  int get totalHits => blocks.fold(0, (sum, b) => sum + b.items.length);

  TorrentSearchState copyWith({
    String? query,
    TorrentCategory? category,
    SearchTabView? activeTab,
    List<SearchTabView>? searchTabs,
    bool? searching,
    Object? error = _sentinel,
    Object? notice = _sentinel,
    List<SiteBlock>? blocks,
    Object? done = _sentinel,
    List<String>? history,
    TorrentHit? actionHit,
    DownloadFlow? download,
    Map<String, TorrentSubmitState>? downloadStates,
    Map<String, TorrentSubmitState>? grabStates,
    (int, String)? grabTarget,
    String? keyword,
    bool? isAdmin,
    bool clearActionHit = false,
    bool clearCategory = false,
    bool clearActiveTab = false,
  }) =>
      TorrentSearchState(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        activeTab: clearActiveTab ? null : (activeTab ?? this.activeTab),
        searchTabs: searchTabs ?? this.searchTabs,
        searching: searching ?? this.searching,
        error: identical(error, _sentinel) ? this.error : error as String?,
        notice: identical(notice, _sentinel) ? this.notice : notice as String?,
        blocks: blocks ?? this.blocks,
        done: identical(done, _sentinel) ? this.done : done as SearchStreamDone?,
        history: history ?? this.history,
        actionHit: clearActionHit ? null : (actionHit ?? this.actionHit),
        download: download ?? this.download,
        downloadStates: downloadStates ?? this.downloadStates,
        grabStates: grabStates ?? this.grabStates,
        grabTarget: grabTarget ?? this.grabTarget,
        keyword: keyword ?? this.keyword,
        isAdmin: isAdmin ?? this.isAdmin,
      );

  static const _sentinel = Object();
}

/// 种子搜索控制器（安卓 `SearchViewModel` 的种子搜索分支 + 下载目标流程）。
///
/// 流式搜索走 SSE：`GET /api/v1/search/torrents/stream`，事件
/// `start` / `site_result` / `site_error` / `done`；流不支持时
/// （[SseUnsupportedException]）报错，不静默回退到不存在的轮询接口。
/// 下载目标流程照 iOS `TorrentActionsState` + 安卓 `DownloadTargetSheet`：
/// 点行 → 资源操作面板 → 点「下载」按保存位置记忆弹确认条或完整弹窗 → 提交。
class TorrentSearchController extends Notifier<TorrentSearchState> {
  McApi get _api => ref.read(mcApiProvider);
  StreamSubscription<SseEvent>? _searchSub;
  int _preflightSeq = 0;
  bool? _isAdminCache;

  @override
  TorrentSearchState build() {
    ref.onDispose(() => unawaited(_searchSub?.cancel()));
    return TorrentSearchState(
      searchTabs: TorrentCategory.values
          .map((c) => SearchTabView(type: 'category', id: c.id, visible: true))
          .toList(),
    );
  }

  /// 读服务端搜索预设（自定义分类页签）；失败时保留内置分类。
  Future<void> loadSearchTabs() async {
    try {
      final presets = await _api.searchPresets();
      final visible = presets.presets.where((t) => t.visible).toList();
      if (visible.isNotEmpty) {
        state = state.copyWith(searchTabs: visible);
      }
    } catch (e) {
      McErrorLog.log(e, context: 'search.tabs');
    }
  }

  Future<void> loadHistory() async {
    final list = await SearchModeMemory.instance.readHistory();
    state = state.copyWith(history: list);
  }

  /// 历史记录与库内搜索共用同一份本机存储（`mc_search_history`）。
  Future<void> clearHistory() async {
    final list = await SearchModeMemory.instance.clearHistory();
    state = state.copyWith(history: list);
  }

  Future<void> removeHistory(String query) async {
    final list = await SearchModeMemory.instance.removeHistory(query);
    state = state.copyWith(history: list);
  }

  void onQuery(String value) => state = state.copyWith(query: value);

  void onCategory(TorrentCategory? category) => state = state.copyWith(
        category: category,
        clearCategory: category == null,
        clearActiveTab: true,
      );

  void onTab(SearchTabView? tab) {
    if (tab == null) {
      state = state.copyWith(clearActiveTab: true);
      return;
    }
    state = state.copyWith(
      activeTab: tab,
      category: TorrentCategory.of(tab.id),
      clearCategory: TorrentCategory.of(tab.id) == null,
    );
  }

  /// 手动选种入口（订阅页“补缺资源”进来时调用）。
  void prefillGrabTarget(int subscriptionId, String title) =>
      state = state.copyWith(grabTarget: (subscriptionId, title));

  /// 提交搜索：SSE 流式，站点结果逐站合并；`done` 事件收尾。
  Future<void> submit([String? keywordOverride]) async {
    final keyword = (keywordOverride ?? state.query).trim();
    if (keyword.isEmpty) return;
    await _searchSub?.cancel();
    state = state.copyWith(
      query: keyword,
      keyword: keyword,
      searching: true,
      error: null,
      blocks: const [],
      done: null,
    );
    unawaited(SearchModeMemory.instance.appendHistory(keyword).then(
      (list) {
        if (state.keyword == keyword) state = state.copyWith(history: list);
      },
    ));
    final tab = state.activeTab;
    final category = state.category;
    final query = <String, String>{'keyword': keyword};
    final isPresetTab = tab != null && tab.type == 'preset';
    final categories = isPresetTab
        ? tab.categories
        : [if (category != null) category.id];
    // SseClient 只接受单值 query：多分类/多站点用逗号拼（服务端按逗号切分，
    // 与安卓逐个 `categories=` 参数等价——见服务端 search/torrents/stream）。
    if (categories.isNotEmpty) query['categories'] = categories.join(',');
    if (tab != null && tab.siteIds.isNotEmpty) {
      query['sites'] = tab.siteIds.join(',');
    }
    final label = isPresetTab ? tab.name : category?.label;
    if (label != null && label.isNotEmpty) query['label'] = label;
    if (tab?.skipHistory == true) query['no_history'] = 'true';
    if (tab?.posterMode == true) query['poster_mode'] = 'true';
    final sse = SseClient(ref.read(sessionStoreProvider));
    try {
      final stream = sse.events(
        '/api/v1/search/torrents/stream',
        query: query,
        terminalEvents: const {'done'},
      );
      _searchSub = stream.listen(
        (event) => _applyEvent(event),
        onError: (Object e) {
          state = state.copyWith(
            searching: false,
            error: e is SseUnsupportedException
                ? '当前服务器不支持资源流式搜索'
                : e is ApiException
                    ? e.friendlyMessage
                    : '搜索失败：$e',
          );
        },
        onDone: () {
          if (state.searching) state = state.copyWith(searching: false);
        },
      );
    } on SseUnsupportedException {
      state = state.copyWith(searching: false, error: '当前服务器不支持资源流式搜索');
    } catch (e) {
      state = state.copyWith(
        searching: false,
        error: e is ApiException ? e.friendlyMessage : '搜索失败：$e',
      );
    }
  }

  void _applyEvent(SseEvent event) {
    try {
      final data = jsonDecode(event.data);
      if (data is! Map<String, dynamic>) return;
      switch (event.name) {
        case 'start':
          final start = SearchStreamStart.fromJson(data);
          state = state.copyWith(
            blocks: [
              for (final s in start.sites)
                SiteBlock(siteId: s.siteId, siteName: s.siteName),
            ],
          );
        case 'site_result':
          final result = SiteStreamResult.fromJson(data);
          state = state.copyWith(
            blocks: state.blocks
                .map((b) => b.siteId == result.siteId ? b.mergeResult(result) : b)
                .toList(),
          );
        case 'site_error':
          final error = SiteStreamError.fromJson(data);
          state = state.copyWith(
            blocks: state.blocks
                .map((b) => b.siteId == error.siteId
                    ? b.copyWith(error: error.error, elapsedMs: error.elapsedMs)
                    : b)
                .toList(),
          );
        case 'done':
          state = state.copyWith(
            done: SearchStreamDone.fromJson(data),
            searching: false,
          );
          unawaited(loadHistory());
      }
    } catch (e) {
      McErrorLog.log(e, context: 'search.torrent-event');
    }
  }

  // —— 资源操作面板（点行 → 查看 / 投给订阅 / 下载）——

  void openActions(TorrentHit hit) => state = state.copyWith(actionHit: hit);

  void closeActions() => state = state.copyWith(clearActionHit: true);

  void consumeNotice() => state = state.copyWith(notice: null);

  /// 点「下载」：无下载链接的种子直接跳过（与安卓 `DownloadTargetRequest.of`
  /// 返回 null 时一致）；终态的种子不再重复提交。
  void startDownload(TorrentHit hit) {
    final request = DownloadTargetRequest.of(hit, state.keyword);
    if (request == null) return;
    final current =
        state.downloadStates[request.hitKey] ?? TorrentSubmitState.idle;
    if (current == TorrentSubmitState.submitting ||
        current == TorrentSubmitState.done ||
        current == TorrentSubmitState.exists) {
      return;
    }
    state = state.copyWith(clearActionHit: true);
    unawaited(_openTargetSheet(request));
  }

  /// 点「投给订阅」：手动选种模式（`forSub` 进来的）才有此入口。
  Future<void> grabForSubscription(TorrentHit hit) async {
    final target = state.grabTarget;
    if (target == null) return;
    final key = hitKey(hit);
    final current = state.grabStates[key] ?? TorrentSubmitState.idle;
    if (current == TorrentSubmitState.submitting ||
        current == TorrentSubmitState.done ||
        current == TorrentSubmitState.exists) {
      return;
    }
    state = state.copyWith(
      clearActionHit: true,
      grabStates: {...state.grabStates, key: TorrentSubmitState.submitting},
    );
    try {
      await _api.grabSubscriptionTorrent(
        target.$1,
        body: GrabPayload(
          siteId: hit.siteId,
          torrentId: hit.torrentId,
          title: hit.title,
          subtitle: hit.subtitle.isEmpty ? null : hit.subtitle,
          category: hit.category,
          downloadUrl: hit.downloadUrl,
          sizeBytes: hit.sizeBytes,
          seeders: hit.seeders,
          isFree: hit.free,
          hitAndRun: hit.hitAndRun,
        ),
      );
      state = state.copyWith(
        grabStates: {...state.grabStates, key: TorrentSubmitState.done},
        notice: '已投给订阅「${target.$2}」',
      );
    } catch (e) {
      state = state.copyWith(
        grabStates: {...state.grabStates, key: TorrentSubmitState.error},
        notice: e is ApiException ? e.friendlyMessage : '投递失败：$e',
      );
    }
  }

  // —— 下载目标流程 ——

  Future<bool> _isAdmin() async {
    final cached = _isAdminCache;
    if (cached != null) return cached;
    try {
      final me = await _api.me();
      _isAdminCache = me.role == 'admin';
    } catch (e) {
      McErrorLog.log(e, context: 'search.admin');
      _isAdminCache = false;
    }
    return _isAdminCache!;
  }

  /// 打开落点弹窗（有记忆先弹确认条；记忆失效把原因摆在弹窗顶上）。
  Future<void> _openTargetSheet(DownloadTargetRequest request) async {
    final isAdmin = await _isAdmin();
    state = state.copyWith(
      download: DownloadFlow(request: request),
      isAdmin: isAdmin,
    );
    DownloadTargetPrefView? remembered;
    Set<String>? dirs;
    if (isAdmin) {
      // 保存位置记忆只对管理员记（服务端也不给成员返回）。
      try {
        final prefs = await _api.downloadTargetPrefs();
        remembered = prefs
            .where((p) => p.category == request.category)
            .firstOrNull;
      } catch (e) {
        McErrorLog.log(e, context: 'search.target-prefs');
      }
      if (remembered != null) {
        try {
          final list = await _api.downloaders();
          final usable = list.where((d) => d.usable).toList();
          dirs = downloaderDirs(list);
          state = state.copyWith(
            download: state.download.copyWith(downloaders: usable),
          );
        } catch (e) {
          McErrorLog.log(e, context: 'search.downloaders');
        }
      }
    }
    final issue = remembered == null
        ? null
        : rememberedPrefIssue(remembered, request, dirs);
    if (remembered != null && issue == null) {
      state = state.copyWith(
        download: state.download.copyWith(
          remembered: remembered,
          dirs: dirs,
          confirmOnly: true,
        ),
      );
      return;
    }
    final patched =
        issue != null ? request.copyWith(reason: issue) : request;
    state = state.copyWith(
      download: state.download.copyWith(
        request: patched,
        remembered: remembered,
        dirs: dirs,
        confirmOnly: false,
        remember: remembered != null,
      ),
    );
    unawaited(_prepareSheet(patched, isAdmin));
  }

  /// 确认条上「更改」→ 进完整弹窗（记忆已失效时带上原因）。
  void reopenTargetDialog({String? reason}) {
    final flow = state.download;
    final request = flow.request;
    if (request == null) return;
    state = state.copyWith(
      download: flow.copyWith(
        request: reason != null ? request.copyWith(reason: reason) : request,
        confirmOnly: false,
        clearError: true,
      ),
    );
    unawaited(_prepareSheet(
      state.download.request ?? request,
      state.isAdmin ?? false,
    ));
  }

  /// 「不再记住」某个分类的保存位置（幂等），然后进完整弹窗。
  Future<void> forgetRemembered() async {
    final flow = state.download;
    final request = flow.request;
    if (request == null) return;
    try {
      await _api.forgetDownloadTargetPref(request.category);
    } catch (e) {
      McErrorLog.log(e, context: 'search.forget-pref');
    }
    state = state.copyWith(
      download: flow.copyWith(remembered: null, confirmOnly: false),
    );
    unawaited(_prepareSheet(request, state.isAdmin ?? false));
  }

  Future<void> _prepareSheet(
    DownloadTargetRequest request,
    bool isAdmin,
  ) async {
    if (!isAdmin) {
      // 成员版：只拉自己可见的库，不碰下载器配置与智能入库预检。
      try {
        final libraries = await _api.libraries();
        final visible =
            libraries.where((l) => l.viewerAccess).toList();
        state = state.copyWith(
          download: state.download.copyWith(
            memberLibraries: visible,
            memberLibrariesLoaded: true,
          ),
        );
      } catch (e) {
        McErrorLog.log(e, context: 'search.member-libraries');
        state = state.copyWith(
          download:
              state.download.copyWith(memberLibrariesLoaded: true),
        );
      }
      _autoSelect();
      return;
    }
    final rememberedKind = state.download.remembered?.kind;
    state = state.copyWith(
      download: state.download.copyWith(
        hint: request.hint,
        hintDraft: request.hint ?? '',
        picking: request.identityKind == null,
        // 有线索时先问「这是哪部」，目录收在「其他保存位置」里：
        // 摊开的目录会被默认选中，用户一点确认就下进了不会自动入库的目录。
        showOther: request.identityKind == null ||
            (state.download.remembered?.kind ?? 'smart') != 'smart',
      ),
    );
    if (rememberedKind == 'smart') {
      state = state.copyWith(
        download: state.download.copyWith(
          downloaderId: state.download.remembered?.downloaderId,
        ),
      );
    }
    if (request.identityKind != null || request.hint != null) {
      _runPreflight(
        downloaderId: rememberedKind == 'smart'
            ? state.download.remembered?.downloaderId
            : null,
        hint: request.hint,
        initial: true,
      );
    }
    _autoSelect();
  }

  /// 「其他保存位置」展开时才读下载器配置。
  Future<void> loadDownloaders() async {
    final flow = state.download;
    if (flow.loadingDownloaders || flow.downloaders.isNotEmpty) return;
    state = state.copyWith(
      download: flow.copyWith(loadingDownloaders: true),
    );
    try {
      final list = await _api.downloaders();
      final usable = list.where((d) => d.usable).toList();
      state = state.copyWith(
        download: state.download.copyWith(
          downloaders: usable,
          loadingDownloaders: false,
        ),
      );
      _autoSelect();
    } catch (e) {
      state = state.copyWith(
        download: state.download.copyWith(
          loadingDownloaders: false,
          error: e is ApiException ? e.friendlyMessage : '下载器加载失败：$e',
        ),
      );
    }
  }

  void selectOption(String id) => state = state.copyWith(
        download: state.download.copyWith(selected: id),
      );

  void showOtherTargets() {
    state = state.copyWith(
      download: state.download.copyWith(showOther: true),
    );
    unawaited(loadDownloaders());
  }

  void setRemember(bool value) => state = state.copyWith(
        download: state.download.copyWith(remember: value),
      );

  void setDownloader(int id) {
    state = state.copyWith(
      download: state.download.copyWith(downloaderId: id),
    );
    _runPreflight(downloaderId: id, initial: false);
    _autoSelect();
  }

  void setHintDraft(String value) => state = state.copyWith(
        download: state.download.copyWith(hintDraft: value),
      );

  /// 「这是哪部作品」搜索框提交：拿关键词重新预检拿候选。
  void searchHint() {
    final hint = state.download.hintDraft.trim();
    if (hint.isEmpty) return;
    _runPreflight(hint: hint, initial: false);
  }

  void selectCandidate(ManualDownloadCandidateView candidate) {
    state = state.copyWith(
      download: state.download.copyWith(selectedCandidate: candidate),
    );
    _runPreflight(candidate: candidate, initial: false);
  }

  void closeTargetSheet() => state = state.copyWith(
        download: const DownloadFlow(),
      );

  /// 手动下载弹窗的只读预检：识别条目 → 库路由 → 投递目录。
  void _runPreflight({
    int? downloaderId,
    ManualDownloadCandidateView? candidate,
    String? hint,
    bool initial = false,
  }) {
    final request = state.download.request;
    if (request == null) return;
    final identityReady = request.identityKind != null;
    if (!identityReady && hint == null && candidate == null) {
      state = state.copyWith(
        download: state.download.copyWith(picking: true),
      );
      return;
    }
    final requestId = ++_preflightSeq;
    state = state.copyWith(
      download: state.download.copyWith(
        loadingTarget: true,
        target: initial ? state.download.target : null,
        clearTarget: !initial,
      ),
    );
    unawaited(_runPreflightAsync(
      requestId: requestId,
      request: request,
      downloaderId: downloaderId,
      candidate: candidate,
      hint: hint,
      initial: initial,
    ));
  }

  Future<void> _runPreflightAsync({
    required int requestId,
    required DownloadTargetRequest request,
    int? downloaderId,
    ManualDownloadCandidateView? candidate,
    String? hint,
    required bool initial,
  }) async {
    try {
      final target = await _api.resolveDownloadTarget(
        body: ManualDownloadTargetRequest(
          kind: request.identityKind,
          title: request.identityTitle,
          year: request.identityYear,
          subtitle: request.subtitle,
          hint: hint,
          downloaderId: downloaderId,
          selectedTmdbId: candidate?.tmdbId,
          selectedKind: candidate?.kind,
        ),
      );
      if (requestId != _preflightSeq) return;
      state = state.copyWith(
        download: state.download.copyWith(
          target: target,
          candidates: target.candidates,
          loadingTarget: false,
          picking: initial
              ? target.status != 'ready'
              : state.download.picking,
          // 有候选可点时目录继续收着；找不到 / 不能自动入库 /
          // 识别不可用时才摊开目录兜底。
          showOther: state.download.showOther ||
              target.status == 'not_found' ||
              (target.status == 'ready' && !target.ok),
        ),
      );
      // 用户刚点选了条目：直接选中随之出现的「自动入库」，别停在先前默认的目录上。
      if (candidate != null && target.status == 'ready' && target.ok) {
        selectOption('smart');
      } else {
        _autoSelect();
      }
    } catch (e) {
      if (requestId != _preflightSeq) return;
      McErrorLog.log(e, context: 'search.preflight');
      state = state.copyWith(
        download: state.download.copyWith(
          target: null,
          clearTarget: true,
          loadingTarget: false,
          showOther: true,
          clearError: true,
        ),
      );
      _autoSelect();
    }
  }

  /// 默认选中：记忆命中 > 智能入库可用 > 第一个目录 > 下载器默认
  /// （成员版：对得上类型的库）。
  void _autoSelect() {
    final flow = state.download;
    final request = flow.request;
    if (request == null || flow.selected != null) return;
    final isAdmin = state.isAdmin ?? false;
    final options = computeTargetOptions(
      isAdmin: isAdmin,
      target: flow.target,
      showOther: flow.showOther,
      downloader: flow.downloaders
          .where((d) => d.id == flow.downloaderId)
          .firstOrNull,
      memberLibraries: flow.memberLibraries,
      request: request,
    );
    if (options.isEmpty) {
      if (!isAdmin && flow.memberLibrariesLoaded) selectOption('default');
      return;
    }
    final remembered = flow.remembered;
    if (remembered != null) {
      final match = options.where((o) {
        switch (remembered.kind) {
          case 'dir':
            return o.kind == TargetOptionKind.dir &&
                o.savePath == remembered.savePath;
          case 'smart':
            return o.kind == TargetOptionKind.smart;
          default:
            return o.kind == TargetOptionKind.fallback;
        }
      }).firstOrNull;
      if (match != null) {
        selectOption(match.id);
        return;
      }
    }
    if (!isAdmin) {
      final kind = request.identityKind;
      final fit =
          flow.memberLibraries.where((l) => l.kind == kind).toList();
      final library = fit.where((l) => l.isDefault).firstOrNull ??
          fit.firstOrNull;
      selectOption(
        library == null ? 'default' : 'library:${library.id}',
      );
      return;
    }
    if (flow.loadingTarget ||
        (flow.showOther && flow.downloaders.isEmpty)) {
      return;
    }
    final pick = options.where((o) => o.kind == TargetOptionKind.smart).firstOrNull ??
        options.where((o) => o.kind != TargetOptionKind.smart).firstOrNull ??
        options.first;
    selectOption(pick.id);
  }

  /// 确认条「确认下载」：按记忆直接提交（记忆是策略时由服务端按身份重新路由）。
  void confirmRemembered() {
    final flow = state.download;
    final request = flow.request;
    final pref = flow.remembered;
    if (request == null || pref == null) return;
    final option = switch (pref.kind) {
      'smart' => const TargetOption(id: 'smart', kind: TargetOptionKind.smart, label: ''),
      'dir' => TargetOption(
          id: 'dir:${pref.savePath}',
          kind: TargetOptionKind.dir,
          savePath: pref.savePath,
          label: '',
        ),
      _ => const TargetOption(id: 'default', kind: TargetOptionKind.fallback, label: ''),
    };
    _submitOption(request, option,
        downloaderId: pref.downloaderId, remember: false);
  }

  /// 完整弹窗的「确认下载」。
  void submitSelected() {
    final flow = state.download;
    final request = flow.request;
    if (request == null) return;
    final isAdmin = state.isAdmin ?? false;
    final options = computeTargetOptions(
      isAdmin: isAdmin,
      target: flow.target,
      showOther: flow.showOther,
      downloader: flow.downloaders
          .where((d) => d.id == flow.downloaderId)
          .firstOrNull,
      memberLibraries: flow.memberLibraries,
      request: request,
    );
    final selected =
        options.where((o) => o.id == flow.selected).firstOrNull;
    if (selected == null) return;
    _submitOption(
      request,
      selected,
      downloaderId: flow.downloaderId,
      remember: flow.remember,
    );
  }

  void _submitOption(
    DownloadTargetRequest request,
    TargetOption option,
    {int? downloaderId,
    required bool remember,
  }) {
    final flow = state.download;
    if (flow.busy) return;
    final isAdmin = state.isAdmin ?? false;
    final DownloadSubmitRequest payload;
    if (!isAdmin) {
      // 成员版只带 library_id（+ 推导条目子目录用的片名年份）：
      // 目录 / 下载器 / 智能入库 / 记忆分类都被服务端强制拒绝。
      payload = DownloadSubmitRequest(
        siteId: request.siteId,
        downloadUrl: request.downloadUrl,
        torrentId: request.torrentId,
        libraryId: option.libraryId,
        title: request.identityTitle,
        year: request.identityYear,
        subtitle: request.subtitle,
      );
    } else {
      var body = DownloadSubmitRequest(
        siteId: request.siteId,
        downloadUrl: request.downloadUrl,
        torrentId: request.torrentId,
        // 只有勾了「记住本次选择」才带分类：服务端拿不到分类就不写记忆。
        category: remember ? request.category : null,
        downloaderId: downloaderId,
      );
      final target = flow.target;
      if (option.kind == TargetOptionKind.smart &&
          target != null &&
          target.tmdbId != null &&
          target.kind != null &&
          (target.title?.isNotEmpty ?? false)) {
        // 身份一律取预检确认的结论：类型可能与种子解析的不同，标题是 TMDB 标题。
        body = body.copyWith(
          autoRoute: true,
          mediaKind: target.kind,
          tmdbId: target.tmdbId,
          title: target.title,
          year: target.year,
          subtitle: request.subtitle,
        );
      }
      if (option.kind == TargetOptionKind.dir) {
        body = body.copyWith(savePath: option.savePath);
      }
      payload = body;
    }
    state = state.copyWith(
      download: flow.copyWith(busy: true, clearError: true),
      downloadStates: {
        ...state.downloadStates,
        request.hitKey: TorrentSubmitState.submitting,
      },
    );
    unawaited(_submitAsync(request, payload));
  }

  Future<void> _submitAsync(
    DownloadTargetRequest request,
    DownloadSubmitRequest payload,
  ) async {
    try {
      final result = await _api.submitDownload(body: payload);
      state = state.copyWith(
        download: const DownloadFlow(),
        downloadStates: {
          ...state.downloadStates,
          request.hitKey: result.alreadyExists
              ? TorrentSubmitState.exists
              : TorrentSubmitState.done,
        },
        notice: result.alreadyExists
            ? '该种子已在下载器中，未重复添加'
            : '已提交到「${result.downloaderName}」'
                '${result.savePath == null ? '' : ' · ${result.savePath}'}',
      );
    } catch (e) {
      state = state.copyWith(
        download: state.download.copyWith(
          busy: false,
          error: e is ApiException ? e.friendlyMessage : '提交失败：$e',
        ),
        downloadStates: {
          ...state.downloadStates,
          request.hitKey: TorrentSubmitState.error,
        },
      );
    }
  }
}

final torrentSearchProvider =
    NotifierProvider<TorrentSearchController, TorrentSearchState>(
  TorrentSearchController.new,
);
