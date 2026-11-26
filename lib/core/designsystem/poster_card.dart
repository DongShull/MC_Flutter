import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../image/image_urls.dart';
import 'mc_chrome.dart';
import 'mc_glass.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 海报卡片统一上下文菜单项（桌面端鼠标右键弹出锚定毛玻璃浮窗，触屏端长按弹出底部毛玻璃菜单）。
class McPosterMenuAction {
  const McPosterMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

/// 在桌面鼠标右键坐标处弹出银玻璃快捷菜单，或在触屏长按时弹出底部毛玻璃菜单。
Future<void> showMcContextActions({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<McPosterMenuAction> actions,
  Offset? globalPosition,
}) async {
  if (actions.isEmpty) return;
  HapticFeedback.selectionClick();
  if (globalPosition != null) {
    final overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay != null) {
      final selected = await showMenu<int>(
        context: context,
        color: const Color(0xF2171A24),
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: McTokens.lineStrong, width: 1),
        ),
        position: RelativeRect.fromRect(
          globalPosition & const Size(1, 1),
          Offset.zero & overlay.size,
        ),
        items: [
          for (var i = 0; i < actions.length; i++)
            PopupMenuItem<int>(
              value: i,
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    actions[i].icon,
                    size: 17,
                    color: actions[i].destructive
                        ? McTokens.danger
                        : McTokens.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      actions[i].label,
                      style: McText.sub.copyWith(
                        color: actions[i].destructive
                            ? McTokens.danger
                            : McTokens.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
      if (selected != null && selected >= 0 && selected < actions.length) {
        actions[selected].onTap();
      }
      return;
    }
  }

  await showMcSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.titleSm,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
              ],
            ),
          ),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              for (final act in actions)
                McInsetRow(
                  icon: act.icon,
                  title: act.label,
                  destructive: act.destructive,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    act.onTap();
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 锁死框比例的封面绘制器（对齐 iOS `LibraryArtwork` + Web `PosterImage`）。
class McArtwork extends StatelessWidget {
  const McArtwork({
    super.key,
    required this.url,
    this.imageAspect,
    this.frameAspect = McTokens.posterAspect,
    this.widthPx = 480,
    this.fallbackText,
    this.placeholderIcon = McIcons.film,
  });

  final String? url;
  final double? imageAspect;
  final double frameAspect;
  final int widthPx;
  final String? fallbackText;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(url, widthPx: widthPx);
    final placeholder = Container(
      color: McTokens.posterPlaceholder,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: fallbackText != null && fallbackText!.isNotEmpty
          ? Text(
              fallbackText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: McText.titleSm.copyWith(color: const Color(0x3DFFFFFF)),
            )
          : Icon(placeholderIcon, size: 28, color: McTokens.textFaint),
    );

    Widget child;
    final ia = imageAspect;
    if (resolved.isEmpty) {
      child = placeholder;
    } else if (ia != null && ia > 0 && (ia - frameAspect).abs() > 0.05) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.45,
            child: Transform.scale(
              scale: 1.25,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  httpHeaders: mcImageHeaders(),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
              ),
            ),
          ),
          const ColoredBox(color: Color(0x40000000)),
          Center(
            child: AspectRatio(
              aspectRatio: ia,
              child: CachedNetworkImage(
                imageUrl: resolved,
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.contain,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
            ),
          ),
        ],
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: resolved,
        httpHeaders: mcImageHeaders(),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    return AspectRatio(aspectRatio: frameAspect, child: ClipRect(child: child));
  }
}

/// 全站唯一竖版/通用海报卡片：
/// - 桌面与 iPad 触控板支持 3D 微倾 + 跟随指针银白高光光斑 + 悬停快播按钮（高速滚动自动静默保 120Hz）
/// - 支持鼠标右键菜单与触屏长按菜单（`contextActions`）
class McPosterCard extends StatefulWidget {
  const McPosterCard({
    super.key,
    required this.title,
    this.posterUrl,
    this.width = 122,
    this.aspect,
    this.imageAspect,
    this.radius = McTokens.posterRadius,
    this.subtitle,
    this.badge,
    this.badgeDotColor,
    this.rating,
    this.progress,
    this.played = false,
    this.favorite = false,
    this.dead = false,
    this.workingLabel,
    this.abnormalLabel,
    this.onTap,
    this.onQuickPlay,
    this.onLongPress,
    this.contextActions = const [],
  });

