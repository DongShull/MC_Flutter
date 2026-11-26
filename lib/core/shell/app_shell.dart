import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/pages/activity_page.dart';
import '../../features/discover/pages/discover_page.dart';
import '../../features/library/pages/library_home_page.dart';
import '../../features/library/state/library_home_controller.dart';
import '../../features/library/state/models.dart';
import '../../features/library/widgets/library_shared.dart';
import '../../features/more/pages/more_page.dart';
import '../../features/more/widgets/account_switcher_sheet.dart';
import '../../features/root/pages/root_page.dart';
import '../../features/root/state/main_tab_bus.dart';
import '../../features/root/state/shell_badges.dart';
import '../../features/subscriptions/pages/subscriptions_page.dart';
import '../designsystem/mc_glass.dart';
import '../designsystem/mc_icons.dart';
import '../designsystem/theme.dart';
import '../image/image_urls.dart';
import '../player/player_page_args.dart';
import 'tab_collapse.dart';

/// 主壳组合根（唯一允许整合各顶层 feature 页面的地方）：
/// - 页签顺序对齐 iOS `MainTabView`：0=媒体库（默认首屏） / 1=订阅 / 2=发现 / 3=活动 / 4=我的
/// - 在底栏上方挂载跨页面「接着看（ResumeBar）」液态玻璃迷你条（对齐 iOS `ResumeAccessory.swift`）
/// - 头像页签长按直接唤起多账号切换面板
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _index = widget.initialTab.clamp(0, 4);
  String? _dismissedResumeKey;

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
    TabCollapseBus.instance.reset();
    setState(() => _index = i);
    if (i == 3) ref.read(shellBadgesProvider.notifier).refresh();
  }

  static String _resumeKey(UpNextItem item) =>
      '${item.mediaItemId}|${item.seasonNumber}|${item.episodeNumber}';

  @override
  Widget build(BuildContext context) {
    final upNext = ref.watch(libraryHomeProvider.select((s) => s.upNext));
    final resumeItem = upNext.isEmpty ? null : upNext.first;
    // 「我的」页自带底部 AI 快捷输入胶囊，不叠「接着看」浮条（同 iOS MainTabView:165）
    final showResume = _index != 4 &&
        resumeItem != null &&
        _resumeKey(resumeItem) != _dismissedResumeKey;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical) {
          TabCollapseBus.instance.onScroll(n.metrics.pixels);
        }
        return false;
      },
      child: RootShell(
        index: _index,
        onSelect: _onSelect,
        onAvatarLongPress: () => showAccountSwitcherSheet(context),
        bottomAccessory: showResume
            ? _ResumeAccessoryBar(
                item: resumeItem,
                onPlay: () {
                  context.push(
                    '/player',
                    extra: PlayerPageArgs(
                      mediaItemId: resumeItem.mediaItemId,
                      seasonNumber:
                          resumeItem.isEpisode ? resumeItem.seasonNumber : null,
                      episodeNumber: resumeItem.isEpisode
                          ? resumeItem.episodeNumber
                          : null,
                      title: resumeItem.title,
                      subtitle: resumeItem.isEpisode
                          ? episodeCode(
                              resumeItem.seasonNumber,
                              resumeItem.episodeNumber,
                            )
                          : null,
                      startPosition: resumeItem.positionMs > 0
                          ? Duration(milliseconds: resumeItem.positionMs)
                          : null,
                      isEpisode: resumeItem.isEpisode,
                    ),
                  );
                },
                onOpenDetail: () => context.push(
                  '/detail/${resumeItem.libraryId}/${resumeItem.mediaItemId}',
                ),
                onDismiss: () => setState(
                  () => _dismissedResumeKey = _resumeKey(resumeItem),
                ),
              )
            : null,
        pages: const [
          LibraryHomePage(),
          SubscriptionsPage(),
          DiscoverPage(),
          ActivityPage(),
          MorePage(),
        ],
      ),
    );
  }
}

/// 液态玻璃「接着看」底部附件条（1:1 复刻 iOS `ResumeAccessory.swift` & 实机图 `scene-1.jpg`）。
class _ResumeAccessoryBar extends StatelessWidget {
  const _ResumeAccessoryBar({
    required this.item,
    required this.onPlay,
    required this.onOpenDetail,
    required this.onDismiss,
  });

  final UpNextItem item;
  final VoidCallback onPlay;
  final VoidCallback onOpenDetail;
  final VoidCallback onDismiss;

  String get _detailLine {
    final parts = <String>[];
    if (item.isEpisode) {
      parts.add(episodeCode(item.seasonNumber, item.episodeNumber));
    }
    final pct = item.progressPercent;
    if (item.positionMs > 0 && pct != null && pct > 0) {
      parts.add('看到 ${pct.round().clamp(1, 99)}%');
    } else if (item.isEpisode) {
      parts.add('下一集');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = McImageUrls.resolve(
      item.episodeStillUrl ?? item.backdropUrl,
      widthPx: 200,
    );
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      blurSigma: 22,
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      child: Row(
        children: [
          Expanded(
            child: McPressable(
              onTap: onPlay,
              onLongPress: onOpenDetail,
              scaleDown: 0.985,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      width: 50,
                      height: 29,
                      color: McTokens.posterPlaceholder,
                      child: thumbUrl.isEmpty
                          ? const Icon(
                              McIcons.film,
                              size: 14,
                              color: McTokens.textFaint,
                            )
                          : CachedNetworkImage(
                              imageUrl: thumbUrl,
                              httpHeaders: mcImageHeaders(),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (_detailLine.isNotEmpty)
                          Text(
                            _detailLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.micro.copyWith(
                              color: McTokens.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      McIcons.playFill,
                      size: 16,
                      color: McTokens.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          McPressable(
            onTap: onDismiss,
            haptic: true,
            child: const SizedBox(
              width: 32,
              height: 30,
              child: Icon(
                McIcons.close,
                size: 14,
                color: McTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
