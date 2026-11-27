import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/guest_playback_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/player_page_args.dart';
import 'mc_api.dart';
import 'models.dart';
import 'share_local_progress.dart';

/// 访客起播结果：正常返回 [PlayerPageArgs]；遇服务端 `consent` 需用户确认后 `force: true` 重试；
/// 遇 `reject` 或错误返回提示文案（不销毁当前分享页）。
class SharePlayResult {
  const SharePlayResult({
    this.args,
    this.consentMessage,
    this.errorMessage,
  });

  final PlayerPageArgs? args;
  final String? consentMessage;
  final String? errorMessage;

  bool get isSuccess => args != null;
  bool get needsConsent => consentMessage != null;
}

/// 访客分享页状态机（1:1 对齐 iOS SharePageView + ShareItemView）：
/// 探测 `/share/{slug}` →（密码门，密码错内联红字提示不替换页面）→ 合集海报网格 / 影片详情 → 访客播放。
class ShareUiState {
  const ShareUiState({
    this.loading = true,
    this.loadingItem = false,
    this.loadingEpisodes = false,
    this.unlocking = false,
    this.error,
    this.passwordError,
    this.probe,
    this.password = '',
    this.item,
    this.collection,
    this.activeCollectionItemId,
    this.selectedSeason = 0,
    this.selectedEpisodeNumber,
    this.episodes = const [],
    this.opening = false,
    this.localResume,
  });

  final bool loading;
  final bool loadingItem;
  final bool loadingEpisodes;
  final bool unlocking;
  final String? error;
  final String? passwordError;
  final SharePublic? probe;
  final String password;
  final SharedItem? item;
  final SharedCollection? collection;

  /// 合集分享中当前打开的子条目 mediaItemId（null = 停留在合集海报网格）。
  final int? activeCollectionItemId;
  final int selectedSeason;
  final int? selectedEpisodeNumber;
  final List<ShareEpisodeView> episodes;
  final bool opening;
  final ShareLocalProgressRecord? localResume;

  bool get needsPassword =>
      (probe?.requiresPassword ?? false) && !(probe?.unlocked ?? false);

  bool get isCollection => probe?.collectionId != null;

  bool get showingCollectionGrid =>
      isCollection && activeCollectionItemId == null && collection != null;

  ShareEpisodeView? get selectedEpisode {
    if (episodes.isEmpty) return null;
    if (selectedEpisodeNumber != null) {
      for (final e in episodes) {
        if (e.episodeNumber == selectedEpisodeNumber) return e;
      }
    }
    for (final e in episodes) {
      if (e.owned) return e;
    }
    return episodes.first;
  }

  /// 当前选中单元（电影或选中剧集）对应的可用文件列表。
  List<SharedFile> get currentAvailableFiles {
    final cur = item;
    if (cur == null) return const [];
    if (cur.isMovie) {
      return cur.files.where((f) => f.isPlayable).toList();
    }
    final ep = selectedEpisode;
    if (ep == null) return const [];
    return cur.files
        .where(
          (f) =>
              f.isPlayable &&
              f.seasonNumber == selectedSeason &&
              f.episodeNumber == ep.episodeNumber,
        )
        .toList();
  }

  ShareUiState copyWith({
    bool? loading,
    bool? loadingItem,
    bool? loadingEpisodes,
    bool? unlocking,
    Object? error = _unset,
    Object? passwordError = _unset,
    SharePublic? probe,
    String? password,
    Object? item = _unset,
    SharedCollection? collection,
    Object? activeCollectionItemId = _unset,
    int? selectedSeason,
    Object? selectedEpisodeNumber = _unset,
    List<ShareEpisodeView>? episodes,
    bool? opening,
    Object? localResume = _unset,
  }) {
    return ShareUiState(
      loading: loading ?? this.loading,
      loadingItem: loadingItem ?? this.loadingItem,
      loadingEpisodes: loadingEpisodes ?? this.loadingEpisodes,
      unlocking: unlocking ?? this.unlocking,
      error: error == _unset ? this.error : error as String?,
      passwordError: passwordError == _unset
          ? this.passwordError
          : passwordError as String?,
      probe: probe ?? this.probe,
      password: password ?? this.password,
      item: item == _unset ? this.item : item as SharedItem?,
      collection: collection ?? this.collection,
      activeCollectionItemId: activeCollectionItemId == _unset
          ? this.activeCollectionItemId
          : activeCollectionItemId as int?,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      selectedEpisodeNumber: selectedEpisodeNumber == _unset
          ? this.selectedEpisodeNumber
          : selectedEpisodeNumber as int?,
      episodes: episodes ?? this.episodes,
      opening: opening ?? this.opening,
      localResume: localResume == _unset
          ? this.localResume
          : localResume as ShareLocalProgressRecord?,
    );
  }

