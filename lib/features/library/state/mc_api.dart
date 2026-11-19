import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 媒体库域 API 单例。
final libraryApiProvider =
    Provider<LibraryApi>((ref) => LibraryApi(ref.watch(sessionStoreProvider)));

/// 媒体库域的 API 封装：统一走 McClient（Channel.general），信封解包后转成
/// 本域模型（对应 Kotlin McApi.kt 里 libraries / collections / ui / search 段）。
class LibraryApi {
  LibraryApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /libraries → LibraryView[]
  Future<List<LibraryView>> libraries() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/libraries',
    );
    return body.whereType<Map<String, dynamic>>().map(LibraryView.fromJson).toList();
  }

  /// GET /collections → CollectionView[]
  Future<List<CollectionView>> collections() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/collections',
    );
    return body.whereType<Map<String, dynamic>>().map(CollectionView.fromJson).toList();
  }

  /// GET /collections/{id}
  Future<CollectionView> collection(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/collections/$id',
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
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/collections/$id/items',
      query: {'limit': limit, 'offset': offset, if (sort != null) 'sort': sort, if (order != null) 'order': order},
    );
    return body.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// GET /playback/up-next
  Future<List<UpNextItem>> upNext({int limit = 20}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/playback/up-next',
      query: {'limit': limit},
    );
    return _listField(body['items'], UpNextItem.fromJson);
  }

  /// GET /playback/favorites
  Future<List<LibraryItemView>> favorites({
    int limit = 20,
    int offset = 0,
    bool unwatchedFirst = false,
    String? sort,
    String? order,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/playback/favorites',
      query: {
        'limit': limit,
        'offset': offset,
        'unwatched_first': unwatchedFirst,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
      },
    );
    final items = body['items'];
    return items is List<dynamic>
        ? items.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList()
        : <LibraryItemView>[];
  }

  /// GET /libraries/{id}/items（三个接口筛选参数同形：g/d/c/w/rating_gte/rt/lang/res/hdr/stock）
  Future<List<LibraryItemView>> libraryItems(
    int id, {
    int limit = 60,
    int offset = 0,
    Map<String, String?> filterQuery = const {},
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/libraries/$id/items',
      query: {'limit': limit, 'offset': offset, ...filterQuery},
    );
    return body.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// GET /libraries/{id}/facets
  Future<LibraryFacets> libraryFacets(int id, {Map<String, String?> filterQuery = const {}}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/libraries/$id/facets',
      query: filterQuery,
    );
    return LibraryFacets.fromJson(body);
  }

  /// GET /libraries/{id}/item-index（索引条，sort/order 必须与 /items 一致）
  Future<List<LibraryIndexEntry>> libraryItemIndex(
    int id, {
    Map<String, String?> filterQuery = const {},
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/libraries/$id/item-index',
      query: {...filterQuery, 'sort': filterQuery['sort'] ?? 'title'},
    );
    return body.whereType<Map<String, dynamic>>().map(LibraryIndexEntry.fromJson).toList();
  }

  /// GET /libraries/kinds/{kind}
  Future<LibraryKindSummaryView> libraryKindSummary(String kind) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/libraries/kinds/$kind',
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
      Channel.general, 'GET', '$_prefix/libraries/kinds/$kind/items',
      query: {
        'limit': limit,
        'offset': offset,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (watch != null) 'w': watch,
        if (genres != null) 'g': genres,
      },
    );
    return body.whereType<Map<String, dynamic>>().map(LibraryItemView.fromJson).toList();
  }

  /// GET /libraries/kinds/{kind}/genres（首页类型色块：一个 TMDB 类型 + 跨库部数 + 封面）
  Future<List<Map<String, dynamic>>> libraryKindGenres(String kind) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general, 'GET', '$_prefix/libraries/kinds/$kind/genres',
    );
    return body.whereType<Map<String, dynamic>>().toList();
  }

  /// GET /ui/preferences
  Future<Map<String, dynamic>> uiPreferences() => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'GET', '$_prefix/ui/preferences',
      );

  /// PUT /ui/preferences（整体覆盖：以拉到的完整偏好为底，只换 home.rows）
  Future<void> updateUiPreferences(Map<String, dynamic> body) => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'PUT', '$_prefix/ui/preferences',
        body: body,
      );

  /// GET /search/library（人物下钻：person_id）
  Future<LibrarySearchView> searchLibraryByPerson(int personId, {int limit = 60, String? cursor}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/search/library',
      query: {'person_id': personId, 'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return LibrarySearchView.fromJson(body);
  }

  List<T> _listField<T>(dynamic v, T Function(Map<String, dynamic>) from) =>
      (v as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().map(from).toList();
}
