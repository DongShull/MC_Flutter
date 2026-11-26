import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart' show DiscTitle;

/// TMDB 影人页状态（GET /discover/people/{tmdbPersonId}）。
class PersonState {
  const PersonState({
    this.loading = true,
    this.error,
    this.name,
    this.titles = const [],
  });

  final bool loading;
  final String? error;
  final String? name;
  final List<DiscTitle> titles;

  PersonState copyWith({
    bool? loading,
    Object? error = _sentinel,
    String? name,
    List<DiscTitle>? titles,
  }) =>
      PersonState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        name: name ?? this.name,
        titles: titles ?? this.titles,
      );

  static const _sentinel = Object();
}

class PersonController extends AutoDisposeFamilyNotifier<PersonState, int> {
  McClient? _client;
  McClient get _mc =>
      _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  PersonState build(int personId) {
    Future.microtask(() => load(personId));
    return const PersonState();
  }

  Future<void> load([int? overrideId]) async {
    final personId = overrideId ?? arg;
    if (personId <= 0) {
      state = state.copyWith(loading: false, error: '缺少人物 id');
      return;
    }
    state = const PersonState();
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/people/$personId',
      );
      final titles = <DiscTitle>[];
      for (final el in (raw['titles'] as List<dynamic>? ?? const [])) {
        if (el is Map) {
          final t = DiscTitle.fromJson(Map<String, dynamic>.from(el));
          if (t != null) titles.add(t);
        }
      }
      state = state.copyWith(
        loading: false,
        name: (raw['name'] ?? '').toString(),
        titles: titles,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络错误，请稍后重试');
    }
  }
}

final personProvider = NotifierProvider.autoDispose
    .family<PersonController, PersonState, int>(PersonController.new);

/// 发现侧影人作品墙（纯黑底 + 浮动返回顶栏 + 独立大字标题头 + 自适应海报墙）。
class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  double _scrollOffset = 0;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(personProvider(widget.personId));
    final topPad = MediaQuery.paddingOf(context).top;
    final form = McFormWatch.of(context);
    final pad = form == McDeviceForm.phone
        ? McTokens.pagePadding
        : McTokens.pagePaddingWide;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (s.loading)
            const McFeedSkeleton(showHero: false)
          else if (s.error != null)
            McErrorView(
              text: s.error!,
              onRetry: () =>
                  ref.read(personProvider(widget.personId).notifier).load(),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = mcGridCrossAxisCount(
                  form,
                  constraints,
                  cellExtent: 122,
                );
                final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.54,
                );
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                      setState(() => _scrollOffset = n.metrics.pixels);
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            topPad + 60,
                            pad,
                            18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name ?? '影人', style: McText.display),
                              const SizedBox(height: 4),
                              Text(
                                '共 ${s.titles.length} 部影视作品',
                                style: McText.caption.muted.tabular,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (s.titles.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: McEmptyView(text: '暂无相关影视作品'),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, 48),
                          sliver: SliverGrid(
                            gridDelegate: gridDelegate,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final t = s.titles[i];
                                return McFocusRing(
                                  borderRadius: McTokens.posterRadius,
                                  child: McPosterCard(
                                    title: t.title,
                                    posterUrl: t.posterUrl,
                                    width: null,
                                    subtitle: t.year?.toString(),
                                    rating: (t.rating ?? 0) > 0
                                        ? t.rating
                                        : null,
                                    badge: t.owned ? '在库' : null,
                                    badgeDotColor: t.owned ? McTokens.ok : null,
                                    onTap: () =>
                                        feat_discover.pushTitle(context, t.ref),
                                    contextActions: [
                                      McPosterMenuAction(
                                        icon: McIcons.film,
                                        label: '查看详情',
                                        onTap: () => feat_discover.pushTitle(
                                          context,
                                          t.ref,
                                        ),
                                      ),
                                      McPosterMenuAction(
                                        icon: McIcons.bookmarkFill,
                                        label: '订阅影片',
                                        onTap: () => showSubscribeSheet(
                                          context,
                                          ref,
                                          titleRef: t.ref,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: s.titles.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: _back,
              title: s.name ?? '影人',
              titleVisible: _scrollOffset > 56,
            ),
          ),
        ],
      ),
    );
  }
}
