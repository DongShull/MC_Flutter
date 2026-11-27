import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/collection_detail_controller.dart';
import '../state/home_rows.dart';
import '../state/models.dart';
import '../state/person_kind_controllers.dart';
import '../widgets/library_shared.dart';
import '../widgets/library_widgets.dart';

/* ────────────────────── 影人详情页（GET /api/v1/people/{tmdbPersonId}） ────────────────────── */

/// 影人作品页：2:3 头像页头 + 原名 + 分组展示「参演（含角色名）」与「执导」，404 友好空态。
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
    final person = state.person;
    final displayName = (person?.name.isNotEmpty == true)
        ? person!.name
        : (widget.personName ?? '影人作品');

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: displayName,
            titleVisible: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(personProvider(_arg).notifier).load(),
              child: state.loading && person == null
                  ? const McLoadingView()
                  : state.notFound
                      ? McEmptyView(
                          icon: McIcons.team,
                          title: '库内暂无该影人作品',
                          text: '当前媒体库中没有收录 ${widget.personName ?? '该影人'} 的参演或执导影片。',
                          actionLabel: '返回媒体库',
                          onRetry: () => context.go('/home'),
                        )
                      : state.error != null && person == null
                          ? McErrorView(
                              text: state.error!,
                              onRetry: () => ref
                                  .read(personProvider(_arg).notifier)
                                  .load(),
                            )
                          : CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                if (person != null)
                                  SliverToBoxAdapter(
                                    child: _personHeader(person),
                                  ),
                                if (person != null &&
                                    person.acted.isEmpty &&
                                    person.directed.isEmpty)
                                  const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: McEmptyView(
                                      icon: McIcons.film,
                                      title: '库内暂无相关作品',
                                      text: '该影人名下目前没有已入库影片。',
                                    ),
                                  ),
                                if (person != null &&
                                    person.acted.isNotEmpty) ...[
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        McTokens.pagePadding,
                                        18,
                                        McTokens.pagePadding,
                                        10,
                                      ),
                                      child: Text(
                                        '参演 · ${person.acted.length} 部',
                                        style: McText.titleSm,
                                      ),
                                    ),
                                  ),
                                  _creditGrid(
                                    context,
                                    person.acted,
                                    form,
                                    showRole: true,
                                  ),
                                ],
                                if (person != null &&
                                    person.directed.isNotEmpty) ...[
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        McTokens.pagePadding,
                                        24,
                                        McTokens.pagePadding,
                                        10,
                                      ),
                                      child: Text(
                                        '执导 · ${person.directed.length} 部',
                                        style: McText.titleSm,
                                      ),
                                    ),
                                  ),
                                  _creditGrid(
                                    context,
                                    person.directed,
                                    form,
                                    showRole: false,
                                  ),
                                ],
                                const SliverPadding(
                                  padding: EdgeInsets.only(bottom: 36),
                                ),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personHeader(PersonView p) {
    final initial = p.name.trim().isNotEmpty ? p.name.trim()[0] : '?';
    final stats = [
      if (p.acted.isNotEmpty) '参演 ${p.acted.length} 部',
      if (p.directed.isNotEmpty) '执导 ${p.directed.length} 部',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        10,
        McTokens.pagePadding,
        6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 108, // 2:3 头像比例
              child: (p.profileUrl != null && p.profileUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: McImageUrls.resolve(p.profileUrl, widthPx: 240),
                      httpHeaders: mcImageHeaders(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(initial),
                    )
                  : _avatarFallback(initial),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: McText.titleLg),
                if (p.originalName != null &&
                    p.originalName!.trim().isNotEmpty &&
                    p.originalName!.trim() != p.name.trim()) ...[
                  const SizedBox(height: 3),
                  Text(
                    p.originalName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: McText.sub.muted,
                  ),
                ],
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(stats.join(' · '), style: McText.caption.faint),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) => Container(
        color: McTokens.posterPlaceholder,
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: McTokens.textMuted,
          ),
        ),
      );

  Widget _creditGrid(
    BuildContext context,
    List<PersonCreditView> credits,
    McDeviceForm form, {
    required bool showRole,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
      sliver: SliverGrid(
        gridDelegate: form == McDeviceForm.phone
            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.49,
              )
            : SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: mcGridCrossAxisCount(
                  form,
                  BoxConstraints.tightFor(
                    width: MediaQuery.widthOf(context) - 32,
                  ),
                  cellExtent: 130,
                ),
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.49,
              ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final c = credits[i];
            final roleText = showRole && c.character != null && c.character!.isNotEmpty
                ? '饰 ${c.character}'
                : (c.year != null ? '${c.year}' : null);
            return GestureDetector(
              onTap: () =>
                  context.push('/detail/${c.libraryId}/${c.mediaItemId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(McTokens.posterRadius),
                      child: LibraryNetImage(
                        url: c.posterUrl,
                        widthPx: 360,
                        placeholderIcon:
                            c.kind == 'tv' ? McIcons.tv : McIcons.movie,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.body.copyWith(fontSize: 13),
                  ),
                  if (roleText != null)
                    Text(
                      roleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption.faint,
                    ),
                ],
              ),
            );
          },
          childCount: credits.length,
        ),
      ),
    );
  }
}

