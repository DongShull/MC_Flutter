import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 媒体库域 API 单例。
final libraryApiProvider =
    Provider<LibraryApi>((ref) => LibraryApi(ref.watch(sessionStoreProvider)));

/// 媒体库域的 API 封装：统一走 McClient（Channel.general），信封解包后转成
/// 本域模型（浏览、图廊、照片墙、合集 CRUD/系列/排序/分享、库管理 CRUD/封面/路由/刮削覆盖、
/// 整理预览与执行、重复文件、待处理抽屉、回收站、活跃分享、影人详情）。
class LibraryApi {
  LibraryApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /* ── 媒体库列表与单库详情 ── */

  /// GET /libraries?scope=all → LibraryView[]
  Future<List<LibraryView>> libraries({
    String? kind,
    String scope = 'all',
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries',
      query: {
        if (kind != null) 'kind': kind,
        if (scope.isNotEmpty) 'scope': scope,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/{id} → LibraryView
  Future<LibraryView> libraryGet(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id',
    );
    return LibraryView.fromJson(body);
  }

  /// GET /libraries/{id}/items/{mediaItemId} → 原始明细（供照片灯箱 EXIF 面板按需拉取）
  Future<Map<String, dynamic>> libraryItemDetail(
    int libraryId,
    int mediaItemId,
  ) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/libraries/$libraryId/items/$mediaItemId',
      );

  /* ── 合集 CRUD / 系列 / 排序 / 分享 / 图廊 ── */

  /// GET /collections → CollectionView[]
  Future<List<CollectionView>> collections({
    int? libraryId,
    bool includeEmpty = false,
    bool includeHidden = false,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/collections',
      query: {
        if (libraryId != null) 'library_id': libraryId,
        if (includeEmpty) 'include_empty': true,
        if (includeHidden) 'include_hidden': true,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => CollectionView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /collections/{id}
  Future<CollectionView> collection(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/collections/$id',
    );
    return CollectionView.fromJson(body);
  }

  /// POST /collections（新建普通合集、动态规则合集或定格快照合集）
  Future<CollectionView> createCollection({
    required String name,
    int? libraryId,
    Object? rules,
    String sort = 'added_at',
    String visibility = 'household',
    List<int>? itemIds,
    bool snapshot = false,
  }) async {
    final hasRules =
        (rules is List && rules.isNotEmpty) || (rules is Map && rules.isNotEmpty);
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/collections',
      body: {
        'name': name,
        if (libraryId != null) 'library_id': libraryId,
        if (hasRules) 'rules': rules,
        'sort': sort,
        'visibility': visibility,
        if (itemIds != null) 'item_ids': itemIds,
        if (snapshot) 'snapshot': true,
      },
    );
    return CollectionView.fromJson(body);
  }

  /// PUT /collections/{id}
  Future<CollectionView> updateCollection(
    int id, {
    String? name,
    String? sort,
    String? visibility,
    bool? hidden,
    List<Map<String, dynamic>>? rules,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '$_prefix/collections/$id',
      body: {
        if (name != null) 'name': name,
        if (sort != null) 'sort': sort,
        if (visibility != null) 'visibility': visibility,
        if (hidden != null) 'hidden': hidden,
        if (rules != null) 'rules': rules,
      },
    );
    return CollectionView.fromJson(body);
  }

  /// PUT /collections/{id}（直接传原始 body 改规则/字段）
  Future<CollectionView> updateCollectionRules(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '$_prefix/collections/$id',
      body: payload,
    );
    return CollectionView.fromJson(body);
  }

  /// DELETE /collections/{id}
  Future<void> deleteCollection(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/collections/$id',
    );
  }

