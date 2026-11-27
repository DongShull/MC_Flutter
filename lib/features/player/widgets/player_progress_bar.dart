import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/session/playback_session_api.dart';
import '../../../core/session/session_store.dart';

/// Trickplay 雪碧图按需加载与格点裁剪缓存（对齐 `TrickplayImages`）。
class TrickplaySpriteCache {
  TrickplaySpriteCache._();

  static final TrickplaySpriteCache instance = TrickplaySpriteCache._();

  final Map<String, ui.Image> _sheets = {};
  final Set<String> _loading = {};
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  ({ui.Image image, Rect srcRect})? tileAt(
    PlaybackTrickplay? index,
    int fileMs, {
    VoidCallback? onLoaded,
  }) {
    if (index == null || !index.usable) return null;
    final perSheet = index.columns * index.rows;
    final ordinal = (fileMs.clamp(0, 1 << 30) ~/ index.intervalMs)
        .clamp(0, index.count - 1);
    final sheetIdx = (ordinal ~/ perSheet).clamp(0, index.sheets.length - 1);
    final within = ordinal - sheetIdx * perSheet;
    final sheetPath = index.sheets[sheetIdx];

    final img = _sheets[sheetPath];
    if (img == null) {
      unawaited(_fetchSheet(sheetPath, onLoaded: onLoaded));
      return null;
    }

    final col = within % index.columns;
    final row = within ~/ index.columns;
    final src = Rect.fromLTWH(
      (col * index.tileWidth).toDouble(),
      (row * index.tileHeight).toDouble(),
      index.tileWidth.toDouble(),
      index.tileHeight.toDouble(),
    );
    return (image: img, srcRect: src);
  }

  Future<void> _fetchSheet(String rawPath, {VoidCallback? onLoaded}) async {
    if (_loading.contains(rawPath) || _sheets.containsKey(rawPath)) return;
    _loading.add(rawPath);
    try {
      var full = rawPath;
      if (full.startsWith('/')) {
        final origin = ServerRoutes.instance.currentOrigin(
          appSession.baseUrl ?? '',
        );
        if (origin.isNotEmpty) full = '$origin$full';
      }
      final resp = await _dio.get<List<int>>(
        full,
        options: Options(
          responseType: ResponseType.bytes,
          headers: mcImageHeaders(),
        ),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) return;
      final codec = await ui.instantiateImageCodec(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      );
      final frame = await codec.getNextFrame();
      // 最多缓存 12 张雪碧图，控制内存占用
      if (_sheets.length >= 12) {
        final firstKey = _sheets.keys.first;
        _sheets.remove(firstKey)?.dispose();
      }
      _sheets[rawPath] = frame.image;
      onLoaded?.call();
    } catch (_) {
    } finally {
      _loading.remove(rawPath);
    }
  }
}

class _SpriteTilePainter extends CustomPainter {
  const _SpriteTilePainter({required this.image, required this.srcRect});

  final ui.Image image;
  final Rect srcRect;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      srcRect,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _SpriteTilePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.srcRect != srcRect;
}

