import 'package:flutter/material.dart';

/// 动作菜单（对齐 ItemActionsMenu.kt / ItemActionSheets.kt 的字段子集；
/// 离线下载 / 分享 / 字幕生成等只留入口意图，具体任务域由对应 feature 完成）。
enum ItemAction { subscribe, download, share, subtitleGen, refreshMetadata, delete }

Future<ItemAction?> showItemActionsMenu(BuildContext context) {
  return showModalBottomSheet<ItemAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item(context, Icons.subscriptions_outlined, '订阅 / 管理订阅', ItemAction.subscribe),
          _item(context, Icons.download_outlined, '下载（离线）', ItemAction.download),
          _item(context, Icons.share_outlined, '分享', ItemAction.share),
          _item(context, Icons.subtitles_outlined, '生成字幕（AI）', ItemAction.subtitleGen),
          _item(context, Icons.refresh_rounded, '刷新元数据', ItemAction.refreshMetadata),
          _item(context, Icons.delete_outline, '删除', ItemAction.delete, danger: true),
        ],
      ),
    ),
  );
}

Widget _item(BuildContext context, IconData icon, String label, ItemAction action,
    {bool danger = false}) {
  final color = danger ? Theme.of(context).colorScheme.error : null;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    onTap: () => Navigator.of(context).pop(action),
  );
}
