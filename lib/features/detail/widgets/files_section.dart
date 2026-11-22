// 详情页文件区（P2；对齐安卓 `FilesSection` / `DeleteFileSheet`）：
// 在库文件列表（本机副本排前、标「本机」在安卓侧由排序体现，
// 此处按服务端返回顺序展示，缺失文件置灰并标注）、展开看规格详情、
// 删除走确认框（由调用方传入 [onDelete] 执行并重拉）。
import 'package:flutter/material.dart';

import '../state/detail_controller.dart';

String _formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unit]}';
}

String _formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

class FilesSection extends StatelessWidget {
  const FilesSection({
    super.key,
    required this.files,
    required this.onDelete,
  });

  final List<DetailFile> files;

  /// 点删除时调用（调用方弹确认框 → `DetailController.deleteFile` → 重拉）。
  final void Function(DetailFile file) onDelete;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('文件（${files.length}）',
              style: theme.textTheme.titleMedium),
        ),
        for (final file in files)
          ExpansionTile(
            title: Text(
              file.fileName.isEmpty ? '未命名文件' : file.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: file.missing
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
            subtitle: Text(
              [
                _formatBytes(file.sizeBytes),
                if (file.specLabel.isNotEmpty) file.specLabel,
                if (file.missing) '已缺失',
                if (file.state != 'in_place' && file.state.isNotEmpty)
                  file.state,
              ].join(' · '),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (file.filePath != null && file.filePath!.isNotEmpty)
                      _row('路径', file.filePath!),
                    if (file.container != null) _row('容器', file.container!),
                    if (file.mediaSource != null)
                      _row('来源', file.mediaSource!),
                    _row('时长', _formatDuration(file.durationSeconds)),
                    if (file.colorSpace != null)
                      _row('色彩空间', file.colorSpace!),
                    if (file.purgeAfter != null)
                      _row('计划清理', file.purgeAfter!),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除文件'),
                        style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error),
                        onPressed: () => onDelete(file),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 64,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
