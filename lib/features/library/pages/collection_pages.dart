import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../routes.dart';
import '../state/collection_detail_controller.dart';
import '../state/models.dart';
import '../widgets/library_widgets.dart';

/// 合集详情页（封面拼贴头 + 条目墙 + 本地排序 + 重命名/可见性/移除条目/删除合集）。
class CollectionDetailPage extends ConsumerStatefulWidget {
  const CollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<CollectionDetailPage> createState() =>
      _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  CollectionDetailArg get _arg =>
      CollectionDetailArg(collectionId: widget.collectionId);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(collectionDetailProvider(_arg).notifier));
  }

  Future<void> _rename(CollectionView c) async {
    final ctrl = TextEditingController(text: c.name);
    final next = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('重命名合集', style: McText.titleSm),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: McText.body,
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 18),
            McActionPill(
              label: '保存',
              primary: true,
              expanded: true,
              onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (next == null || next.isEmpty || next == c.name || !mounted) return;
    try {
      await ref.read(collectionDetailProvider(_arg).notifier).rename(next);
      if (mounted) McToast.success('已重命名合集');
    } catch (e) {
      if (mounted) McToast.error('重命名失败：$e');
    }
  }

  Future<void> _openMore(CollectionView c) async {
    final act = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.edit,
                  title: '重命名合集',
                  onTap: () => Navigator.of(ctx).pop('rename'),
                ),
                McInsetRow(
                  icon: c.visibility == 'private'
                      ? McIcons.team
                      : McIcons.lock,
                  title: c.visibility == 'private'
                      ? '设为家庭成员共享可见'
                      : '设为仅自己可见',
                  onTap: () => Navigator.of(ctx).pop('visibility'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.trash2,
                  title: '删除此合集',
                  destructive: true,
                  onTap: () => Navigator.of(ctx).pop('delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || act == null) return;
    if (act == 'rename') {
      await _rename(c);
    } else if (act == 'visibility') {
      try {
        await ref
            .read(collectionDetailProvider(_arg).notifier)
            .toggleVisibility();
        if (mounted) McToast.success('已切换合集可见性');
      } catch (e) {
        if (mounted) McToast.error('操作失败：$e');
      }
    } else if (act == 'delete') {
      try {
        await ref.read(collectionDetailProvider(_arg).notifier).deleteSelf();
        ref.read(collectionsProvider.notifier).load();
        if (mounted) {
          McToast.success('合集已删除');
          context.canPop() ? context.pop() : context.go('/home');
        }
      } catch (e) {
        if (mounted) McToast.error('删除失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionDetailProvider(_arg));
    final c = state.collection;
    final form = McFormWatch.of(context);
    final canRemoveItem = c != null && c.editable && !c.ruleDriven;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: c?.name ?? '合集',
            titleVisible: true,
            trailing: [
              McGlassIconButton(
                icon: McIcons.sort,
                tooltip: '排序',
                onTap: () => _openSortSheet(context, state),
              ),
              if (c != null && c.editable) ...[
                const SizedBox(width: 6),
                McGlassIconButton(
                  icon: McIcons.more,
                  tooltip: '管理合集',
                  onTap: () => _openMore(c),
                ),
              ],
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(collectionDetailProvider(_arg).notifier).reload(),
              child: state.loading && state.items.isEmpty
                  ? const McLoadingView()
                  : state.error != null && state.items.isEmpty
                      ? McErrorView(
                          text: state.error!,
                          onRetry: () => ref
                              .read(collectionDetailProvider(_arg).notifier)
                              .reload(),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >
                                n.metrics.maxScrollExtent - 400) {
                              ref
                                  .read(collectionDetailProvider(_arg).notifier)
                                  .loadMore();
                            }
                            return false;
                          },
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (c != null)
                                SliverToBoxAdapter(
                                  child: _header(context, c, state),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  McTokens.pagePadding,
                                  12,
                                  McTokens.pagePadding,
                                  32,
                                ),
                                sliver: state.items.isEmpty
                                    ? const SliverToBoxAdapter(
                                        child: McEmptyView(text: '合集还没有条目'),
                                      )
                                    : SliverGrid(
                                        gridDelegate: form == McDeviceForm.phone
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
                                                    width: MediaQuery.widthOf(
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
                                        delegate: SliverChildBuilderDelegate(
                                          (context, i) {
                                            final it = state.items[i];
                                            return mcItemCard(
                                              context,
                                              it,
                                              width: null,
                                              fallbackLibraryId: c?.libraryId,
                                              extraActions: [
                                                if (canRemoveItem)
                                                  McPosterMenuAction(
                                                    icon: McIcons.trash2,
                                                    label: '从合集中移除',
                                                    destructive: true,
                                                    onTap: () async {
                                                      await ref
                                                          .read(
                                                            collectionDetailProvider(
                                                              _arg,
                                                            ).notifier,
                                                          )
                                                          .removeItem(
                                                            it.mediaItemId,
                                                          );
                                                      if (context.mounted) {
                                                        McToast.success(
                                                          '已从合集中移除',
                                                        );
                                                      }
                                                    },
                                                  ),
                                              ],
                                            );
                                          },
                                          childCount: state.items.length,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    CollectionView c,
    CollectionDetailState state,
  ) {
    final covers =
        c.covers.map((e) => e.url).where((u) => u.isNotEmpty).toList();
    final visLabel = c.visibility == 'private' ? '仅自己可见' : '家庭共享';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (covers.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              children: [
                for (final url in covers)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(McTokens.radiusSm),
                      child: CachedNetworkImage(
                        imageUrl: McImageUrls.resolve(url, widthPx: 480),
                        httpHeaders: mcImageHeaders(),
                        width: 180,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: McTokens.posterPlaceholder,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            McTokens.pagePadding,
            12,
            McTokens.pagePadding,
            0,
          ),
          child: Text(
            '${state.items.isNotEmpty ? state.items.length : c.itemCount} 部 · ${_sortLabel(state.sort)} · $visLabel${c.ruleDriven ? ' · 智能规则' : ''}',
            style: McText.caption.muted,
          ),
        ),
      ],
    );
  }

  String _sortLabel(String sort) => switch (sort) {
        'title' => '按名称',
        'release_date' => '按上映日期',
        'rating' => '按评分',
        'random' => '随机',
        _ => '按添加时间',
      };

  void _openSortSheet(BuildContext context, CollectionDetailState state) {
    const options = <(String, String)>[
      ('added_at', '按添加时间'),
      ('title', '按名称'),
      ('release_date', '按上映日期'),
      ('rating', '按评分'),
      ('random', '随机'),
    ];
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '排序方式',
          margin: EdgeInsets.zero,
          children: [
            for (final (value, label) in options)
              McInsetRow(
                title: label,
                trailing: state.sort == value
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(collectionDetailProvider(_arg).notifier)
                      .setSort(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 「合集」入口页：合集清单 + 新建合集 + 删除。
class LibraryCollectionsPage extends ConsumerStatefulWidget {
  const LibraryCollectionsPage({super.key});

  @override
  ConsumerState<LibraryCollectionsPage> createState() =>
      _LibraryCollectionsPageState();
}

class _LibraryCollectionsPageState
    extends ConsumerState<LibraryCollectionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(collectionsProvider.notifier).load());
  }

  Future<void> _createCollection() async {
    final ctrl = TextEditingController();
    var visibility = 'household';
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('新建片单合集', style: McText.titleSm),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: McText.body,
                decoration: const InputDecoration(hintText: '合集名称，例如「周末必看」'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  McChip(
                    label: '家庭共享',
                    icon: McIcons.team,
                    compact: true,
                    selected: visibility == 'household',
                    onTap: () => setSheet(() => visibility = 'household'),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '仅自己可见',
                    icon: McIcons.lock,
                    compact: true,
                    selected: visibility == 'private',
                    onTap: () => setSheet(() => visibility = 'private'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              McActionPill(
                label: '创建合集',
                icon: McIcons.addS,
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty || !mounted) return;
    try {
      final created = await ref
          .read(collectionsProvider.notifier)
          .create(name: name, visibility: visibility);
      if (mounted) {
        McToast.success('已创建合集「$name」');
        context.push(routeLibraryCollection(created.id));
      }
    } catch (e) {
      if (mounted) McToast.error('创建失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsProvider);
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '全部合集',
            titleVisible: true,
            trailing: [
              McGlassIconButton(
                icon: McIcons.addS,
                tooltip: '新建合集',
                onTap: _createCollection,
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(collectionsProvider.notifier).load(),
              child: state.loading && state.collections.isEmpty
                  ? const McLoadingView()
                  : state.collections.isEmpty
                      ? McEmptyView(
                          icon: McIcons.stack,
                          title: '还没有合集',
                          text: '点击右上角 + 创建你的第一个片单合集，或在媒体库筛选后保存智能合集。',
                          actionLabel: '新建合集',
                          onRetry: _createCollection,
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 32),
                          children: [
                            McInsetGroup(
                              dividerIndent: 72,
                              children: [
                                for (final c in state.collections)
                                  McInsetRow(
                                    leading: _coverThumb(c),
                                    title: c.name,
                                    subtitle:
                                        '${c.itemCount} 部${c.ruleDriven ? ' · 智能规则' : ''}${c.visibility == 'private' ? ' · 私密' : ''}',
                                    trailing: c.editable
                                        ? IconButton(
                                            tooltip: '删除合集',
                                            icon: const Icon(
                                              McIcons.trash2,
                                              size: 17,
                                              color: McTokens.textFaint,
                                            ),
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                    collectionsProvider
                                                        .notifier,
                                                  )
                                                  .delete(c.id);
                                              if (context.mounted) {
                                                McToast.success('已删除合集');
                                              }
                                            },
                                          )
                                        : null,
                                    onTap: () => context
                                        .push(routeLibraryCollection(c.id))
                                        .then((_) {
                                          if (mounted) {
                                            ref
                                                .read(
                                                  collectionsProvider.notifier,
                                                )
                                                .load();
                                          }
                                        }),
                                  ),
                              ],
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverThumb(CollectionView c) {
    final url = c.covers.isEmpty ? null : c.covers.first.url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(McTokens.radiusSm),
      child: SizedBox(
        width: 44,
        height: 60,
        child: url == null || url.isEmpty
            ? const ColoredBox(color: McTokens.posterPlaceholder)
            : CachedNetworkImage(
                imageUrl: McImageUrls.resolve(url, widthPx: 480),
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: McTokens.posterPlaceholder),
              ),
      ),
    );
  }
}
