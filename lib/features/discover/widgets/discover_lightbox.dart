import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';

/// 发现模块全屏可缩放看图灯箱（对齐 iOS `DiscoverLightbox.swift`）：
/// - 左右滑动翻页、双指缩放、双击 1× / 2.5× 切换；
/// - 顶部标题 + 序号 + 关闭按钮；
/// - 底部缩略图条（≥2 张时显示，高亮当前项，点击直达）。
class DiscoverLightboxPage extends StatefulWidget {
  const DiscoverLightboxPage({
    super.key,
    required this.urls,
    required this.title,
    this.thumbnails,
    this.initialIndex = 0,
    this.thumbAspect = 16 / 9,
  });

  final List<String> urls;
  final List<String>? thumbnails;
  final String title;
  final int initialIndex;
  final double thumbAspect;

  static Future<void> show(
    BuildContext context, {
    required List<String> urls,
    required String title,
    List<String>? thumbnails,
    int initialIndex = 0,
    double thumbAspect = 16 / 9,
  }) {
    if (urls.isEmpty) return Future.value();
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => DiscoverLightboxPage(
          urls: urls,
          thumbnails: thumbnails,
          title: title,
          initialIndex: initialIndex,
          thumbAspect: thumbAspect,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<DiscoverLightboxPage> createState() => _DiscoverLightboxPageState();
}

class _DiscoverLightboxPageState extends State<DiscoverLightboxPage> {
  late int _index =
      widget.initialIndex.clamp(0, widget.urls.isEmpty ? 0 : widget.urls.length - 1);
  late final PageController _pageCtrl = PageController(initialPage: _index);
  final ScrollController _thumbCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  void _jumpTo(int i) {
    if (!_pageCtrl.hasClients) return;
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollThumbIntoView(int i) {
    if (!_thumbCtrl.hasClients) return;
    final itemW = (56 * widget.thumbAspect).roundToDouble() + 8;
    final target = (i * itemW - 120).clamp(
      0.0,
      _thumbCtrl.position.maxScrollExtent,
    );
    _thumbCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final thumbs = widget.thumbnails ?? widget.urls;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _scrollThumbIntoView(i);
            },
            itemBuilder: (_, i) => _ZoomableSlide(rawUrl: widget.urls[i]),
          ),
          // 顶部信息栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB8000000), Colors.transparent],
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
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_index + 1} / ${widget.urls.length}',
                          style: McText.caption
                              .copyWith(color: const Color(0xB3FFFFFF))
                              .tabular,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部缩略图条
          if (thumbs.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad + 12,
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  controller: _thumbCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: thumbs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final active = i == _index;
                    final w = (56 * widget.thumbAspect).roundToDouble();
                    final resolved = McImageUrls.resolve(
                      thumbs[i],
                      widthPx: widget.thumbAspect > 1 ? 360 : 240,
                    );
                    return GestureDetector(
                      onTap: () => _jumpTo(i),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: active ? 1.0 : 0.55,
                        child: Container(
                          width: w,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active
                                  ? McTokens.accentStrong
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: resolved.isEmpty
                              ? const Icon(
                                  McIcons.image3Fill,
                                  size: 18,
                                  color: McTokens.textFaint,
                                )
                              : CachedNetworkImage(
                                  imageUrl: resolved,
                                  httpHeaders: mcImageHeaders(),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    McIcons.image3Fill,
                                    size: 18,
                                    color: McTokens.textFaint,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomableSlide extends StatefulWidget {
  const _ZoomableSlide({required this.rawUrl});

  final String rawUrl;

  @override
  State<_ZoomableSlide> createState() => _ZoomableSlideState();
}

class _ZoomableSlideState extends State<_ZoomableSlide> {
  final TransformationController _ctrl = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _ctrl.value.getMaxScaleOnAxis();
    if (currentScale > 1.1) {
      _ctrl.value = Matrix4.identity();
      return;
    }
    final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _ctrl.value = Matrix4.identity()
      ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(widget.rawUrl, widthPx: 1920);
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: resolved.isEmpty
              ? const Icon(
                  McIcons.image3Fill,
                  size: 48,
                  color: McTokens.textFaint,
                )
              : CachedNetworkImage(
                  imageUrl: resolved,
                  httpHeaders: mcImageHeaders(),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        McIcons.image3Fill,
                        size: 42,
                        color: McTokens.textFaint,
                      ),
                      const SizedBox(height: 8),
                      Text('图片暂时无法加载', style: McText.caption.faint),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