/// 全屏播放器进度条（对齐 iOS `PlayerProgressBar` + `ScrubPreview`）：
/// - 底轨半透白 + 已缓冲轨道（`bufferedEnd`）+ 已播纯白轨迹 + 琥珀色可跳过段标记；
/// - 拖动时滑块上方实时浮出 Trickplay 雪碧图预览帧 + 落点时间戳 + 所属章节名。
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.bufferedEnd = Duration.zero,
    this.onScrubPreview,
    this.skipSegments = const [],
    this.chapters = const [],
    this.trickplay,
    this.timelineOffsetMs = 0,
  });

  final Duration position;
  final Duration duration;
  final Duration bufferedEnd;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration?>? onScrubPreview;
  final List<PlaybackSkipSegment> skipSegments;
  final List<PlaybackChapter> chapters;
  final PlaybackTrickplay? trickplay;

  /// 片段模式偏移量（毫秒）：用于把进度条位置换算回文件时间查找 Trickplay / 章节。
  final int timelineOffsetMs;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  Duration? _scrub;

  double get _fraction {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    final shown = (_scrub ?? widget.position).inMilliseconds;
    return (shown / total).clamp(0.0, 1.0);
  }

  double get _bufferedFraction {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.bufferedEnd.inMilliseconds / total).clamp(0.0, 1.0);
  }

  String? _chapterAt(int fileMs) {
    String? title;
    for (final c in widget.chapters) {
      if (c.startMs <= fileMs) {
        title = c.title;
      } else {
        break;
      }
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return const SizedBox(height: 24);
    final shown = _scrub ?? widget.position;
    final remainSeconds =
        ((total - shown.inMilliseconds).clamp(0, total) / 1000).floor();
    final scrubbing = _scrub != null;
    final thumbSize = scrubbing ? 16.0 : 11.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            slider: true,
            label: '播放进度',
            value: mcFormatClock(shown.inSeconds),
            child: SizedBox(
              height: 44,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  Duration targetOf(double x) => Duration(
                        milliseconds: ((x / width).clamp(0.0, 1.0) * total)
                            .round(),
                      );
                  final fileMs =
                      widget.timelineOffsetMs + shown.inMilliseconds;
                  final tile = scrubbing
                      ? TrickplaySpriteCache.instance.tileAt(
                          widget.trickplay,
                          fileMs,
                          onLoaded: () {
                            if (mounted) setState(() {});
                          },
                        )
                      : null;
                  final chapter = scrubbing ? _chapterAt(fileMs) : null;
                  const previewWidth = 160.0;
                  final thumbX = _fraction * width;
                  final previewLeft = (thumbX - previewWidth / 2)
                      .clamp(0.0, (width - previewWidth).clamp(0.0, width));

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (scrubbing)
                        Positioned(
                          left: previewLeft,
                          bottom: 44,
                          width: previewWidth,
                          child: IgnorePointer(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tile != null)
                                  Container(
                                    width: previewWidth,
                                    height: previewWidth *
                                        (tile.srcRect.height /
                                            tile.srcRect.width),
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0x55FFFFFF),
                                        width: 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x99000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: CustomPaint(
                                      painter: _SpriteTilePainter(
                                        image: tile.image,
                                        srcRect: tile.srcRect,
                                      ),
                                    ),
                                  ),
                                McLiquidGlass(
                                  radius: McTokens.pillRadius,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    chapter != null
                                        ? '${mcFormatClock(shown.inSeconds)} · $chapter'
                                        : mcFormatClock(shown.inSeconds),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: McText.micro
                                        .copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        )
                                        .tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          HapticFeedback.selectionClick();
                          widget.onSeek(targetOf(d.localPosition.dx));
                        },
                        onHorizontalDragStart: (d) {
                          HapticFeedback.selectionClick();
                          final t = targetOf(d.localPosition.dx);
                          setState(() => _scrub = t);
                          widget.onScrubPreview?.call(t);
                        },
                        onHorizontalDragUpdate: (d) {
                          final t = targetOf(d.localPosition.dx);
                          setState(() => _scrub = t);
                          widget.onScrubPreview?.call(t);
                        },
                        onHorizontalDragEnd: (_) {
                          final t = _scrub;
                          setState(() => _scrub = null);
                          widget.onScrubPreview?.call(null);
                          if (t != null) widget.onSeek(t);
                        },
                        onHorizontalDragCancel: () {
                          setState(() => _scrub = null);
                          widget.onScrubPreview?.call(null);
                        },
                        child: Center(
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            clipBehavior: Clip.none,
                            children: [
                              // 底层轨道
                              Container(
                                height: scrubbing ? 5.5 : 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0x38FFFFFF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // 已缓冲轨道
                              if (_bufferedFraction > 0)
                                FractionallySizedBox(
                                  widthFactor: _bufferedFraction,
                                  child: Container(
                                    height: scrubbing ? 5.5 : 3.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0x5CFFFFFF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              // 已播放轨道
                              FractionallySizedBox(
                                widthFactor: _fraction,
                                child: Container(
                                  height: scrubbing ? 5.5 : 3.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              // 片头 / 广告 / 预告等可跳过段标记
                              for (final seg in widget.skipSegments)
                                if (seg.endMs > seg.startMs &&
                                    seg.startMs < total)
                                  Positioned(
                                    left: (seg.startMs / total).clamp(0.0, 1.0) *
                                        width,
                                    width: (((seg.endMs - seg.startMs) / total)
                                                .clamp(0.0, 1.0) *
                                            width)
                                        .clamp(3.0, width),
                                    child: Container(
                                      height: scrubbing ? 6 : 4,
                                      decoration: BoxDecoration(
                                        color: McTokens.warning
                                            .withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                              // 圆形亮白滑块
                              Align(
                                alignment: Alignment(_fraction * 2 - 1, 0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: thumbSize,
                                  height: thumbSize,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x80000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mcFormatClock(shown.inSeconds),
                style: McText.micro
                    .copyWith(
                      color: const Color(0xCCF3F5F9),
                      fontWeight: FontWeight.w500,
                    )
                    .tabular,
              ),
              Text(
                '-${mcFormatClock(remainSeconds)}',
                style: McText.micro
                    .copyWith(
                      color: McTokens.textMuted,
                      fontWeight: FontWeight.w500,
                    )
                    .tabular,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
