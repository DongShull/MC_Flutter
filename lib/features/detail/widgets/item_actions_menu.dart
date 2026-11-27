import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';

/// 条目全能管理操作菜单（1:1 对齐 iOS `LibraryItemDetailView.actionsMenu`）。
enum ItemAction {
  subscribe,
  upgrade,
  download,
  addToCollection,
  share,
  subtitleGen,
  artwork,
  reidentify,
  refreshMetadata,
  reloadNfo,
  regenerateChapters,
  transfer,
  delete,
}

Future<ItemAction?> showItemActionsMenu(
  BuildContext context, {
  bool isAdmin = true,
  bool canManageLibraries = true,
  bool canSubscribe = true,
  bool canDownload = true,
  bool isScraped = true,
  bool hasTmdbId = false,
  bool isVideoOrPhoto = false,
  bool showChapterRegen = true,
  bool chaptersPending = false,
  bool scraping = false,
}) {
  final canUpgrade = canSubscribe && hasTmdbId && !isVideoOrPhoto;
  final canShare = isAdmin && !isVideoOrPhoto;

  return showMcSheet<ItemAction>(
    context: context,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          McInsetGroup(
            margin: EdgeInsets.zero,
            dividerIndent: 48,
            children: [
              if (canSubscribe && hasTmdbId)
                McInsetRow(
                  icon: McIcons.bookmark,
                  title: '订阅追更管理',
                  onTap: () => Navigator.of(ctx).pop(ItemAction.subscribe),
                ),
              if (canUpgrade)
                McInsetRow(
                  icon: McIcons.aiStarFill,
                  iconColor: McTokens.accentStrong,
                  title: '洗版升级',
                  subtitle: '搜寻更高规格片源替换当前版本',
                  onTap: () => Navigator.of(ctx).pop(ItemAction.upgrade),
                ),
              if (canDownload)
                McInsetRow(
                  icon: McIcons.downloadCloudOut,
                  title: '离线缓存到本地',
                  onTap: () => Navigator.of(ctx).pop(ItemAction.download),
                ),
              McInsetRow(
                icon: McIcons.stack,
                title: '加入片单合集…',
                onTap: () => Navigator.of(ctx).pop(ItemAction.addToCollection),
              ),
              if (canShare)
                McInsetRow(
                  icon: McIcons.share,
                  title: '分享观看链接（有效期 / 密码）…',
                  onTap: () => Navigator.of(ctx).pop(ItemAction.share),
                ),
            ],
          ),
          if (canManageLibraries) ...[
            const SizedBox(height: 12),
            McInsetGroup(
              header: '媒体刮削与 AI 工具',
              margin: EdgeInsets.zero,
              dividerIndent: 48,
              children: [
                if (isAdmin && !isVideoOrPhoto)
                  McInsetRow(
                    icon: McIcons.closedCaptioning,
                    title: 'AI 生成单语 / 双语字幕…',
                    onTap: () => Navigator.of(ctx).pop(ItemAction.subtitleGen),
                  ),
                if (isScraped)
                  McInsetRow(
                    icon: McIcons.imageEdit,
                    title: '更换海报 / 剧照 / Logo…',
                    onTap: () => Navigator.of(ctx).pop(ItemAction.artwork),
                  ),
                if (isScraped)
                  McInsetRow(
                    icon: McIcons.fileSearch,
                    title: '手动修正词条识别…',
                    onTap: () => Navigator.of(ctx).pop(ItemAction.reidentify),
                  ),
                McInsetRow(
                  icon: McIcons.refreshS,
                  title: scraping ? '正在刷新元数据…' : '重新抓取元数据',
                  onTap: scraping
                      ? null
                      : () => Navigator.of(ctx).pop(ItemAction.refreshMetadata),
                ),
                McInsetRow(
                  icon: McIcons.fileText,
                  title: scraping ? '正在重读 NFO…' : '重读本地 NFO',
                  subtitle: '从媒体目录的 NFO 文件重新同步元数据与封面',
                  onTap: scraping
                      ? null
                      : () => Navigator.of(ctx).pop(ItemAction.reloadNfo),
                ),
                if (showChapterRegen)
                  McInsetRow(
                    icon: McIcons.slideshow,
                    title: chaptersPending ? '章节缩略图生成中…' : '重新生成章节缩略图',
                    onTap: chaptersPending
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(ItemAction.regenerateChapters),
                  ),
                McInsetRow(
                  icon: McIcons.arrowLeftRight,
                  title: '转移到其他媒体库…',
                  onTap: () => Navigator.of(ctx).pop(ItemAction.transfer),
                ),
              ],
            ),
            const SizedBox(height: 12),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.trash2,
                  title: '从媒体库删除…',
                  destructive: true,
                  onTap: () => Navigator.of(ctx).pop(ItemAction.delete),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
