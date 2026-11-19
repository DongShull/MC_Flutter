import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../state/subscription_events.dart';
import '../widgets/sub_card.dart';

/// 订阅列表页（对齐设计文档 04 §5.1 与 SubsHomeScreen 的订阅墙区）：
/// kind 筛选 + 海报卡片（状态徽标 + 进度）+ 按最近活动倒序；点卡片进详情；
/// 「查看全部」进订阅墙。
class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<SubscriptionsPage> {
  String? _kind;
  int _lastRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionsListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // SubscriptionEvents.revision 变化（取消 / 新建）→ 重拉列表
    final rev = SubscriptionEvents.revision;
    if (rev != _lastRevision) {
      _lastRevision = rev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(subscriptionsListProvider.notifier).reload();
      });
    }

    final state = ref.watch(subscriptionsListProvider);
    final subs = state.value ?? const <SubscriptionView>[];
    final form = McFormWatch.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅'),
        actions: [
          IconButton(
            tooltip: '剧集订阅墙',
            icon: const Icon(Icons.tv_outlined),
            onPressed: () => context.push('/subscriptions/wall?kind=tv'),
          ),
          IconButton(
            tooltip: '电影订阅墙',
            icon: const Icon(Icons.movie_outlined),
            onPressed: () => context.push('/subscriptions/wall?kind=movie'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(subscriptionsListProvider.notifier).reload(),
        child: Column(
          children: [
            // kind 筛选
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final (label, value) in [
                    ('全部', null),
                    ('剧集', 'tv'),
                    ('电影', 'movie'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _kind == value,
                        onSelected: (_) {
                          setState(() => _kind = value);
                          ref.read(subscriptionsListProvider.notifier).load(kind: value);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading && subs.isEmpty
                  ? const McLoadingView()
                  : state.hasError
                      ? ListView(
                          children: [
                            const SizedBox(height: 48),
                            McErrorView(text: '${state.error}'),
                          ],
                        )
                      : subs.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 48),
                                Center(child: Text('还没有订阅')),
                              ],
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              // 平板/TV 自适应列数；手机保持现有密度不变。
                              gridDelegate: form == McDeviceForm.phone
                                  ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 150,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 126 / 240,
                                    )
                                  : SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: mcGridCrossAxisCount(
                                          form,
                                          BoxConstraints.tightFor(
                                              width:
                                                  MediaQuery.widthOf(context) - 24),
                                      cellExtent: 150),
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 126 / 240,
                                    ),
                              itemCount: subs.length,
                              itemBuilder: (context, i) {
                                final sub = subs[i];
                                return McFocusRing(
                                  borderRadius: 10,
                                  child: SubCard(
                                    sub: sub,
                                    onTap: () =>
                                        context.push('/subscriptions/detail/${sub.id}'),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
