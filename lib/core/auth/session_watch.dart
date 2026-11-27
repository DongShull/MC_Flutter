import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/permissions.dart';
import '../session/session_store.dart';

/// 安全监听全局单例 `appSession` 的权限快照：
/// 通过 `addListener` / `removeListener` 驱动 Riverpod 重建，避免 `ChangeNotifierProvider`
/// 在 `ProviderScope` 销毁时错误调用全局单例 `appSession.dispose()`。
final mcPermissionsProvider = Provider<McPermissions>((ref) {
  void onChanged() => ref.invalidateSelf();
  appSession.addListener(onChanged);
  ref.onDispose(() => appSession.removeListener(onChanged));
  return appSession.permissions;
});

/// 安全监听全局单例 `appSession.sessionGeneration`。
final mcSessionGenerationProvider = Provider<int>((ref) {
  void onChanged() => ref.invalidateSelf();
  appSession.addListener(onChanged);
  ref.onDispose(() => appSession.removeListener(onChanged));
  return appSession.sessionGeneration;
});
