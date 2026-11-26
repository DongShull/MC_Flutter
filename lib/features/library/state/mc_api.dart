import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 媒体库域 API 单例。
final libraryApiProvider =
    Provider<LibraryApi>((ref) => LibraryApi(ref.watch(sessionStoreProvider)));

/// 媒体库域的 API 封装：统一走 McClient（Channel.general），信封解包后转成
/// 本域模型（包含浏览、合集 CRUD、库管理 CRUD、服务端目录选择器、异常文件与回收站、分享管理）。
class LibraryApi {
  LibraryApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /libraries → LibraryView[]
  Future<List<LibraryView>> libraries() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries',
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /collections → CollectionView[]
  Future<List<CollectionView>> collections({
    int? libraryId,
    bool includeEmpty = false,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/collections',
      query: {
        if (libraryId != null) 'library_id': libraryId,
        if (includeEmpty) 'include_empty': true,
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

  /// POST /collections（新建普通合集或智能规则合集）
  Future<CollectionView> createCollection({
    required String name,
    int? libraryId,
    Map<String, dynamic>? rules,
    String sort = 'added_at',
    String visibility = 'household',
    List<int>? itemIds,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/collections',
      body: {
        'name': name,
        if (libraryId != null) 'library_id': libraryId,
        if (rules != null && rules.isNotEmpty) 'rules': rules,
        'sort': sort,
        'visibility': visibility,
        if (itemIds != null) 'item_ids': itemIds,
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
      },
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

  /// GET /collections/{id}/items
  Future<List<LibraryItemView>> collectionItems(
    int id, {
    int limit = 60,
    int offset = 0,
    String? sort,
    String? order,
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
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

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
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/favorites',
      query: {
        'limit': limit,
        'offset': offset,
        'unwatched_first': unwatchedFirst,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
      },
    );
    final items = _listField(body['items'], LibraryItemView.fromJson);
    final total = body['total'];
    return FavoritesResult(
      items: items,
      total: total is num ? total.toInt() : items.length,
    );
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
    final deleted = body is Map<String, dynamic> ? body['deleted_states'] : null;
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
    final role =
        body['role'] ?? (user is Map ? user['role'] : null);
    return role?.toString() ?? '';
  }

  /// GET /libraries/{id}/items
  Future<List<LibraryItemView>> libraryItems(
    int id, {
    int limit = 60,
    int offset = 0,
    Map<String, String?> filterQuery = const {},
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/items',
      query: {'limit': limit, 'offset': offset, ...filterQuery},
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/{id}/facets
  Future<LibraryFacets> libraryFacets(
    int id, {
    Map<String, String?> filterQuery = const {},
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/facets',
      query: filterQuery,
    );
    return LibraryFacets.fromJson(body);
  }

  /// GET /libraries/{id}/item-index
  Future<List<LibraryIndexEntry>> libraryItemIndex(
    int id, {
    Map<String, String?> filterQuery = const {},
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/$id/item-index',
      query: {...filterQuery, 'sort': filterQuery['sort'] ?? 'title'},
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryIndexEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/kinds/{kind}
  Future<LibraryKindSummaryView> libraryKindSummary(String kind) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/kinds/$kind',
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
        if (watch != null) 'w': watch,
        if (genres != null) 'g': genres,
      },
    );
    return body
        .whereType<Map>()
        .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /libraries/kinds/{kind}/genres
  Future<List<Map<String, dynamic>>> libraryKindGenres(String kind) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries/kinds/$kind/genres',
    );
    return body.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// GET /ui/preferences
  Future<Map<String, dynamic>> uiPreferences() =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/ui/preferences',
      );

  /// PUT /ui/preferences
  Future<void> updateUiPreferences(Map<String, dynamic> body) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '$_prefix/ui/preferences',
        body: body,
      );

  /// GET /search/library（人物下钻：person_id）
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

  /* ── 服务端目录浏览与媒体库管控中心（/library/manage） ── */

  /// GET /fs/browse
  Future<Map<String, dynamic>> browseServerFs({String? path}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/fs/browse',
        query: {if (path != null && path.isNotEmpty) 'path': path},
      );

  /// POST /libraries
  Future<LibraryView> createLibrary({
    required String name,
    required String kind,
    required List<String> paths,
    bool isDefault = false,
    bool excludeFromHome = false,
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
      },
    );
    return LibraryView.fromJson(body);
  }

  /// PUT /libraries/{id}
  Future<LibraryView> updateLibrary(
    int id, {
    required String name,
    required List<String> paths,
    bool? isDefault,
    bool? excludeFromHome,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '$_prefix/libraries/$id',
      body: {
        'name': name,
        'paths': paths,
        'root_paths': paths,
        if (isDefault != null) 'is_default': isDefault,
        if (excludeFromHome != null) 'exclude_from_home': excludeFromHome,
      },
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

  /// POST /libraries/{id}/metadata/refresh
  Future<void> refreshLibraryMetadata(int id) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/$id/metadata/refresh',
    );
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

  /// GET /libraries/identification/unidentified-files
  Future<List<Map<String, dynamic>>> unidentifiedFiles({int? libraryId}) async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/libraries/identification/unidentified-files',
      query: {if (libraryId != null) 'library_id': libraryId},
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['items'] ?? raw['files'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
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

  /// GET /libraries/trashed-files
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

  /// POST /libraries/trashed-files/restore
  Future<void> restoreTrashedFiles(List<int> ids) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/trashed-files/restore',
      body: {'ids': ids},
    );
  }

  /// POST /libraries/trashed-files/purge
  Future<void> purgeTrashedFiles(List<int> ids) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'POST',
      '$_prefix/libraries/trashed-files/purge',
      body: {'ids': ids},
    );
  }

  /// GET /shares
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

  /// DELETE /shares/{id}
  Future<void> revokeShare(String idOrSlug) async {
    await client.unwrap<dynamic>(
      Channel.general,
      'DELETE',
      '$_prefix/shares/${Uri.encodeComponent(idOrSlug)}',
    );
  }

  List<T> _listField<T>(dynamic v, T Function(Map<String, dynamic>) from) =>
      (v as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => from(Map<String, dynamic>.from(m)))
          .toList();
}