  static const _unset = Object();
}

class ShareController extends FamilyNotifier<ShareUiState, String> {
  GuestShareApi? _cachedApi;
  String? _cachedOrigin;
  int? _pendingItemId;

  @override
  ShareUiState build(String slug) {
    Future.microtask(probe);
    return const ShareUiState();
  }

  String get effectiveOrigin {
    final explicit = ref.read(shareOriginProvider).trim();
    if (explicit.isNotEmpty) return explicit.replaceAll(RegExp(r'/+$'), '');
    final sessionBase = ref.read(sessionStoreProvider).baseUrl ?? '';
    return ServerRoutes.instance
        .currentOrigin(sessionBase)
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
  }

  GuestShareApi get api {
    final origin = effectiveOrigin;
    if (_cachedApi == null || _cachedOrigin != origin) {
      _cachedOrigin = origin;
      _cachedApi = GuestShareApi(origin);
    }
    return _cachedApi!;
  }

  GuestPlaybackApi get _playback => GuestPlaybackApi(
        effectiveOrigin,
        cookieHeader: api.cookieHeader,
      );

  void setInitialItemId(int? itemId) {
    _pendingItemId = itemId;
  }

  void onPassword(String value) {
    state = state.copyWith(password: value, passwordError: null);
  }

  Future<void> probe() async {
    state = state.copyWith(loading: true, error: null, passwordError: null);
    final slug = arg;
    try {
      final view = await api.sharePublic(slug);
      state = state.copyWith(loading: false, probe: view);
      if (!view.requiresPassword || view.unlocked) {
        await loadContent();
      }
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络不可达，请稍后重试');
    }
  }

  /// 密码解锁：密码错误时保持密码输入卡可见，仅在输入框下方显示红字错误，绝不替换为整页错误页。
  Future<void> unlock() async {
    final password = state.password.trim();
    if (password.isEmpty || state.unlocking) return;
    state = state.copyWith(unlocking: true, passwordError: null);
    try {
      final view = await api.shareUnlock(arg, password);
      state = state.copyWith(
        unlocking: false,
        probe: view,
        password: '',
        passwordError: null,
      );
      await loadContent();
    } on ApiException catch (e) {
      final msg = e.friendlyMessage.isNotEmpty ? e.friendlyMessage : '密码不正确，请重试';
      state = state.copyWith(unlocking: false, passwordError: msg);
    } catch (_) {
      state = state.copyWith(
        unlocking: false,
        passwordError: '网络不可达，请稍后重试',
      );
    }
  }

  Future<void> loadContent() async {
    final probe = state.probe;
    if (probe?.collectionId != null) {
      state = state.copyWith(loading: true, error: null);
      try {
        final c = await api.shareCollection(arg);
        state = state.copyWith(loading: false, collection: c);
        if (_pendingItemId != null) {
          final target = _pendingItemId!;
          _pendingItemId = null;
          await openCollectionItem(target);
        }
      } on ApiException catch (e) {
        state = state.copyWith(loading: false, error: e.friendlyMessage);
      } catch (_) {
        state = state.copyWith(loading: false, error: '无法打开合集分享，请稍后重试');
      }
      return;
    }
    await _loadItem(itemId: _pendingItemId);
    _pendingItemId = null;
  }

  /// 合集分享点击海报进入某一部影片详情（携带 `?item=<mediaItemId>`）。
  Future<void> openCollectionItem(int mediaItemId) async {
    state = state.copyWith(
      activeCollectionItemId: mediaItemId,
      item: null,
      episodes: const [],
      selectedEpisodeNumber: null,
      localResume: null,
      loadingItem: true,
      error: null,
    );
    await _loadItem(itemId: mediaItemId);
  }

  /// 合集分享中从影片详情返回合集海报网格。
  void backToCollection() {
    state = state.copyWith(
      activeCollectionItemId: null,
      item: null,
      episodes: const [],
      selectedEpisodeNumber: null,
      localResume: null,
      loadingItem: false,
      error: null,
    );
  }

