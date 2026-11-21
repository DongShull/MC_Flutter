import 'package:go_router/go_router.dart';

/// root 模块路由：StatefulShellRoute 挂载在 core/router.dart（需要引用各
/// feature 的真实页面，属于应用组合根，不在本 feature 内跨域 import）。
const routeRoot = '/home';

final List<GoRoute> routes = [];
