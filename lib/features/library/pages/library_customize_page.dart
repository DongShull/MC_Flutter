import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/home_rows.dart';
import '../state/library_customize_controller.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 自定义首页（对齐 Kotlin LibraryCustomizeScreen.kt）：
/// 行清单编辑器：拖拽排序、隐藏/显示、删除、行内排序与观看过滤、新增媒体库/合集行、恢复出厂。
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryCustomizeProvider);
    return PopScope(
      canPop: !state.dirty,
      child: Scaffold(
        backgroundColor: McTokens.bg,
        body: Column(
          children: [
            McFloatingDetailBar(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              title: '自定义首页',
              titleVisible: true,
              trailing: [
                if (state.dirty)
                  McChip(
                    label: state.saving ? '保存中…' : '保存',
                    selected: true,
                    compact: true,
                    onTap: state.saving
                        ? null
                        : () async {
                            final ok = await ref
                                .read(libraryCustomizeProvider.notifier)
                                .save();
                            if (ok) McToast.success('已保存');
                          },
                  ),
              ],
            ),
            Expanded(
              child: state.loading
                  ? const McLoadingView()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        McTokens.pagePadding,
                        8,
                        McTokens.pagePadding,
                        16,
                      ),
                      itemCount: state.rows.length,
                      onReorder: (oldIndex, newIndex) {
                        final moved =
                            newIndex > oldIndex ? newIndex - 1 : newIndex;
                        ref
                            .read(libraryCustomizeProvider.notifier)
                            .reorder(oldIndex, moved);
                      },
                      itemBuilder: (context, i) {
                        final row = state.rows[i];
                        return _RowTile(
                          key: ValueKey(row.id),
                          row: row,
                          preview: _previewCount(state, row),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  McTokens.pagePadding,
                  8,
                  McTokens.pagePadding,
                  16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: McActionPill(
                        label: '添加行',
                        icon: McIcons.addS,
                        primary: false,
                        expanded: true,
                        onTap: () => _showAddSheet(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: McActionPill(
                        label: '恢复出厂',
                        icon: McIcons.refreshS,
                        primary: false,
                        expanded: true,
                        onTap: () => ref
                            .read(libraryCustomizeProvider.notifier)
                            .resetToDefault(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _previewCount(CustomizeState state, HomeRow row) {
    final k = row.kind;
    if (k is LibraryRowKind) {
      final items = state.rowItems[row.id];
      if (items == null) return null;
      return '${items.length} 部预览';
    }
    if (k is CollectionRowKind) {
      final items = state.rowItems[row.id];
      if (items == null) return null;
      return '${items.length} 部预览';
    }
    if (k is FavoritesRowKind) return '${state.favorites.length} 部';
    if (k is UpNextRowKind) return '${state.upNext.length} 部';
    return null;
  }

  void _showAddSheet(BuildContext context) {
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => _AddSheet(
        onPickLibrary: (lib) {
          Navigator.of(sheetContext).pop();
          ref.read(libraryCustomizeProvider.notifier).addLibraryRow(lib);
        },
        onPickCollection: (c) {
          Navigator.of(sheetContext).pop();
          ref.read(libraryCustomizeProvider.notifier).addCollectionRow(c);
        },
      ),
    );
  }
}

class _RowTile extends ConsumerWidget {
  const _RowTile({super.key, required this.row, this.preview});

  final HomeRow row;
  final String? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(libraryCustomizeProvider.notifier);
    final k = row.kind;
    final removable = k is CollectionRowKind || k is GenresRowKind;
    final sortOptions = k is FavoritesRowKind
        ? HomeRows.favoritesSorts
        : (k is LibraryRowKind
            ? HomeRows.sortsFor(k.library.kind)
            : k is CollectionRowKind
                ? HomeRows.allSorts
                : const <String>[]);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.posterRadius),
        border: Border.all(color: McTokens.line),
      ),
      child: ListTile(
        title: Text(
          row.title(),
          style: row.hidden
              ? McText.ui.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: McTokens.textFaint,
                )
              : McText.ui,
        ),
        subtitle: Text(
          [row.meta(), preview].nonNulls.where((s) => s.isNotEmpty).join(' · '),
          style: McText.caption.muted,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sortOptions.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: '行排序',
                onSelected: (v) {
                  if (v == '__dir__') {
                    final sort = k is LibraryRowKind
                        ? k.sort
                        : k is CollectionRowKind
                            ? k.sort
                            : k is FavoritesRowKind
                                ? k.sort
                                : 'added_at';
                    notifier.setRowSort(row.id, sort, !_isReversed(k));
                  } else {
                    notifier.setRowSort(row.id, v, HomeRows.isReversed(v, null));
                  }
                },
                itemBuilder: (_) => [
                  for (final s in sortOptions)
                    PopupMenuItem(
                      value: s,
                      child: Text(HomeRows.shortLabel(s, false)),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: '__dir__', child: Text('切换方向')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(McIcons.sort, size: 19, color: McTokens.textMuted),
                ),
              ),
            if (k is LibraryRowKind && k.sort != 'last_played')
              IconButton(
                tooltip: k.unwatched ? '只看未看：开' : '只看未看：关',
                icon: Icon(
                  k.unwatched ? McIcons.eyeClosedFill : McIcons.eyeOpen,
                  size: 19,
                ),
                onPressed: () => notifier.setUnwatched(row.id, !k.unwatched),
              ),
            IconButton(
              tooltip: row.hidden ? '显示' : '隐藏',
              icon: Icon(
                row.hidden ? McIcons.eyeOpen : McIcons.eyeOff,
                size: 19,
              ),
              onPressed: () => notifier.setHidden(row.id, !row.hidden),
            ),
            if (removable)
              IconButton(
                tooltip: '删除行',
                icon: const Icon(
                  McIcons.trash2,
                  size: 19,
                  color: McTokens.danger,
                ),
                onPressed: () => notifier.removeRow(row.id),
              ),
            const Icon(
              McIcons.draggableS,
              size: 18,
              color: McTokens.textFaint,
            ),
          ],
        ),
      ),
    );
  }

  bool _isReversed(HomeRowKind k) {
    final kind = k;
    if (kind is LibraryRowKind) return kind.reversed;
    if (kind is CollectionRowKind) return kind.reversed;
    if (kind is FavoritesRowKind) return kind.reversed;
    return false;
  }
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({
    required this.onPickLibrary,
    required this.onPickCollection,
  });

  final void Function(LibraryView) onPickLibrary;
  final void Function(CollectionView) onPickCollection;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  List<LibraryView>? _libs;
  List<CollectionView>? _collections;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final api = ref.read(libraryApiProvider);
      try {
        final libs = await api.libraries();
        final collections = await api.collections();
        if (mounted) {
          setState(() {
            _libs = libs;
            _collections = collections;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _libs = const [];
            _collections = const [];
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final libs = _libs;
    final collections = _collections;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      shrinkWrap: true,
      children: [
        const Text('添加媒体库行', style: McText.titleSm),
        const SizedBox(height: 10),
        if (libs == null)
          const Padding(padding: EdgeInsets.all(12), child: McLoadingView())
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lib in libs.where((l) => !l.excludeFromHome))
                McChip(
                  label: lib.name,
                  onTap: () => widget.onPickLibrary(lib),
                ),
            ],
          ),
        const SizedBox(height: 20),
        const Text('添加合集行', style: McText.titleSm),
        const SizedBox(height: 10),
        if (collections == null)
          const Padding(padding: EdgeInsets.all(12), child: McLoadingView())
        else if (collections.isEmpty)
          Text('还没有合集', style: McText.sub.muted)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in collections)
                McChip(
                  label: c.name,
                  onTap: () => widget.onPickCollection(c),
                ),
            ],
          ),
      ],
    );
  }
}
