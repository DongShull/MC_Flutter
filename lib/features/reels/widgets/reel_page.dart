import 'package:flutter/material.dart';

import '../state/models.dart';

/// 一页片段（对应 Android ReelPage 竖屏布局）：
/// 16:9 横带（满宽、中心在屏高 46%）+ 右下图标列 + 左下导演与简介 +
/// 最底一条细进度线。播放引擎由 player 域负责，横带里放封面 + 播放按钮。
class ReelPage extends StatelessWidget {
  const ReelPage({
    super.key,
    required this.item,
    required this.favorite,
    required this.played,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
    required this.onOpenDetail,
    required this.onShare,
    required this.onPlay,
  });

  final ReelItemView item;
  final bool favorite;
  final bool played;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;
  final VoidCallback onOpenDetail;
  final VoidCallback onShare;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final cover = item.coverUrl ?? title.backdropUrl ?? title.posterUrl;
    final overview =
        (title.episode?.overview ?? title.overview)?.trim() ?? '';
    final director = title.directors.isEmpty
        ? ''
        : title.directors.map((e) => e.name).join(' / ');
    final progress = title.progressPercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bandWidth = constraints.maxWidth;
        final bandHeight = bandWidth * 9 / 16;
        final bandTop = (constraints.maxHeight * 0.46 - bandHeight / 2)
            .clamp(0.0, double.infinity);

        return Stack(
          children: [
            // ── 画面槽：竖屏是 16:9 横带（中心 46%）──
            Positioned(
              left: 0,
              right: 0,
              top: bandTop,
              height: bandHeight,
              child: GestureDetector(
                onTap: onPlay,
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null)
                        Image.network(
                          cover,
                          fit: BoxFit.contain, // 横带里整张封面完整可见，两侧留黑
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      // TODO(reels-playback): 封面压暗，等接上播放引擎后移除
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      Center(
                        child: IconButton.outlined(
                          onPressed: onPlay,
                          iconSize: 32,
                          color: Colors.white,
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 横带下方一行：画质胶囊 TODO、右侧「全屏观看」描边小胶囊 ──
            Positioned(
              left: 16,
              right: 16,
              top: bandTop + bandHeight + 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OutlinedCapsule(
                    label: '原画',
                    onTap: onPlay,
                  ), // TODO(reels-quality): 按网络环境记档位（原画 / 720p）
                  _OutlinedCapsule(
                    label: '全屏观看',
                    onTap: onPlay,
                  ),
                ],
              ),
            ),

            // ── 右下图标列：收藏 / 详情 / 已看 / 分享（无底色）──
            Positioned(
              right: 10,
              bottom: 64,
              child: ReelActions(
                favorite: favorite,
                played: played,
                onToggleFavorite: onToggleFavorite,
                onOpenDetail: onOpenDetail,
                onTogglePlayed: onTogglePlayed,
                onShare: onShare,
              ),
            ),

            // ── 左下信息：导演行 + 三行简介 ──
            Positioned(
              left: 16,
              right: 84,
              bottom: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (director.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.14),
                            child: const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              director,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title.kind == 'tv' ? '主创' : '导演',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (overview.isNotEmpty)
                    Text(
                      overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                ],
              ),
            ),

            // ── 最底一条细进度线（2dp，看了一半才显示；同抖音只在暂停淡入，
            //    这里静态展示当前续播进度）──
            if (progress != null && progress > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(1, 99) / 100,
                    minHeight: 2,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.22),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 右下角一列无底色图标（图标 26、标签 11）：收藏 / 详情 / 已看 / 分享。
/// 「详情」替换了原来的「播放」——刷到感兴趣的片最常做的是看详细信息。
class ReelActions extends StatelessWidget {
  const ReelActions({
    super.key,
    required this.favorite,
    required this.played,
    required this.onToggleFavorite,
    required this.onOpenDetail,
    required this.onTogglePlayed,
    required this.onShare,
  });

  final bool favorite;
  final bool played;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenDetail;
  final VoidCallback onTogglePlayed;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReelIcon(
          icon: favorite ? Icons.favorite : Icons.favorite_border,
          label: '收藏',
          color: favorite ? const Color(0xFFFF4459) : Colors.white,
          onTap: onToggleFavorite,
        ),
        const SizedBox(height: 18),
        _ReelIcon(
          icon: Icons.movie_outlined,
          label: '详情',
          iconSize: 21, // 宽扁的符号小一号，整列视觉等重
          onTap: onOpenDetail,
        ),
        const SizedBox(height: 18),
        _ReelIcon(
          icon: Icons.check_circle_outline,
          label: '已看',
          color: played ? const Color(0xFF4ADE80) : Colors.white,
          onTap: onTogglePlayed,
        ),
        const SizedBox(height: 18),
        _ReelIcon(icon: Icons.share_outlined, label: '分享', onTap: onShare),
      ],
    );
  }
}

class _ReelIcon extends StatelessWidget {
  const _ReelIcon({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.iconSize = 26,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 30,
          child: IconButton(
            onPressed: onTap,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: iconSize, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 描边小胶囊（画质档 / 全屏观看）
class _OutlinedCapsule extends StatelessWidget {
  const _OutlinedCapsule({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