  final String title;
  final String? posterUrl;
  final double? width;
  final double? aspect;
  final double? imageAspect;
  final double radius;
  final String? subtitle;
  final String? badge;
  final Color? badgeDotColor;
  final double? rating;
  final double? progress;
  final bool played;
  final bool favorite;
  final bool dead;
  final String? workingLabel;
  final String? abnormalLabel;
  final VoidCallback? onTap;
  final VoidCallback? onQuickPlay;
  final VoidCallback? onLongPress;
  final List<McPosterMenuAction> contextActions;

  @override
  State<McPosterCard> createState() => _McPosterCardState();
}

class _McPosterCardState extends State<McPosterCard> {
  bool _hovered = false;
  Alignment _pointerAlign = Alignment.center;

  void _onHoverMove(PointerHoverEvent e) {
    if (Scrollable.recommendDeferredLoadingForContext(context)) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final w = box.size.width;
    final h = box.size.height;
    if (w <= 0 || h <= 0) return;
    final nx = ((e.localPosition.dx / w) * 2 - 1).clamp(-1.0, 1.0);
    final ny = ((e.localPosition.dy / h) * 2 - 1).clamp(-1.0, 1.0);
    setState(() {
      _hovered = true;
      _pointerAlign = Alignment(nx, ny);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget artwork = McArtwork(
      url: widget.posterUrl,
      imageAspect: widget.imageAspect,
      frameAspect: widget.aspect ?? McTokens.posterAspect,
      widthPx: (widget.aspect ?? McTokens.posterAspect) > 1.0 ? 640 : 480,
    );

    if (widget.dead) {
      artwork = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.5, 0,
        ]),
        child: artwork,
      );
    }

    final borderColor = widget.workingLabel != null
        ? McTokens.info
        : (_hovered ? McTokens.lineStrong : McTokens.line);

