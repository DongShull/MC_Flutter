import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_client.dart';
import '../session/session_store.dart';

/// 全局唯一会话/McClient provider（审核重构 #1）。
/// 之前 18 个 feature 各自 new SessionStore() 导致实例分裂：
/// SessionStore 的 baseUrl/token 是内存状态，必须全 App 共享同一实例。
final sessionStoreProvider = Provider<SessionStore>((ref) => appSession);

final mcClientProvider = Provider<McClient>(
  (ref) => McClient(session: ref.watch(sessionStoreProvider)),
);
