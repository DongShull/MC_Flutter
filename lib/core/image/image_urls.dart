import '../network/server_routes.dart';
import '../session/session_store.dart';

/// 图片地址解析（对齐 android-core ImageUrls.kt，并优先走 `ServerRoutes` 当前最优内外网地址）。
class McImageUrls {
  McImageUrls._();

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
      return explicitBase.trim();
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
}

/// 图片请求统一附带登录令牌。
Map<String, String> mcImageHeaders() {
  final t = appSession.token;
  return t == null || t.isEmpty
      ? const <String, String>{}
      : <String, String>{'Authorization': 'Bearer $t'};
}