    Widget posterBox = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: borderColor,
          width: widget.workingLabel != null ? 1.8 : 1.0,
        ),
        boxShadow: _hovered
            ? const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius - 0.5),
        child: Stack(
          children: [
            artwork,
            // 桌面/触控板指针跟随银白镜面光斑
            if (_hovered)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: _pointerAlign,
                        radius: 0.95,
                        colors: const [
                          Color(0x26EEF2F8),
                          Color(0x00EEF2F8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.badge != null && widget.badge!.isNotEmpty)
              Positioned(
                left: 6,
                top: 6,
                child: _CapsuleBadge(
                  text: widget.badge!,
                  dotColor: widget.badgeDotColor,
                ),
              ),
            if (widget.played ||
                widget.favorite ||
                (widget.rating != null && widget.rating! > 0))
              Positioned(
                right: 6,
                top: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.rating != null &&
                        widget.rating! > 0 &&
                        !widget.played)
                      _CapsuleBadge(
                        text: '★ ${widget.rating!.toStringAsFixed(1)}',
                      ),
                    if (widget.played)
                      Container(
                        width: 21,
                        height: 21,
                        decoration: BoxDecoration(
                          color: McTokens.ok.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          McIcons.check,
                          size: 12,
                          color: McTokens.onAccent,
                        ),
                      ),
                    if (widget.favorite) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x94000000),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          McIcons.heart2Fill,
                          size: 12,
                          color: McTokens.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (_hovered && widget.onQuickPlay != null)
              Positioned(
                right: 7,
                bottom: 9,
                child: GestureDetector(
                  onTap: widget.onQuickPlay,
                  child: const McLiquidGlass(
                    radius: 16,
                    blurSigma: 14,
                    withShadow: true,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        McIcons.playFill,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.workingLabel != null && widget.workingLabel!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  color: const Color(0xEB070C14),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: McTokens.info,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.workingLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.micro.copyWith(color: McTokens.info),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (widget.progress != null && widget.progress! > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: widget.progress!.clamp(0.0, 1.0),
                  minHeight: 2.8,
                  backgroundColor: const Color(0x66000000),
                  valueColor: const AlwaysStoppedAnimation(
                    McTokens.accentStrong,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (_hovered) {
      final tiltX = -_pointerAlign.y * 0.045;
      final tiltY = _pointerAlign.x * 0.045;
      posterBox = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(tiltX)
          ..rotateY(tiltY),
        child: posterBox,
      );
    }

    Widget card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        posterBox,
        const SizedBox(height: 7),
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: McText.posterTitle,
        ),
        if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.caption,
          ),
        ],
        if (widget.abnormalLabel != null &&
            widget.abnormalLabel!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.dead ? McTokens.textFaint : McTokens.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.abnormalLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (widget.width != null) card = SizedBox(width: widget.width, child: card);

    final hasMenu = widget.contextActions.isNotEmpty;
    return MouseRegion(
      onHover: _onHoverMove,
      onExit: (_) {
        if (_hovered && mounted) {
          setState(() {
            _hovered = false;
            _pointerAlign = Alignment.center;
          });
        }
      },
      child: McPressable(
        hoverScale: 1.03,
        onTap: widget.onTap,
        onSecondaryTapUp: hasMenu
            ? (details) => showMcContextActions(
                  context: context,
                  title: widget.title,
                  subtitle: widget.subtitle,
                  actions: widget.contextActions,
                  globalPosition: details.globalPosition,
                )
            : null,
        onLongPress: hasMenu
            ? () => showMcContextActions(
                  context: context,
                  title: widget.title,
                  subtitle: widget.subtitle,
                  actions: widget.contextActions,
                )
            : widget.onLongPress,
        child: card,
      ),
    );
  }
}

class _CapsuleBadge extends StatelessWidget {
  const _CapsuleBadge({required this.text, this.dotColor});

  final String text;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(McTokens.pillRadius),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: McText.micro.copyWith(color: const Color(0xF2FFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// 16:9 横版「接下来继续 / 刚刚入库」剧照卡片（支持悬停微扩与右键菜单）。
class McUpNextCard extends StatelessWidget {
  const McUpNextCard({
    super.key,
    required this.title,
    this.backdropUrl,
    this.subtitle,
    this.footnote,
    this.timeLabel,
    this.badge,
    this.progress,
    this.width = 232,
    this.centerPlayIcon = true,
    this.onPlay,
    this.onTap,
    this.onLongPress,
    this.contextActions = const [],
  });

  final String title;
  final String? backdropUrl;
  final String? subtitle;
  final String? footnote;
  final String? timeLabel;
  final String? badge;
  final double? progress;
  final double width;
  final bool centerPlayIcon;
  final VoidCallback? onPlay;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<McPosterMenuAction> contextActions;

  @override
  Widget build(BuildContext context) {
    final hasMenu = contextActions.isNotEmpty;
    return SizedBox(
      width: width,
      child: McPressable(
        hoverScale: 1.025,
        onTap: onTap ?? onPlay,
        onSecondaryTapUp: hasMenu
            ? (details) => showMcContextActions(
                  context: context,
                  title: title,
                  subtitle: subtitle,
                  actions: contextActions,
                  globalPosition: details.globalPosition,
                )
            : null,
        onLongPress: hasMenu
            ? () => showMcContextActions(
                  context: context,
                  title: title,
                  subtitle: subtitle,
                  actions: contextActions,
                )
            : onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                border: Border.all(color: McTokens.line, width: 1),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(McTokens.posterRadius - 0.5),
                child: Stack(
                  children: [
                    McArtwork(
                      url: backdropUrl,
                      frameAspect: McTokens.backdropAspect,
                      widthPx: 640,
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 54,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xA6000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (badge != null && badge!.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _CapsuleBadge(text: badge!),
                      ),
                    if (centerPlayIcon)
                      Positioned.fill(
                        child: Center(
                          child: GestureDetector(
                            onTap: onPlay ?? onTap,
                            child: const McLiquidGlass(
                              radius: 22,
                              blurSigma: 14,
                              withShadow: false,
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  McIcons.playFill,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: onPlay ?? onTap,
                          child: const McLiquidGlass(
                            radius: 16,
                            blurSigma: 14,
                            withShadow: false,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                McIcons.playFill,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (timeLabel != null && timeLabel!.isNotEmpty)
                      Positioned(
                        left: 10,
                        bottom: (progress != null && progress! > 0) ? 9 : 7,
                        child: Text(
                          timeLabel!,
                          style: McText.micro.copyWith(
                            color: const Color(0xEBFFFFFF),
                          ),
                        ),
                      ),
                    if (progress != null && progress! > 0)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress!.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: const Color(0x4DFFFFFF),
                            valueColor: const AlwaysStoppedAnimation(
                              McTokens.accentStrong,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.posterTitle,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption,
              ),
            ],
            if (footnote != null && footnote!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                footnote!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(color: McTokens.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
