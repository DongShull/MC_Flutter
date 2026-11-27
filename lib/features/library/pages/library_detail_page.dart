import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../routes.dart';
import '../state/library_detail_controller.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/gallery_wall_view.dart';
import '../widgets/issue_drawer_sheet.dart';
import '../widgets/library_form_sheet.dart';
import '../widgets/library_organize_sheet.dart';
import '../widgets/library_shared.dart';
import '../widgets/library_widgets.dart';
import 'photo_wall_page.dart';

/// 单库详情页（完整对齐 upstream iOS `LibraryDetailView`）：
/// - `viewerAccess == false` 管理员权限锁屏 + 一键「将我加入可见成员」；
/// - 照片库（`!capabilities.playable`）自动切换 `PhotoWallView`（EXIF 按月相册 + 三级灯箱）；
/// - 图床模式（`LibraryGalleryWall`）+ 密度/按作品分组偏好；
/// - 管理员 `⋯` 菜单：待处理抽屉、扫描/停止扫描、整理文件名（4段式）、元数据刷新（全量/NFO/封面/停止）、
///   章节图生成/重建、编辑库、图床切换、显示已隐藏合集；
/// - 页头健康状态胶囊（上次扫描、扫描/整理进度、缺失/待识别/复核直达待处理抽屉）+ `MetadataRefreshPanel`；
/// - 10 维筛选（count==0 禁用、真实评分/HDR 分面计数）+ 演员 chip + `SaveAsCollectionSheet`（自动命名 + 动态/定格 + 可见性）
///   + 0 结果 `/relax` 一键放宽；
/// - 临时身份区（`identity=provisional`）+ 未刮削库横/竖版分栏；
/// - 向上补页 + 倒序反向 A–Z 索引条（带部数气泡）+ `LibraryWallRecall`「回到上次位置」。
class LibraryDetailPage extends ConsumerStatefulWidget {
  const LibraryDetailPage({
    super.key,
    required this.libraryId,
    this.query = const {},
  });

  final int libraryId;
  final Map<String, String> query;

  @override
  ConsumerState<LibraryDetailPage> createState() => _LibraryDetailPageState();
}

class _LibraryDetailPageState extends ConsumerState<LibraryDetailPage> {
  final ScrollController _scroll = ScrollController();
  LibraryIndexEntry? _activeIndexEntry;
  String? _lastIndexLetter;
  int? _recallOffset;
  bool _offeredRecall = false;
  int _lastRecordedOffset = -1;
  int _galleryStart = 0;
  PhotoWallJump? _photoJump;
  bool _didAutoOpenPending = false;
  late LibraryDetailArg _arg;

  String get _recallScope => 'library:${widget.libraryId}';