  Future<void> _loadItem({int? itemId}) async {
    state = state.copyWith(loadingItem: true, error: null);
    try {
      final item = await api.shareItem(arg, itemId: itemId);
      final ownedSeasons = {for (final f in item.files) f.seasonNumber};
      var initialSeason = 0;
      if (item.seasons.isNotEmpty) {
        initialSeason = item.seasons
                .where((s) => ownedSeasons.contains(s))
                .firstOrNull ??
            item.seasons.first;
      }
      state = state.copyWith(
        loading: false,
        loadingItem: false,
        item: item,
        selectedSeason: initialSeason,
        episodes: const [],
        selectedEpisodeNumber: null,
      );
      if (item.kind == 'tv' && item.seasons.isNotEmpty) {
        await loadEpisodes(initialSeason);
      } else {
        await refreshLocalResume();
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        loading: false,
        loadingItem: false,
        error: e.friendlyMessage,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        loadingItem: false,
        error: '无法打开影片信息，请稍后重试',
      );
    }
  }

  Future<void> selectSeason(int season, {int? preferredEpisode}) async {
    state = state.copyWith(
      selectedSeason: season,
      selectedEpisodeNumber: preferredEpisode,
      episodes: const [],
    );
    await loadEpisodes(season, preferredEpisode: preferredEpisode);
  }

  Future<void> loadEpisodes(int season, {int? preferredEpisode}) async {
    state = state.copyWith(loadingEpisodes: true);
    try {
      final view = await api.shareEpisodes(
        arg,
        seasonNumber: season,
        itemId: state.activeCollectionItemId,
      );
      int? picked = preferredEpisode;
      if (picked == null ||
          !view.episodes.any((e) => e.episodeNumber == picked)) {
        picked = (view.episodes.where((e) => e.owned).firstOrNull ??
                view.episodes.firstOrNull)
            ?.episodeNumber;
      }
      state = state.copyWith(
        loadingEpisodes: false,
        episodes: view.episodes,
        selectedEpisodeNumber: picked,
      );
      await refreshLocalResume();
    } catch (_) {
      state = state.copyWith(loadingEpisodes: false);
    }
  }

  Future<void> selectEpisode(int episodeNumber) async {
    state = state.copyWith(selectedEpisodeNumber: episodeNumber);
    await refreshLocalResume();
  }

  /// 读取当前电影或选中剧集的本机访客续播点（`ShareLocalProgress`）。
  Future<void> refreshLocalResume() async {
    final item = state.item;
    if (item == null) return;
    final season = item.isMovie ? 0 : state.selectedSeason;
    final episode = item.isMovie
        ? 0
        : (state.selectedEpisode?.episodeNumber ?? 0);
    if (!item.isMovie && episode <= 0) {
      state = state.copyWith(localResume: null);
      return;
    }
    final record = await ShareLocalProgress.read(
      slug: arg,
      mediaItemId: item.mediaItemId,
      season: season,
      episode: episode,
    );
    state = state.copyWith(
      localResume: (record != null && record.positionMs > 0) ? record : null,
    );
  }

