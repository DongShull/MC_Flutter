import 'package:flutter/material.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 动作菜单（对齐安卓 `ItemActionId` / `itemMenuEntries`；
/// 离线下载 / 分享 / 字幕生成等只留入口意图，具体任务域由对应 feature 完成）。
///
/// 安卓 `itemMenuEntries` 的顺序与权限口径（`ItemActionsMenu.kt`）：
/// 1. PRIORITIZE_DOWNLOADS——仅当本剧有在下任务、且队列里有其他条目的任务
///    （`canPrioritizeShow`）；2. CANCEL_SELECTED_DOWNLOAD——仅当本条目在下任务
///    恰好 1 个；3. CANCEL_DOWNLOADS——本条目在下任务 > 1 个（文案带数量，
///    与上一项互斥）；
/// 4. DOWNLOAD；5. SEARCH（搜资源）；6. ADD_TO_COLLECTION；7. SHARE——仅管理员；
/// 8. UPGRADE（洗版）——Flutter 不单独出入口，复用「订阅」入口（见 P2.md）；
/// 9. REIDENTIFY / 10. REFRESH_METADATA / 11. REGENERATE_CHAPTERS /
/// 12. ARTWORK / 13. TRANSFER / 14. DELETE_ITEM / 15. CLEAR_HISTORY——仅 `manage`。
///
/// Flutter 详情页目前没有权限模型：菜单照安卓顺序全量出（除动态数量条件外），
/// 管理类操作由服务端强制拒绝（见 P2.md 偏差记录），不在 UI 层按权限隐藏。
/// [itemMenuEntries] 是纯函数，可单测。
enum ItemAction {
  subscribe,
  download,
  share,
  subtitleGen,
  addToCollection,
  reidentify,
  refreshMetadata,
  delete,

  /// 搜资源（跳搜索页资源模式）。
  searchResources,

  /// 更换图片（海报 / 背景 / 标志）。
  artwork,

  /// 转移到其他库。
  transfer,

  /// 清除观看记录。
  clearHistory,

  /// 取消本条目全部在下任务。
  cancelDownloads,

  /// 取消本条目选中的在下任务（仅当恰好 1 个在下任务时出现）。
  cancelSelectedDownload,

  /// 优先下载（把本剧的在下任务排到同剧其他条目前面）。
  prioritizeDownloads,
}

/// 菜单条目计算的输入（纯数据，便于单测）。
class ItemMenuInput {
  const ItemMenuInput({
    this.activeDownloads = 0,
    this.otherQueuedDownloads = false,
    this.isTv = false,
  });

  /// 本条目在下任务数（running / queued / waitingWifi）。
  final int activeDownloads;

  /// 队列里是否存在其他条目的在下任务（用于优先下载的出现条件）。
  final bool otherQueuedDownloads;

  /// 是否剧集（优先下载仅对剧集有意义：别的条目排在本剧某集前面）。
  final bool isTv;
}

/// 按安卓 `itemMenuEntries` 顺序返回应展示的菜单动作。
///
/// 规则：
/// - 优先下载：`isTv && activeDownloads > 0 && otherQueuedDownloads`
///   （安卓 `canPrioritizeShow` 的近似口径：Flutter 拿不到「别的条目排在
///   本剧某集前面」的精确判定，见 P2.md）；
/// - 取消选中下载：`activeDownloads == 1`；
/// - 取消下载：`activeDownloads > 1`（文案由调用方带数量；两者互斥，只出一行）。
List<ItemAction> itemMenuEntries(ItemMenuInput input) {
  return [
    // 订阅在 Flutter 历史菜单里排首位（安卓里它是独立入口，不在
    // itemMenuEntries 列表中；章节生成也不进菜单，在详情页章节区）。
    ItemAction.subscribe,
    if (input.isTv &&
        input.activeDownloads > 0 &&
        input.otherQueuedDownloads)
      ItemAction.prioritizeDownloads,
    if (input.activeDownloads == 1) ItemAction.cancelSelectedDownload,
    if (input.activeDownloads > 1) ItemAction.cancelDownloads,
    ItemAction.download,
    ItemAction.searchResources,
    ItemAction.addToCollection,
    ItemAction.share,
    ItemAction.subtitleGen,
    ItemAction.reidentify,
    ItemAction.refreshMetadata,
    ItemAction.artwork,
    ItemAction.transfer,
    ItemAction.delete,
    ItemAction.clearHistory,
  ];
}

/// 动作菜单。默认展示 [itemMenuEntries] 的全量顺序（无在下任务时）；
/// 调用方可传 [entries] 与 [cancelLabel]（带在下任务数量的文案）做动态菜单。
Future<ItemAction?> showItemActionsMenu(
  BuildContext context, {
  List<ItemAction>? entries,
  String? cancelLabel,
}) {
  final items = entries ??
      itemMenuEntries(const ItemMenuInput());
  return showModalBottomSheet<ItemAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in items) _row(context, action, cancelLabel),
          ],
        ),
      ),
    ),
  );
}

Widget _row(BuildContext context, ItemAction action, String? cancelLabel) {
  switch (action) {
    case ItemAction.prioritizeDownloads:
      return _item(context, McIcons.arrowUp, '优先下载本剧', action);
    case ItemAction.cancelSelectedDownload:
      return _item(context, McIcons.pauseS, '取消下载', action);
    case ItemAction.cancelDownloads:
      return _item(
          context, McIcons.pauseS, cancelLabel ?? '取消下载', action);
    case ItemAction.download:
      return _item(
          context, McIcons.downloadCloudOutFill, '下载（离线）', action);
    case ItemAction.searchResources:
      return _item(context, McIcons.aiSearch2, '搜索资源', action);
    case ItemAction.addToCollection:
      return _item(context, McIcons.folderSmartShare, '加入合集', action);
    case ItemAction.share:
      return _item(context, McIcons.share, '分享', action);
    case ItemAction.subtitleGen:
      return _item(
          context, McIcons.closedCaptioning, '生成字幕（AI）', action);
    case ItemAction.reidentify:
      return _item(context, McIcons.scan, '重新识别', action);
    case ItemAction.refreshMetadata:
      return _item(context, McIcons.refreshS, '刷新元数据', action);
    case ItemAction.artwork:
      return _item(context, McIcons.image3Fill, '更换图片', action);
    case ItemAction.transfer:
      return _item(context, McIcons.folderUploadFill, '转移到其他库', action);
    case ItemAction.delete:
      return _item(context, McIcons.trash2, '删除', action, danger: true);
    case ItemAction.clearHistory:
      return _item(context, McIcons.history1Remove, '清除观看记录', action);
    case ItemAction.subscribe:
      return _item(context, McIcons.rss, '订阅 / 管理订阅', action);
  }
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
