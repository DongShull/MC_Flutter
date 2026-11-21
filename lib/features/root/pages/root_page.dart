import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/adaptive.dart';
import '../state/shell_badges.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/session_store.dart';

/// 主壳 chrome（只管壳，不管页面）：手机悬浮胶囊底栏 / 平板TV 左侧 Rail。
/// 页面与页签状态由 core/shell/app_shell.dart（组合根）持有，本壳纯展示。
class RootShell extends ConsumerWidget {
  const RootShell({
    super.key,
    required this.index,
    required this.pages,
    required this.onSelect,
  });

  final int index;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(shellBadgesProvider);
    final form = ref.watch(mcFormProvider);

    final body = IndexedStack(index: index, children: pages);

    // 手机：悬浮胶囊底栏。
    if (form == McDeviceForm.phone) {
      // extendBody：页面内容延伸到胶囊底栏背后（悬浮胶囊透出海报，对齐飞牛悬浮底栏）。
      return Scaffold(
        extendBody: true,
        body: body,
        bottomNavigationBar: _phoneBottomBar(context, badges),
      );
    }

    // 平板/TV：左侧 Rail。
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
        currentIndex: index,
        onSelect: onSelect,
        body: body,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 注意：不能包 Center——它会把 bottomNavigationBar 撑成整屏高，把 body 挤成 0（真机白屏元凶）。
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Container(
          width: 348,
          height: 54,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF141A21) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(child: _tabSlot(i, badges, dark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabSlot(int i, ShellBadges badges, bool dark) {
    final selected = i == index;
    final badgeDot = _dotColor(i, badges);

    Widget iconWidget;
    if (i == _labels.length - 1) {
      // 末格 = 账号头像
      final nickname = appSession.username;
      final initial =
          nickname.isEmpty ? '?' : String.fromCharCode(nickname.runes.first);
      final avatar = appSession.avatarUrl;
      iconWidget = Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B8DEF), Color(0xFF9B6BDF)],
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : const Color(0xFF141A21),
              ),
            ),
            if (avatar.isNotEmpty)
              Positioned.fill(
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: McImageUrls.resolve(avatar, widthPx: 96),
                    httpHeaders: mcImageHeaders(),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      iconWidget = Icon(_icons[i],
          size: 22,
          color: selected
              ? (dark ? Colors.white : const Color(0xFF141A21))
              : (dark
                  ? Colors.white.withValues(alpha: 0.62)
                  : const Color(0xFF5A6673)));
    }

    return Tooltip(
      message: _labels[i],
      child: InkResponse(
        onTap: () => onSelect(i),
        radius: 24,
        child: Center(
          child: Container(
            width: 46,
            height: 34,
            decoration: BoxDecoration(
              // 当前格药丸：暗色白 15%、浅色墨 8%。
              color: selected
                  ? (dark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                iconWidget,
                if (badgeDot != null)
                  Positioned(
                    right: 7,
                    top: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: badgeDot, shape: BoxShape.circle),
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
    return null;
  }
}
