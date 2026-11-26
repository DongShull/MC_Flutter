import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 条目全能管理操作菜单（对齐并超越 Web `ItemDetailMenu` + iOS `ItemActionsMenu`）。
enum ItemAction {
  subscribe,
  download,
  addToCollection,
  share,
  subtitleGen,
  artwork,
  reidentify,
  refreshMetadata,
  delete,
}

Future<ItemAction?> showItemActionsMenu(BuildContext context) {
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
              McInsetRow(
                icon: McIcons.bookmark,
                title: '订阅 / 洗版管理',
                onTap: () => Navigator.of(ctx).pop(ItemAction.subscribe),
              ),
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
              McInsetRow(
                icon: McIcons.share,
                title: '分享观看链接（有效期 / 密码）…',
                onTap: () => Navigator.of(ctx).pop(ItemAction.share),
              ),
            ],
          ),
          const SizedBox(height: 12),
          McInsetGroup(
            header: '媒体刮削与 AI 工具',
            margin: EdgeInsets.zero,
            dividerIndent: 48,
            children: [
              McInsetRow(
                icon: McIcons.closedCaptioning,
                title: 'AI 生成单语 / 双语字幕…',
                onTap: () => Navigator.of(ctx).pop(ItemAction.subtitleGen),
              ),
              McInsetRow(
                icon: McIcons.imageEdit,
                title: '更换海报 / 剧照 / Logo…',
                onTap: () => Navigator.of(ctx).pop(ItemAction.artwork),
              ),
              McInsetRow(
                icon: McIcons.fileSearch,
                title: '手动修正词条识别…',
                onTap: () => Navigator.of(ctx).pop(ItemAction.reidentify),
              ),
              McInsetRow(
                icon: McIcons.refreshS,
                title: '重新抓取元数据',
                onTap: () => Navigator.of(ctx).pop(ItemAction.refreshMetadata),
              ),
            ],
          ),
          const SizedBox(height: 12),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                icon: McIcons.trash2,
                title: '删除此条目…',
                destructive: true,
                onTap: () => Navigator.of(ctx).pop(ItemAction.delete),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
