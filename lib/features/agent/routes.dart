
import 'package:go_router/go_router.dart';

import 'pages/chat_page.dart';
import 'pages/sessions_page.dart';
import 'pages/skills_page.dart';

/// agent 模块路由（挂载到 core/router.dart）。
const routeAgent = '/agent';

final List<GoRoute> routes = [
  GoRoute(path: routeAgent, builder: (context, state) => const SessionsPage()),
  GoRoute(
    path: '$routeAgent/new',
    builder: (context, state) => const ChatPage(),
  ),
  GoRoute(
    path: '$routeAgent/session/:sessionId',
    builder: (context, state) => ChatPage(
      sessionId: state.pathParameters['sessionId'],
    ),
  ),
  GoRoute(
    path: '$routeAgent/skills',
    builder: (context, state) => const SkillsPage(),
  ),
];
