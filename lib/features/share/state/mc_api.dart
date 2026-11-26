import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import 'models.dart';

/// 访客分享 API：在内存中维护 `POST /share/{slug}/unlock` 返回的 `Set-Cookie`，
/// 确保加密分享解锁后拉取条目、季集与发起播放均携带有效访客凭证。
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
    final res = await _dio.request<Map<String, dynamic>>(
      '$origin$_prefix$path',
      data: body,
      queryParameters: query,
      options: Options(
        method: method,
        headers: {if (ck != null) 'Cookie': ck},
      ),
    );
    _captureCookies(res.headers);
    final data = res.data;
    if (data == null) {
      throw ApiException(
        'network.empty',
        '服务器返回为空',
        httpStatus: res.statusCode,
      );
    }
    return _unwrap(data);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> body) {
    final data = unwrapEnvelope<dynamic>(body);
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  Future<SharePublic> sharePublic(String slug) async =>
      SharePublic.fromJson(await _send('GET', '/share/$slug'));

  Future<SharePublic> shareUnlock(String slug, String password) async =>
      SharePublic.fromJson(
        await _send('POST', '/share/$slug/unlock', body: {'password': password}),
      );

  Future<SharedItem> shareItem(String slug) async =>
      SharedItem.fromJson(await _send('GET', '/share/$slug/item'));

  Future<SharedCollection> shareCollection(String slug) async =>
      SharedCollection.fromJson(await _send('GET', '/share/$slug/collection'));

  Future<SeasonEpisodesView> shareEpisodes(String slug, int season) async =>
      SeasonEpisodesView.fromJson(
        await _send(
          'GET',
          '/share/$slug/episodes',
          query: {'season_number': season, 'season': season},
        ),
      );

  String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$origin$_prefix$path';
  }
}
