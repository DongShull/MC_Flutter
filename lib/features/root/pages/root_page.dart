import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../state/main_tab_bus.dart';
import '../state/shell_badges.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 五 Tab 主壳（对齐 MainTabScreen.kt）：真实页面由 core/router.dart 的
/// StatefulShellRoute.indexedStack 五个 branch 提供（IndexedStack 保活），
/// 本壳只负责外壳 chrome：悬浮胶囊底栏（手机）/ 左侧 Rail（平板·TV）+ 角标。
/// 页签按权限裁剪（订阅需 canSubscribe、活动需 isAdmin——会话层暂不可用，默认全显）；
/// 再点当前页签 = 回到该分支根页面；MainTabBus 请求合并进帧内消费。
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  /// 页签顺序对齐安卓 MainTab 枚举（发现/媒体库/订阅/活动/我的）。
  static const _labels = ['发现', '媒体库', '订阅', '活动', '我的'];
  static const _icons = [
    McIcons.compass,
    McIcons.mediaLibraryFill,
    Icons.subscriptions_outlined,
    McIcons.bellOn,
    McIcons.accountCircle,
  ];
  static const _filledIcons = [
    McIcons.compassFill,
    McIcons.mediaLibraryFill,
    Icons.subscriptions,
    McIcons.bellOnFill,
    McIcons.accountCircleFill,
  ];

  int get _index => widget.shell.currentIndex;

  @override
  void initState() {
    super.initState();
    // MainTabBus：其他域请求切页签（切完即消费）
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
      final i = MainTab.values.indexOf(pending);
      if (i != _index) _onTab(i);
    }
  }

  void _onTab(int i) {
    // 再点当前页签 = 回到分支根（清掉分支内压栈）
    widget.shell.goBranch(i, initialLocation: i == _index);
    if (i == 3) ref.read(shellBadgesProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(shellBadgesProvider);
    final form = ref.watch(mcFormProvider);

    // 手机：悬浮胶囊底栏（compact 回归零差异）。
    if (form == McDeviceForm.phone) {
      return Scaffold(
        body: widget.shell,
        bottomNavigationBar: _phoneBottomBar(context, badges),
      );
    }

    // 平板/TV：左侧 Rail（5 个 tab 语义不变）。
    return McFormWatch(
      form: form,
      child: McAdaptiveScaffold(
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            McAdaptiveDestination(
              icon: _icons[i],
              selectedIcon: _filledIcons[i],
              label: _labels[i],
            ),
        ],
        currentIndex: _index,
        onSelect: _onTab,
        body: widget.shell,
        railTrailing: _railBadgeDot(badges),
      ),
    );
  }

  /// Rail 侧活动角标点（红 > 绿 > 蓝 优先级）；无活动则不占位。
  Widget? _railBadgeDot(ShellBadges badges) {
    final Color? color;
    if (badges.attentionTotal > 0) {
      color = const Color(0xFFE5615B);
    } else if (badges.livePlayback > 0) {
      color = const Color(0xFF34C77B);
    } else if (badges.activeTotal > 0) {
      color = const Color(0xFF6AA7FF);
    } else {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  /// 悬浮胶囊底栏：348×54、圆角 999、图标-only（仅手机形态使用）。
  Widget _phoneBottomBar(BuildContext context, ShellBadges badges) {
    return SafeArea(
      child: Center(
        child: Container(
          width: 348,
          height: 54,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF141A21)
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(child: _tabSlot(i, badges)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabSlot(int i, ShellBadges badges) {
    final selected = i == _index;
    final showDot = _dotColor(i, badges) != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = selected
        ? (dark ? Colors.white : const Color(0xFF141A21))
        : (dark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF5A6673));
    final pillColor = dark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFF141A21).withValues(alpha: 0.08);

    Widget iconWidget;
    if (i == _labels.length - 1) {
      // 末格 = 账号头像
      iconWidget = CircleAvatar(
        radius: 13,
        backgroundColor: selected ? pillColor : (dark ? Colors.white24 : Colors.black12),
        child: Icon(_icons[i], size: 16, color: iconColor),
      );
    } else {
      iconWidget = Icon(_icons[i], size: 22, color: iconColor);
    }

    return Tooltip(
      message: _labels[i],
      child: InkResponse(
        onTap: () => _onTab(i),
        radius: 24,
        child: Center(
          child: Container(
            width: 46,
            height: 34,
            decoration: BoxDecoration(
              // 当前格药丸（深色白 15%，浅色墨 8%）
              color: selected ? pillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                iconWidget,
                if (showDot)
                  Positioned(
                    right: 7,
                    top: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _dotColor(i, badges),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color? _dotColor(int i, ShellBadges badges) {
    if (i == 3) {
      if (badges.attentionTotal > 0) return const Color(0xFFE5615B);
      if (badges.livePlayback > 0) return const Color(0xFF34C77B);
      if (badges.activeTotal > 0) return const Color(0xFF6AA7FF);
    }
    if (i == 4 && badges.pendingUpdate) return const Color(0xFF6AA7FF);
    return null;
  }
}