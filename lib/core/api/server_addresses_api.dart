import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/server_routes.dart';
import 'mc_client.dart';
import 'session_providers.dart';

/// GET /api/v1/server/addresses 地址簿：
/// 登录后与冷启动后由 `ServerRoutes.configure` 拉取；旧服务器 404 时静默降级为 null。
Future<ServerAddressesView?> fetchServerAddresses(McClient client) async {
  try {
    final data = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/server/addresses',
    );
    return ServerAddressesView.fromJson(data);
  } catch (_) {
    return null;
  }
}

final serverAddressesApiProvider =
    Provider<Future<ServerAddressesView?> Function()>((ref) {
  final client = ref.watch(mcClientProvider);
  return () => fetchServerAddresses(client);
});