/* ────────────────────── 跨库类型墙页（movie / tv / video） ────────────────────── */

/// 跨库类型墙页（完整对齐 iOS `LibraryKindWallView`）：
/// - 支持 `movie` / `tv` / `video`（其他视频自动 16:9 宽卡并裁剪无意义的评分/上映时间排序）；
/// - 支持 `?g=` 初始类型、`?w=` 4 态观看过滤（全部/未看/未看完/看过）+ 空态一键清除；
/// - 排序方向升降序切换 + 按 kind 本机持久化排序偏好。
class KindWallPage extends ConsumerStatefulWidget {
  const KindWallPage({
    super.key,
    required this.kind,
    this.initialGenre,
    this.initialWatch,
    this.initialSort,
    this.initialOrder,
  });

  final String kind;
  final String? initialGenre;
  final String? initialWatch;
  final String? initialSort;
  final String? initialOrder;

  @override
  ConsumerState<KindWallPage> createState() => _KindWallPageState();
}

class _KindWallPageState extends ConsumerState<KindWallPage> {
  KindWallArg get _arg => KindWallArg(
        kind: widget.kind,
        initialGenre: widget.initialGenre,
        initialWatch: widget.initialWatch,
        initialSort: widget.initialSort,
        initialOrder: widget.initialOrder,
      );

  static const _watchOptions = <(String?, String)>[
    (null, '全部'),
    ('unwatched', '未看'),
    ('unfinished', '未看完'),
    ('seen', '已看'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(kindWallProvider(_arg).notifier));
  }

