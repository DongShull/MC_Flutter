import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import 'models.dart';

class ReelsApi {
  ReelsApi(this._client);

  final McClient _client;
  static const _prefix = '/api/v1';

  Map<String, dynamic> _filterQuery(ReelFilter f) => {
        if (f.kind != null) 'kind': f.kind,
        if (f.genres != null) 'g': f.genres,
        if (f.countries != null) 'c': f.countries,
        if (f.decades != null) 'd': f.decades,
        if (f.ratingGte != null) 'rating_gte': f.ratingGte,
        if (f.runtimes != null) 'rt': f.runtimes,
        if (f.watch != null) 'w': f.watch,
      };

  /// 取一页片段。第一页不带 seed，服务端生成后随响应返回；翻页时原样带回。
  Future<ReelFeedView> feed({
    int? seed,
    required int offset,
    required int limit,
    ReelFilter filter = const ReelFilter(),
  }) async {
    final data = await _client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/reels',
      query: {
        if (seed != null) 'seed': seed,
        'offset': offset,
        'limit': limit,
        'modes': 'seek,clip',
        ..._filterQuery(filter),
      },
    );
    return ReelFeedView.fromJson((data as Map<String, dynamic>?) ?? const {});
  }

  /// 刷片筛选菜单的候选值与计数（与 /reels 同一组参数；为 0 的档 UI 置灰）
  Future<ReelFacetsView> facets({ReelFilter filter = const ReelFilter()}) async {
    final data = await _client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/reels/facets',
      query: _filterQuery(filter),
    );
    return ReelFacetsView.fromJson((data as Map<String, dynamic>?) ?? const {});
  }

  /// 刷片事件批量上报（只落 reel_event 表；失败即丢）
  Future<void> reportEvents(List<ReelEventView> events) async {
    await _client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/reels/events',
      body: {'events': events.map((e) => e.toJson()).toList()},
    );
  }

  /// 标记已看 / 收藏（与详情页同一套 marks 接口）。
  /// 收藏落在整部；已看剧集记这一集、电影记整部。只传要改的那一项。
  Future<void> setMarks({
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    bool? played,
    bool? favorite,
  }) async {
    await _client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/playback/marks',
      body: {
        'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        if (played != null) 'played': played,
        if (favorite != null) 'favorite': favorite,
      },
    );
  }
}

final reelsApiProvider = Provider<ReelsApi>((ref) {
  final session = ref.watch(sessionStoreProvider);
  return ReelsApi(McClient(session: session));
});
