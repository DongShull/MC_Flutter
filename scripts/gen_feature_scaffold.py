#!/usr/bin/env python3
"""Generate per-feature routes.dart / placeholder page / README.

Reusable scaffold generator: keeps all 18 feature modules structurally identical.
"""
from pathlib import Path

FEATURES = {
    "onboarding": "/onboarding",
    "root": "/home",
    "library": "/library",
    "discover": "/discover",
    "search": "/search",
    "detail": "/detail",
    "player": "/player",
    "subscriptions": "/subscriptions",
    "activity": "/activity",
    "offline": "/offline",
    "reels": "/reels",
    "account": "/account",
    "notices": "/notices",
    "agent": "/agent",
    "settings": "/settings",
    "share": "/share",
    "update": "/update",
    "more": "/more",
}

TAB_TITLES = {
    "library": "媒体库",
    "discover": "发现",
    "search": "搜索",
    "subscriptions": "订阅",
    "more": "我的",
}

BASE = Path(__file__).resolve().parent.parent / "lib" / "features"


def class_name(feat: str) -> str:
    return "".join(w.capitalize() for w in feat.split("_"))


PLACEHOLDER_MARK = "1:1 重写中"


def is_placeholder(path: Path) -> bool:
    """True if the page is still our placeholder (safe to regenerate)."""
    if not path.exists():
        return True
    return PLACEHOLDER_MARK in path.read_text()


def gen(feat: str, route: str) -> None:
    d = BASE / feat
    (d / "routes.dart").write_text(
        f"""import 'package:go_router/go_router.dart';
import 'pages/{feat}_page.dart';

/// {feat} 模块路由（挂载到 core/router.dart）。
const route{class_name(feat)} = '{route}';

final List<GoRoute> routes = [
  GoRoute(path: route{class_name(feat)}, builder: (context, state) => const {class_name(feat)}Page()),
];
"""
    )
    if feat == "root":
        page = d / "pages" / "root_page.dart"
        if is_placeholder(page) or not page.exists():
            page.write_text(ROOT_PAGE)
    else:
        title = TAB_TITLES.get(feat)
        body = (
            f"Scaffold(appBar: AppBar(title: const Text('{title}')), body: const FeaturePlaceholder(title: '{title}'))"
            if title
            else f"const FeaturePlaceholder(title: '{feat}')"
        )
        page = d / "pages" / f"{feat}_page.dart"
        if is_placeholder(page):
            page.write_text(
            f"""import 'package:flutter/material.dart';

import '../../../core/designsystem/widgets.dart';

/// {feat} 页面（对应原 Kotlin feature/{feat}，1:1 重写中）。
class {class_name(feat)}Page extends StatelessWidget {{
  const {class_name(feat)}Page({{super.key}});

  @override
  Widget build(BuildContext context) => {body};
}}
"""
        )
    (d / "README.md").write_text(
        f"""# feature/{feat}

- 原 Kotlin 模块：apps/android .../feature/{feat}
- 设计文档：docs/design/（见 01–05 号）
- 状态：⬜ 未实现（当前为统一占位页，骨架已挂路由）
- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。
"""
    )


ROOT_PAGE = """import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/widgets.dart';

/// 五 Tab 主壳（对齐原 feature/root 的底部导航）。
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const _labels = ['媒体库', '发现', '搜索', '订阅', '我的'];
  static const _icons = [
    Icons.video_library_outlined,
    Icons.explore_outlined,
    Icons.search,
    Icons.subscriptions_outlined,
    Icons.person_outline,
  ];
  static const _tabRoutes = ['/library', '/discover', '/search', '/subscriptions', '/more'];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeaturePlaceholder(title: _labels[_index], hint: '由各 Tab 模块实现'),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          context.go(_tabRoutes[i]);
        },
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
        ],
      ),
    );
  }
}
"""


def main() -> None:
    for feat, route in FEATURES.items():
        gen(feat, route)
    print(f"generated {len(FEATURES)} feature modules")


if __name__ == "__main__":
    main()
