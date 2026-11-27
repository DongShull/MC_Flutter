import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import 'models.dart';

/// 访客分享 API（对齐 iOS `ShareLinkKit.swift`）：
/// - 在内存中维护 `POST /share/{slug}/unlock` 返回的 `Set-Cookie`；
/// - 支持合集分享点开单部影片时携带 `?item=<mediaItemId>` 查询参数；
/// - 正确处理 401/403/404 响应体，保留后端中文错误文案。
class GuestShareApi {
  GuestShareApi(this.origin)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 20),
            validateStatus: (_) => true,
          ),
        );

  final String origin;
  final Dio _dio;
  final Map<String, String> _cookies = {};

  static const _prefix = '/api/v1';

  String get _normalizedOrigin => origin.trim().replaceAll(RegExp(r'/+$'), '');

  String? get cookieHeader => _cookies.isEmpty
      ? null
      : _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void _captureCookies(Headers headers) {
    final setCookies = headers['set-cookie'];
    if (setCookies == null) return;
    for (final raw in setCookies) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq > 0) {
        _cookies[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
      }
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final ck = cookieHeader;
    final res = await _dio.request<dynamic>(
      '$_normalizedOrigin$_prefix$path',
      data: body,
      queryParameters: query,
      options: Options(
        method: method,
        headers: {if (ck != null) 'Cookie': ck},
      ),
    );
    _captureCookies(res.headers);
    final raw = res.data;
    if (raw == null) {
      throw ApiException(
        'network.empty',
        '服务器返回为空',
        httpStatus: res.statusCode,
      );
    }
    if (raw is Map<String, dynamic>) {
      return _unwrap(raw, statusCode: res.statusCode);
    }
    throw ApiException(
      'http.${res.statusCode ?? 0}',
      '请求失败（HTTP ${res.statusCode ?? 0}）',
      httpStatus: res.statusCode,
    );
  }

  Map<String, dynamic> _unwrap(
    Map<String, dynamic> body, {
    int? statusCode,
  }) {
    try {
      final data = unwrapEnvelope<dynamic>(body);
      if (data is Map) return data.cast<String, dynamic>();
      return <String, dynamic>{};
    } on ApiException catch (e) {
      throw ApiException(
        e.code,
        e.message,
        httpStatus: e.httpStatus ?? statusCode,
      );
    }
  }

  Future<SharePublic> sharePublic(String slug) async =>
      SharePublic.fromJson(await _send('GET', '/share/$slug'));

  Future<SharePublic> shareUnlock(String slug, String password) async =>
      SharePublic.fromJson(
        await _send(
          'POST',
          '/share/$slug/unlock',
          body: {'password': password},
        ),
      );

  /// 获取分享条目详情；合集分享点开某一部时必须带 `?item=<itemId>`。
  Future<SharedItem> shareItem(String slug, {int? itemId}) async =>
      SharedItem.fromJson(
        await _send(
          'GET',
          '/share/$slug/item',
          query: {if (itemId != null) 'item': itemId},
        ),
      );

  Future<SharedCollection> shareCollection(String slug) async =>
      SharedCollection.fromJson(await _send('GET', '/share/$slug/collection'));

  /// 获取分享剧集某季的分集列表；合集分享点开某部剧时带 `?item=<itemId>`。
  Future<SeasonEpisodesView> shareEpisodes(
    String slug, {
    required int seasonNumber,
    int? itemId,
  }) async =>
      SeasonEpisodesView.fromJson(
        await _send(
          'GET',
          '/share/$slug/episodes',
          query: {
            'season_number': seasonNumber,
            if (itemId != null) 'item': itemId,
          },
        ),
      );

  String? imageUrl(String? path, {int? widthPx}) {
    if (path == null || path.isEmpty) return null;
    final p = path.trim();
    String url;
    if (p.startsWith('http://') || p.startsWith('https://')) {
      url = '$_normalizedOrigin$_prefix/images/proxy?url=${Uri.encodeQueryComponent(p)}';
    } else if (p.startsWith('/api/')) {
      url = '$_normalizedOrigin$p';
    } else if (p.startsWith('/')) {
      url = '$_normalizedOrigin$_prefix$p';
    } else {
      url = '$_normalizedOrigin$_prefix/$p';
    }
    if (widthPx != null) {
      url += '${url.contains('?') ? '&' : '?'}w=$widthPx';
    }
    return url;
  }
}
