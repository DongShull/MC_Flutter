import '../network/server_routes.dart';
import '../session/session_store.dart';

/// 图片地址解析（对齐 android-core ImageUrls.kt 与 iOS `AvatarURL`，并优先走 `ServerRoutes` 当前最优内外网地址）。
class McImageUrls {
  McImageUrls._();

  static const String accountQueryParam = 'mc_account';

  static const List<int> widthLadder = [
    160,
    240,
    360,
    480,
    720,
    960,
    1280,
    1920,
    2560,
    3840,
  ];

  static int snap(int widthPx) => widthLadder.firstWhere(
        (e) => e >= widthPx,
        orElse: () => widthLadder.last,
      );

  static String _effectiveOrigin(String? explicitBase) {
    if (explicitBase != null && explicitBase.trim().isNotEmpty) {
      return ServerRoutes.instance.originFor(explicitBase.trim());
    }
    final routed = ServerRoutes.instance.currentOrigin().trim();
    if (routed.isNotEmpty) return routed;
    return appSession.baseUrl?.trim() ?? '';
  }

  static String? build(String? raw, {int? widthPx, String? baseUrl}) {
    final base = _effectiveOrigin(baseUrl);
    if (base.isEmpty) return null;
    final p = (raw ?? '').trim().replaceAll('\\', '/');
    if (p.isEmpty) return null;
    String url;
    if (p.startsWith('http://') || p.startsWith('https://')) {
      url = '$base/api/v1/images/proxy?url=${Uri.encodeQueryComponent(p)}';
    } else if (p.startsWith('/api/')) {
      url = '$base$p';
    } else {
      url = '$base/api/v1/${p.startsWith('/') ? p.substring(1) : p}';
    }
    if (widthPx != null) {
      url += '${url.contains('?') ? '&' : '?'}w=${snap(widthPx)}';
    }
    return url;
  }

  static String resolve(String? raw, {int? widthPx, String? baseUrl}) =>
      build(raw, widthPx: widthPx, baseUrl: baseUrl) ?? '';

  /// 给多账号头像 URL 附加 `mc_account=<username>` 标记（对齐 iOS `AvatarURL.tagged`），
  /// 便于图片缓存按账号区分并按对应账号令牌鉴权。
  static String? tagAccount(String? raw, String username) {
    if (raw == null || raw.trim().isEmpty || username.trim().isEmpty) {
      return raw;
    }
    if (raw.contains('$accountQueryParam=')) return raw;
    final sep = raw.contains('?') ? '&' : '?';
    final encoded = Uri.encodeQueryComponent(username.trim());
    return '$raw$sep$accountQueryParam=$encoded';
  }

  /// 将已拼好的图片地址按当前活跃路由重写为最优地址。
  static String rewrite(String url) => ServerRoutes.instance.rewrite(url);
}

/// 图片请求统一附带当前登录账号令牌（向后兼容）。
Map<String, String> mcImageHeaders() => mcImageHeadersFor();

/// 按目标服务器与账号返回图片请求头（对齐 iOS `AuthTokenRegistry.token(for:)`）：
/// 支持在账号切换列表中用各已保存账号各自的 Bearer 令牌加载头像。
Map<String, String> mcImageHeadersFor({
  String? origin,
  String? username,
}) {
  final token = appSession.tokenFor(origin: origin, username: username);
  final headers = <String, String>{};
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  final route = origin != null && origin.trim().isNotEmpty
      ? ServerRoutes.instance.routeFor(origin)?.headerValue
      : ServerRoutes.instance.routeHeaderValue;
  if (route != null && route.isNotEmpty) {
    headers['X-MovieClaw-Route'] = route;
  }
  return headers;
}
