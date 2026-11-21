import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../state/subscription_events.dart';
import '../widgets/subs_home_sections.dart';

/// 订阅首页（逐块对齐鸿蒙 SubscriptionsPage.ets）：
/// 失败（重试）/ 空态（去发现）/ 内容（Hero 轮播 → 刚刚入库 → 日程 →
/// 剧集订阅 → 电影订阅）。手机单列；平板/TV 居中加宽。
class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<SubscriptionsPage> {
  int _lastRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionsHomeProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // SubscriptionEvents.revision 变化（新建 / 取消订阅）→ 重拉首页数据
    final rev = SubscriptionEvents.revision;
    if (rev != _lastRevision) {
      _lastRevision = rev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(subscriptionsHomeProvider.notifier).reload();
      });
    }

    final state = ref.watch(subscriptionsHomeProvider);
    final form = McFormWatch.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(subscriptionsHomeProvider.notifier).reload(),
        child: state.isLoading
            ? const McLoadingView()
            : state.hasError
                ? _errorState()
                : _content(context, state, form),
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      children: [
        const SizedBox(height: 96),
        McErrorView(
          text: McStrings.subsLoadFailed,
          onRetry: () => ref.read(subscriptionsHomeProvider.notifier).reload(),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, AsyncValue<SubsHomeBundle> state,
      McDeviceForm form) {
    final bundle = state.valueOrNull;
    if (bundle == null || bundle.subs.isEmpty) return _emptyState(context);
    final home = bundle.home();
    final wide = form != McDeviceForm.phone;
    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SubsHeroCarousel(home: home, now: home.now),
        const SizedBox(height: 36),
        SubsRecentRow(home: home, now: home.now),
        const SizedBox(height: 36),
        SubsScheduleRow(home: home, now: home.now),
        const SizedBox(height: 36),
        SubsShelfRow(
          home: home,
          title: McStrings.subsTvShelfTitle,
          kind: 'tv',
          onViewAll: () => context.push('/subscriptions/wall?kind=tv'),
        ),
        const SizedBox(height: 36),
        SubsShelfRow(
          home: home,
          title: McStrings.subsMovieShelfTitle,
          kind: 'movie',
          onViewAll: () => context.push('/subscriptions/wall?kind=movie'),
        ),
        const SizedBox(height: 36),
      ],
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // 平板/TV 居中加宽
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 720 : double.infinity),
            child: sections,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(McIcons.bookmark,
            size: 34, color: theme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        const Center(
          child: Text(McStrings.subsEmptyTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(McStrings.subsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.onSurface.withValues(alpha: 0.55))),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: () => context.push('/discover'),
            child: const Text(McStrings.subsGoDiscover),
          ),
        ),
      ],
    );
  }
}
