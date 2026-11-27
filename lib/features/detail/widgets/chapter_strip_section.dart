import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/detail_controller.dart';

/// 详情页「章节」横排（1:1 对齐 iOS `ChapterStripSection.swift`）：
/// - 16:9 章节图卡片 + 左下角时间戳 + 右上角「上次看到这里」（自动横滚入视野）；
/// - 后台生成中（`pending == true`）在标题右侧展示进度指示并在无章节时展示骨架；
/// - 有图章节点击打开可缩放灯箱（滑动翻页 + 顶栏「从此处播放」）；无图章节点击直接跳播。
class ChapterStripSection extends StatefulWidget {
  const ChapterStripSection({
    super.key,
    required this.chapters,
    required this.onPlayFrom,
    this.pending = false,
    this.resumeMs,
  });

  final List<DetailChapter> chapters;
  final void Function(Duration startPosition) onPlayFrom;
  final bool pending;
  final int? resumeMs;

  @override
  State<ChapterStripSection> createState() => _ChapterStripSectionState();
}

class _ChapterStripSectionState extends State<ChapterStripSection> {
  final ScrollController _scroll = ScrollController();
  bool _resumeScrolled = false;

  static const double _cardWidth = 200;
  static const double _cardSpacing = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScrollToResume());
  }

  @override
  void didUpdateWidget(covariant ChapterStripSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resumeMs != widget.resumeMs ||
        oldWidget.chapters.length != widget.chapters.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScrollToResume());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int? get _resumeChapterIndex {
    final pos = widget.resumeMs;
    if (pos == null || pos <= 0 || widget.chapters.isEmpty) return null;
    for (final c in widget.chapters) {
      final inStart = pos >= c.startMs;
      final inEnd = c.endMs == null || pos < c.endMs!;
      if (inStart && inEnd) return c.index;
    }
    return null;
  }

  void _maybeScrollToResume() {
    if (_resumeScrolled || !_scroll.hasClients) return;
    final targetIdx = _resumeChapterIndex;
    if (targetIdx == null) return;
    final listPos = widget.chapters.indexWhere((c) => c.index == targetIdx);
    if (listPos < 0) return;
    _resumeScrolled = true;
    final viewport = _scroll.position.viewportDimension;
    final rawOffset = listPos * (_cardWidth + _cardSpacing) -
        (viewport - _cardWidth) / 2 +
        McTokens.pagePadding;
    final clamped = rawOffset.clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _openChapter(DetailChapter chapter) {
    final withImages = widget.chapters
        .where((c) => c.imageUrl != null && c.imageUrl!.isNotEmpty)
        .toList();
    final idx = withImages.indexWhere((c) => c.index == chapter.index);
    if (idx < 0) {
      widget.onPlayFrom(Duration(milliseconds: chapter.effectiveMs));
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        pageBuilder: (_, __, ___) => _ChapterLightboxPage(
          chapters: withImages,
          initialIndex: idx,
          onPlayFrom: (pos) {
            widget.onPlayFrom(pos);
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty && !widget.pending) {
      return const SizedBox.shrink();
    }
    final resumeIndex = _resumeChapterIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        McSectionHeader(
          title: '章节',
          countLabel:
              widget.chapters.isNotEmpty ? '${widget.chapters.length} 章' : null,
          trailing: widget.pending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: McTokens.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '正在生成章节图…',
                      style: McText.caption.muted,
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 146,
          child: widget.chapters.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: McTokens.pagePadding,
                  ),
                  itemCount: 4,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _cardSpacing),
                  itemBuilder: (_, __) => const _ChapterSkeletonCard(),
                )
              : ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: McTokens.pagePadding,
                  ),
                  itemCount: widget.chapters.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _cardSpacing),
                  itemBuilder: (context, i) {
                    final chapter = widget.chapters[i];
                    return _ChapterCard(
                      chapter: chapter,
                      resumeHere: chapter.index == resumeIndex,
                      onTap: () => _openChapter(chapter),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChapterSkeletonCard extends StatelessWidget {
  const _ChapterSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 112.5,
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            alignment: Alignment.center,
            child: const Icon(
              McIcons.film,
              size: 24,
              color: McTokens.textFaint,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 108,
            height: 12,
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.resumeHere,
    required this.onTap,
  });

  final DetailChapter chapter;
  final bool resumeHere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clock = mcClock(chapter.effectiveMs);
    final label = (chapter.title != null && chapter.title!.trim().isNotEmpty)
        ? chapter.title!.trim()
        : '第 ${chapter.index + 1} 章';
    final resolved = McImageUrls.resolve(chapter.imageUrl, widthPx: 420);

    return McPressable(
      onTap: onTap,
      scaleDown: 0.98,
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 112.5,
              decoration: BoxDecoration(
                color: McTokens.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: resumeHere
                      ? const Color(0xCC9FB0C9)
                      : const Color(0x14FFFFFF),
                  width: resumeHere ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (resolved.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: resolved,
                      httpHeaders: mcImageHeaders(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(clock),
                      errorWidget: (_, __, ___) => _placeholder(clock),
                    )
                  else
                    _placeholder(clock),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        clock,
                        style: McText.micro
                            .copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            )
                            .tabular,
                      ),
                    ),
                  ),
                  if (resumeHere)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9FB0C9),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          '上次看到这里',
                          style: McText.micro.copyWith(
                            color: McTokens.onAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.sub.copyWith(
                color: McTokens.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String clock) {
    return ColoredBox(
      color: McTokens.surfaceRaised,
      child: Center(
        child: Text(
          clock,
          style: McText.title.copyWith(
            color: Colors.white.withValues(alpha: 0.2),
            fontWeight: FontWeight.w700,
          ).tabular,
        ),
      ),
    );
  }
}

