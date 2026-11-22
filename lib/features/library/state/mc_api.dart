import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_api.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/models.dart' as core;
import '../../../core/api/session_providers.dart';
import 'models.dart';

/// 媒体库域 API 单例。
final libraryApiProvider = Provider<LibraryApi>((ref) => LibraryApi(
      ref.watch(mcApiProvider),
      ref.watch(mcClientProvider),
    ));

/// 媒体库域 API（P1 薄代理）：方法签名与返回的本域模型不变，调用全部委托给
/// 核心层 [McApi]（类型化端点 + freezed 模型），再经 `toJson/fromJson` 转回
/// 本域模型。本文件不再自建 McClient、不再拼路径、不再手写信封解包。
/// 例外：[updateUiPreferences] 整体覆盖必须原样发回拉到的完整 map（未知键不能
/// 丢），故仍走 [McClient] 直发（见方法注释）。
class LibraryApi {
  LibraryApi(this._api, [McClient? client])
      : _client = client;

  final McApi _api;

  /// 仅 updateUiPreferences 用（整体覆盖直发原 map）。
  final McClient? _client;

  static List<T> _convList<T, C>(
    List<C> items,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(C) toJson,
  ) =>
      items.map((e) => fromJson(toJson(e))).toList();

  /// GET /libraries → LibraryView[]
  Future<List<LibraryView>> libraries() async =>
      _convList(await _api.libraries(), LibraryView.fromJson,
          (core.LibraryView e) => e.toJson());

  /// GET /collections → CollectionView[]
  Future<List<CollectionView>> collections() async =>
      _convList(await _api.collections(), CollectionView.fromJson,
          (core.CollectionView e) => e.toJson());

  /// GET /collections/{id}
  Future<CollectionView> collection(int id) async =>
      CollectionView.fromJson((await _api.collection(id)).toJson());

  /// GET /collections/{id}/items
  Future<List<LibraryItemView>> collectionItems(
    int id, {
    int limit = 60,
    int offset = 0,
    String? sort,
    String? order,
  }) async =>
      _convList(
          await _api.collectionItems(id,
              limit: limit, offset: offset, sort: sort, order: order),
          LibraryItemView.fromJson,
          (core.LibraryItemView e) => e.toJson());

  /// GET /playback/up-next
  Future<List<UpNextItem>> upNext({int limit = 20}) async =>
      _convList((await _api.upNext(limit: limit)).items,
          UpNextItem.fromJson, (core.UpNextItemView e) => e.toJson());

  /// GET /playback/favorites
  Future<List<LibraryItemView>> favorites({
    int limit = 20,
    int offset = 0,
    bool unwatchedFirst = false,
    String? sort,
    String? order,
  }) async =>
      _convList(
          (await _api.favorites(
                  limit: limit,
                  offset: offset,
                  unwatchedFirst: unwatchedFirst,
                  sort: sort,
                  order: order))
              .items,
          LibraryItemView.fromJson,
          (core.FavoriteItemView e) => e.toJson());

  /// GET /libraries/{id}/items（三个接口筛选参数同形：g/d/c/w/rating_gte/rt/lang/res/hdr/stock）
  Future<List<LibraryItemView>> libraryItems(
    int id, {
    int limit = 60,
    int offset = 0,
    Map<String, String?> filterQuery = const {},
  }) async =>
      _convList(
          await _api.libraryItems(id,
              limit: limit,
              offset: offset,
              sort: filterQuery['sort'],
              order: filterQuery['order'],
              genres: filterQuery['g'],
              countries: filterQuery['c'],
              decades: filterQuery['d'],
              watch: filterQuery['w'],
              ratingGte: double.tryParse(filterQuery['rating_gte'] ?? ''),
              runtimes: filterQuery['rt'],
              languages: filterQuery['lang'],
              resolutions: filterQuery['res'],
              hdr: filterQuery['hdr'] == null
                  ? null
                  : filterQuery['hdr'] == 'true',
              stock: filterQuery['stock'],
              actor: filterQuery['actor']),
          LibraryItemView.fromJson,
          (core.LibraryItemView e) => e.toJson());

