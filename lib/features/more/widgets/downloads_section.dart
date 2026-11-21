import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';

/// 下载段：离线下载入口卡（进行中/已下载明细在下载管理页维护，
/// 数据属 offline 域——禁跨 feature import，经路由跳转）。
class DownloadsSection extends StatelessWidget {
  const DownloadsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/offline'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(McIcons.fileDownload, size: 22, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      McStrings.downloadsTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      McStrings.downloadsSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(McIcons.chevronRight,
                  size: 13, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
