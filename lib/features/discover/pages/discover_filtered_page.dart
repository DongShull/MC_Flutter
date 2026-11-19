// IMPLEMENTED — 筛选态正文整块换成结果网格（对应 DiscoverScreen filtering 分支）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/discover_grid.dart';

class DiscoverFilteredPage extends ConsumerWidget {
  const DiscoverFilteredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const DiscoverFilteredGrid();
}
