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
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../routes.dart';
import '../state/collection_detail_controller.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/gallery_wall_view.dart';
import '../widgets/library_shared.dart';
import '../widgets/library_widgets.dart';

/* ────────────────────── 合集详情页 ────────────────────── */

/// 合集详情页（完整对齐 iOS `CollectionDetailView`）：
/// - 系列合集：展示「已有 X / 共 Y 部」，并在默认正序下将未入库作品按上映时间穿插为虚线灰卡
///   （点按/长按直达 `showSubscribeSheet`）；
/// - 智能规则合集：规则摘要胶囊 + 规则详情弹层 + 行内规则编辑器（`PUT /collections/{id}`）；
/// - 手动合集：拖动/上下按钮排序与移除弹层（`PUT /collections/{id}/order`）；
/// - 分享外链、首页展示开关、隐藏/恢复、排序升降序切换、图床模式切换。
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

  bool _editingRules = false;
  final Set<int> _editGenres = {};
  final Set<String> _editDecades = {};
  final Set<String> _editCountries = {};
  String? _editWatch;
  bool _savingRules = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(collectionDetailProvider(_arg).notifier));
  }

  void _startEditRules(CollectionView c) {
    _editGenres.clear();
    _editDecades.clear();
    _editCountries.clear();
    _editWatch = null;
    for (final r in c.rules) {
      final field = r['field']?.toString() ?? '';
      final values = (r['values'] as List<dynamic>? ?? const []);
      switch (field) {
        case 'genres':
          for (final v in values) {
            final id = int.tryParse(v.toString());
            if (id != null) _editGenres.add(id);
          }
        case 'decades':
          for (final v in values) {
            _editDecades.add(v.toString());
          }
        case 'origin_countries':
          for (final v in values) {
            _editCountries.add(v.toString());
          }
        case 'watch':
          if (values.isNotEmpty) _editWatch = values.first.toString();
      }
    }
    setState(() => _editingRules = true);
  }

  List<Map<String, dynamic>> _buildEditRulesPayload() => [
        if (_editGenres.isNotEmpty)
          {
            'field': 'genres',
            'op': 'any_of',
            'values': _editGenres.toList()..sort(),
          },
        if (_editDecades.isNotEmpty)
          {
            'field': 'decades',
            'op': 'any_of',
            'values': _editDecades.toList(),
          },
        if (_editCountries.isNotEmpty)
          {
            'field': 'origin_countries',
            'op': 'any_of',
            'values': _editCountries.toList(),
          },
        if (_editWatch != null && _editWatch!.isNotEmpty)
          {
            'field': 'watch',
            'op': 'any_of',
            'values': [_editWatch!],
          },
      ];

  Future<void> _saveRules() async {
    final payload = _buildEditRulesPayload();
    if (payload.isEmpty) {
      McToast.info('至少保留一条规则条件');
      return;
    }
    setState(() => _savingRules = true);
    try {
      await ref
          .read(collectionDetailProvider(_arg).notifier)
          .updateRules(payload);
      if (!mounted) return;
      setState(() {
        _savingRules = false;
        _editingRules = false;
      });
      McToast.success('规则已更新');
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingRules = false);
      McToast.error('保存失败：$e');
    }
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

  Future<void> _openOrderSheet() async {
    final notifier = ref.read(collectionDetailProvider(_arg).notifier);
    List<LibraryItemView> list;
    try {
      list = await notifier.fetchOrderingList();
    } catch (e) {
      if (mounted) McToast.error('读取合集名单失败：$e');
      return;
    }
    if (!mounted) return;
    await showMcSheet<void>(
      context: context,
      builder: (ctx) => _CollectionOrderSheet(
        collectionId: widget.collectionId,
        initialItems: list,
        onSaveOrder: (ids) async {
          await notifier.reorderItems(ids);
        },
        onRemoveItem: (id) async {
          await notifier.removeItem(id);
        },
      ),
    );
  }

  Future<void> _openShare(CollectionView c) async {
    final api = ref.read(libraryApiProvider);
    await showCollectionShareSheet(
      context,
      api: api,
      collection: c,
    );
  }

  Future<void> _openMore(CollectionView c, CollectionDetailState state) async {
    final galleryLibId = c.libraryId;
    final galleryOn =
        GalleryPrefs.instance.galleryModeFor(libraryId: galleryLibId) &&
            state.items.isNotEmpty;
    final automatic = c.kind != 'user';

    final act = await showMcSheet<String>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                if (state.items.isNotEmpty)
                  McInsetRow(
                    icon: galleryOn ? McIcons.gallery1 : McIcons.imageAdd,
                    title: galleryOn ? '回到海报墙' : '图床浏览',
                    onTap: () => Navigator.of(ctx).pop('gallery'),
                  ),
                if (galleryOn)
                  McInsetRow(
                    icon: McIcons.listSettings2,
                    title: '图床显示设置（分组与密度）',
                    onTap: () => Navigator.of(ctx).pop('gallery_prefs'),
                  ),
                if (c.manageable)
                  McInsetRow(
                    icon: McIcons.edit,
                    title: '重命名合集',
                    onTap: () => Navigator.of(ctx).pop('rename'),
                  ),
                if (state.isAdmin)
                  McInsetRow(
                    icon: McIcons.share,
                    title: '外链分享…',
                    onTap: () => Navigator.of(ctx).pop('share'),
                  ),
                if (c.editable && c.ruleDriven && c.libraryId != null)
                  McInsetRow(
                    icon: McIcons.filter,
                    title: '编辑自动收录条件',
                    onTap: () => Navigator.of(ctx).pop('edit_rules'),
                  ),
                if (c.editable && !c.ruleDriven)
                  McInsetRow(
                    icon: McIcons.sort,
                    title: '整理顺序与名单…',
                    onTap: () => Navigator.of(ctx).pop('order'),
                  ),
                McInsetRow(
                  icon: McIcons.home,
                  title: state.onHome ? '从首页移除' : '显示在首页',
                  onTap: () => Navigator.of(ctx).pop('home'),
                ),
                if (c.editable)
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
            if (c.manageable) ...[
              const SizedBox(height: 12),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  if (c.hidden)
                    McInsetRow(
                      icon: McIcons.eyeOpen,
                      title: '恢复显示此合集',
                      onTap: () => Navigator.of(ctx).pop('unhide'),
                    )
                  else
                    McInsetRow(
                      icon: automatic ? McIcons.eyeOff : McIcons.trash2,
                      title: automatic ? '隐藏此合集' : '删除此合集',
                      destructive: !automatic,
                      onTap: () => Navigator.of(ctx).pop('remove'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || act == null) return;
    final notifier = ref.read(collectionDetailProvider(_arg).notifier);
    switch (act) {
      case 'gallery':
        await GalleryPrefs.instance
            .setGalleryMode(!galleryOn, libraryId: galleryLibId);
      case 'gallery_prefs':
        await showGalleryPrefsSheet(context);
      case 'rename':
        await _rename(c);
      case 'share':
        await _openShare(c);
      case 'edit_rules':
        _startEditRules(c);
      case 'order':
        await _openOrderSheet();
      case 'home':
        try {
          await notifier.toggleOnHome();
          if (mounted) {
            McToast.success(
              state.onHome ? '已从首页移除' : '已固定到首页',
            );
          }
        } catch (e) {
          if (mounted) McToast.error('操作失败：$e');
        }
      case 'visibility':
        try {
          await notifier.toggleVisibility();
          if (mounted) McToast.success('已切换合集可见性');
        } catch (e) {
          if (mounted) McToast.error('操作失败：$e');
        }
      case 'unhide':
        try {
          await notifier.setHidden(false);
          if (mounted) McToast.success('已恢复显示合集');
        } catch (e) {
          if (mounted) McToast.error('恢复失败：$e');
        }
      case 'remove':
        await _confirmRemove(c);
    }
  }

  Future<void> _confirmRemove(CollectionView c) async {
    final automatic = c.kind != 'user';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text(automatic ? '隐藏「${c.name}」？' : '删除「${c.name}」？'),
        content: Text(
          automatic
              ? '隐藏后不再出现在合集列表中，可随时打开「显示已隐藏合集」恢复。'
              : '删除合集不会影响媒体库中的任何视频文件。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              automatic ? '隐藏' : '删除',
              style: TextStyle(
                color: automatic ? McTokens.text : McTokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(collectionDetailProvider(_arg).notifier).deleteSelf();
      ref.read(collectionsProvider.notifier).load();
      if (mounted) {
        McToast.success(automatic ? '合集已隐藏' : '合集已删除');
        context.canPop() ? context.pop() : context.go('/home');
      }
    } catch (e) {
      if (mounted) McToast.error('操作失败：$e');
    }
  }

  List<({String label, List<String> values})> _ruleGroups(
    CollectionView c,
    LibraryFacets? facets,
  ) {
    String labelOf(List<FacetValue>? pool, String v) {
      if (pool == null) return v;
      for (final f in pool) {
        if (f.value == v) return f.label;
      }
      return v;
    }

    final groups = <({String label, List<String> values})>[];
    for (final r in c.rules) {
      final field = r['field']?.toString() ?? '';
      final raw = (r['values'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (raw.isEmpty) continue;
      switch (field) {
        case 'genres':
          groups.add((
            label: '类型',
            values: raw.map((v) => labelOf(facets?.genres, v)).toList(),
          ));
        case 'decades':
          groups.add((
            label: '年代',
            values: raw.map((v) => labelOf(facets?.decades, v)).toList(),
          ));
        case 'origin_countries':
          groups.add((
            label: '地区',
            values: raw.map((v) => labelOf(facets?.countries, v)).toList(),
          ));
        case 'watch':
          groups.add((
            label: '观看状态',
            values: raw.map((v) => labelOf(facets?.watch, v)).toList(),
          ));
        case 'rating_gte':
          groups.add((
            label: '评分',
            values: raw.map((v) => '≥ $v 分').toList(),
          ));
        case 'resolutions':
          groups.add((label: '分辨率', values: raw));
        case 'hdr':
          groups.add((
            label: '动态范围',
            values: raw.map((v) => v == 'true' || v == '1' ? 'HDR' : 'SDR').toList(),
          ));
        case 'languages':
          groups.add((
            label: '语言',
            values: raw.map((v) => labelOf(facets?.languages, v)).toList(),
          ));
      }
    }
    return groups;
  }

  void _openRulesDetailSheet(
    CollectionView c,
    List<({String label, List<String> values})> groups,
  ) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: Text('自动收录条件', style: McText.titleSm),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                groups.length > 1
                    ? '同时满足以下各组条件的新老作品会自动归入本合集（每组内满足任意一项即可）。'
                    : '满足以下条件的新老作品会自动归入本合集。',
                style: McText.caption.muted,
              ),
            ),
            for (final g in groups) ...[
              McInsetGroup(
                header: g.label,
                margin: const EdgeInsets.only(bottom: 10),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final v in g.values)
                          McChip(label: v, compact: true, selected: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (c.editable && c.libraryId != null)
              McActionPill(
                label: '编辑条件',
                icon: McIcons.filter,
                primary: true,
                expanded: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startEditRules(c);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<_CollectionCell> _interleaveCells(
    List<LibraryItemView> owned,
    List<SeriesPartView> missing,
  ) {
    if (missing.isEmpty) {
      return [for (final it in owned) _CollectionCell.item(it)];
    }
    String dateOf(String? s) =>
        (s == null || s.isEmpty) ? '9999-12-31' : s;
    final sortedMissing = [...missing]
      ..sort((a, b) => dateOf(a.releaseDate).compareTo(dateOf(b.releaseDate)));
    final out = <_CollectionCell>[];
    var mi = 0;
    for (final it in owned) {
      while (mi < sortedMissing.length &&
          dateOf(sortedMissing[mi].releaseDate)
                  .compareTo(dateOf(it.releaseDate)) <
              0) {
        out.add(_CollectionCell.missing(sortedMissing[mi]));
        mi++;
      }
      out.add(_CollectionCell.item(it));
    }
    while (mi < sortedMissing.length) {
      out.add(_CollectionCell.missing(sortedMissing[mi]));
      mi++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionDetailProvider(_arg));
    final c = state.collection;
    final form = McFormWatch.of(context);
    final canRemoveItem = c != null && c.editable && !c.ruleDriven;

    return AnimatedBuilder(
      animation: GalleryPrefs.instance,
      builder: (context, _) {
        final galleryLibId = c?.libraryId;
        final galleryOn = c != null &&
            GalleryPrefs.instance.galleryModeFor(libraryId: galleryLibId) &&
            state.items.isNotEmpty;

        final missingParts = (state.series != null &&
                state.series!.available &&
                state.sort == 'default' &&
                !state.reversed &&
                state.endReached)
            ? state.series!.parts.where((p) => p.mediaItemId == null).toList()
            : const <SeriesPartView>[];
        final cells = _interleaveCells(state.items, missingParts);

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
                  if (c != null && state.items.isNotEmpty)
                    McGlassIconButton(
                      icon: galleryOn ? McIcons.gallery1 : McIcons.imageAdd,
                      tooltip: galleryOn ? '海报墙' : '图床浏览',
                      onTap: () => GalleryPrefs.instance
                          .setGalleryMode(!galleryOn, libraryId: galleryLibId),
                    ),
                  if (c != null) ...[
                    const SizedBox(width: 6),
                    McGlassIconButton(
                      icon: McIcons.more,
                      tooltip: '更多操作',
                      onTap: () => _openMore(c, state),
                    ),
                  ],
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(collectionDetailProvider(_arg).notifier).load(),
                  child: state.loading && state.items.isEmpty && c == null
                      ? const McLoadingView()
                      : state.error != null && c == null
                          ? McErrorView(
                              text: state.error!,
                              onRetry: () => ref
                                  .read(collectionDetailProvider(_arg).notifier)
                                  .load(),
                            )
                          : galleryOn
                              ? LibraryGalleryWall(
                              reloadKey:
                                  '${c.id}|${state.sortKey}|${state.membersEpoch}',
                              headerSlivers: [
                                SliverToBoxAdapter(
                                  child: _buildHeader(context, c, state),
                                ),
                              ],
                              padding: EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                14,
                                McTokens.pagePadding,
                                32 + MediaQuery.paddingOf(context).bottom,
                              ),
                              fetch: (offset, limit) {
                                final p = state.sortParams;
                                return ref
                                    .read(libraryApiProvider)
                                    .collectionGallery(
                                      c.id,
                                      limit: limit,
                                      offset: offset,
                                      sort: p.sort,
                                      order: p.order,
                                    );
                              },
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.pixels >
                                    n.metrics.maxScrollExtent - 400) {
                                  ref
                                      .read(
                                        collectionDetailProvider(_arg).notifier,
                                      )
                                      .loadMore();
                                }
                                return false;
                              },
                              child: CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  if (c != null)
                                    SliverToBoxAdapter(
                                      child: _buildHeader(context, c, state),
                                    ),
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      McTokens.pagePadding,
                                      12,
                                      McTokens.pagePadding,
                                      36 + MediaQuery.paddingOf(context).bottom,
                                    ),
                                    sliver: state.loading && cells.isEmpty
                                        ? const SliverToBoxAdapter(
                                            child: McLoadingView(),
                                          )
                                        : cells.isEmpty
                                            ? const SliverToBoxAdapter(
                                                child: McEmptyView(
                                                  text: '合集还没有条目',
                                                ),
                                              )
                                            : SliverGrid(
                                                  gridDelegate: form ==
                                                          McDeviceForm.phone
                                                      ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                                          maxCrossAxisExtent:
                                                              130,
                                                          mainAxisSpacing: 14,
                                                          crossAxisSpacing: 12,
                                                          childAspectRatio:
                                                              0.515,
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
                                                          childAspectRatio:
                                                              0.515,
                                                        ),
                                                  delegate:
                                                      SliverChildBuilderDelegate(
                                                    (context, i) {
                                                      final cell = cells[i];
                                                      if (cell.part != null) {
                                                        return _MissingPartCell(
                                                          part: cell.part!,
                                                        );
                                                      }
                                                      final it = cell.item!;
                                                      return mcItemCard(
                                                        context,
                                                        it,
                                                        width: null,
                                                        fallbackLibraryId:
                                                            c?.libraryId,
                                                        showRating:
                                                            state.sort ==
                                                                'rating',
                                                        extraActions: [
                                                          if (canRemoveItem)
                                                            McPosterMenuAction(
                                                              icon: McIcons
                                                                  .trash2,
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
                                                                if (context
                                                                    .mounted) {
                                                                  McToast.success(
                                                                    '已从合集中移除',
                                                                  );
                                                                }
                                                              },
                                                            ),
                                                        ],
                                                      );
                                                    },
                                                    childCount: cells.length,
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
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CollectionView c,
    CollectionDetailState state,
  ) {
    final series = state.series;
    final countText =
        (series != null && series.available && series.total > 0)
            ? '已有 ${series.ownedCount} / 共 ${series.total} 部'
            : '${c.itemCount} 部';
    final tags = [
      countText,
      if (c.visibility == 'private') '仅自己可见',
      if (c.hidden) '已隐藏',
      if (state.onHome) '已显示在首页',
    ];
    final groups = _ruleGroups(c, state.facets);
    final currentMeta = state.sort == 'default'
        ? state.defaultSortMeta
        : wallSortMetaOf(state.sort);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        6,
        McTokens.pagePadding,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name, style: McText.titleLg),
          const SizedBox(height: 4),
          Text(tags.join(' · '), style: McText.sub.muted),
          const SizedBox(height: 10),
          if (_editingRules)
            _buildInlineRuleEditor(state.facets)
          else ...[
            if (c.kind == 'series')
              Text('TMDB 官方电影系列，库内影片自动归类并提示未入库续集。',
                  style: McText.caption.faint)
            else if (!c.ruleDriven)
              Text('手动维护的固定名单合集。', style: McText.caption.faint)
            else if (groups.isEmpty)
              Text('动态规则合集（全库符合条件的作品将自动归入）。',
                  style: McText.caption.faint)
            else
              InkWell(
                onTap: () => _openRulesDetailSheet(c, groups),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: McTokens.glassFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: McTokens.accent,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '自动收录',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: McTokens.text,
                        ),
                      ),
                      const Text(' · ', style: TextStyle(color: McTokens.textFaint)),
                      Flexible(
                        child: Text(
                          groups
                              .map((g) => '${g.label}：${g.values.join('、')}')
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: McTokens.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        McIcons.chevronRight,
                        size: 14,
                        color: McTokens.textFaint,
                      ),
                    ],
                  ),
                ),
              ),
            if (state.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  McChip(
                    label: currentMeta.label,
                    icon: McIcons.sort,
                    compact: true,
                    onTap: () => _openSortSheet(context, state),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: currentMeta.directionLabel(reversed: state.reversed),
                    icon: state.reversed
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    compact: true,
                    selected: state.reversed,
                    onTap: () => ref
                        .read(collectionDetailProvider(_arg).notifier)
                        .toggleDirection(),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInlineRuleEditor(LibraryFacets? facets) {
    Widget chipRow<T>(
      String title,
      List<FacetValue> list,
      bool Function(FacetValue) isSelected,
      void Function(FacetValue) onToggle,
    ) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: McText.caption.muted),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in list.take(24))
                  McChip(
                    label: f.label,
                    compact: true,
                    selected: isSelected(f),
                    onTap: () => setState(() => onToggle(f)),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('编辑自动收录条件', style: McText.titleSm),
          const SizedBox(height: 10),
          if (facets == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: McLoadingView(label: '加载分面选项…'),
            )
          else ...[
            chipRow(
              '类型',
              facets.genres,
              (f) => _editGenres.contains(int.tryParse(f.value)),
              (f) {
                final id = int.tryParse(f.value);
                if (id == null) return;
                if (!_editGenres.remove(id)) _editGenres.add(id);
              },
            ),
            chipRow(
              '年代',
              facets.decades,
              (f) => _editDecades.contains(f.value),
              (f) {
                if (!_editDecades.remove(f.value)) _editDecades.add(f.value);
              },
            ),
            chipRow(
              '地区',
              facets.countries,
              (f) => _editCountries.contains(f.value),
              (f) {
                if (!_editCountries.remove(f.value)) {
                  _editCountries.add(f.value);
                }
              },
            ),
            chipRow(
              '观看状态',
              facets.watch,
              (f) => _editWatch == f.value,
              (f) => _editWatch = _editWatch == f.value ? null : f.value,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              McActionPill(
                label: _savingRules ? '保存中…' : '保存条件',
                primary: true,
                onTap: _savingRules ? null : _saveRules,
              ),
              const SizedBox(width: 8),
              McActionPill(
                label: '取消',
                onTap: _savingRules
                    ? null
                    : () => setState(() => _editingRules = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSortSheet(BuildContext context, CollectionDetailState state) {
    final defaultMeta = state.defaultSortMeta;
    final options = <WallSortMeta>[
      defaultMeta,
      for (final m in collectionSortMetas)
        if (m.label != defaultMeta.label) m,
    ];
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
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
                  ref
                      .read(collectionDetailProvider(_arg).notifier)
                      .setSort(opt.value);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCell {
  const _CollectionCell.item(this.item) : part = null;
  const _CollectionCell.missing(this.part) : item = null;
  final LibraryItemView? item;
  final SeriesPartView? part;
}

/// 系列中未入库的影片虚线卡片（点按或长按直达 `showSubscribeSheet`）。
class _MissingPartCell extends ConsumerWidget {
  const _MissingPartCell({required this.part});

  final SeriesPartView part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearStr =
        (part.releaseDate != null && part.releaseDate!.length >= 4)
            ? part.releaseDate!.substring(0, 4)
            : null;
    final statusLabel = part.subscribed ? '追踪中' : '未入库';

    Future<void> openSubscribe() async {
      await showSubscribeSheet(
        context,
        ref,
        titleRef: 'tmdb:movie:${part.tmdbId}',
      );
    }

    return GestureDetector(
      onTap: openSubscribe,
      onLongPress: openSubscribe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: Colors.white.withValues(alpha: 0.24),
                radius: McTokens.posterRadius,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: McTokens.posterPlaceholder),
                    if (part.posterUrl != null && part.posterUrl!.isNotEmpty)
                      Opacity(
                        opacity: 0.36,
                        child: CachedNetworkImage(
                          imageUrl: McImageUrls.resolve(
                            part.posterUrl,
                            widthPx: 360,
                          ),
                          httpHeaders: mcImageHeaders(),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: part.subscribed
                                ? McTokens.info.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              part.subscribed
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.add_rounded,
                              size: 12,
                              color: part.subscribed
                                  ? McTokens.info
                                  : McTokens.text,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: part.subscribed
                                    ? McTokens.info
                                    : McTokens.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            part.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.body.copyWith(fontSize: 13),
          ),
          Text(
            [if (yearStr != null) yearStr, statusLabel].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.caption.faint,
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashLen = 6.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// 手动合集拖动排序弹层（保存至 `PUT /collections/{id}/order`）。
class _CollectionOrderSheet extends StatefulWidget {
  const _CollectionOrderSheet({
    required this.collectionId,
    required this.initialItems,
    required this.onSaveOrder,
    required this.onRemoveItem,
  });

  final int collectionId;
  final List<LibraryItemView> initialItems;
  final Future<void> Function(List<int> ids) onSaveOrder;
  final Future<void> Function(int mediaItemId) onRemoveItem;

  @override
  State<_CollectionOrderSheet> createState() => _CollectionOrderSheetState();
}

class _CollectionOrderSheetState extends State<_CollectionOrderSheet> {
  late List<LibraryItemView> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = [...widget.initialItems];
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.onSaveOrder(_items.map((e) => e.mediaItemId).toList());
      if (mounted) {
        McToast.success('已保存合集顺序');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        McToast.error('保存失败：$e');
      }
    }
  }

  Future<void> _remove(LibraryItemView item) async {
    setState(() => _busy = true);
    try {
      await widget.onRemoveItem(item.mediaItemId);
      if (mounted) {
        setState(() {
          _items.removeWhere((e) => e.mediaItemId == item.mediaItemId);
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        McToast.error('移除失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('整理合集顺序', style: McText.titleSm),
                      SizedBox(height: 2),
                      Text(
                        '拖动或点按移除，保存后作为默认排序',
                        style: TextStyle(
                          fontSize: 12,
                          color: McTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                McActionPill(
                  label: _busy ? '保存中…' : '保存顺序',
                  primary: true,
                  onTap: _busy || _items.isEmpty ? null : _save,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: _items.isEmpty
                ? const McEmptyView(text: '合集已空')
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final row = _items.removeAt(oldIndex);
                        _items.insert(newIndex, row);
                      });
                    },
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return ListTile(
                        key: ValueKey(it.mediaItemId),
                        dense: true,
                        leading: SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.right,
                            style: McText.caption.faint,
                          ),
                        ),
                        title: Text(
                          it.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.body,
                        ),
                        subtitle: it.year != null
                            ? Text('${it.year}', style: McText.caption.faint)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '从合集移除',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: McTokens.textMuted,
                              ),
                              onPressed: _busy ? null : () => _remove(it),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Icon(
                                Icons.drag_handle_rounded,
                                size: 20,
                                color: McTokens.textFaint,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/* ────────────────────── 全部合集入口页 ────────────────────── */

/// 全部合集入口页（对齐 iOS `AllCollectionsView`）：
/// - 按类型筛选（全部 / 系列 / 智能规则 / 自建名单）与按媒体库筛选，实时分面计数、0 项置灰不可点；
/// - 3 张错叠海报封面（`LibraryCollectionCover`）网格，按跨库与各媒体库分组；
/// - 支持「显示已隐藏合集」（`include_hidden`）开关与新建合集。
class LibraryCollectionsPage extends ConsumerStatefulWidget {
  const LibraryCollectionsPage({super.key});

  @override
  ConsumerState<LibraryCollectionsPage> createState() =>
      _LibraryCollectionsPageState();
}

class _LibraryCollectionsPageState
    extends ConsumerState<LibraryCollectionsPage> {
  static const _typeOptions = <(String, String)>[
    ('all', '全部'),
    ('series', '系列'),
    ('rule', '智能规则'),
    ('manual', '自建名单'),
  ];

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

  Widget _chipRow({
    required String label,
    required List<({String label, int count, bool selected, VoidCallback onTap})>
        items,
  }) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(label, style: McText.caption.faint),
            ),
          ),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Opacity(
                opacity: it.count == 0 && !it.selected ? 0.3 : 1,
                child: McChip(
                  label: '${it.label} ${it.count}',
                  compact: true,
                  selected: it.selected,
                  onTap: it.count == 0 && !it.selected ? null : it.onTap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<CollectionView> items,
    McDeviceForm form,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
      gridDelegate: form == McDeviceForm.phone
          ? const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 145,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.54,
            )
          : SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mcGridCrossAxisCount(
                form,
                BoxConstraints.tightFor(
                  width: MediaQuery.widthOf(context) - 32,
                ),
                cellExtent: 145,
              ),
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.54,
            ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        final tags = [
          '${c.itemCount} 部',
          if (c.kind == 'series')
            '系列'
          else if (c.ruleDriven)
            '自动收录',
          if (c.visibility == 'private') '私密',
          if (c.hidden) '已隐藏',
        ];
        return GestureDetector(
          onTap: () => context.push(routeLibraryCollection(c.id)).then((_) {
            if (mounted) ref.read(collectionsProvider.notifier).load();
          }),
          child: Opacity(
            opacity: c.hidden ? 0.45 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LibraryCollectionCover(covers: c.covers),
                const SizedBox(height: 8),
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tags.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.faint,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsProvider);
    final notifier = ref.read(collectionsProvider.notifier);
    final form = McFormWatch.of(context);
    final shown = state.filtered;
    final cross = shown.where((c) => c.libraryId == null).toList();
    final grouped = <({LibraryView lib, List<CollectionView> items})>[];
    for (final lib in state.libraries) {
      final list = shown.where((c) => c.libraryId == lib.id).toList();
      if (list.isNotEmpty) grouped.add((lib: lib, items: list));
    }

    final libFilterItems = <({
      String label,
      int count,
      bool selected,
      VoidCallback onTap,
    })>[
      (
        label: '全部库',
        count: state.countForLibrary(null),
        selected: state.libraryFilter == null,
        onTap: () => notifier.setLibraryFilter(null),
      ),
      if (state.collections.any((c) => c.libraryId == null))
        (
          label: '跨库',
          count: state.countForLibrary(-1),
          selected: state.libraryFilter == -1,
          onTap: () => notifier.setLibraryFilter(-1),
        ),
      for (final lib in state.libraries)
        (
          label: lib.name,
          count: state.countForLibrary(lib.id),
          selected: state.libraryFilter == lib.id,
          onTap: () => notifier.setLibraryFilter(lib.id),
        ),
    ];

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
                icon: state.includeHidden ? McIcons.eyeOpen : McIcons.eyeOff,
                tooltip: state.includeHidden ? '隐藏已隐藏合集' : '显示已隐藏合集',
                onTap: notifier.toggleIncludeHidden,
              ),
              const SizedBox(width: 6),
              McGlassIconButton(
                icon: McIcons.addS,
                tooltip: '新建合集',
                onTap: _createCollection,
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.load,
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
                          padding: const EdgeInsets.only(top: 6, bottom: 36),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: McTokens.pagePadding,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      shown.length == state.collections.length
                                          ? '共 ${state.collections.length} 个合集'
                                          : '已筛出 ${shown.length} / 共 ${state.collections.length} 个合集',
                                      style: McText.sub.muted,
                                    ),
                                  ),
                                  if (state.includeHidden)
                                    McChip(
                                      label: '含已隐藏',
                                      compact: true,
                                      selected: true,
                                      onTap: notifier.toggleIncludeHidden,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _chipRow(
                              label: '类型',
                              items: [
                                for (final (val, title) in _typeOptions)
                                  (
                                    label: title,
                                    count: state.countForType(val),
                                    selected: state.typeFilter == val,
                                    onTap: () => notifier.setTypeFilter(val),
                                  ),
                              ],
                            ),
                            if (libFilterItems.length > 2) ...[
                              const SizedBox(height: 8),
                              _chipRow(label: '媒体库', items: libFilterItems),
                            ],
                            const SizedBox(height: 18),
                            if (shown.isEmpty)
                              McEmptyView(
                                text: '当前筛选下没有匹配的合集',
                                actionLabel: '清空筛选',
                                onRetry: () {
                                  notifier.setTypeFilter('all');
                                  notifier.setLibraryFilter(null);
                                },
                              )
                            else ...[
                              if (cross.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    McTokens.pagePadding,
                                    0,
                                    McTokens.pagePadding,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('跨库合集', style: McText.titleSm),
                                      Text(
                                        '不限定单个媒体库的手动片单与全站系列',
                                        style: McText.caption.faint,
                                      ),
                                    ],
                                  ),
                                ),
                                _buildGrid(context, cross, form),
                                const SizedBox(height: 24),
                              ],
                              for (final grp in grouped) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    McTokens.pagePadding,
                                    0,
                                    McTokens.pagePadding,
                                    10,
                                  ),
                                  child: Text(
                                    grp.lib.name,
                                    style: McText.titleSm,
                                  ),
                                ),
                                _buildGrid(context, grp.items, form),
                                const SizedBox(height: 24),
                              ],
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
