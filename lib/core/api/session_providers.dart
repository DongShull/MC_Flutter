import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_client.dart';
import '../session/session_store.dart';

/// 会话单源头（P1 核心层定稿）：
/// - 唯一实例是全局单例 [appSession]（定义见 session_store.dart）。
///   选它而不是反过来用 provider 做源头，因为 main() 必须在 ProviderScope
///   创建之前 restore 会话（决定首屏），router redirect 与 image_urls 等
///   无 ref 的静态代码也需要会话——provider 做不到这两点。
/// - [sessionStoreProvider] 只是 [appSession] 的薄代理（同一实例，不 new
///   第二个 SessionStore）：有 ref 的代码走 provider（可 override 做测试），
///   无 ref 的代码直接读 [appSession]；两者永远是同一对象（见单测
///   test/session_single_source_test.dart）。
/// 之前 18 个 feature 各自 new SessionStore() 导致实例分裂的问题，
/// 自审核重构 #1 起已不存在；本文件把“单例 + 薄代理”写死为约定。
final sessionStoreProvider = Provider<SessionStore>((ref) => appSession);

final mcClientProvider = Provider<McClient>(
  (ref) => McClient(session: ref.watch(sessionStoreProvider)),
);
