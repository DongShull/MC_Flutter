import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/person_kind_controllers.dart';
import '../widgets/library_widgets.dart';

/// 人物下钻页（对齐 Kotlin LibraryPersonScreen.kt）：
/// GET /search/library?person_id 游标分页的网格。
class LibraryPersonPage extends ConsumerStatefulWidget {
  const LibraryPersonPage({
    super.key,
    required this.personId,
    this.personName,
  });

  final int personId;
  final String? personName;

  @override
  ConsumerState<LibraryPersonPage> createState() => _LibraryPersonPageState();
}

class _LibraryPersonPageState extends ConsumerState<LibraryPersonPage> {
  PersonArg get _arg =>
      PersonArg(personId: widget.personId, personName: widget.personName);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(personProvider(_arg).notifier));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personProvider(_arg));
    final form = McFormWatch.of(context);
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: widget.personName ?? '相关作品',
            titleVisible: true,
          ),
          Expanded(
            child: state.loading && state.items.isEmpty
                ? const McLoadingView()
                : state.error != null && state.items.isEmpty
                    ? McErrorView(
                        text: state.error!,
                        onRetry: () =>
                            ref.read(personProvider(_arg).notifier).load(),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >
                              n.metrics.maxScrollExtent - 400) {
                            ref.read(personProvider(_arg).notifier).loadMore();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (state.indexPending)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: McTokens.pagePadding,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '正在为相关内容建索引，结果可能不完整',
                                    style: McText.caption.muted,
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                8,
                                McTokens.pagePadding,
                                32,
                              ),
                              sliver: state.items.isEmpty
                                  ? const SliverToBoxAdapter(
                                      child: McEmptyView(text: '没有找到相关作品'),
                                    )
                                  : SliverGrid(
                                      gridDelegate: form == McDeviceForm.phone
                                          ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 130,
                                              mainAxisSpacing: 14,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 0.55,
                                            )
                                          : SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount:
                                                  mcGridCrossAxisCount(
                                                form,
                                                BoxConstraints.tightFor(
                                                  width: MediaQuery.widthOf(
                                                        context,
                                                      ) -
                                                      32,
                                                ),
                                                cellExtent: 130,
                                              ),
                                              mainAxisSpacing: 14,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 0.55,
                                            ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, i) => mcItemCard(
                                          context,
                                          state.items[i].item,
                                        ),
                                        childCount: state.items.length,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// 类型墙页（对齐 Kotlin KindWallScreen.kt）：跨库 kind + 类型/观看筛选 + 排序。
class KindWallPage extends ConsumerStatefulWidget {
  const KindWallPage({super.key, required this.kind});

  final String kind;

  @override
  ConsumerState<KindWallPage> createState() => _KindWallPageState();
}

class _KindWallPageState extends ConsumerState<KindWallPage> {
  KindWallArg get _arg => KindWallArg(kind: widget.kind);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(kindWallProvider(_arg).notifier));
  }

  void _openWatchSheet(KindWallState state) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '观看过滤',
          margin: EdgeInsets.zero,
          children: [
            for (final (v, label) in const <(String?, String)>[
              (null, '全部'),
              ('unwatched', '未看'),
            ])
              McInsetRow(
                title: label,
                trailing: state.watch == v
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  ref.read(kindWallProvider(_arg).notifier).setWatch(v);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openSortSheet(KindWallState state) {
    const sorts = <(String, String)>[
      ('added_at', '按添加时间'),
      ('title', '按名称'),
      ('release_date', '按上映日期'),
      ('rating', '按评分'),
      ('random', '随机'),
    ];
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '排序方式',
          margin: EdgeInsets.zero,
          children: [
            for (final (v, label) in sorts)
              McInsetRow(
                title: label,
                trailing: state.sort == v
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  ref.read(kindWallProvider(_arg).notifier).setSort(v, null);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kindWallProvider(_arg));
    final total = state.summary?.itemCount ?? 0;
    final form = McFormWatch.of(context);
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '${widget.kind == 'movie' ? '电影' : '剧集'} · $total 部',
            titleVisible: true,
            trailing: [
              McGlassIconButton(
                icon: McIcons.eyeOpen,
                tooltip: '观看过滤',
                badgeColor: state.watch != null ? McTokens.accentStrong : null,
                onTap: () => _openWatchSheet(state),
              ),
              const SizedBox(width: 6),
              McGlassIconButton(
                icon: McIcons.sort,
                tooltip: '排序',
                onTap: () => _openSortSheet(state),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(kindWallProvider(_arg).notifier).reload(),
              child: Column(
                children: [
                  if (state.genres.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: McTokens.pagePadding,
                          vertical: 5,
                        ),
                        children: [
                          for (final g in state.genres)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Builder(
                                builder: (_) {
                                  final val =
                                      (g['id'] ?? g['value'] ?? '').toString();
                                  final selected = state.genre == val;
                                  return McChip(
                                    label:
                                        (g['name'] ?? g['label'] ?? '')
                                            .toString(),
                                    selected: selected,
                                    compact: true,
                                    onTap: () => ref
                                        .read(kindWallProvider(_arg).notifier)
                                        .setGenre(selected ? null : val),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: state.loading && state.items.isEmpty
                        ? const McLoadingView()
                        : state.error != null && state.items.isEmpty
                            ? McErrorView(
                                text: state.error!,
                                onRetry: () => ref
                                    .read(kindWallProvider(_arg).notifier)
                                    .reload(),
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n.metrics.pixels >
                                      n.metrics.maxScrollExtent - 400) {
                                    ref
                                        .read(kindWallProvider(_arg).notifier)
                                        .loadMore();
                                  }
                                  return false;
                                },
                                child: state.items.isEmpty
                                    ? const McEmptyView(text: '没有符合条件的媒体')
                                    : GridView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          McTokens.pagePadding,
                                          8,
                                          McTokens.pagePadding,
                                          32,
                                        ),
                                        gridDelegate: form == McDeviceForm.phone
                                            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 130,
                                                mainAxisSpacing: 14,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 0.55,
                                              )
                                            : SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    mcGridCrossAxisCount(
                                                  form,
                                                  BoxConstraints.tightFor(
                                                    width: MediaQuery.widthOf(
                                                          context,
                                                        ) -
                                                        32,
                                                  ),
                                                  cellExtent: 130,
                                                ),
                                                mainAxisSpacing: 14,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 0.55,
                                              ),
                                        itemCount: state.items.length,
                                        itemBuilder: (context, i) =>
                                            mcItemCard(context, state.items[i]),
                                      ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
