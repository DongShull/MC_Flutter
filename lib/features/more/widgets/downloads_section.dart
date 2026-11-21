import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../offline/embed.dart';

/// 「我的」页下载段：不再跳页，内嵌鸿蒙同款五个分区
/// （对齐 MorePage.ets 下载分支的顺序：容量条 → 下载中 → 清理建议 →
/// 已下载 → 其他账号；空段由 embed.dart 内部按鸿蒙口径隐藏）。
/// 模块化铁律：more 只 import offline/embed.dart 这一个入口文件。
class DownloadsSection extends ConsumerStatefulWidget {
  const DownloadsSection({super.key});

  @override
  ConsumerState<DownloadsSection> createState() => _DownloadsSectionState();
}

class _DownloadsSectionState extends ConsumerState<DownloadsSection> {
  @override
  void initState() {
    super.initState();
    // 进入下载段时刷新容量（对齐鸿蒙 CapacityCard aboutToAppear 的重查）。
    ref.read(offlineProvider.notifier).refreshStorage();
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CapacityCard(),
          DownloadingSection(),
          WatchedCard(),
          DownloadedSection(),
          OtherOwnersSection(),
        ],
      ),
    );
  }
}