  /// GET /libraries/{id}/facets
  Future<LibraryFacets> libraryFacets(int id,
      {Map<String, String?> filterQuery = const {}}) async {
    final facets = await _api.libraryFacets(id,
        sort: filterQuery['sort'],
        order: filterQuery['order'],
        genres: filterQuery['g'],
        countries: filterQuery['c'],
        decades: filterQuery['d'],
        watch: filterQuery['w'],
        ratingGte: double.tryParse(filterQuery['rating_gte'] ?? ''),
        runtimes: filterQuery['rt'],
        languages: filterQuery['lang'],
        resolutions: filterQuery['res'],
        hdr: filterQuery['hdr'] == null ? null : filterQuery['hdr'] == 'true',
        stock: filterQuery['stock'],
        actor: filterQuery['actor']);
    return LibraryFacets.fromJson(facets.toJson());
  }

  /// GET /libraries/{id}/item-index（索引条，sort/order 必须与 /items 一致）
  Future<List<LibraryIndexEntry>> libraryItemIndex(
    int id, {
    Map<String, String?> filterQuery = const {},
  }) async =>
      _convList(
          await _api.libraryItemIndex(id,
              sort: filterQuery['sort'] ?? 'title',
              order: filterQuery['order'],
              genres: filterQuery['g'],
              countries: filterQuery['c'],
              decades: filterQuery['d'],
              watch: filterQuery['w'],
              ratingGte: double.tryParse(filterQuery['rating_gte'] ?? ''),
              runtimes: filterQuery['rt'],
              languages: filterQuery['lang'],
              resolutions: filterQuery['res'],
              hdr: filterQuery['hdr'] == null
                  ? null
                  : filterQuery['hdr'] == 'true',
              stock: filterQuery['stock'],
              actor: filterQuery['actor']),
          LibraryIndexEntry.fromJson,
          (core.LibraryIndexEntry e) => e.toJson());

  /// GET /libraries/kinds/{kind}
  Future<LibraryKindSummaryView> libraryKindSummary(String kind) async =>
      LibraryKindSummaryView.fromJson(
          (await _api.libraryKindSummary(kind)).toJson());

  /// GET /libraries/kinds/{kind}/items
  Future<List<LibraryItemView>> libraryKindItems(
    String kind, {
    int limit = 60,
    int offset = 0,
    String? sort,
    String? order,
    String? watch,
    String? genres,
  }) async =>
      _convList(
          await _api.libraryKindItems(kind,
              limit: limit,
              offset: offset,
              sort: sort,
              order: order,
              watch: watch,
              genres: genres),
          LibraryItemView.fromJson,
          (core.LibraryItemView e) => e.toJson());

  /// GET /libraries/kinds/{kind}/genres（首页类型色块：一个 TMDB 类型 + 跨库部数 + 封面）
  Future<List<Map<String, dynamic>>> libraryKindGenres(String kind) async =>
      (await _api.libraryKindGenres(kind)).map((e) => e.toJson()).toList();

  /// GET /ui/preferences
  Future<Map<String, dynamic>> uiPreferences() async =>
      (await _api.uiPreferences()).toJson();

  /// PUT /ui/preferences（整体覆盖：以拉到的完整偏好为底，只换 home.rows）。
  /// 不走 McApi 的类型化方法：typed round-trip 会丢掉模型未知的偏好键；
  /// 整体覆盖语义下必须原样发回调用方给的 map。需 McClient 时由 provider
  /// 外层注入；未注入时退化为类型化调用（会丢未知键，见 P1-core.md）。
  Future<void> updateUiPreferences(Map<String, dynamic> body) async {
    final client = _client;
    if (client == null) {
      await _api.updateUiPreferences(
          body: core.UiPreferencesSetting.fromJson(body));
      return;
    }
    await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '/api/v1/ui/preferences',
      body: body,
    );
  }

  /// GET /search/library（人物下钻：person_id）
  Future<LibrarySearchView> searchLibraryByPerson(int personId,
      {int limit = 60, String? cursor}) async {
    final result = await _api.searchLibrary(
        personId: personId, limit: limit, cursor: cursor);
    return LibrarySearchView.fromJson(result.toJson());
  }
}
