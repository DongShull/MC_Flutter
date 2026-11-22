import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_error.dart';
import 'models.dart';

/// 访客分享 API（对齐 Kotlin McApi.kt 访客段 sharePublic/unlock/item/collection/episodes）。
///
/// 实现说明：访客接口带显式 origin（分享深链可来自任意服务器），而 McClient 的 baseUrl
/// 绑定到会话 origin 且不可注入外部 origin（SessionStore 无公开 setter，login 会落盘覆盖会话）。
/// 故本域用同一信封协议（复用 core 的 decodeEnvelope 语义）直连 origin；已登录成员打开
/// 分享链接看到的也是同一张独立页，接口不带成员令牌（访客通道语义）。
/// P1：本文件保留（访客通道≠会话通道，无法并入 McApi），但 _send 已收敛到
/// core 的信封解包与错误分级（DioException → 分级 ApiException），不再各自为政。
class GuestShareApi {
  GuestShareApi(this.origin) : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ));

  final String origin;
  final Dio _dio;

  static const _prefix = '/api/v1';

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        '$origin$_prefix$path',
        data: body,
        options: Options(method: method),
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('network.empty', '服务器返回为空', httpStatus: res.statusCode);
      }
      return _unwrap(data);
    } on DioException catch (e) {
      throw McError.classify(e).toApiException();
    }
  }

  /// 与 core 的 /api/v1 统一信封 {code, message, data} 同构（复用 core decodeEnvelope）。
  Map<String, dynamic> _unwrap(Map<String, dynamic> body) {
    final data = decodeEnvelope(body);
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// GET /share/{slug} 探测（可能要密码）。
  Future<SharePublic> sharePublic(String slug) async =>
      SharePublic.fromJson(await _send('GET', '/share/$slug'));

  /// POST /share/{slug}/unlock 密码解锁（成功后服务端 Set-Cookie 走同一 Dio 实例）。
  Future<SharePublic> shareUnlock(String slug, String password) async =>
      SharePublic.fromJson(
          await _send('POST', '/share/$slug/unlock', body: {'password': password}));

  /// GET /share/{slug}/item
  Future<SharedItem> shareItem(String slug) async =>
      SharedItem.fromJson(await _send('GET', '/share/$slug/item'));

  /// GET /share/{slug}/collection
  Future<SharedCollection> shareCollection(String slug) async =>
      SharedCollection.fromJson(await _send('GET', '/share/$slug/collection'));

  /// GET /share/{slug}/episodes?season=
  Future<SeasonEpisodesView> shareEpisodes(String slug, int season) async {
    final res = await _dio.request<Map<String, dynamic>>(
      '$origin$_prefix/share/$slug/episodes',
      queryParameters: {'season': season},
      options: Options(method: 'GET'),
    );
    final data = res.data;
    if (data == null) {
      throw ApiException('network.empty', '服务器返回为空', httpStatus: res.statusCode);
    }
    return SeasonEpisodesView.fromJson(_unwrap(data));
  }

  /// 分享通道的图片要经 API 基址（/api/v1）访问。
  String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$origin$_prefix$path';
  }
}
