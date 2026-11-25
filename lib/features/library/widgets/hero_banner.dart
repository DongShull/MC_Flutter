import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/models.dart';
import 'library_shared.dart';

/// 首页大图轮播（1:1 对齐鸿蒙 library/HeroBanner.ets，华为视频推荐页 Banner 同款）：
/// 全宽剧照 + 底部渐变压黑 + 片名 / 元信息 / 简介 / 进度条 / 播放·详情按钮 +
/// 右下角胶囊指示点（当前页拉长）。数据来自「接下来继续」，取前 6 条，5 秒自动轮播。
class LibraryHeroBanner extends StatefulWidget {
  const LibraryHeroBanner({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onPlay,
  });

  final List<UpNextItem> items;
  final ValueChanged<UpNextItem> onOpen;
  final ValueChanged<UpNextItem> onPlay;

  static const height = 236.0;

  @override
  State<LibraryHeroBanner> createState() => _LibraryHeroBannerState();
}

class _LibraryHeroBannerState extends State<LibraryHeroBanner> {
  // 无限页：用大偏移起步，左右都能滑（loop）。
  static const _loopBase = 6000;
  late final PageController _controller = PageController(initialPage: _loopBase);
  Timer? _timer;
  int _current = 0;

  List<UpNextItem> get _pages => widget.items.take(6).toList();

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant LibraryHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_current >= _pages.length) _current = 0;
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_pages.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
          duration: const Duration(milliseconds: 420), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages.isEmpty) return const SizedBox.shrink();
    final loop = pages.length > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
      child: SizedBox(
        height: LibraryHeroBanner.height,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              // 手动拖动时暂停自动轮播，松手后重新计时。
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) _timer?.cancel();
                if (n is ScrollEndNotification) _restartTimer();
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: loop ? null : 1,
                onPageChanged: (i) => setState(() => _current = i % pages.length),
                itemBuilder: (context, i) => _BannerPage(
                  item: pages[i % pages.length],
                  onOpen: widget.onOpen,
                  onPlay: widget.onPlay,
                ),
              ),
            ),
            if (loop)
              Positioned(
                right: 14,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x59000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
                            width: i == _current ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _current ? McTokens.text : McTokens.textFaint,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerPage extends StatelessWidget {
  const _BannerPage({required this.item, required this.onOpen, required this.onPlay});

  final UpNextItem item;
  final ValueChanged<UpNextItem> onOpen;
  final ValueChanged<UpNextItem> onPlay;

  /// Banner 占满屏宽：横卡的 480 放大发虚，取 1280 档。
  String get _artUrl => McImageUrls.resolve(
        item.isEpisode
            ? (item.episodeStillOriginalUrl ?? item.episodeStillUrl ?? item.backdropUrl)
            : item.backdropUrl,
        widthPx: 1280,
      );

  /// 元信息行：年份 / 类型（最多 3 个）/ 季集 / 还有 N 集。
  String get _meta => [
        if (item.year != null) '${item.year}',
        if (item.genres.isNotEmpty) item.genres.take(3).join(' / '),
        if (item.isEpisode) episodeCode(item.seasonNumber, item.episodeNumber),
        if (item.unwatchedAheadCount > 0) '还有 ${item.unwatchedAheadCount} 集',
      ].join(' · ');

  int? get _percent {
    final raw = item.progressPercent;
    if (item.positionMs <= 0 || raw == null) return null;
    return raw.round().clamp(0, 100);
  }

  /// 主按钮文案：看了一半是「继续播放」，全新是「播放」。
  String get _playLabel {
    final p = _percent;
    if (p != null) return '继续播放 · $p%';
    return item.positionMs > 0 ? '继续播放' : '播放';
  }

  @override
  Widget build(BuildContext context) {
    final overview = item.overview ?? '';
    final percent = _percent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(McTokens.cardRadius),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpen(item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LibraryNetImage(url: _artUrl),
            const Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x8C000000), Color(0xEB000000)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w700, color: McTokens.text)),
                  if (_meta.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(_meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: McTokens.textMuted)),
                  ],
                  if (overview.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, height: 17 / 12, color: Color(0xC7F3F5F9))),
                  ],
                  if (percent != null) ...[
                    const SizedBox(height: 9),
                    SizedBox(
                      width: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 3,
                          color: McTokens.text,
                          backgroundColor: const Color(0x2EFFFFFF),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      McGlassButton(
                        onTap: () => onPlay(item),
                        tone: McGlassTone.primary,
                        radius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        foregroundColor: Colors.black,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 16),
                            const SizedBox(width: 5),
                            Text(_playLabel,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      McGlassButton(
                        onTap: () => onOpen(item),
                        radius: 17,
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        foregroundColor: McTokens.text,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.movie_outlined, size: 15),
                            SizedBox(width: 5),
                            Text('详情',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
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
