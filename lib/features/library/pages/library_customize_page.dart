import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/home_rows.dart';
import '../state/library_customize_controller.dart';
import '../state/models.dart';
import '../widgets/library_shared.dart';

/// 自定义首页（1:1 对齐 upstream iOS `LibraryCustomizeView.swift`）：
/// - 行首圆圈显隐 + 拖拽重排 + 点进单行设置弹层（改名最多 40 字 / 排序依据 / 升降序 / 3 态观看过滤 / 删除）；
/// - 严格使用 `row.removable()` 判定删除权（自加 `row:` 与老版本 `kind:` 可删，内置行只能隐藏）；
/// - 400ms 防抖自动保存 + 离页自动 flush；
/// - 恢复出厂布局直接保存空清单 `[]`。
class LibraryCustomizePage extends ConsumerStatefulWidget {
  const LibraryCustomizePage({super.key});

  @override
  ConsumerState<LibraryCustomizePage> createState() =>
      _LibraryCustomizePageState();
}

class _LibraryCustomizePageState extends ConsumerState<LibraryCustomizePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(libraryCustomizeProvider.notifier).load());
  }

  Future<void> _close() async {
    await ref.read(libraryCustomizeProvider.notifier).flushPendingSave();
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/home');
  }

  Future<void> _confirmReset() async {
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('恢复默认首页布局？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '将清空自定义排序、改名和添加的行，恢复为出厂默认布局。',
              style: McText.sub.muted,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '恢复默认',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final success =
        await ref.read(libraryCustomizeProvider.notifier).resetToDefault();
    if (mounted && success) {
      McToast.success('已恢复出厂布局');
    }
  }

  void _openRowSettings(String rowId) {
    showMcSheet<void>(
      context: context,
      maxWidth: 560,
      builder: (_) => _RowSettingsSheet(rowId: rowId),
    );
  }

  void _openAddSheet(CustomizeState state) {
    final visibleLibs =
        state.libraries.where((l) => l.viewerAccess).toList();
    final kindGroups = HomeRows.mediaKindGroups(visibleLibs);
    final userCols =
        state.collections.where((c) => c.kind == 'user').toList();
    final onHomeIds = <int>{
      for (final r in state.rows)
        if (r.kind is CollectionRowKind)
          (r.kind as CollectionRowKind).collection.id,
    };
    showMcSheet<void>(
      context: context,
      maxWidth: 560,
      builder: (sheetCtx) => _AddRowSheet(
        kindGroups: kindGroups,
        libraries: visibleLibs,
        collections: userCols,
        onHomeIds: onHomeIds,
        onAddMediaKind: (kind, libs) {
          Navigator.of(sheetCtx).pop();
          final created = ref
              .read(libraryCustomizeProvider.notifier)
              .addMediaKindRow(kind, libs);
          _openRowSettings(created.id);
        },
        onAddLibrary: (lib) {
          Navigator.of(sheetCtx).pop();
          final created = ref
              .read(libraryCustomizeProvider.notifier)
              .addLibraryRow(lib);
          _openRowSettings(created.id);
        },
        onAddCollection: (col) {
          Navigator.of(sheetCtx).pop();
          final created = ref
              .read(libraryCustomizeProvider.notifier)
              .addCollectionRow(col);
          _openRowSettings(created.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryCustomizeProvider);
    final notifier = ref.read(libraryCustomizeProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: McTokens.bg,
        body: Column(
          children: [
            McFloatingDetailBar(
              onBack: _close,
              title: '自定义首页',
              titleVisible: true,
              trailing: [
                if (state.saving)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (state.savedAt != null && !state.dirty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('已保存', style: McText.caption.muted),
                  ),
                McGlassIconButton(
                  icon: McIcons.addS,
                  tooltip: '添加一行',
                  onTap: state.loading ? null : () => _openAddSheet(state),
                ),
              ],
            ),
            if (state.saveError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  McTokens.pagePadding,
                  4,
                  McTokens.pagePadding,
                  6,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: McTokens.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: McTokens.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    state.saveError!,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
                ),
              ),
            Expanded(
              child: state.loading
                  ? const McLoadingView()
                  : state.error != null && state.rows.isEmpty
                      ? McErrorView(
                          text: state.error!,
                          onRetry: notifier.load,
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  McTokens.pagePadding,
                                  8,
                                  McTokens.pagePadding,
                                  16,
                                ),
                                itemCount: state.rows.length,
                                onReorder: (oldIndex, newIndex) {
                                  final moved = newIndex > oldIndex
                                      ? newIndex - 1
                                      : newIndex;
                                  notifier.reorder(oldIndex, moved);
                                },
                                footer: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '显示 ${state.visibleRows.length} 行 · 隐藏 ${state.hiddenCount} 行（改动自动保存）',
                                        textAlign: TextAlign.center,
                                        style: McText.caption.faint,
                                      ),
                                      const SizedBox(height: 16),
                                      McActionPill(
                                        label: '恢复默认布局',
                                        icon: McIcons.refreshS,
                                        primary: false,
                                        tone: McGlassTone.danger,
                                        expanded: true,
                                        onTap: _confirmReset,
                                      ),
                                    ],
                                  ),
                                ),
                                itemBuilder: (context, i) {
                                  final row = state.rows[i];
                                  return _RowLine(
                                    key: ValueKey(row.id),
                                    row: row,
                                    index: i,
                                    onToggleHidden: () =>
                                        notifier.setHidden(row.id, !row.hidden),
                                    onOpenSettings: row.configurable
                                        ? () => _openRowSettings(row.id)
                                        : null,
                                    onRemove: row.removable()
                                        ? () => notifier.removeRow(row.id)
                                        : null,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({
    super.key,
    required this.row,
    required this.index,
    required this.onToggleHidden,
    required this.onOpenSettings,
    required this.onRemove,
  });

  final HomeRow row;
  final int index;
  final VoidCallback onToggleHidden;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.posterRadius),
        border: Border.all(color: McTokens.line),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: row.hidden ? '显示该行' : '隐藏该行',
            icon: Icon(
              row.hidden ? McIcons.circler : McIcons.checkCircleFill,
              size: 21,
              color: row.hidden ? McTokens.textFaint : McTokens.accentStrong,
            ),
            onPressed: onToggleHidden,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(McTokens.posterRadius),
              onTap: onOpenSettings,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: row.hidden
                          ? McText.ui.copyWith(color: McTokens.textFaint)
                          : McText.ui,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.meta(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption.faint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: '删除行',
              icon: const Icon(
                McIcons.trash2,
                size: 18,
                color: McTokens.danger,
              ),
              onPressed: onRemove,
            ),
          if (onOpenSettings != null)
            IconButton(
              tooltip: '单行设置',
              icon: const Icon(
                McIcons.chevronRight,
                size: 17,
                color: McTokens.textMuted,
              ),
              onPressed: onOpenSettings,
            ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Icon(
                McIcons.draggableS,
                size: 18,
                color: McTokens.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单行设置底部弹层（对齐 iOS `RowSettingsView`）：
/// 改名（最多 40 字）/ 排序依据 / 升降序 / 3 态观看过滤（全部 / 未看 / 未看完）/ 来源 / 删除（仅 `row.removable()`）。
class _RowSettingsSheet extends ConsumerStatefulWidget {
  const _RowSettingsSheet({required this.rowId});

  final String rowId;

  @override
  ConsumerState<_RowSettingsSheet> createState() => _RowSettingsSheetState();
}

class _RowSettingsSheetState extends ConsumerState<_RowSettingsSheet> {
  late final TextEditingController _nameCtrl;
  bool _inited = false;

  @override
  void dispose() {
    if (_inited) _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryCustomizeProvider);
    final notifier = ref.read(libraryCustomizeProvider.notifier);
    final row = state.rows.where((r) => r.id == widget.rowId).firstOrNull;
    if (row == null) return const SizedBox.shrink();

    if (!_inited) {
      _nameCtrl = TextEditingController(text: row.customName());
      _inited = true;
    }

    final k = row.kind;
    final nameEditable = k is LibraryRowKind ||
        k is MediaKindRowKind ||
        k is CollectionRowKind;
    final sortKeys = switch (k) {
      FavoritesRowKind() => HomeRows.favoritesSorts,
      LibraryRowKind(:final library) => HomeRows.sortsFor(library.kind),
      MediaKindRowKind(:final kind) => HomeRows.sortsFor(kind),
      CollectionRowKind() => HomeRows.allSorts,
      _ => const <String>[],
    };
    final curSort = row.sort ?? 'added_at';
    final dir = (k is FavoritesRowKind && curSort == 'unwatched_first')
        ? null
        : HomeRows.direction(curSort);
    final supportsWatch = (k is LibraryRowKind || k is MediaKindRowKind) &&
        curSort != 'last_played';
    final curWatch = row.unfinished
        ? 'unfinished'
        : ((k is LibraryRowKind && k.unwatched) ||
                (k is MediaKindRowKind && k.unwatched))
            ? 'unwatched'
            : '';

    final sourceText = switch (k) {
      LibraryRowKind(:final library) => '${library.name}库',
      MediaKindRowKind(:final libraries) =>
        libraries.map((l) => l.name).join('、'),
      CollectionRowKind(:final collection) => '合集「${collection.name}」',
      _ => null,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Row(
            children: [
              Expanded(child: Text(row.title(), style: McText.titleSm)),
              McChip(
                label: '完成',
                compact: true,
                selected: true,
                onTap: () {
                  if (nameEditable) {
                    notifier.setRowName(row.id, _nameCtrl.text.trim());
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          if (nameEditable) ...[
            const SizedBox(height: 16),
            Text('自定义行名（留空则跟随排序自动命名）', style: McText.caption.muted),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              maxLength: 40,
              style: McText.body,
              decoration: InputDecoration(
                hintText: row.defaultTitle(),
                suffixIcon: _nameCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(McIcons.close, size: 16),
                        onPressed: () {
                          _nameCtrl.clear();
                          notifier.setRowName(row.id, '');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                notifier.setRowName(row.id, v);
                setState(() {});
              },
            ),
          ],
          if (sortKeys.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('排序依据', style: McText.caption.muted),
            const SizedBox(height: 8),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final key in sortKeys)
                  McInsetRow(
                    title: HomeRows.sortTitle(key),
                    subtitle: HomeRows.sortHint(key),
                    trailing: curSort == key
                        ? const Icon(
                            McIcons.check,
                            size: 18,
                            color: McTokens.accentStrong,
                          )
                        : null,
                    onTap: () => notifier.setRowSort(row.id, key, false),
                  ),
              ],
            ),
          ],
          if (dir != null) ...[
            const SizedBox(height: 14),
            Text('排序方向', style: McText.caption.muted),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: McChip(
                    label: HomeRows.directionLabel(curSort, false),
                    selected: !row.reversed,
                    onTap: () => notifier.setRowSort(row.id, curSort, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: McChip(
                    label: HomeRows.directionLabel(curSort, true),
                    selected: row.reversed,
                    onTap: () => notifier.setRowSort(row.id, curSort, true),
                  ),
                ),
              ],
            ),
          ],
          if (supportsWatch) ...[
            const SizedBox(height: 16),
            Text('观看过滤', style: McText.caption.muted),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (val, label) in const [
                  ('', '全部'),
                  ('unwatched', '只看未看'),
                  ('unfinished', '未看完'),
                ]) ...[
                  Expanded(
                    child: McChip(
                      label: label,
                      selected: curWatch == val,
                      compact: true,
                      onTap: () => notifier.setWatch(row.id, val),
                    ),
                  ),
                  if (val != 'unfinished') const SizedBox(width: 8),
                ],
              ],
            ),
          ],
          if (sourceText != null) ...[
            const SizedBox(height: 16),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  title: '数据来源',
                  subtitle: sourceText,
                ),
              ],
            ),
            if (k is MediaKindRowKind)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '跨库合并时同一部影片只出现一次。',
                  style: McText.micro.faint,
                ),
              ),
          ],
          if (row.removable()) ...[
            const SizedBox(height: 20),
            McActionPill(
              label: '删除这一行',
              icon: McIcons.trash2,
              primary: false,
              tone: McGlassTone.danger,
              expanded: true,
              onTap: () {
                notifier.removeRow(row.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 添加一行弹层（按类型 / 媒体库 / 合集 三组）。
class _AddRowSheet extends StatelessWidget {
  const _AddRowSheet({
    required this.kindGroups,
    required this.libraries,
    required this.collections,
    required this.onHomeIds,
    required this.onAddMediaKind,
    required this.onAddLibrary,
    required this.onAddCollection,
  });

  final List<({String kind, List<LibraryView> libraries})> kindGroups;
  final List<LibraryView> libraries;
  final List<CollectionView> collections;
  final Set<int> onHomeIds;
  final void Function(String kind, List<LibraryView> libs) onAddMediaKind;
  final void Function(LibraryView lib) onAddLibrary;
  final void Function(CollectionView col) onAddCollection;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          const Text('添加一行到首页', style: McText.titleSm),
          if (kindGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('按类型（跨库合并去重）', style: McText.caption.muted),
            const SizedBox(height: 8),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final g in kindGroups)
                  McInsetRow(
                    icon: libraryKindIcon(g.kind),
                    title: '全部${HomeRows.mediaKindLabel(g.kind)}',
                    subtitle: '${g.libraries.length} 个媒体库合并',
                    onTap: () => onAddMediaKind(g.kind, g.libraries),
                  ),
              ],
            ),
          ],
          if (libraries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('按单个媒体库', style: McText.caption.muted),
            const SizedBox(height: 8),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final lib in libraries)
                  McInsetRow(
                    icon: libraryKindIcon(lib.kind),
                    title: lib.name,
                    subtitle: '${lib.stats.itemCount} 部',
                    onTap: () => onAddLibrary(lib),
                  ),
              ],
            ),
          ],
          if (collections.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('按合集', style: McText.caption.muted),
            const SizedBox(height: 8),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final c in collections)
                  McInsetRow(
                    icon: McIcons.stack,
                    title: c.name,
                    subtitle: '${c.itemCount} 部',
                    trailing: onHomeIds.contains(c.id)
                        ? const Icon(
                            McIcons.check,
                            size: 16,
                            color: McTokens.textFaint,
                          )
                        : null,
                    onTap: onHomeIds.contains(c.id)
                        ? null
                        : () => onAddCollection(c),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
