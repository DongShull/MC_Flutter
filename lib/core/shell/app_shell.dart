import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/pages/discover_page.dart';
import '../../features/library/pages/library_home_page.dart';
import '../../features/subscriptions/pages/subscriptions_page.dart';
import '../../features/activity/pages/activity_page.dart';
import '../../features/more/pages/more_page.dart';
import '../../features/root/pages/root_page.dart';
import '../../features/root/state/main_tab_bus.dart';
import '../../features/root/state/shell_badges.dart';

/// 主壳组合根（唯一允许 import 各 feature 页面的地方，对齐 core/router.dart 职责）：
/// 页签状态与五个真实页面在此持有，IndexedStack 保活；本文件属于 core 组合层，
/// 各 feature 之间仍然互不 import（模块化铁律不破）。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialTab = 1});

  /// 初始页签（安卓默认媒体库 = index 1）。
  final int initialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _index = widget.initialTab;

  @override
  void initState() {
    super.initState();
    MainTabBus.instance.addListener(_consumeBus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeBus());
  }

  @override
  void dispose() {
    MainTabBus.instance.removeListener(_consumeBus);
    super.dispose();
  }

  void _consumeBus() {
    final pending = MainTabBus.instance.consume();
    if (pending != null && mounted) {
      setState(() => _index = MainTab.values.indexOf(pending));
    }
  }

  void _onSelect(int i) {
    setState(() => _index = i);
    if (i == 3) ref.read(shellBadgesProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RootShell(
      index: _index,
      onSelect: _onSelect,
      pages: const [
        DiscoverPage(),
        LibraryHomePage(),
        SubscriptionsPage(),
        ActivityPage(),
        MorePage(),
      ],
    );
  }
}