  @override
  void initState() {
    super.initState();
    _arg = LibraryDetailArg(
      libraryId: widget.libraryId,
      initialQuery: Map<String, String>.unmodifiable(widget.query),
    );
    Future.microtask(() {
      ref.read(libraryDetailProvider(_arg).notifier);
      if (widget.query['pending'] == '1' && !_didAutoOpenPending) {
        _didAutoOpenPending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openIssueDrawer();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant LibraryDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextArg = LibraryDetailArg(
      libraryId: widget.libraryId,
      initialQuery: Map<String, String>.unmodifiable(widget.query),
    );
    if (nextArg != _arg) {
      _arg = nextArg;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkRecallOffer(LibraryDetailState state) {
    if (_offeredRecall || state.loading || state.total < 24) return;
    _offeredRecall = true;
    LibraryWallRecall.read(
      scope: _recallScope,
      view: state.filter.filterKey,
    ).then((saved) {
      if (mounted && saved != null && saved < state.total) {
        setState(() => _recallOffset = saved);
      }
    });
  }

  void _recordOffset(LibraryDetailState state, int offset) {
    if (_recallOffset != null && (offset - state.baseOffset).abs() >= 12) {
      setState(() => _recallOffset = null);
    }
    if (offset != _lastRecordedOffset && _recallOffset == null) {
      _lastRecordedOffset = offset;
      LibraryWallRecall.write(
        scope: _recallScope,
        view: state.filter.filterKey,
        offset: offset,
      );
    }
  }

  Future<void> _openIssueDrawer({String? initialTab}) async {
    await showIssueDrawerSheet(
      context,
      libraryId: widget.libraryId,
      initialTab: initialTab,
      onChanged: () {
        if (mounted) {
          ref.read(libraryDetailProvider(_arg).notifier).refreshLibraryMeta();
          ref.read(libraryDetailProvider(_arg).notifier).reload();
        }
      },
    );
  }

  Future<void> _openEditLibrary(LibraryView lib) async {
    List<LibraryView> allLibs = const [];
    try {
      allLibs = await ref.read(libraryApiProvider).libraries(scope: 'all');
    } catch (_) {}
    if (!mounted) return;
    final saved = await showLibraryFormSheet(
      context,
      editing: lib,
      existingLibraries: allLibs,
    );
    if (saved == true && mounted) {
      ref.read(libraryDetailProvider(_arg).notifier).refreshLibraryMeta();
      ref.read(libraryDetailProvider(_arg).notifier).reload();
    }
  }

  Future<void> _openAdminMenu(
    LibraryView lib,
    LibraryDetailState state,
    bool galleryOn,
  ) async {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    final isPhoto = !lib.capabilities.playable;
    final isRefreshing = state.metadataRefresh?.refreshing == true;
    final pending = state.pendingIssuesCount;

    final action = await showMcSheet<String>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            McInsetGroup(
              header: '浏览显示',
              margin: EdgeInsets.zero,
              children: [
                if (!isPhoto && state.items.isNotEmpty)
                  McInsetRow(
                    icon: galleryOn ? McIcons.gallery1 : McIcons.imageAdd,
                    title: galleryOn ? '回到海报墙' : '图床浏览',
                    onTap: () => Navigator.of(ctx).pop('toggle_gallery'),
                  ),
                if (galleryOn || isPhoto)
                  McInsetRow(
                    icon: McIcons.listSettings2,
                    title: isPhoto ? '瀑布流密度设置' : '图床显示设置（分组与密度）',
                    onTap: () => Navigator.of(ctx).pop('gallery_prefs'),
                  ),
                if (state.viewMode == 'collections')
                  McInsetRow(
                    icon: state.showHiddenCollections
                        ? McIcons.eyeOff
                        : McIcons.eyeOpen,
                    title: state.showHiddenCollections
                        ? '隐藏已隐藏合集'
                        : '显示已隐藏合集',
                    onTap: () => Navigator.of(ctx).pop('toggle_hidden_cols'),
                  ),
              ],
            ),
            if (state.isAdmin) ...[
              const SizedBox(height: 12),
              McInsetGroup(
                header: '媒体库管理',
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    icon: McIcons.alert1,
                    title: pending > 0 ? '待处理中心（$pending）' : '待处理中心',
                    onTap: () => Navigator.of(ctx).pop('issues'),
                  ),
                  McInsetRow(
                    icon: lib.scanning ? McIcons.stop : McIcons.refresh,
                    title: lib.scanning ? '停止扫描' : '扫描媒体库',
                    destructive: lib.scanning,
                    onTap: () => Navigator.of(ctx)
                        .pop(lib.scanning ? 'stop_scan' : 'start_scan'),
                  ),
                  if (lib.capabilities.naming)
                    McInsetRow(
                      icon: McIcons.folderSettings,
                      title: '整理文件名…',
                      subtitle: '预览改名方案并规范目录结构',
                      onTap: () => Navigator.of(ctx).pop('organize'),
                    ),
                  if (lib.capabilities.scraped) ...[
                    if (isRefreshing)
                      McInsetRow(
                        icon: McIcons.stop,
                        title:
                            '停止元数据刷新 (${state.metadataRefresh!.processed}/${state.metadataRefresh!.total})',
                        destructive: true,
                        onTap: () => Navigator.of(ctx).pop('stop_refresh'),
                      )
                    else ...[
                      McInsetRow(
                        icon: McIcons.refresh,
                        title: '刷新元数据（全量重刮）',
                        onTap: () => Navigator.of(ctx).pop('refresh_all'),
                      ),
                      McInsetRow(
                        icon: McIcons.file,
                        title: '重新读取本地 NFO',
                        onTap: () => Navigator.of(ctx).pop('refresh_nfo'),
                      ),
                      McInsetRow(
                        icon: McIcons.imageAdd,
                        title: '重建缺失海报与剧照',
                        onTap: () => Navigator.of(ctx).pop('refresh_covers'),
                      ),
                    ],
                  ],
                  if (!isPhoto) ...[
                    McInsetRow(
                      icon: McIcons.film,
                      title: '生成章节关键帧图',
                      onTap: () => Navigator.of(ctx).pop('chapters'),
                    ),
                    McInsetRow(
                      icon: McIcons.refresh,
                      title: '强制重建全部章节图',
                      onTap: () => Navigator.of(ctx).pop('chapters_force'),
                    ),
                  ],
                  McInsetRow(
                    icon: McIcons.setting1,
                    title: '编辑媒体库设置…',
                    onTap: () => Navigator.of(ctx).pop('edit_lib'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'toggle_gallery':
          await GalleryPrefs.instance
              .setGalleryMode(!galleryOn, libraryId: widget.libraryId);
        case 'gallery_prefs':
          await showGalleryPrefsSheet(context, showsGrouping: !isPhoto);
        case 'toggle_hidden_cols':
          await notifier.toggleShowHiddenCollections();
        case 'issues':
          await _openIssueDrawer();
        case 'start_scan':
          await notifier.startScan();
          McToast.success('已触发媒体库扫描');
        case 'stop_scan':
          await notifier.stopScan();
          McToast.info('已请求停止扫描');
        case 'organize':
          await showLibraryOrganizeSheet(
            context,
            libraryId: widget.libraryId,
            onStarted: () {
              if (mounted) notifier.refreshLibraryMeta();
            },
          );
        case 'refresh_all':
          await notifier.startMetadataRefresh('all');
          McToast.success('已启动全量元数据刷新');
        case 'refresh_nfo':
          await notifier.startMetadataRefresh('nfo');
          McToast.success('已启动 NFO 重读');
        case 'refresh_covers':
          await notifier.startMetadataRefresh('covers');
          McToast.success('已启动封面重建');
        case 'stop_refresh':
          await notifier.stopMetadataRefresh();
          McToast.info('已请求停止刷新');
        case 'chapters':
          await notifier.generateChapters(force: false);
          McToast.success('已启动章节图生成');
        case 'chapters_force':
          await notifier.generateChapters(force: true);
          McToast.success('已启动强制重建章节图');
        case 'edit_lib':
          await _openEditLibrary(lib);
      }
    } catch (e) {
      if (mounted) McToast.error('操作失败：$e');
    }
  }

  Future<void> _jumpToEntry(LibraryIndexEntry entry, int cols) async {
    if (_lastIndexLetter == entry.initial) return;
    _lastIndexLetter = entry.initial;
    setState(() => _activeIndexEntry = entry);
    HapticFeedback.selectionClick();
    if (entry.count == 0) {
      Future<void>.delayed(const Duration(milliseconds: 550), () {
        if (mounted && _activeIndexEntry?.initial == entry.initial) {
          setState(() => _activeIndexEntry = null);
          if (_lastIndexLetter == entry.initial) _lastIndexLetter = null;
        }
      });
      return;
    }
    final localIdx = await ref
        .read(libraryDetailProvider(_arg).notifier)
        .jumpToIndexOffset(entry.offset);
    if (!mounted || localIdx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final row = localIdx ~/ cols;
      const estimatedRowHeight = 236.0;
      final target = (row * estimatedRowHeight).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(target);
    });
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _activeIndexEntry?.initial == entry.initial) {
        setState(() => _activeIndexEntry = null);
        if (_lastIndexLetter == entry.initial) _lastIndexLetter = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryDetailProvider(_arg));
    final library = state.library;
    final form = McFormWatch.of(context);
    _checkRecallOffer(state);

    // 管理员但自己不在可见成员中 → 锁屏提示页
    if (library != null && !library.viewerAccess) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Column(
          children: [
            McFloatingDetailBar(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              title: library.name,
              titleVisible: true,
            ),
            Expanded(
              child: McEmptyView(
                icon: McIcons.lock,
                title: '你当前不在「${library.name}」的可见成员名单中',
                text: '该媒体库设置了仅指定成员可见且未勾选管理员可见，因此浏览视图已锁定。',
                actionLabel: state.isAdmin ? '将我加入可见成员' : null,
                onRetry:
                    state.isAdmin ? () => _openEditLibrary(library) : null,
              ),
            ),
          ],
        ),
      );
    }

    final isPhoto = library != null && !library.capabilities.playable;

    return AnimatedBuilder(
      animation: GalleryPrefs.instance,
      builder: (context, _) {
        final galleryOn = !isPhoto &&
            state.viewMode == 'items' &&
            GalleryPrefs.instance.galleryModeFor(libraryId: widget.libraryId) &&
            state.items.isNotEmpty;
        final showIndex = !isPhoto &&
            !galleryOn &&
            state.viewMode == 'items' &&
            state.filter.sort == 'title' &&
            state.index.length > 1;
        final displayIndex = state.filter.order == 'desc'
            ? state.index.reversed.toList()
            : state.index;

        return Scaffold(
          backgroundColor: McTokens.bg,
          body: Stack(
            children: [
              Column(
                children: [
                  McFloatingDetailBar(
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    title: library?.name ?? '媒体库',
                    titleVisible: true,
                    trailing: [
                      if (!isPhoto && state.viewMode == 'items') ...[
                        McGlassIconButton(
                          icon: McIcons.filterS,
                          tooltip: '十维筛选',
                          badgeColor: state.filter.activeCount > 0
                              ? McTokens.accentStrong
                              : null,
                          onTap: () => _openFilterSheet(context, state),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (state.viewMode == 'items') ...[
                        McGlassIconButton(
                          icon: McIcons.sort,
                          tooltip: '排序',
                          onTap: () => _openSortSheet(context, state, isPhoto),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (library != null)
                        McGlassIconButton(
                          icon: McIcons.more,
                          tooltip: '更多操作',
                          badgeColor: state.isAdmin &&
                                  state.pendingIssuesCount > 0
                              ? McTokens.warning
                              : null,
                          onTap: () =>
                              _openAdminMenu(library, state, galleryOn),
                        ),
                    ],
                  ),

                  // 影片 / 合集 分段栏（照片库不显示合集切换）
                  if (!isPhoto)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        McTokens.pagePadding,
                        2,
                        McTokens.pagePadding,
                        6,
                      ),
                      child: Row(
                        children: [
                          McChip(
                            label: '影片',
                            icon: McIcons.film,
                            compact: true,
                            selected: state.viewMode == 'items',
                            onTap: () => ref
                                .read(libraryDetailProvider(_arg).notifier)
                                .setViewMode('items'),
                          ),
                          const SizedBox(width: 8),
                          McChip(
                            label: state.collections.isNotEmpty
                                ? '合集 (${state.collections.length})'
                                : '合集',
                            icon: McIcons.stack,
                            compact: true,
                            selected: state.viewMode == 'collections',
                            onTap: () => ref
                                .read(libraryDetailProvider(_arg).notifier)
                                .setViewMode('collections'),
                          ),
                          const Spacer(),
                          if (state.viewMode == 'items' && state.total > 0)
                            Text(
                              '共 ${state.total} 部',
                              style: McText.caption.faint.tabular,
                            ),
                        ],
                      ),
                    ),

                  // 主体内容
                  Expanded(
                    child: isPhoto
                        ? _buildPhotoBody(library, state)
                        : state.viewMode == 'collections'
                            ? _buildCollectionsView(context, state)
                            : _buildVideoWallBody(
                                context,
                                library,
                                state,
                                form,
                                galleryOn: galleryOn,
                                showIndex: showIndex,
                                displayIndex: displayIndex,
                              ),
                  ),
                ],
              ),

              // 底部「回到上次位置」胶囊
              if (_recallOffset != null && state.viewMode == 'items')
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom + 20,
                  child: Center(
                    child: WallRecallPill(
                      onJump: () {
                        final target = _recallOffset!;
                        setState(() => _recallOffset = null);
                        if (isPhoto) {
                          setState(() => _photoJump = PhotoWallJump(target));
                        } else if (galleryOn) {
                          setState(() => _galleryStart = target);
                        } else {
                          ref
                              .read(libraryDetailProvider(_arg).notifier)
                              .jumpToIndexOffset(target);
                        }
                      },
                      onDismiss: () => setState(() => _recallOffset = null),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 照片库主体（EXIF 按月相册 + 健康头）。
  Widget _buildPhotoBody(LibraryView library, LibraryDetailState state) {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    final grouped = state.filter.sort != 'added_at';
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
      onRefresh: () async {
        await notifier.refreshLibraryMeta();
        await notifier.reload();
      },
      child: PhotoWallView(
        libraryId: widget.libraryId,
        reloadKey: state.filter.filterKey,
        grouped: grouped,
        refreshToken: state.photoRefreshToken,
        jumpRequest: _photoJump,
        headerSlivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              McTokens.pagePadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _healthChipsSection(library, state),
                  if (state.metadataRefresh?.refreshing == true)
                    _metadataRefreshPanel(state.metadataRefresh!, notifier),
                ],
              ),
            ),
          ),
        ],
        padding: EdgeInsets.fromLTRB(
          McTokens.pagePadding,
          4,
          McTokens.pagePadding,
          48 + bottomPad,
        ),
        fetch: (offset, limit) => ref.read(libraryApiProvider).libraryItems(
              widget.libraryId,
              offset: offset,
              limit: limit,
              filterQuery: state.filter.toQuery(),
            ),
        onFirstVisible: (off) => _recordOffset(state, off),
      ),
    );
  }

  /// 影视/视频库主体（海报墙 / 图床模式 / 未刮削分栏 / 临时身份区 / 索引条）。
  Widget _buildVideoWallBody(
    BuildContext context,
    LibraryView? library,
    LibraryDetailState state,
    McDeviceForm form, {
    required bool galleryOn,
    required bool showIndex,
    required List<LibraryIndexEntry> displayIndex,
  }) {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final headerSlivers = <Widget>[
      if (library != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            child: _healthChipsSection(library, state),
          ),
        ),
      if (state.metadataRefresh?.refreshing == true)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              6,
              McTokens.pagePadding,
              4,
            ),
            child: _metadataRefreshPanel(
              state.metadataRefresh!,
              notifier,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: _filterBar(context, state),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = form == McDeviceForm.phone
            ? ((constraints.maxWidth - 32) / 130).floor().clamp(3, 6)
            : mcGridCrossAxisCount(
                form,
                BoxConstraints.tightFor(width: constraints.maxWidth - 32),
                cellExtent: 130,
              );

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await notifier.refreshLibraryMeta();
                await notifier.reload();
              },
              child: state.loading && state.items.isEmpty
                  ? const McLoadingView()
                  : state.error != null && state.items.isEmpty
                      ? McErrorView(
                          text: state.error!,
                          onRetry: notifier.reload,
                        )
                      : galleryOn
                          ? LibraryGalleryWall(
                              reloadKey: state.filter.filterKey,
                              startOffset: _galleryStart,
                              controller: _scroll,
                              headerSlivers: headerSlivers,
                              padding: EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                8,
                                McTokens.pagePadding,
                                40 + bottomPad,
                              ),
                              fetch: (offset, limit) => ref
                                  .read(libraryApiProvider)
                                  .libraryGallery(
                                    widget.libraryId,
                                    offset: offset,
                                    limit: limit,
                                    filterQuery: state.filter.toQuery(),
                                  ),
                              onFirstVisible: (off) =>
                                  _recordOffset(state, off),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.pixels >
                                    n.metrics.maxScrollExtent - 400) {
                                  notifier.loadMore();
                                }
                                if (n is ScrollEndNotification &&
                                    state.items.isNotEmpty) {
                                  final approxRow = (n.metrics.pixels / 215)
                                      .floor()
                                      .clamp(0, 99999);
                                  _recordOffset(
                                    state,
                                    state.baseOffset + approxRow * cols,
                                  );
                                }
                                return false;
                              },
                              child: CustomScrollView(
                                controller: _scroll,
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  ...headerSlivers,
                                  if (state.baseOffset > 0)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          bottom: 4,
                                        ),
                                        child: Center(
                                          child: McActionPill(
                                            label: state.loadingPrevious
                                                ? '加载中…'
                                                : '加载前面已跳过的作品',
                                            icon: Icons.arrow_upward_rounded,
                                            onTap: state.loadingPrevious
                                                ? null
                                                : notifier.loadPrevious,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ..._buildItemWallSlivers(
                                    context,
                                    library,
                                    state,
                                    cols,
                                    showIndex: showIndex,
                                  ),
                                  if (state.provisionalItems.isNotEmpty)
                                    ..._buildProvisionalSection(
                                      context,
                                      state.provisionalItems,
                                      cols,
                                      showIndex: showIndex,
                                    ),
                                  SliverPadding(
                                    padding: EdgeInsets.only(
                                      bottom: 44 + bottomPad,
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),

            // 右侧 A–Z 索引条（倒序自动反向）
            if (showIndex)
              Positioned(
                top: 32,
                bottom: 32 + bottomPad,
                right: 4,
                child: _AlphaIndexRail(
                  entries: displayIndex,
                  activeInitial: _activeIndexEntry?.initial,
                  onPick: (e) => _jumpToEntry(e, cols),
                  onInteractionEnd: () => _lastIndexLetter = null,
                ),
              ),

            // 索引定位浮窗气泡（显示字母 + 部数/无作品）
            if (_activeIndexEntry != null)
              Center(
                child: McLiquidGlass(
                  tone: McGlassTone.regular,
                  radius: McTokens.cardRadius,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _activeIndexEntry!.initial,
                        style: McText.display.copyWith(fontSize: 38),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeIndexEntry!.count > 0
                            ? '${_activeIndexEntry!.count} 部'
                            : '无作品',
                        style: McText.caption.muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 页头健康状态胶囊（上次扫描、实时扫描/整理进度、待入库、缺失/待识别/复核跳转待处理抽屉）。
  Widget _healthChipsSection(LibraryView lib, LibraryDetailState state) {
    final chips = <Widget>[];
    if (lib.scanning) {
      final p = lib.scanProgress;
      final label = p != null && p.total > 0
          ? '${scanPhaseLabel(p.phase)} ${p.processed}/${p.total}'
          : scanPhaseLabel(p?.phase);
      chips.add(
        McChip(
          label: label,
          icon: McIcons.refresh,
          compact: true,
          selected: true,
        ),
      );
    } else if (lib.organizing) {
      final p = lib.organizeProgress;
      final label = p != null && p.total > 0
          ? '正在整理 ${p.processed}/${p.total}'
          : '正在整理文件名';
      chips.add(
        McChip(
          label: label,
          icon: McIcons.folderSettings,
          compact: true,
          selected: true,
          onTap: () => showLibraryOrganizeSheet(
            context,
            libraryId: widget.libraryId,
          ),
        ),
      );
    } else if (lib.lastScanAt != null && lib.lastScanAt!.isNotEmpty) {
      chips.add(
        McChip(
          label: '上次扫描 ${mcFromNowIso(lib.lastScanAt)}',
          compact: true,
        ),
      );
    }

    if (state.isAdmin) {
      if (lib.missingCount > 0) {
        chips.add(
          McChip(
            label: '缺失 ${lib.missingCount}',
            icon: McIcons.alert1,
            compact: true,
            onTap: () => _openIssueDrawer(initialTab: 'missing'),
          ),
        );
      }
      if (lib.unidentifiedCount > 0) {
        chips.add(
          McChip(
            label: '待识别 ${lib.unidentifiedCount}',
            icon: McIcons.search,
            compact: true,
            onTap: () => _openIssueDrawer(initialTab: 'unidentified'),
          ),
        );
      }
      if (lib.reviewCount > 0) {
        chips.add(
          McChip(
            label: '待复核 ${lib.reviewCount}',
            icon: McIcons.edit,
            compact: true,
            onTap: () => _openIssueDrawer(initialTab: 'review'),
          ),
        );
      }
      if (lib.pendingIngestCount > 0) {
        chips.add(
          McChip(
            label: '待入库 ${lib.pendingIngestCount}',
            compact: true,
          ),
        );
      }
      if (lib.activeJobsCount > 0) {
        chips.add(
          McChip(
            label: '后台任务 ${lib.activeJobsCount}',
            compact: true,
          ),
        );
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in chips)
              Padding(padding: const EdgeInsets.only(right: 6), child: c),
          ],
        ),
      ),
    );
  }

  /// 整库元数据刷新进度面板（2s 轮询 + 停止按钮）。
  Widget _metadataRefreshPanel(
    MetadataRefresh mr,
    LibraryDetailController notifier,
  ) {
    final frac = mr.total > 0 ? (mr.processed / mr.total).clamp(0.0, 1.0) : 0.0;
    final headline = StringBuffer(mr.stopping ? '正在停止刷新' : '正在刷新元数据');
    if (mr.total > 0) headline.write(' ${mr.processed}/${mr.total}');
    if (mr.failed > 0) headline.write(' · 失败 ${mr.failed}');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.info.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: McTokens.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: McTokens.info,
                  ),
                ),
              ),
              TextButton(
                onPressed: mr.stopping
                    ? null
                    : () async {
                        try {
                          await notifier.stopMetadataRefresh();
                        } catch (e) {
                          McToast.error('停止失败：$e');
                        }
                      },
                child: Text(mr.stopping ? '收尾中…' : '停止'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: frac,
            color: McTokens.info,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
          if (mr.active.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final a in mr.active.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: McTokens.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(a.phase, style: McText.caption.faint),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 主墙网格 Sliver：包含 0 结果 `/relax` 放宽建议，以及未刮削库横/竖版分栏。
  List<Widget> _buildItemWallSlivers(
    BuildContext context,
    LibraryView? library,
    LibraryDetailState state,
    int cols, {
    required bool showIndex,
  }) {
    final rightPad =
        showIndex ? McTokens.pagePadding + 24 : McTokens.pagePadding;

    if (state.items.isEmpty) {
      final relax = state.relax;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            child: Column(
              children: [
                const McEmptyView(
                  icon: McIcons.filter,
                  title: '没有符合条件的媒体',
                  text: '当前筛选组合太严格，可以尝试放宽其中某一条条件。',
                ),
                if (relax != null && relax.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in relax.suggestions)
                        McActionPill(
                          label: '去掉 ${s.label} → 救回 ${s.count} 部',
                          height: 34,
                          onTap: () => ref
                              .read(libraryDetailProvider(_arg).notifier)
                              .applyRelax(s),
                        ),
                    ],
                  ),
                ],
                if (!state.filter.isEmpty) ...[
                  const SizedBox(height: 14),
                  McActionPill(
                    label: '清空全部条件',
                    primary: true,
                    onTap: () => ref
                        .read(libraryDetailProvider(_arg).notifier)
                        .clearFilter(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    // 未刮削库（如其他视频）：竖图（primaryAspect < 1）和横图（>= 1）分两段排布，互不挤歪比例
    final unscraped = library != null && !library.capabilities.scraped;
    if (unscraped) {
      final portraits =
          state.items.where((i) => i.primaryAspect < 1.0).toList();
      final landscapes =
          state.items.where((i) => i.primaryAspect >= 1.0).toList();
      if (portraits.isNotEmpty && landscapes.isNotEmpty) {
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              8,
              rightPad,
              16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => mcItemCard(
                  ctx,
                  landscapes[i],
                  width: null,
                  frameAspect: 16 / 9,
                  fallbackLibraryId: widget.libraryId,
                ),
                childCount: landscapes.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                McTokens.pagePadding,
                8,
                McTokens.pagePadding,
                8,
              ),
              child: Text('竖屏视频 · ${portraits.length}', style: McText.titleSm),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              rightPad,
              16,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.515,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => mcItemCard(
                  ctx,
                  portraits[i],
                  width: null,
                  fallbackLibraryId: widget.libraryId,
                ),
                childCount: portraits.length,
              ),
            ),
          ),
        ];
      }
      if (landscapes.isNotEmpty) {
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              8,
              rightPad,
              20,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => mcItemCard(
                  ctx,
                  landscapes[i],
                  width: null,
                  frameAspect: 16 / 9,
                  fallbackLibraryId: widget.libraryId,
                ),
                childCount: landscapes.length,
              ),
            ),
          ),
        ];
      }
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(McTokens.pagePadding, 8, rightPad, 20),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.515,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => mcItemCard(
              context,
              state.items[i],
              width: null,
              fallbackLibraryId: widget.libraryId,
              showRating: state.filter.sort == 'rating',
            ),
            childCount: state.items.length,
          ),
        ),
      ),
    ];
  }

  /// 临时身份区（`identity=provisional`）：尚未最终认领但可先播放的条目。
  List<Widget> _buildProvisionalSection(
    BuildContext context,
    List<LibraryItemView> items,
    int cols, {
    required bool showIndex,
  }) {
    final rightPad =
        showIndex ? McTokens.pagePadding + 24 : McTokens.pagePadding;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            McTokens.pagePadding,
            20,
            McTokens.pagePadding,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('临时身份 · ${items.length} 部', style: McText.titleSm),
                    Text(
                      '尚未最终匹配 TMDB 档案，可先正常观看，随时去待处理认领。',
                      style: McText.caption.faint,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openIssueDrawer(initialTab: 'unidentified'),
                child: const Text('去认领'),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(McTokens.pagePadding, 4, rightPad, 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.515,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => mcItemCard(
              ctx,
              items[i],
              width: null,
              fallbackLibraryId: widget.libraryId,
            ),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  /// 顶部已选条件胶囊条（含演员 chip、清空、以及非演员筛选时的「存为合集」按钮）。
  Widget _filterBar(BuildContext context, LibraryDetailState state) {
    final f = state.filter;
    if (f.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        2,
        McTokens.pagePadding,
        6,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (f.hasActor)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: McChip(
                  label: '演员：${f.actor} ×',
                  compact: true,
                  selected: true,
                  onTap: () => notifier.applyFilter(f.copyWith(clearActor: true)),
                ),
              ),
            McChip(
              label: '已选 ${f.activeCount} 项筛选',
              icon: McIcons.filter,
              compact: true,
              selected: true,
              onTap: () => _openFilterSheet(context, state),
            ),
            if (!f.hasActor) ...[
              const SizedBox(width: 8),
              McChip(
                label: '存为合集',
                icon: McIcons.stack,
                compact: true,
                onTap: () => _openSaveAsCollectionSheet(context, state),
              ),
            ],
            const SizedBox(width: 8),
            McChip(
              label: '清空',
              icon: McIcons.close,
              compact: true,
              onTap: notifier.clearFilter,
            ),
          ],
        ),
      ),
    );
  }

  /// 合集分段视图（3 错叠海报网格 + 显示已隐藏切换）。
  Widget _buildCollectionsView(BuildContext context, LibraryDetailState state) {
    final form = McFormWatch.of(context);
    if (state.collections.isEmpty) {
      return McEmptyView(
        icon: McIcons.stack,
        title: '此媒体库还没有合集',
        text: '先在「影片」视图筛选喜欢的条件，然后点击「存为合集」创建动态规则或定格合集。',
        actionLabel: '去筛选影片',
        onRetry: () => ref
            .read(libraryDetailProvider(_arg).notifier)
            .setViewMode('items'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryDetailProvider(_arg).notifier).reload(),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          McTokens.pagePadding,
          10,
          McTokens.pagePadding,
          36 + MediaQuery.paddingOf(context).bottom,
        ),
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
        itemCount: state.collections.length,
        itemBuilder: (_, i) {
          final c = state.collections[i];
          final tags = [
            '${c.itemCount} 部',
            if (c.kind == 'series')
              '系列'
            else if (c.ruleDriven)
              '自动收录',
            if (c.hidden) '已隐藏',
          ];
          return GestureDetector(
            onTap: () => context.push(routeLibraryCollection(c.id)),
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
      ),
    );
  }

  /// 「存为合集」弹层（对齐 `SaveAsCollectionSheet.swift`：自动语义命名 + 动态规则 vs 定格快照 + 私密开关）。
  Future<void> _openSaveAsCollectionSheet(
    BuildContext context,
    LibraryDetailState state,
  ) async {
    final facets = state.facets;
    final filter = state.filter;

    String? labelOf(List<FacetValue>? pool, String v) {
      if (pool == null) return null;
      for (final f in pool) {
        if (f.value == v) return f.label;
      }
      return null;
    }

    final parts = <String>[
      for (final g in filter.genres)
        if (labelOf(facets?.genres, g) != null) labelOf(facets?.genres, g)!,
      for (final c in filter.countries)
        if (labelOf(facets?.countries, c) != null)
          labelOf(facets?.countries, c)!,
      for (final d in filter.decades)
        if (labelOf(facets?.decades, d) != null) labelOf(facets?.decades, d)!,
      for (final w in filter.watch)
        if (labelOf(facets?.watch, w) != null) labelOf(facets?.watch, w)!,
      if (filter.ratingGte != null) '≥ ${filter.ratingGte} 分',
      ...filter.resolutions,
    ];
    final suggested = parts.take(3).join(' · ');

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => _SaveAsCollectionSheet(
        suggested: suggested,
        total: state.total,
        onSave: ({
          required String name,
          required bool snapshot,
          required String visibility,
        }) async {
          final created = await ref
              .read(libraryDetailProvider(_arg).notifier)
              .saveAsCollection(
                name: name,
                snapshot: snapshot,
                visibility: visibility,
              );
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          McToast.success('已保存为合集「${created.name}」');
          if (mounted) {
            context.push(routeLibraryCollection(created.id));
          }
        },
      ),
    );
  }

  void _openSortSheet(
    BuildContext context,
    LibraryDetailState state,
    bool isPhoto,
  ) {
    final sorts = isPhoto
        ? const <(String, String)>[
            ('release_date', '按拍摄日期（按月相册）'),
            ('added_at', '按最近添加'),
            ('title', '按文件名'),
            ('size', '按文件大小'),
          ]
        : const <(String, String)>[
            ('title', '按名称'),
            ('added_at', '按添加时间'),
            ('release_date', '按上映日期'),
            ('rating', '按评分'),
            ('runtime', '按时长'),
            ('size', '按体积'),
            ('last_played', '按最近观看'),
            ('random', '随机'),
          ];
    final currentOrder =
        state.filter.order ?? (state.filter.sort == 'title' ? 'asc' : 'desc');
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            McInsetGroup(
              header: '排序方式',
              margin: EdgeInsets.zero,
              children: [
                for (final (value, label) in sorts)
                  McInsetRow(
                    title: label,
                    trailing: state.filter.sort == value
                        ? const Icon(
                            McIcons.check,
                            size: 18,
                            color: McTokens.accentStrong,
                          )
                        : null,
                    onTap: () {
                      final defaultOrder = value == 'title' ? 'asc' : 'desc';
                      ref
                          .read(libraryDetailProvider(_arg).notifier)
                          .setSort(value, defaultOrder);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
            if (state.filter.sort != 'random') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: McActionPill(
                      label: '升序',
                      primary: currentOrder == 'asc',
                      expanded: true,
                      onTap: () {
                        ref
                            .read(libraryDetailProvider(_arg).notifier)
                            .setSort(state.filter.sort, 'asc');
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: McActionPill(
                      label: '降序',
                      primary: currentOrder == 'desc',
                      expanded: true,
                      onTap: () {
                        ref
                            .read(libraryDetailProvider(_arg).notifier)
                            .setSort(state.filter.sort, 'desc');
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 十维筛选抽屉（count==0 未选置灰不可点，评分与 HDR 使用服务端真实分面计数）。
  void _openFilterSheet(BuildContext context, LibraryDetailState state) {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    showMcSheet<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (sheetCtx, sheetRef, __) {
          final live = sheetRef.watch(libraryDetailProvider(_arg));
          final f = live.filter;
          final facets = live.facets;

          Widget facetGroup(
            String title,
            List<FacetValue> values,
            Set<String> selected,
            LibraryFilter Function(Set<String>) updater,
          ) {
            if (values.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: McText.caption.muted),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final fv in values) ...[
                        () {
                          final on = selected.contains(fv.value);
                          final disabled = fv.count == 0 && !on;
                          return Opacity(
                            opacity: disabled ? 0.3 : 1,
                            child: McChip(
                              label: '${fv.label} ${fv.count}',
                              compact: true,
                              selected: on,
                              onTap: disabled
                                  ? null
                                  : () {
                                      final next = {...selected};
                                      if (!next.remove(fv.value)) {
                                        next.add(fv.value);
                                      }
                                      notifier.applyFilter(updater(next));
                                    },
                            ),
                          );
                        }(),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }

          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '筛选（命中 ${live.total} 部）',
                          style: McText.titleSm,
                        ),
                      ),
                      if (!f.isEmpty)
                        TextButton(
                          onPressed: notifier.clearFilter,
                          child: const Text('清空'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: McTokens.line),
                Expanded(
                  child: facets == null
                      ? const McLoadingView()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            facetGroup(
                              '类型',
                              facets.genres,
                              f.genres,
                              (s) => f.copyWith(genres: s),
                            ),
                            facetGroup(
                              '地区',
                              facets.countries,
                              f.countries,
                              (s) => f.copyWith(countries: s),
                            ),
                            facetGroup(
                              '年代',
                              facets.decades,
                              f.decades,
                              (s) => f.copyWith(decades: s),
                            ),
                            facetGroup(
                              '观看状态',
                              facets.watch,
                              f.watch,
                              (s) => f.copyWith(watch: s),
                            ),
                            // 真实评分分面计数
                            if (facets.ratings.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('评分', style: McText.caption.muted),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final rv in facets.ratings) ...[
                                          () {
                                            final val =
                                                double.tryParse(rv.value);
                                            final on = val != null &&
                                                f.ratingGte == val;
                                            final disabled =
                                                rv.count == 0 && !on;
                                            return Opacity(
                                              opacity: disabled ? 0.3 : 1,
                                              child: McChip(
                                                label:
                                                    '${rv.label} ${rv.count}',
                                                compact: true,
                                                selected: on,
                                                onTap: disabled || val == null
                                                    ? null
                                                    : () => notifier.applyFilter(
                                                          on
                                                              ? f.copyWith(
                                                                  clearRating:
                                                                      true,
                                                                )
                                                              : f.copyWith(
                                                                  ratingGte:
                                                                      val,
                                                                ),
                                                        ),
                                              ),
                                            );
                                          }(),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            facetGroup(
                              '片长',
                              facets.runtimes,
                              f.runtimes,
                              (s) => f.copyWith(runtimes: s),
                            ),
                            facetGroup(
                              '语言',
                              facets.languages,
                              f.languages,
                              (s) => f.copyWith(languages: s),
                            ),
                            facetGroup(
                              '分辨率',
                              facets.resolutions,
                              f.resolutions,
                              (s) => f.copyWith(resolutions: s),
                            ),
                            // 真实 HDR 分面计数
                            if (facets.hdr.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('动态范围', style: McText.caption.muted),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final hv in facets.hdr) ...[
                                          () {
                                            final bVal = hv.value == 'true' ||
                                                hv.value == '1';
                                            final on = f.hdr == bVal;
                                            final disabled =
                                                hv.count == 0 && !on;
                                            return Opacity(
                                              opacity: disabled ? 0.3 : 1,
                                              child: McChip(
                                                label:
                                                    '${hv.label} ${hv.count}',
                                                compact: true,
                                                selected: on,
                                                onTap: disabled
                                                    ? null
                                                    : () => notifier.applyFilter(
                                                          on
                                                              ? f.copyWith(
                                                                  clearHdr:
                                                                      true,
                                                                )
                                                              : f.copyWith(
                                                                  hdr: bVal,
                                                                ),
                                                        ),
                                              ),
                                            );
                                          }(),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            facetGroup(
                              '库存状态',
                              facets.stock,
                              f.stock,
                              (s) => f.copyWith(stock: s),
                            ),
                          ],
                        ),
                ),
                if (!f.isEmpty && !f.hasActor)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: McActionPill(
                      label: '将当前筛选存为合集',
                      icon: McIcons.stack,
                      primary: true,
                      expanded: true,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _openSaveAsCollectionSheet(context, live);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 「存为合集」弹层内容（独立 StatefulWidget 管理并安全释放 TextEditingController）。
class _SaveAsCollectionSheet extends StatefulWidget {
  const _SaveAsCollectionSheet({
    required this.suggested,
    required this.total,
    required this.onSave,
  });

  final String suggested;
  final int total;
  final Future<void> Function({
    required String name,
    required bool snapshot,
    required String visibility,
  }) onSave;

  @override
  State<_SaveAsCollectionSheet> createState() => _SaveAsCollectionSheetState();
}

class _SaveAsCollectionSheetState extends State<_SaveAsCollectionSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.suggested);
  bool _snapshot = false;
  bool _privateOnly = false;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('存为合集', style: McText.titleSm),
          const SizedBox(height: 4),
          Text(
            '当前筛选命中 ${widget.total} 部作品',
            style: McText.caption.muted,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: widget.suggested.isEmpty,
            style: McText.body,
            decoration: InputDecoration(
              labelText: '合集名称',
              hintText:
                  widget.suggested.isEmpty ? '例如：90 年代科幻佳作' : widget.suggested,
            ),
          ),
          const SizedBox(height: 14),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                title: '自动收录（动态规则）',
                subtitle: '以后入库的新片只要符合这组条件也会自动归入',
                trailing: Icon(
                  !_snapshot
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color:
                      !_snapshot ? McTokens.accentStrong : McTokens.textFaint,
                ),
                onTap: () => setState(() => _snapshot = false),
              ),
              McInsetRow(
                title: '固定这批（${widget.total} 部快照）',
                subtitle: '定格为手动名单，后续新入库作品不会自动加入',
                trailing: Icon(
                  _snapshot
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _snapshot ? McTokens.accentStrong : McTokens.textFaint,
                ),
                onTap: () => setState(() => _snapshot = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _privateOnly,
            onChanged: (v) => setState(() => _privateOnly = v),
            title: const Text('仅自己可见', style: McText.body),
            subtitle: const Text(
              '关闭则与家庭所有有权限的成员共享',
              style: TextStyle(fontSize: 12, color: McTokens.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          McActionPill(
            label: _saving ? '保存中…' : '创建合集',
            primary: true,
            expanded: true,
            onTap: _saving
                ? null
                : () async {
                    final name = _ctrl.text.trim().isEmpty
                        ? widget.suggested
                        : _ctrl.text.trim();
                    if (name.isEmpty) {
                      McToast.error('请输入合集名称');
                      return;
                    }
                    setState(() => _saving = true);
                    try {
                      await widget.onSave(
                        name: name,
                        snapshot: _snapshot,
                        visibility: _privateOnly ? 'private' : 'household',
                      );
                    } catch (e) {
                      if (mounted) setState(() => _saving = false);
                      McToast.error('保存失败：$e');
                    }
                  },
          ),
        ],
      ),
    );
  }
}

/// 右侧 A–Z 索引条（支持点按与垂直滑擦定位；同一字母不重复触发震动与请求）。
class _AlphaIndexRail extends StatefulWidget {
  const _AlphaIndexRail({
    required this.entries,
    required this.activeInitial,
    required this.onPick,
    this.onInteractionEnd,
  });

  final List<LibraryIndexEntry> entries;
  final String? activeInitial;
  final ValueChanged<LibraryIndexEntry> onPick;
  final VoidCallback? onInteractionEnd;

  @override
  State<_AlphaIndexRail> createState() => _AlphaIndexRailState();
}

class _AlphaIndexRailState extends State<_AlphaIndexRail> {
  String? _lastPickedInitial;

  void _pickAt(Offset localPos, double totalHeight) {
    if (widget.entries.isEmpty || totalHeight <= 0) return;
    final idx =
        ((localPos.dy / totalHeight) * widget.entries.length).floor().clamp(
              0,
              widget.entries.length - 1,
            );
    final entry = widget.entries[idx];
    if (_lastPickedInitial == entry.initial) return;
    _lastPickedInitial = entry.initial;
    widget.onPick(entry);
  }

  void _endInteraction() {
    _lastPickedInitial = null;
    widget.onInteractionEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            _lastPickedInitial = null;
            _pickAt(d.localPosition, box.maxHeight);
          },
          onTapUp: (_) => _endInteraction(),
          onTapCancel: _endInteraction,
          onVerticalDragStart: (d) {
            _lastPickedInitial = null;
            _pickAt(d.localPosition, box.maxHeight);
          },
          onVerticalDragUpdate: (d) => _pickAt(d.localPosition, box.maxHeight),
          onVerticalDragEnd: (_) => _endInteraction(),
          onVerticalDragCancel: _endInteraction,
          child: Container(
            width: 22,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final e in widget.entries)
                  Text(
                    e.initial,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: widget.activeInitial == e.initial
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: widget.activeInitial == e.initial
                          ? McTokens.accentStrong
                          : (e.count > 0
                              ? McTokens.textMuted
                              : McTokens.textFaint.withValues(alpha: 0.35)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
