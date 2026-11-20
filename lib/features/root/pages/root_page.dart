import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../state/main_tab_bus.dart';
import '../state/shell_badges.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 五 Tab 主壳（对齐 feature/root 的 MainTabScreen.kt）：
/// 悬浮胶囊底栏（图标-only、当前格白 15% 药丸、末格账号头像）+ IndexedStack 保活；
/// 页签按权限裁剪（订阅需 canSubscribe、活动需 isAdmin——会话层暂不可用，默认全显）；
/// 再点当前页签 = 回根（onTabReselect 语义）；MainTabBus 请求合并进帧内消费。
/// 各 tab 的真实页面由各自 feature 挂在 /discover /library /search 等路由，
/// 本壳内面板保持自包含：显示该 tab 摘要 + 「打开」入口（跨域页面禁止直接 import）。
class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  /// 页签顺序对齐安卓 MainTab 枚举。
  static const _tabs = MainTab.values;

  static const _labels = ['发现', '媒体库', '订阅', '活动', '我的'];
  static const _icons = [
    McIcons.compass,
    McIcons.mediaLibraryFill,
    Icons.subscriptions_outlined,
    McIcons.bellOn,
    McIcons.accountCircle,
  ];

  /// 各页签对应的真实路由（页面由各 feature 域实现挂载）。
  static const _tabRoutes = ['/discover', '/library', '/subscriptions', '/activity', '/more'];
  static const _tabHints = [
    '发现页：海报墙 / 检索 / 订阅入口',
    '媒体库：逐库浏览 / 筛选 / 索引条',
    '订阅：列表 / 创建弹层 / 详情 / 订阅墙',
    '活动中心：任务与播放动态',
    '我的：账号 / 设置 / 更新',
  ];

  int _index = 1; // 默认媒体库（同安卓初始 tab）

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
      setState(() => _index = _tabs.indexOf(pending));
    }
  }

  void _onTab(int i) {
    // 再点当前页签 = 回根
    if (i == _index && _tabRoutes[i].isNotEmpty) {
      context.go(_tabRoutes[i]);
      return;
    }
    setState(() => _index = i);
    if (i == 3) ref.read(shellBadgesProvider.notifier).refresh();
  }

  static const _filledIcons = [
    McIcons.compassFill,
    McIcons.mediaLibraryFill,
    Icons.subscriptions,
    McIcons.bellOnFill,
    McIcons.accountCircleFill,
  ];

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(shellBadgesProvider);
    final form = ref.watch(mcFormProvider);

    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          _TabPanel(
            label: _labels[i],
            route: _tabRoutes[i],
            hint: _tabHints[i],
            icon: _icons[i],
            badge: _badgeText(i, badges),
          ),
      ],
    );

    // 手机：现有悬浮胶囊底栏原样保留（compact 回归零差异）。
    if (form == McDeviceForm.phone) {
      return Scaffold(body: body, bottomNavigationBar: _phoneBottomBar(context, badges));
    }

    // 平板/TV：左侧 Rail（5 个 tab 语义不变），main_tab_bus / shell_badges 逻辑不动。
    return McFormWatch(
      form: form,
      child: McAdaptiveScaffold(
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            McAdaptiveDestination(
              icon: _icons[i],
              selectedIcon: _filledIcons[i],
              label: _labels[i],
            ),
        ],
        currentIndex: _index,
        onSelect: _onTab,
        body: body,
        railTrailing: _railBadgeDot(badges),
      ),
    );
  }

  /// Rail 侧活动角标点（红 > 绿 > 蓝 优先级，与 _dotColor 同规则）；无活动则不占位。
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
              for (var i = 0; i < _tabs.length; i++)
                Expanded(child: _tabSlot(i, badges)),
            ],
          ),
        ),
      ),
    );
  }

  String? _badgeText(int i, ShellBadges badges) {
    if (i == 3) {
      // 活动页签：红 > 绿 > 蓝 优先级
      if (badges.attentionTotal > 0) return '有需要处理的任务';
      if (badges.livePlayback > 0) return '有人正在观看';
      if (badges.activeTotal > 0) return '有任务进行中';
    }
    if (i == 4 && badges.pendingUpdate) return '有可用更新';
    return null;
  }

  Color _dotColor(int i, ShellBadges badges) {
    if (i == 3) {
      if (badges.attentionTotal > 0) return const Color(0xFFE5615B);
      if (badges.livePlayback > 0) return const Color(0xFF34C77B);
      if (badges.activeTotal > 0) return const Color(0xFF6AA7FF);
    }
    return const Color(0xFF6AA7FF);
  }

  Widget _tabSlot(int i, ShellBadges badges) {
    final selected = i == _index;
    final badgeText = _badgeText(i, badges);

    Widget iconWidget;
    if (i == _tabs.length - 1) {
      // 末格 = 账号头像
      iconWidget = CircleAvatar(
        radius: 13,
        backgroundColor: selected ? Colors.white.withValues(alpha: 0.15) : Colors.white24,
        child: Icon(_icons[i], size: 16, color: selected ? Colors.white : Colors.white70),
      );
    } else {
      iconWidget = Icon(_icons[i],
          size: 22, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.62));
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
              // 当前格白 15% 药丸
              color: selected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                iconWidget,
                if (badgeText != null)
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
}

/// 页签面板（自包含）：该 tab 的摘要 + 「打开」入口。
/// 真实页面由各 feature 域挂载在同一路由（跨 feature 页面禁止在本壳内 import）。
class _TabPanel extends StatelessWidget {
  const _TabPanel({
    required this.label,
    required this.route,
    required this.hint,
    required this.icon,
    this.badge,
  });

  final String label;
  final String route;
  final String hint;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(height: 12),
                Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                ),
                if (badge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      badge!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE5615B)),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('打开$label'),
                  onPressed: () => context.push(route),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
