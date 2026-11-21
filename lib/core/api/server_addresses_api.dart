import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/server_routes.dart';
import 'mc_client.dart';
import 'session_providers.dart';

/// GET /server/addresses 地址簿（鸿蒙 api.serverAddresses() 对应）：
/// 登录后由 ServerRoutes.configure 拉一次；旧服务器 404 时静默降级。
Future<ServerAddressesView?> fetchServerAddresses(McClient client) async {
  final res = await client.get(Channel.general, '/server/addresses');
  if (res.statusCode != 200 || res.data == null) return null;
  return ServerAddressesView.fromJson(res.data!);
}

final serverAddressesApiProvider = Provider<Future<ServerAddressesView?> Function()>((ref) {
  final client = ref.watch(mcClientProvider);
  return () => fetchServerAddresses(client);
});
