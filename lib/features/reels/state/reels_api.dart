import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/network/server_routes.dart';
import 'models.dart';

class ReelsApi {
  ReelsApi(this._client);

  final McClient _client;
  static const _prefix = '/api/v1';

  Map<String, dynamic> _filterQuery(ReelFilter f) => {
        if (f.kind != null) 'kind': f.kind,
        if (f.genresQuery != null) 'g': f.genresQuery,
        if (f.countriesQuery != null) 'c': f.countriesQuery,
        if (f.decadesQuery != null) 'd': f.decadesQuery,
        if (f.ratingGte != null) 'rating_gte': f.ratingGte,
        if (f.runtimesQuery != null) 'rt': f.runtimesQuery,
        if (f.watch != null) 'w': f.watch,
      };

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
    return ReelFeedView.fromJson(
      (data as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<ReelFacetsView> facets({ReelFilter filter = const ReelFilter()}) async {
    final data = await _client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/reels/facets',
      query: _filterQuery(filter),
    );
    return ReelFacetsView.fromJson(
      (data as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> reportEvents(List<ReelEventView> events) async {
    if (events.isEmpty) return;
    await _client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/reels/events',
      body: {'events': events.map((e) => e.toJson()).toList()},
    );
  }

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

  /// 创建真实访客分享链接：`POST /api/v1/libraries/{libraryId}/items/{id}/share`
  Future<ReelShareResult> createShareLink({
    required int libraryId,
    required int mediaItemId,
    int expiresInDays = 7,
  }) async {
    final data = await _client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$libraryId/items/$mediaItemId/share',
      body: {'expires_in_days': expiresInDays},
    );
    return ReelShareResult.fromJson(
      (data as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// 拉取片段外挂字幕文本（支持相对路径自动拼接当前路由地址）。
  Future<String?> fetchSnippetSubtitles(String rawUrl) async {
    var full = rawUrl.trim();
    if (full.isEmpty) return null;
    if (full.startsWith('/')) {
      final origin = ServerRoutes.instance.currentOrigin(_client.baseUrl);
      if (origin.isNotEmpty) full = '$origin$full';
    }
    try {
      final resp = await Dio().get<String>(
        full,
        options: Options(
          headers: mcImageHeaders(),
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      if ((resp.statusCode ?? 0) >= 200 && (resp.statusCode ?? 0) < 300) {
        return resp.data;
      }
    } catch (_) {}
    return null;
  }
}

final reelsApiProvider = Provider<ReelsApi>((ref) {
  final session = ref.watch(sessionStoreProvider);
  return ReelsApi(McClient(session: session));
});