/// 章节图全屏缩放灯箱（双指缩放 + 左右翻页 + 顶栏「从此处播放」+ 底部缩略图条）。
class _ChapterLightboxPage extends StatefulWidget {
  const _ChapterLightboxPage({
    required this.chapters,
    required this.initialIndex,
    required this.onPlayFrom,
  });

  final List<DetailChapter> chapters;
  final int initialIndex;
  final void Function(Duration startPosition) onPlayFrom;

  @override
  State<_ChapterLightboxPage> createState() => _ChapterLightboxPageState();
}

class _ChapterLightboxPageState extends State<_ChapterLightboxPage> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _chromeVisible = true;
  bool _isZoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _stepPage(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.chapters.length) return;
    _page.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.chapters[_index];
    final clock = mcClock(current.effectiveMs);
    final caption = (current.title != null && current.title!.trim().isNotEmpty)
        ? '${current.title!.trim()} · $clock'
        : '第 ${current.index + 1} 章 · $clock';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _stepPage(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _stepPage(1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _page,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.chapters.length,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _isZoomed = false;
                }),
                itemBuilder: (_, i) {
                  final ch = widget.chapters[i];
                  final url = McImageUrls.resolve(ch.imageUrl, widthPx: 1440);
                  return _ZoomableChapterSlide(
                    imageUrl: url,
                    onSingleTap: () =>
                        setState(() => _chromeVisible = !_chromeVisible),
                    onZoomChanged: (zoomed) {
                      if (i == _index && _isZoomed != zoomed) {
                        setState(() => _isZoomed = zoomed);
                      }
                    },
                  );
                },
              ),
          if (_chromeVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                    ),
                  ),
                  child: Row(
                    children: [
                      McGlassIconButton(
                        icon: McIcons.close,
                        tooltip: '关闭',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.ui.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_index + 1} / ${widget.chapters.length}',
                              style: McText.micro.faint.tabular,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      McActionPill(
                        label: '从此处播放',
                        icon: McIcons.play2Fill,
                        primary: true,
                        height: 36,
                        onTap: () {
                          final pos = Duration(
                            milliseconds: current.effectiveMs,
                          );
                          Navigator.of(context).pop();
                          widget.onPlayFrom(pos);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_chromeVisible && widget.chapters.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xB3000000),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: widget.chapters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final ch = widget.chapters[i];
                      final active = i == _index;
                      return GestureDetector(
                        onTap: () => _page.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        child: Container(
                          width: 92,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active
                                  ? McTokens.accentStrong
                                  : Colors.white.withValues(alpha: 0.16),
                              width: active ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: McImageUrls.resolve(
                              ch.imageUrl,
                              widthPx: 240,
                            ),
                            httpHeaders: mcImageHeaders(),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
      ),
    );
  }
}

class _ZoomableChapterSlide extends StatefulWidget {
  const _ZoomableChapterSlide({
    required this.imageUrl,
    required this.onSingleTap,
    required this.onZoomChanged,
  });

  final String imageUrl;
  final VoidCallback onSingleTap;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableChapterSlide> createState() => _ZoomableChapterSlideState();
}

class _ZoomableChapterSlideState extends State<_ZoomableChapterSlide> {
  final TransformationController _ctrl = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTransformChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final zoomed = _ctrl.value.getMaxScaleOnAxis() > 1.01;
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTap() {
    final scale = _ctrl.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      _ctrl.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      const zoom = 2.5;
      _ctrl.value = Matrix4.identity()
        ..translateByDouble(-pos.dx * (zoom - 1), -pos.dy * (zoom - 1), 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onSingleTap,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            httpHeaders: mcImageHeaders(),
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                color: McTokens.accent,
              ),
            ),
            errorWidget: (_, __, ___) => const Icon(
              McIcons.film,
              size: 48,
              color: McTokens.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}
