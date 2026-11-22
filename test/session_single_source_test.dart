import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/session_providers.dart';
import 'package:mc_flutter/core/session/session_store.dart';

/// 会话单源头（P1 核心层）：全局单例 appSession 是唯一实例；
/// sessionStoreProvider 只是它的薄代理（同一实例，不 new 第二个）。
void main() {
  test('sessionStoreProvider 返回的就是 appSession（同一实例）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final viaProvider = container.read(sessionStoreProvider);
    expect(identical(viaProvider, appSession), isTrue);
  });

  test('多次读取 provider 始终是同一实例', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(sessionStoreProvider);
    final second = container.read(sessionStoreProvider);
    expect(identical(first, second), isTrue);
    expect(identical(first, appSession), isTrue);
  });
}