  void _openSortSheet(KindWallState state) {
    final options = KindWallController.sortOptionsFor(widget.kind);
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '排序方式',
          margin: EdgeInsets.zero,
          children: [
            for (final opt in options)
              McInsetRow(
                title: opt.label,
                subtitle: state.sort == opt.value
                    ? opt.directionLabel(reversed: state.reversed)
                    : null,
                trailing: state.sort == opt.value
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  ref.read(kindWallProvider(_arg).notifier).setSort(opt.value);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _titleFor(KindWallState state) {
    if (state.genre != null && state.genre!.isNotEmpty) {
      final gid = int.tryParse(state.genre!);
      if (gid != null && HomeRows.genreNames.containsKey(gid)) {
        return HomeRows.genreNames[gid]!;
      }
      for (final g in state.genres) {
        if (g.value == state.genre) return g.label;
      }
    }
    return '全部${HomeRows.mediaKindLabel(widget.kind)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kindWallProvider(_arg));
    final notifier = ref.read(kindWallProvider(_arg).notifier);
    final total = state.summary?.itemCount ?? state.items.length;
    final libCount = state.summary?.libraryIds.length ?? 0;
    final form = McFormWatch.of(context);
    final wide = widget.kind == 'video';
    final sortMeta = wallSortMetaOf(state.sort);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: _titleFor(state),
            titleVisible: true,
            trailing: [
              McGlassIconButton(
                icon: McIcons.sort,
                tooltip: '排序',
                onTap: () => _openSortSheet(state),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.reload,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 页头计数 + 排序胶囊与升降序按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      McTokens.pagePadding,
                      4,
                      McTokens.pagePadding,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libCount > 0
                              ? '$total 部${HomeRows.mediaKindLabel(widget.kind)} · 来自 $libCount 个媒体库（同片去重）'
                              : '$total 部${HomeRows.mediaKindLabel(widget.kind)}',
                          style: McText.caption.muted,
                        ),
                        const SizedBox(height: 10),
                        // 4 态观看过滤条
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (wVal, wLabel) in _watchOptions)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: McChip(
                                    label: wLabel,
                                    compact: true,
                                    selected: state.watch == wVal,
                                    onTap: () => notifier.setWatch(wVal),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              McChip(
                                label: sortMeta.label,
                                icon: McIcons.sort,
                                compact: true,
                                onTap: () => _openSortSheet(state),
                              ),
                              const SizedBox(width: 6),
                              McChip(
                                label: sortMeta.directionLabel(
                                  reversed: state.reversed,
                                ),
                                icon: state.reversed
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                compact: true,
                                selected: state.reversed,
                                onTap: notifier.toggleDirection,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 类型横滚筛选条（非 video 时展示）
                  if (!wide && state.genres.isNotEmpty)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: McTokens.pagePadding,
                          vertical: 2,
                        ),
                        children: [
                          for (final g in state.genres)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: McChip(
                                label: '${g.label} ${g.count}',
                                selected: state.genre == g.value,
                                compact: true,
                                onTap: () => notifier.setGenre(
                                  state.genre == g.value ? null : g.value,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 4),
                  Expanded(
                    child: state.loading && state.items.isEmpty
                        ? const McLoadingView()
                        : state.error != null && state.items.isEmpty
                            ? McErrorView(
                                text: state.error!,
                                onRetry: notifier.reload,
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n.metrics.pixels >
                                      n.metrics.maxScrollExtent - 400) {
                                    notifier.loadMore();
                                  }
                                  return false;
                                },
                                child: state.items.isEmpty
                                    ? McEmptyView(
                                        icon: McIcons.filter,
                                        title: state.watch != null
                                            ? HomeRows.watchEmptyTitle(
                                                state.watch!,
                                              )
                                            : '没有符合条件的媒体',
                                        text: state.watch != null
                                            ? '当前观看状态筛选下没有匹配作品，可一键恢复查看全部。'
                                            : '尝试更换其他类型或排序条件。',
                                        actionLabel: (state.watch != null ||
                                                state.genre != null)
                                            ? '清除筛选'
                                            : null,
                                        onRetry: (state.watch != null ||
                                                state.genre != null)
                                            ? () async {
                                                await notifier.setWatch(null);
                                                if (state.genre != null) {
                                                  await notifier.setGenre(null);
                                                }
                                              }
                                            : null,
                                      )
                                    : GridView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          McTokens.pagePadding,
                                          8,
                                          McTokens.pagePadding,
                                          36,
                                        ),
                                        gridDelegate: wide
                                            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 220,
                                                mainAxisSpacing: 16,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 1.28,
                                              )
                                            : form == McDeviceForm.phone
                                                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                                    maxCrossAxisExtent: 130,
                                                    mainAxisSpacing: 14,
                                                    crossAxisSpacing: 12,
                                                    childAspectRatio: 0.515,
                                                  )
                                                : SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount:
                                                        mcGridCrossAxisCount(
                                                      form,
                                                      BoxConstraints.tightFor(
                                                        width: MediaQuery
                                                                .widthOf(
                                                              context,
                                                            ) -
                                                            32,
                                                      ),
                                                      cellExtent: 130,
                                                    ),
                                                    mainAxisSpacing: 14,
                                                    crossAxisSpacing: 12,
                                                    childAspectRatio: 0.515,
                                                  ),
                                        itemCount: state.items.length,
                                        itemBuilder: (context, i) => mcItemCard(
                                          context,
                                          state.items[i],
                                          width: null,
                                          frameAspect: wide
                                              ? 16 / 9
                                              : McTokens.posterAspect,
                                          showRating: state.sort == 'rating',
                                        ),
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