  /// 访客播放：走 `/api/v1/share/{slug}/playback/sessions` 协商播放会话，
  /// 处理 `consent` / `reject`，合并本机 `ShareLocalProgress` 续播点与轨道偏好，
  /// 并向 `/player` 传递完整访客上下文（含 `shareSlug`、Cookie、季集列表与封面）。
  Future<SharePlayResult> play({
    int? episodeNumber,
    int? startMs,
    bool force = false,
    bool useUniversalEngine = true,
  }) async {
    final item = state.item;
    if (item == null) {
      return const SharePlayResult(errorMessage: '影片尚未加载完成');
    }
    final isTv = !item.isMovie;
    final season = isTv ? state.selectedSeason : 0;
    final epNum = isTv
        ? (episodeNumber ?? state.selectedEpisode?.episodeNumber ?? 0)
        : 0;
    if (isTv && epNum <= 0) {
      return const SharePlayResult(errorMessage: '请先选择要播放的剧集');
    }

    // 读取本机保存的访客进度与轨道偏好
    final local = await ShareLocalProgress.read(
      slug: arg,
      mediaItemId: item.mediaItemId,
      season: season,
      episode: epNum,
    );
    final effectiveStartMs = startMs ?? local?.positionMs;

    // 匹配对应的在位文件 ID
    final matchingFiles = isTv
        ? item.files
            .where(
              (f) =>
                  f.isPlayable &&
                  f.seasonNumber == season &&
                  f.episodeNumber == epNum,
            )
            .toList()
        : item.files.where((f) => f.isPlayable).toList();
    final fileId = matchingFiles.isNotEmpty ? matchingFiles.first.id : null;

    state = state.copyWith(opening: true);
    try {
      final session = await _playback.start(
        slug: arg,
        mediaItemId: item.mediaItemId,
        fileId: fileId,
        seasonNumber: isTv ? season : null,
        episodeNumber: isTv ? epNum : null,
        startMs: effectiveStartMs,
        audioTrack: local?.audioTrack,
        subtitleTrack: local?.subtitleTrack,
        force: force,
        useUniversalEngine: useUniversalEngine,
      );

      if (session.needsConsent) {
        state = state.copyWith(opening: false);
        return SharePlayResult(
          consentMessage: session.decisionMessage?.isNotEmpty == true
              ? session.decisionMessage!
              : '当前设备播放此视频需要服务器实时转码，是否继续？',
        );
      }
      if (session.rejected) {
        state = state.copyWith(opening: false);
        return SharePlayResult(
          errorMessage: session.decisionMessage?.isNotEmpty == true
              ? session.decisionMessage!
              : '服务端拒绝了此次访客播放请求',
        );
      }

      var streamUrl = session.streamUrl ?? '';
      if (streamUrl.isEmpty) {
        state = state.copyWith(opening: false);
        return const SharePlayResult(errorMessage: '无法获取播放流，请稍后重试');
      }
      if (streamUrl.startsWith('/')) {
        streamUrl = '$effectiveOrigin$streamUrl';
      }

      final epObj = isTv
          ? state.episodes
              .where((e) => e.episodeNumber == epNum)
              .firstOrNull
          : null;
      final epSubtitle = isTv
          ? (epObj?.name != null && epObj!.name!.isNotEmpty
              ? '第 $season 季 第 $epNum 集 · ${epObj.name}'
              : '第 $season 季 第 $epNum 集')
          : null;

      final resumePositionMs = effectiveStartMs ??
          (session.startMs > 0 ? session.startMs : null);
      final ck = api.cookieHeader;
      final playerEpisodes = [
        for (final ep in state.episodes)
          EpisodeItem(
            season: season,
            episode: ep.episodeNumber,
            name: ep.name ?? '第 ${ep.episodeNumber} 集',
            fileId: ep.fileIds.isNotEmpty
                ? ep.fileIds.first
                : item.files
                    .where(
                      (f) =>
                          f.isPlayable &&
                          f.seasonNumber == season &&
                          f.episodeNumber == ep.episodeNumber,
                    )
                    .firstOrNull
                    ?.id,
            owned: ep.owned,
            stillUrl: api.imageUrl(ep.stillUrl, widthPx: 480),
            overview: ep.overview,
            played: ep.played,
          ),
      ];

      state = state.copyWith(opening: false);
      return SharePlayResult(
        args: PlayerPageArgs(
          url: streamUrl,
          mediaItemId: item.mediaItemId,
          fileId: session.fileId ?? fileId,
          seasonNumber: isTv ? season : null,
          episodeNumber: isTv ? epNum : null,
          title: item.title,
          subtitle: epSubtitle,
          seriesTitle: isTv ? item.title : null,
          episodeSubtitle: epSubtitle,
          startPosition: resumePositionMs != null && resumePositionMs > 0
              ? Duration(milliseconds: resumePositionMs)
              : null,
          headers: {
            if (ck != null && ck.isNotEmpty) 'Cookie': ck,
          },
          isEpisode: isTv,
          seasons: item.seasons,
          episodes: playerEpisodes,
          shareSlug: arg,
          artworkUrl: api.imageUrl(
            epObj?.stillUrl ?? item.backdropUrl ?? item.posterUrl,
            widthPx: 960,
          ),
        ),
      );
    } on ApiException catch (e) {
      state = state.copyWith(opening: false);
      return SharePlayResult(errorMessage: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(opening: false);
      return const SharePlayResult(errorMessage: '无法开始访客播放，请稍后重试');
    }
  }
}

/// 分享深链的来源服务器（由 routes.dart 从查询参数 / 深链解析注入）。
final shareOriginProvider = StateProvider<String>((ref) => '');

final shareControllerFamily =
    NotifierProvider.family<ShareController, ShareUiState, String>(
  ShareController.new,
);
