import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_ambient.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/shell/main_tab_bus.dart';
import '../state/controllers.dart';
import '../state/subscription_events.dart';
import '../widgets/subs_home_sections.dart';

/// 订阅首页（Tab 2，1:1 对齐 iOS `SubscriptionsView.swift`）：
/// - 全出血沉浸轮播 Hero + 剧照主色 `McAmbientTopGlow` 氛围底色晕染；
/// - 10s 轮询整周日程 + 下载器实时进度，20s 轮询刚刚入库；
/// - 账号隔离 `PageSnapshots` 冷启动秒显。
class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<SubscriptionsPage> {
  int _lastRevision = -1;
  double _scrollOffset = 0;
  Color? _ambientTint;

  Timer? _fastPollTimer; // 10s: today-arrivals + downloadTasks
  Timer? _recentPollTimer; // 20s: recent-arrivals

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionsHomeProvider.notifier).load();
    });
    _fastPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => ref
          .read(subscriptionsHomeProvider.notifier)
          .refreshArrivalsAndTasks(),
    );
    _recentPollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => ref.read(subscriptionsHomeProvider.notifier).refreshRecent(),
    );
  }

  @override
  void dispose() {
    _fastPollTimer?.cancel();
    _recentPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rev = SubscriptionEvents.revision;
    if (rev != _lastRevision) {
      _lastRevision = rev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(subscriptionsHomeProvider.notifier).reload();
      });
    }

    final state = ref.watch(subscriptionsHomeProvider);
    final form = McFormWatch.of(context);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          McAmbientTopGlow(
            tint: _ambientTint,
            scrollOffset: _scrollOffset,
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                setState(() => _scrollOffset = n.metrics.pixels);
              }
              return false;
            },
            child: RefreshIndicator(
              edgeOffset: topPad + 56,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceSolid,
              onRefresh: () =>
                  ref.read(subscriptionsHomeProvider.notifier).reload(),
              child: state.isLoading && !state.hasValue
                  ? const McFeedSkeleton(showHero: true)
                  : state.hasError && !state.hasValue
                      ? _errorState(topPad)
                      : _content(context, state, form, topPad),
            ),
          ),
          // 顶部浮动沉浸标题栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                McPageFog(height: topPad + 72),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    topPad + 6,
                    12,
                    8,
                  ),
                  child: Row(
                    children: [
                      const Text('订阅', style: McText.display),
                      const Spacer(),
                      McGlassIconButton(
                        icon: McIcons.search,
                        tooltip: '搜索',
                        onTap: () => context.push('/search'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(double topPad) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: topPad + 96),
        McErrorView(
          text: McStrings.subsLoadFailed,
          onRetry: () => ref.read(subscriptionsHomeProvider.notifier).reload(),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    AsyncValue<SubsHomeBundle> state,
    McDeviceForm form,
    double topPad,
  ) {
    final bundle = state.valueOrNull;
    if (bundle == null || bundle.subs.isEmpty) {
      return _emptyState(context, topPad);
    }
    final home = bundle.home();
    final wide = form != McDeviceForm.phone;
    final hasSchedule = home.today.isNotEmpty;

    final bodySections = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (home.recent.isNotEmpty) ...[
          const SizedBox(height: 22),
          SubsRecentRow(home: home, now: home.now),
        ],
        if (hasSchedule) ...[
          const SizedBox(height: 28),
          SubsScheduleRow(home: home, now: home.now),
        ],
        const SizedBox(height: 30),
        SubsShelfRow(
          home: home,
          title: McStrings.subsTvShelfTitle,
          kind: 'tv',
          onViewAll: () => context.push('/subscriptions/wall?kind=tv'),
        ),
        const SizedBox(height: 30),
        SubsShelfRow(
          home: home,
          title: McStrings.subsMovieShelfTitle,
          kind: 'movie',
          onViewAll: () => context.push('/subscriptions/wall?kind=movie'),
        ),
        const SizedBox(height: McTokens.bottomBarClearance),
      ],
    );

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      children: [
        SubsHeroCarousel(
          home: home,
          now: home.now,
          scrollOffset: _scrollOffset,
          topClearance: topPad + 58,
          onAmbientColorChanged: (c) {
            if (mounted && c != _ambientTint) {
              setState(() => _ambientTint = c);
            }
          },
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 880 : double.infinity),
            child: bodySections,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, double topPad) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: topPad + 96),
        McEmptyView(
          icon: McIcons.bookmark,
          title: McStrings.subsEmptyTitle,
          text: McStrings.subsEmptyBody,
          actionLabel: McStrings.subsGoDiscover,
          onRetry: () => MainTabBus.instance.open(MainTab.discover),
        ),
      ],
    );
  }
}
