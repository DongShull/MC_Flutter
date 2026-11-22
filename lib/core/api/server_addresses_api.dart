import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/server_routes.dart';
import 'api_exception.dart';
import 'mc_api.dart';
import 'mc_error.dart';

/// GET /api/v1/server/addresses 地址簿（鸿蒙 api.serverAddresses() 对应）：
/// 登录后由 ServerRoutes.configure 拉一次；旧服务器 404 时静默降级。
///
/// 既有 bug 修复（P1）：旧实现调 `client.get(Channel.general, '/server/addresses')`
/// 缺 `/api/v1` 前缀，服务端只在 /api/v1 下挂载，恒 404 → 地址簿从未拉到、
/// 内外网自动选路静默失效。现委托核心层 McApi（路径已带 /api/v1）。
Future<ServerAddressesView?> fetchServerAddresses(McApi api) async {
  try {
    final core = await api.serverAddresses();
    return ServerAddressesView.fromJson(core.toJson());
  } on ApiException catch (e) {
    // 404 / 网络不可达：旧服务器或离线，降级为只用登录 origin。
    McErrorLog.log(e, context: 'serverAddresses');
    return null;
  }
}

final serverAddressesApiProvider = Provider<Future<ServerAddressesView?> Function()>((ref) {
  final api = ref.watch(mcApiProvider);
  return () => fetchServerAddresses(api);
});
