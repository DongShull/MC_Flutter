import '../session/session_store.dart';

/// 图片地址解析（对齐 android-core ImageUrls.kt）：远程图走服务端代理
/// /api/v1/images/proxy?url=…，本地图补 /api/v1 前缀，可按宽度阶梯取档。
class McImageUrls {
  McImageUrls._();

  static const List<int> widthLadder = [
    160, 240, 360, 480, 720, 960, 1280, 1920, 2560, 3840,
  ];

  /// 向上取到阶梯里的一档；超过最大档用最大档。
  static int snap(int widthPx) =>
      widthLadder.firstWhere((e) => e >= widthPx, orElse: () => widthLadder.last);

  /// raw 支持：绝对 http(s)（走代理）/ /api/…（原样拼 base）/ 相对路径（补 /api/v1/）。
  /// 解析失败（无服务器或空串）返回 null，由调用方落回占位图。
  static String? build(String? raw, {int? widthPx, String? baseUrl}) {
    final base = (baseUrl ?? appSession.baseUrl)?.trim() ?? '';
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

  /// 便捷封装：解析失败返回空串（CachedNetworkImage 走 errorWidget 占位）。
  static String resolve(String? raw, {int? widthPx}) =>
      build(raw, widthPx: widthPx) ?? '';
}
