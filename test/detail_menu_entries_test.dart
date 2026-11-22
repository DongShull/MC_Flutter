// P2：详情页 ⋯ 菜单条目（`itemMenuEntries`，对齐安卓 `itemMenuEntries`）。
// 纯函数单测：优先/取消下载的动态条件 + 其余动作的固定顺序。
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/features/detail/widgets/item_actions_menu.dart';

void main() {
  group('itemMenuEntries', () {
    test('无在下任务：订阅首位，其余按安卓顺序', () {
      final entries = itemMenuEntries(const ItemMenuInput());
      expect(entries.first, ItemAction.subscribe);
      expect(entries, [
        ItemAction.subscribe,
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
      ]);
    });

    test('恰好 1 个在下任务：只出现“取消选中下载”，不出现“取消下载”', () {
      final entries =
          itemMenuEntries(const ItemMenuInput(activeDownloads: 1));
      expect(entries, contains(ItemAction.cancelSelectedDownload));
      expect(entries, isNot(contains(ItemAction.cancelDownloads)));
      expect(entries, isNot(contains(ItemAction.prioritizeDownloads)));
    });

    test('多个在下任务：只出现“取消下载”，不出现“取消选中下载”', () {
      final entries =
          itemMenuEntries(const ItemMenuInput(activeDownloads: 3));
      expect(entries, contains(ItemAction.cancelDownloads));
      expect(entries, isNot(contains(ItemAction.cancelSelectedDownload)));
    });

    test('剧集 + 有在下任务 + 队列有其他条目：出现“优先下载”', () {
      final entries = itemMenuEntries(const ItemMenuInput(
        activeDownloads: 2,
        otherQueuedDownloads: true,
        isTv: true,
      ));
      expect(entries, contains(ItemAction.prioritizeDownloads));
      expect(entries.indexOf(ItemAction.prioritizeDownloads),
          lessThan(entries.indexOf(ItemAction.cancelDownloads)));
    });

    test('电影即使满足其他条件也不出现“优先下载”', () {
      final entries = itemMenuEntries(const ItemMenuInput(
        activeDownloads: 2,
        otherQueuedDownloads: true,
        isTv: false,
      ));
      expect(entries, isNot(contains(ItemAction.prioritizeDownloads)));
    });

    test('剧集但队列无其他条目：不出现“优先下载”', () {
      final entries = itemMenuEntries(const ItemMenuInput(
        activeDownloads: 2,
        otherQueuedDownloads: false,
        isTv: true,
      ));
      expect(entries, isNot(contains(ItemAction.prioritizeDownloads)));
    });
  });
}
