import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/guest_playback_api.dart';
import '../../../core/player/player_page_args.dart';
import 'mc_api.dart';
import 'models.dart';

/// 访客分享页状态机（对齐 Kotlin ShareViewModel.UiState）：
/// 探测 /share/{slug} →（可能要密码）→ 条目 / 合集 → 访客播放意图。
class ShareUiState {
  const ShareUiState({
    this.loading = true,
    this.error,
    this.probe,
    this.password = '',
    this.item,
    this.collection,
    this.selectedSeason = 0,
    this.episodes = const [],
    this.opening = false,
  });

  final bool loading;
  final String? error;
  final SharePublic? probe;
  final String password;
  final SharedItem? item;
  final SharedCollection? collection;
  final int selectedSeason;
  final List<ShareEpisodeView> episodes;
  final bool opening;

  bool get needsPassword => (probe?.requiresPassword ?? false) && !(probe?.unlocked ?? false);

  ShareUiState copyWith({
    bool? loading,
    Object? error = _unset,
    SharePublic? probe,
    String? password,
    SharedItem? item,
    SharedCollection? collection,
    int? selectedSeason,
    List<ShareEpisodeView>? episodes,
    bool? opening,
  }) {
    return ShareUiState(
      loading: loading ?? this.loading,
      error: error == _unset ? this.error : error as String?,
      probe: probe ?? this.probe,
      password: password ?? this.password,
      item: item ?? this.item,
      collection: collection ?? this.collection,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      episodes: episodes ?? this.episodes,
      opening: opening ?? this.opening,
    );
  }

  static const _unset = Object();
}

class ShareController extends FamilyNotifier<ShareUiState, String> {
  @override
  ShareUiState build(String slug) {
    // arg 不能在 build 内同步访问：探针挪到微任务里（首个状态固定为 loading）。
    Future.microtask(probe);
    return const ShareUiState();
  }

  GuestShareApi get _api => GuestShareApi(ref.read(shareOriginProvider));

  GuestPlaybackApi get _playback => GuestPlaybackApi(ref.read(shareOriginProvider));

  void onPassword(String value) {
    state = state.copyWith(password: value);
  }

  Future<void> probe() async {
    state = state.copyWith(loading: true, error: null);
    final slug = arg;
    try {
      final view = await _api.sharePublic(slug);
      state = state.copyWith(loading: false, probe: view);
      if (!view.requiresPassword || view.unlocked) await loadContent();
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络不可达，请稍后重试');
    }
  }

  Future<void> unlock() async {
    final password = state.password;
    if (password.isEmpty) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final view = await _api.shareUnlock(arg, password);
      state = state.copyWith(loading: false, probe: view, password: '');
      await loadContent();
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: '密码不正确或分享已失效：${e.friendlyMessage}');
    } catch (_) {
      state = state.copyWith(loading: false, error: '密码不正确或分享已失效');
    }
  }

  Future<void> loadContent() async {
    final probe = state.probe;
    if (probe?.collectionId != null) {
      try {
        final c = await _api.shareCollection(arg);
        state = state.copyWith(loading: false, collection: c);
      } on ApiException catch (e) {
        state = state.copyWith(loading: false, error: e.friendlyMessage);
      }
      return;
    }
    try {
      final item = await _api.shareItem(arg);
      final season = item.seasons.isNotEmpty ? item.seasons.first : 0;
      state = state.copyWith(loading: false, item: item, selectedSeason: season);
      if (item.kind == 'tv' && item.seasons.isNotEmpty) await loadEpisodes(season);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    }
  }

  Future<void> selectSeason(int season) async {
    state = state.copyWith(selectedSeason: season);
    await loadEpisodes(season);
  }

  Future<void> loadEpisodes(int season) async {
    try {
      final view = await _api.shareEpisodes(arg, season);
      state = state.copyWith(episodes: view.episodes);
    } catch (_) {
      // 分集拉取失败不打断主流程，季切换时会重试。
    }
  }

  /// 访客播放：player 模块外只做导航意图（铁律 4）。经访客播放接口
  /// POST /api/v1/share/{slug}/playback/sessions（对齐 Kotlin McApi.sharePlaybackSessionStart）
  /// 换取直连流地址，返回 PlayerPageArgs 交由页面跳 /player；失败置 error 返回 null。
  /// 续播点用服务端 startMs（访客进度记本机、不写成员进度）。
  Future<PlayerPageArgs?> play(int episodeNumber) async {
    final item = state.item;
    if (item == null) return null;
    final isTv = item.kind == 'tv';
    final season = state.selectedSeason;
    state = state.copyWith(opening: true, error: null);
    try {
      final session = await _playback.start(
        slug: arg,
        mediaItemId: item.mediaItemId,
        seasonNumber: isTv ? season : null,
        episodeNumber: isTv ? episodeNumber : null,
      );
      var streamUrl = session.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        state = state.copyWith(opening: false, error: '无法获取播放流，请稍后重试');
        return null;
      }
      // 服务器可能回相对路径，拼分享通道基址。
      if (streamUrl.startsWith('/')) {
        streamUrl = ref.read(shareOriginProvider) + streamUrl;
      }
      final subtitle = isTv ? '第 $season 季 第 $episodeNumber 集' : null;
      state = state.copyWith(opening: false);
      return PlayerPageArgs(
        url: streamUrl,
        title: item.title,
        subtitle: subtitle,
        seasonNumber: isTv ? season : null,
        episodeNumber: isTv ? episodeNumber : null,
        isEpisode: isTv,
        startPosition:
            session.startMs > 0 ? Duration(milliseconds: session.startMs) : null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(opening: false, error: e.friendlyMessage);
      return null;
    } catch (_) {
      state = state.copyWith(opening: false, error: '无法开始访客播放，请稍后重试');
      return null;
    }
  }
}

/// 分享深链的来源服务器（由 routes.dart 从查询参数 / 深链解析注入）。
final shareOriginProvider = StateProvider<String>((ref) => '');

final shareControllerFamily = NotifierProvider.family<ShareController, ShareUiState, String>(
  ShareController.new,
);