  /// POST /collections/{id}/items
  Future<void> addCollectionItems(int id, List<int> mediaItemIds) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/collections/$id/items',
      body: {'media_item_ids': mediaItemIds},
    );
  }

  /// DELETE /collections/{id}/items/{mediaItemId}
  Future<void> removeCollectionItem(int id, int mediaItemId) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/collections/$id/items/$mediaItemId',
    );
  }

  /// PUT /collections/{id}/order
  Future<CollectionView> updateCollectionOrder(
    int id,
    List<int> mediaItemIds,
  ) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '$_prefix/collections/$id/order',
      body: {'media_item_ids': mediaItemIds},
    );
    return CollectionView.fromJson(body);
  }

  /// GET /collections/{id}/items
  Future<List<LibraryItemView>> collectionItems(
    int id, {
    int limit = 60,
    int offset = 0,
    String? sort,
    String? order,
    String? badges,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/collections/$id/items',
      query: {
        'limit': limit,
        'offset': offset,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (badges != null && badges.isNotEmpty) 'badges': badges,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /collections/{id}/gallery
  Future<List<LibraryGalleryGroupView>> collectionGallery(
    int id, {
    int limit = 24,
    int offset = 0,
    String? sort,
    String? order,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/collections/$id/gallery',
      query: {
        'limit': limit,
        'offset': offset,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryGalleryGroupView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /collections/{id}/series
  Future<CollectionSeriesView> collectionSeries(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/collections/$id/series',
    );
    return CollectionSeriesView.fromJson(body);
  }

  /// GET /collections/{id}/share
  Future<LibraryShareView?> collectionShareGet(int id) async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/collections/$id/share',
    );
    if (body is Map) {
      return LibraryShareView.fromJson(Map<String, dynamic>.from(body));
    }
    return null;
  }

  /// POST /collections/{id}/share
  Future<LibraryShareView> collectionShareCreate(
    int id, {
    int expiresInDays = 7,
    String? password,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/collections/$id/share',
      body: {
        'expires_in_days': expiresInDays,
        if (password != null && password.trim().isNotEmpty)
          'password': password.trim(),
      },
    );
    return LibraryShareView.fromJson(body);
  }

  /// DELETE /collections/{id}/share
  Future<void> collectionShareRevoke(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/collections/$id/share',
    );
  }

  /* ── 播放标记 / 接下来继续 / 收藏 ── */

  /// POST /playback/marks（快捷收藏 / 标为已看）
  Future<void> setItemMark(
    int mediaItemId, {
    bool? favorite,
    bool? played,
  }) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/playback/marks',
      body: {
        'media_item_id': mediaItemId,
        if (favorite != null) 'favorite': favorite,
        if (played != null) 'played': played,
      },
    );
  }

  /// GET /playback/up-next
  Future<List<UpNextItem>> upNext({int limit = 20}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/up-next',
      query: {'limit': limit},
    );
    return _listField(body['items'], UpNextItem.fromJson);
  }

  /// GET /playback/favorites → items + total
  Future<FavoritesResult> favorites({
    int limit = 20,
    int offset = 0,
    bool unwatchedFirst = false,
    String? sort,
    String? order,
    String? badges,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/favorites',
      query: {
        'limit': limit,
        'offset': offset,
        if (unwatchedFirst) 'unwatched_first': true,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (badges != null && badges.isNotEmpty) 'badges': badges,
      },
    );
    final items = _listField(body['items'], LibraryItemView.fromJson);
    final total = body['total'];
    return FavoritesResult(
      items: items,
      total: total is num ? total.toInt() : items.length,
    );
  }

  /// GET /playback/favorites/gallery
  Future<List<LibraryGalleryGroupView>> favoritesGallery({
    int limit = 24,
    int offset = 0,
    String? sort,
    String? order,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/favorites/gallery',
      query: {
        'limit': limit,
        'offset': offset,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryGalleryGroupView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// DELETE /playback/history
  Future<int> clearPlaybackHistory({
    required String scope,
    DateTime? since,
    int? libraryId,
  }) async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/playback/history',
      query: {
        'scope': scope,
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (libraryId != null) 'library_id': libraryId,
      },
    );
    final deleted = body is Map ? body['deleted_states'] : null;
    return deleted is num ? deleted.toInt() : 0;
  }

  /// GET /auth/me → role（admin / member）
  Future<String> currentRole() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/auth/me',
    );
    final user = body['user'];
    final role = body['role'] ?? (user is Map ? user['role'] : null);
    return role?.toString() ?? '';
  }

  /* ── 单库墙 / 分面 / 放宽建议 / 索引 / 图廊 / 临时身份 ── */

  /// GET /libraries/{id}/items
  Future<List<LibraryItemView>> libraryItems(
    int id, {
    int limit = 60,
    int offset = 0,
    String? identity,
    String? badges,
    Map<String, String?> filterQuery = const {},
  }) async {
    final q = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (identity != null) 'identity': identity,
      if (badges != null && badges.isNotEmpty) 'badges': badges,
      for (final e in filterQuery.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value,
    };
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/items',
      query: q,
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/{id}/items?identity=provisional
  Future<List<LibraryItemView>> libraryItemsProvisional(
    int id, {
    int limit = 200,
  }) =>
      libraryItems(
        id,
        limit: limit,
        identity: 'provisional',
        filterQuery: const {'sort': 'added_at'},
      );

  /// GET /libraries/{id}/facets?tier=all
  Future<LibraryFacets> libraryFacets(
    int id, {
    bool allTiers = true,
    Map<String, String?> filterQuery = const {},
  }) async {
    final q = <String, dynamic>{
      if (allTiers) 'tier': 'all',
      for (final e in filterQuery.entries)
        if (e.value != null &&
            e.value!.isNotEmpty &&
            e.key != 'sort' &&
            e.key != 'order')
          e.key: e.value,
    };
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/facets',
      query: q,
    );
    return LibraryFacets.fromJson(body);
  }

  /// GET /libraries/{id}/relax
  Future<LibraryRelaxView> libraryRelax(
    int id,
    Map<String, dynamic> params,
  ) async {
    final q = <String, dynamic>{
      for (final e in params.entries)
        if (e.value != null &&
            e.value.toString().isNotEmpty &&
            e.key != 'sort' &&
            e.key != 'order')
          e.key: e.value,
    };
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/relax',
      query: q,
    );
    return LibraryRelaxView.fromJson(body);
  }

  /// GET /libraries/{id}/item-index
  Future<List<LibraryIndexEntry>> libraryItemIndex(
    int id, {
    String? granularity,
    Map<String, String?> filterQuery = const {},
  }) async {
    final q = <String, dynamic>{
      for (final e in filterQuery.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value,
      'sort': filterQuery['sort'] ?? 'title',
      if (granularity != null) 'granularity': granularity,
    };
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/item-index',
      query: q,
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryIndexEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/{id}/gallery
  Future<List<LibraryGalleryGroupView>> libraryGallery(
    int id, {
    int limit = 24,
    int offset = 0,
    Map<String, String?> filterQuery = const {},
  }) async {
    final q = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      for (final e in filterQuery.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value,
    };
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/gallery',
      query: q,
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryGalleryGroupView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /* ── 跨库类型墙 ── */

  /// GET /libraries/kinds/{kind}
  Future<LibraryKindSummaryView> libraryKindSummary(
    String kind, {
    String? genres,
    String? watch,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/kinds/$kind',
      query: {
        if (genres != null && genres.isNotEmpty) 'g': genres,
        if (watch != null && watch.isNotEmpty) 'w': watch,
      },
    );
    return LibraryKindSummaryView.fromJson(body);
  }

  /// GET /libraries/kinds/{kind}/items
  Future<List<LibraryItemView>> libraryKindItems(
    String kind, {
    int limit = 60,
    int offset = 0,
    String? sort,
    String? order,
    String? watch,
    String? genres,
    String? badges,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/kinds/$kind/items',
      query: {
        'limit': limit,
        'offset': offset,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (watch != null && watch.isNotEmpty) 'w': watch,
        if (genres != null && genres.isNotEmpty) 'g': genres,
        if (badges != null && badges.isNotEmpty) 'badges': badges,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/kinds/{kind}/genres（原始列表）
  Future<List<Map<String, dynamic>>> libraryKindGenres(String kind) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/kinds/$kind/genres',
    );
    return body.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// GET /libraries/kinds/{kind}/genres（强类型）
  Future<List<LibraryKindGenreView>> libraryKindGenresTyped(String kind) async {
    final rows = await libraryKindGenres(kind);
    return rows.map(LibraryKindGenreView.fromJson).toList();
  }

  /* ── 界面偏好 / 影人详情 / 人物搜索 ── */

  /// GET /ui/preferences
  Future<Map<String, dynamic>> uiPreferences() =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/ui/preferences',
      );

  /// PUT /ui/preferences
  Future<void> updateUiPreferences(Map<String, dynamic> body) =>
      client.unwrap<dynamic>(
        Channel.general,
        'PUT',
        '$_prefix/ui/preferences',
        body: body,
      );

  /// GET /people/{tmdbPersonId}
  Future<PersonView> personDetail(int tmdbPersonId) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/people/$tmdbPersonId',
    );
    return PersonView.fromJson(body);
  }

  /// GET /search/library（人物下钻兜底：person_id）
  Future<LibrarySearchView> searchLibraryByPerson(
    int personId, {
    int limit = 60,
    String? cursor,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/search/library',
      query: {
        'person_id': personId,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return LibrarySearchView.fromJson(body);
  }

  /* ── 服务端目录浏览 / 媒体库 CRUD / 路由选项 / 封面 / 刮削配置 ── */

  /// GET /fs/browse
  Future<Map<String, dynamic>> browseServerFs({String? path}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/fs/browse',
        query: {if (path != null && path.isNotEmpty) 'path': path},
      );

  /// GET /libraries/routing-options
  Future<RoutingOptionsView> libraryRoutingOptions() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/routing-options',
    );
    return RoutingOptionsView.fromJson(body);
  }

  /// GET /members
  Future<List<MemberOptionView>> membersList() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/members',
    );
    return body
        .whereType<Map>()
        .map((m) => MemberOptionView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /scrape/config
  Future<Map<String, dynamic>> scrapeConfig() =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/scrape/config',
      );

  /// GET /jobs?active_only=true&limit=100
  Future<List<Map<String, dynamic>>> activeJobs() async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/jobs',
      query: const {'active_only': true, 'limit': 100},
    );
    final list = body is List
        ? body
        : (body is Map ? (body['items'] as List<dynamic>? ?? const []) : const []);
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// POST /libraries
  Future<LibraryView> createLibrary({
    required String name,
    required String kind,
    required List<String> paths,
    bool isDefault = false,
    bool excludeFromHome = false,
    bool generateThumbnails = true,
    bool extractChapterImages = true,
    bool autoSeriesCollections = true,
    bool autoClearMissing = false,
    bool realtimeWatch = true,
    String accessMode = 'everyone',
    bool adminVisible = true,
    List<int> memberIds = const [],
    List<Map<String, dynamic>> matchRules = const [],
    Map<String, dynamic> scrapeOverrides = const {},
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/libraries',
      body: {
        'name': name,
        'kind': kind,
        'paths': paths,
        'root_paths': paths,
        'is_default': isDefault,
        'exclude_from_home': excludeFromHome,
        'generate_thumbnails': generateThumbnails,
        'extract_chapter_images': extractChapterImages,
        'auto_series_collections': autoSeriesCollections,
        'auto_clear_missing': autoClearMissing,
        'realtime_watch': realtimeWatch,
        'access_mode': accessMode,
        'admin_visible': adminVisible,
        'member_ids': accessMode == 'selected' ? memberIds : const <int>[],
        'match_rules': matchRules,
        'scrape_overrides': scrapeOverrides,
      },
    );
    return LibraryView.fromJson(body);
  }

  /// PUT /libraries/{id}
  Future<LibraryView> updateLibrary(
    int id, {
    required String name,
    required List<String> paths,
    String? kind,
    bool? isDefault,
    bool? excludeFromHome,
    bool? generateThumbnails,
    bool? extractChapterImages,
    bool? autoSeriesCollections,
    bool? autoClearMissing,
    bool? realtimeWatch,
    String? accessMode,
    bool? adminVisible,
    List<int>? memberIds,
    List<Map<String, dynamic>>? matchRules,
    Map<String, dynamic>? scrapeOverrides,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '$_prefix/libraries/$id',
      body: {
        'name': name,
        if (kind != null) 'kind': kind,
        'paths': paths,
        'root_paths': paths,
        if (isDefault != null) 'is_default': isDefault,
        if (excludeFromHome != null) 'exclude_from_home': excludeFromHome,
        if (generateThumbnails != null)
          'generate_thumbnails': generateThumbnails,
        if (extractChapterImages != null)
          'extract_chapter_images': extractChapterImages,
        if (autoSeriesCollections != null)
          'auto_series_collections': autoSeriesCollections,
        if (autoClearMissing != null) 'auto_clear_missing': autoClearMissing,
        if (realtimeWatch != null) 'realtime_watch': realtimeWatch,
        if (accessMode != null) 'access_mode': accessMode,
        if (adminVisible != null) 'admin_visible': adminVisible,
        if (memberIds != null) 'member_ids': memberIds,
        if (matchRules != null) 'match_rules': matchRules,
        if (scrapeOverrides != null) 'scrape_overrides': scrapeOverrides,
      },
    );
    return LibraryView.fromJson(body);
  }

  /// POST /libraries/{id}/cover（multipart file 上传，与 upstream APIClient.upload 100% 一致）
  Future<void> uploadLibraryCover(int id, String filePath) async {
    await client.postMultipart<dynamic>(
      Channel.general,
      '$_prefix/libraries/$id/cover',
      fileField: 'file',
      filePath: filePath,
      fileName: 'cover.jpg',
      contentType: 'image/jpeg',
    );
  }

  /// DELETE /libraries/{id}/cover
  Future<void> deleteLibraryCover(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/libraries/$id/cover',
    );
  }

  /// POST /libraries/{id}/default-selection
  Future<LibraryView> setDefaultLibrary(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/default-selection',
    );
    return LibraryView.fromJson(body);
  }

  /// DELETE /libraries/{id}
  Future<void> deleteLibrary(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/libraries/$id',
    );
  }

  /// PUT /libraries/display-order
  Future<void> reorderLibraries(List<int> orderedIds) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'PUT',
      '$_prefix/libraries/display-order',
      body: {'ordered_ids': orderedIds},
    );
  }

  /* ── 扫描 / 元数据刷新 / 章节图 / 整理文件名 ── */

  /// POST /libraries/{id}/scan
  Future<void> scanLibrary(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/scan',
    );
  }

  /// POST /libraries/{id}/scan/stop
  Future<void> stopLibraryScan(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/scan/stop',
    );
  }

  /// POST /libraries/{id}/metadata/refresh?mode=$mode
  Future<void> libraryMetadataRefresh(int id, {String mode = 'all'}) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/metadata/refresh',
      query: {if (mode.isNotEmpty) 'mode': mode},
    );
  }

  /// 兼容旧名。
  Future<void> refreshLibraryMetadata(int id) => libraryMetadataRefresh(id);

  /// GET /libraries/{id}/metadata/refresh/progress
  Future<MetadataRefresh> metadataRefreshProgress(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/metadata/refresh/progress',
    );
    return MetadataRefresh.maybe(body) ?? const MetadataRefresh();
  }

  /// POST /libraries/{id}/metadata/refresh/stop
  Future<void> metadataRefreshStop(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/metadata/refresh/stop',
    );
  }

  /// POST /libraries/{id}/chapter-images?force=$force
  Future<void> generateChapterImages(int id, {bool force = false}) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/chapter-images',
      query: {'force': force},
    );
  }

  /// POST /libraries/{id}/file-organization-preview
  Future<OrganizePreviewView> organizePreview(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/file-organization-preview',
    );
    return OrganizePreviewView.fromJson(body);
  }

  /// POST /libraries/{id}/file-organizations
  Future<void> organizeLibrary(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/file-organizations',
      body: const {},
    );
  }

  /* ── 重复文件（/libraries/duplicate-files） ── */

  /// GET /libraries/duplicate-files
  Future<DuplicateFilesData> duplicateFiles({
    String? tier,
    String? reviewKind,
    String? q,
    int? libraryId,
    int? mediaItemId,
    int limit = 20,
    int offset = 0,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/duplicate-files',
      query: {
        if (tier != null) 'tier': tier,
        if (reviewKind != null) 'review_kind': reviewKind,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (libraryId != null) 'library_id': libraryId,
        if (mediaItemId != null) 'media_item_id': mediaItemId,
        'limit': limit,
        'offset': offset,
      },
    );
    return DuplicateFilesData.fromJson(body);
  }

  /// POST /libraries/duplicate-files/scan
  Future<Map<String, dynamic>> scanDuplicateFiles() async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/duplicate-files/scan',
    );
    return body is Map ? Map<String, dynamic>.from(body) : const {};
  }

  /// POST /libraries/duplicate-files/resolve
  Future<TrashedBatchResultView> resolveDuplicateFiles({
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    int? keepFileId,
    String? keepVersion,
    bool? keepAll,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/libraries/duplicate-files/resolve',
      body: {
        'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        if (keepFileId != null) 'keep_file_id': keepFileId,
        if (keepVersion != null) 'keep_version': keepVersion,
        if (keepAll != null) 'keep_all': keepAll,
      },
    );
    return TrashedBatchResultView.fromJson(body);
  }

  /// POST /libraries/duplicate-files/resolve-all
  Future<TrashedBatchResultView> resolveAllDuplicateFiles({
    required String tier,
    String? reviewKind,
    int? libraryId,
    bool? keepAll,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/libraries/duplicate-files/resolve-all',
      body: {
        'tier': tier,
        if (reviewKind != null) 'review_kind': reviewKind,
        if (libraryId != null) 'library_id': libraryId,
        if (keepAll != null) 'keep_all': keepAll,
      },
    );
    return TrashedBatchResultView.fromJson(body);
  }

  /* ── 待处理抽屉（缺失 / 待识别 / 身份复核 / 已忽略） ── */

  /// 按 tab 路由拉取待处理列表（missing / unidentified / review / ignored）。
  Future<List<Map<String, dynamic>>> libraryIssues(
    String tab, {
    int? libraryId,
  }) async {
    final path = switch (tab) {
      'missing' => '$_prefix/libraries/${libraryId ?? 0}/missing',
      'review' => '$_prefix/libraries/identification/review-cases',
      'ignored' => '$_prefix/libraries/identification/ignored-files',
      _ => '$_prefix/libraries/identification/unidentified-files',
    };
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      path,
      query: {
        if (tab != 'missing' && libraryId != null) 'library_id': libraryId,
      },
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['items'] ?? raw['files'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// GET /libraries/{id}/missing
  Future<List<MissingItemView>> missingItems(int libraryId) async {
    final rows = await libraryIssues('missing', libraryId: libraryId);
    return rows.map(MissingItemView.fromJson).toList();
  }

  /// POST /libraries/missing-redownloads
  Future<int> redownloadMissing({
    required int libraryId,
    required int mediaItemId,
  }) async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/missing-redownloads',
      body: {
        'library_id': libraryId,
        'media_item_id': mediaItemId,
      },
    );
    final requeued = body is Map ? body['requeued'] : null;
    return requeued is num ? requeued.toInt() : 0;
  }

  /// POST /libraries/missing-record-clearances
  Future<void> clearMissingRecords({
    required int libraryId,
    int? mediaItemId,
  }) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/missing-record-clearances',
      body: {
        'library_id': libraryId,
        if (mediaItemId != null) 'media_item_id': mediaItemId,
      },
    );
  }

  /// GET /libraries/identification/unidentified-files
  Future<List<Map<String, dynamic>>> unidentifiedFiles({int? libraryId}) =>
      libraryIssues('unidentified', libraryId: libraryId);

  Future<List<UnidentifiedGroupView>> unidentifiedGroups({
    int? libraryId,
  }) async {
    final rows = await libraryIssues('unidentified', libraryId: libraryId);
    return rows.map(UnidentifiedGroupView.fromJson).toList();
  }

  /// GET /libraries/identification/review-cases
  Future<List<ReviewGroupView>> reviewGroups({int? libraryId}) async {
    final rows = await libraryIssues('review', libraryId: libraryId);
    return rows.map(ReviewGroupView.fromJson).toList();
  }

  /// GET /libraries/identification/ignored-files
  Future<List<UnidentifiedGroupView>> ignoredGroups({int? libraryId}) async {
    final rows = await libraryIssues('ignored', libraryId: libraryId);
    return rows.map(UnidentifiedGroupView.fromJson).toList();
  }

  /// POST /libraries/identification/file-title-assignments
  Future<void> assignFileTitle({
    required List<int> fileIds,
    required String titleRef,
    int? seasonNumber,
  }) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/identification/file-title-assignments',
      body: {
        'file_ids': fileIds,
        'title_ref': titleRef,
        if (seasonNumber != null) 'season_number': seasonNumber,
      },
    );
  }

  /// POST /libraries/identification/files/{fileId}/ignore
  Future<void> ignoreIssue(int fileId) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/identification/files/$fileId/ignore',
    );
  }

  /// POST /libraries/identification/unidentified-file-ignores
  Future<void> ignoreAllUnidentified(int libraryId) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/identification/unidentified-file-ignores',
      body: {'library_id': libraryId},
    );
  }

  /// POST /libraries/identification/ignored-file-restorations
  Future<void> unignoreIssue(List<int> fileIds) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/identification/ignored-file-restorations',
      body: {'file_ids': fileIds},
    );
  }

  /// POST /libraries/identification/review-decisions
  Future<void> confirmReview({
    required List<int> fileIds,
    required String decision, // 'accept_suggestion' | 'keep_current'
  }) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/identification/review-decisions',
      body: {
        'file_ids': fileIds,
        'decision': decision,
      },
    );
  }

  /* ── 回收站与活跃分享 ── */

  /// GET /libraries/trashed-files（兼容旧原始返回）
  Future<List<Map<String, dynamic>>> trashedFiles() async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/libraries/trashed-files',
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['items'] ?? raw['files'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// GET /libraries/trashed-files（完整强类型：含摘要、分面计数、24h 倒计时）
  Future<TrashedFilesData> trashedFilesData({
    String? q,
    int? libraryId,
    String? reason,
    int limit = 20,
    int offset = 0,
  }) async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/libraries/trashed-files',
      query: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (libraryId != null) 'library_id': libraryId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'limit': limit,
        'offset': offset,
      },
    );
    if (raw is Map) {
      return TrashedFilesData.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is List) {
      final items = raw
          .whereType<Map>()
          .map((m) => TrashedItemView.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return TrashedFilesData(
        totalItems: items.length,
        totalFiles: items.fold(0, (s, i) => s + i.fileCount),
        totalBytes: items.fold(0, (s, i) => s + i.totalBytes),
        items: items,
      );
    }
    return const TrashedFilesData();
  }

  /// POST /libraries/trashed-files/restore
  Future<TrashedBatchResultView> restoreTrashedFiles(List<int> ids) async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/trashed-files/restore',
      body: {'ids': ids},
    );
    return raw is Map
        ? TrashedBatchResultView.fromJson(Map<String, dynamic>.from(raw))
        : TrashedBatchResultView(done: ids.length);
  }

  /// POST /libraries/trashed-files/purge
  Future<TrashedBatchResultView> purgeTrashedFiles(
    List<int>? ids, {
    Map<String, dynamic>? filter,
  }) async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/trashed-files/purge',
      body: {
        if (ids != null) 'ids': ids,
        if (filter != null) 'filter': filter,
      },
    );
    return raw is Map
        ? TrashedBatchResultView.fromJson(Map<String, dynamic>.from(raw))
        : TrashedBatchResultView(done: ids?.length ?? 0);
  }

  /// GET /shares（原始）
  Future<List<Map<String, dynamic>>> activeShares() async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/shares',
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['items'] ?? raw['shares'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// GET /shares（强类型，含 viewCount / lastAccessedAt / password / itemCount）
  Future<List<LibraryShareView>> activeSharesTyped() async {
    final rows = await activeShares();
    return rows.map(LibraryShareView.fromJson).toList();
  }

  /// DELETE /shares/{id}
  Future<void> revokeShare(String idOrSlug) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/shares/${Uri.encodeComponent(idOrSlug)}',
    );
  }

  /// POST /search/titles（认领面板按片名检索 TMDB）
  Future<List<Map<String, dynamic>>> searchTmdbTitles(
    String query, {
    String? mediaType,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/search/titles',
      body: {
        'query': query,
        'provider': 'tmdb',
        'save_history': false,
      },
    );
    final titles = (body['titles'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    if (mediaType != null && mediaType.isNotEmpty) {
      return titles
          .where((t) => (t['media_type']?.toString() ?? '') == mediaType)
          .toList();
    }
    return titles;
  }

  /// GET /discover/titles/{titleRef}（认领确认面板预览海报/简介/季数）
  Future<Map<String, dynamic>> discoverTitleDetails(String titleRef) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/discover/titles/${Uri.encodeComponent(titleRef)}',
      );

  /// GET /scrape/language-options
  Future<List<Map<String, dynamic>>> scrapeLanguageOptions() async {
    final raw = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/scrape/language-options',
    );
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// GET /scrape/country-options
  Future<List<Map<String, dynamic>>> scrapeCountryOptions() async {
    final raw = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/scrape/country-options',
    );
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  List<T> _listField<T>(dynamic v, T Function(Map<String, dynamic>) from) =>
      (v as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => from(Map<String, dynamic>.from(m)))
          .toList();
}
