import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 条目更多操作毛玻璃弹层（对齐 iOS `ItemActionsMenu`）。
enum ItemAction {
  subscribe,
  download,
  share,
  subtitleGen,
  refreshMetadata,
  delete,
}

Future<ItemAction?> showItemActionsMenu(BuildContext context) {
  return showMcSheet<ItemAction>(
    context: context,
    builder: (ctx) => Padding(
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
                title: '订阅 / 管理订阅',
                onTap: () => Navigator.of(ctx).pop(ItemAction.subscribe),
              ),
              McInsetRow(
                icon: McIcons.downloadCloudOut,
                title: '离线缓存到本地',
                onTap: () => Navigator.of(ctx).pop(ItemAction.download),
              ),
              McInsetRow(
                icon: McIcons.share,
                title: '分享观看链接',
                onTap: () => Navigator.of(ctx).pop(ItemAction.share),
              ),
              McInsetRow(
                icon: McIcons.closedCaptioning,
                title: 'AI 生成中文字幕',
                onTap: () => Navigator.of(ctx).pop(ItemAction.subtitleGen),
              ),
              McInsetRow(
                icon: McIcons.refreshS,
                title: '重新识别 / 刷新元数据',
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
                title: '删除此条目',
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
