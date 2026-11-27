import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../../../core/navigation/external_media_link.dart';
import '../../offline/embed.dart';
import '../state/detail_controller.dart';

/// 详情页底部「物理媒体文件」区块（1:1 对齐 iOS `fileSection` & `LibraryFileRow`）：
/// - 本机离线副本行（`OfflineLocalFileRow`）排在最前；
/// - 展开每行查看目录路径（长按复制）、入库时间、来源快照、体积、片源/人工标注、画面规格/编码/色深/帧率/色彩空间/码率；
/// - 待回收文件展示倒计时与内联「恢复」/「彻底删除」；在位文件提供单文件删除按钮；
/// - 存在重复版本/多集重复时在标题行显示「N 处重复 · 处理重复」直达重复文件管理页。
class LibraryFileSection extends ConsumerWidget {
  const LibraryFileSection({
    super.key,
    required this.entry,
    required this.files,
    required this.localTitle,
    required this.canManage,
    this.onManageDuplicates,
    this.onDeleteFile,
    this.onRestoreFile,
    this.onPurgeFile,
  });

  final DetailEntry entry;
  final List<DetailFileInfo> files;
  final String localTitle;
  final bool canManage;
  final VoidCallback? onManageDuplicates;
  final ValueChanged<DetailFileInfo>? onDeleteFile;
  final ValueChanged<DetailFileInfo>? onRestoreFile;
  final ValueChanged<DetailFileInfo>? onPurgeFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (files.isEmpty) return const SizedBox.shrink();
    final offline = ref.watch(offlineProvider);
    final localFiles = [
      for (final f in files)
        if (offline.unitForFile(f.id)?.playable == true) f,
    ];

    final inPlaceAll = entry.files.where((f) => f.state == 'in_place').toList();
    final dupUnits = entry.duplicateUnitsCount;
    final String? dupLabel = dupUnits == 0
        ? null
        : (entry.isTv ? '$dupUnits 处重复' : '${inPlaceAll.length} 个版本');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        24,
        McTokens.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '文件',
                style: McText.sub.copyWith(
                  color: McTokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${files.length + localFiles.length}',
                style: McText.caption.faint.tabular,
              ),
              if (canManage && dupLabel != null && onManageDuplicates != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: '前往重复文件管理',
                  child: McPressable(
                    haptic: true,
                    onTap: onManageDuplicates,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Center(
                        widthFactor: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: McTokens.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: McTokens.warning.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            '$dupLabel · 处理重复',
                            style: McText.micro.copyWith(
                              color: McTokens.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (localFiles.isNotEmpty) ...[
            for (final lf in localFiles) ...[
              OfflineLocalFileRow(
                fileId: lf.id,
                title: localTitle,
                fileName: lf.fileName,
                specRows: lf.specRows(),
              ),
              const SizedBox(height: 8),
            ],
          ],
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < files.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  LibraryFileRow(
                    file: files[i],
                    onDelete: canManage && onDeleteFile != null
                        ? () => onDeleteFile!(files[i])
                        : null,
                    onRestore: canManage && onRestoreFile != null
                        ? () => onRestoreFile!(files[i])
                        : null,
                    onPurge: canManage && onPurgeFile != null
                        ? () => onPurgeFile!(files[i])
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryFileRow extends StatefulWidget {
  const LibraryFileRow({
    super.key,
    required this.file,
    this.onDelete,
    this.onRestore,
    this.onPurge,
  });

  final DetailFileInfo file;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPurge;

  @override
  State<LibraryFileRow> createState() => _LibraryFileRowState();
}

class _LibraryFileRowState extends State<LibraryFileRow> {
  bool _expanded = false;

  static String _directoryOf(String path) {
    var normalized = path.trim();
    while (normalized.endsWith('/') || normalized.endsWith('\\')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    final idx = normalized.lastIndexOf(RegExp(r'[/\\]'));
    if (idx < 0) return '—';
    if (idx == 0) return normalized.substring(0, 1);
    return normalized.substring(0, idx);
  }

  static String _purgeCountdown(String? raw) {
    if (raw == null || raw.isEmpty) return '不自动清理（需手动处理）';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '即将自动清理';
    final ms = dt.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return '即将自动清理';
    final days = ms ~/ 86400000;
    final hours = (ms % 86400000) ~/ 3600000;
    if (days > 0) return '$days 天 $hours 小时后自动清理';
    if (hours > 0) return '$hours 小时后自动清理';
    return '1 小时内自动清理';
  }

  void _copyPath() {
    final p = widget.file.filePath;
    if (p.isEmpty) return;
    Clipboard.setData(ClipboardData(text: p));
    McToast.success('已复制文件路径');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final trashed = f.isTrashed;
    final specRows = f.specRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _expanded = !_expanded),
                  onLongPress: _copyPath,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0.0,
                          duration: const Duration(milliseconds: 160),
                          child: const Icon(
                            McIcons.chevronRight,
                            size: 13,
                            color: McTokens.textFaint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f.fileName.isNotEmpty ? f.fileName : f.filePath,
                            maxLines: _expanded ? null : 1,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: McText.caption.copyWith(
                              color:
                                  trashed ? McTokens.textFaint : McTokens.textMuted,
                              decoration: trashed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (f.missing) ...[
                const SizedBox(width: 6),
                _tag('缺失', McTokens.warning),
              ],
              if (trashed) ...[
                const SizedBox(width: 6),
                _tag('待回收', McTokens.textFaint),
                if (widget.onRestore != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '从回收站恢复此文件',
                    child: McPressable(
                      haptic: true,
                      onTap: widget.onRestore,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              '恢复',
                              style: McText.micro.copyWith(
                                color: McTokens.accentStrong,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.onPurge != null) ...[
                  const SizedBox(width: 2),
                  Tooltip(
                    message: '彻底删除此文件',
                    child: McPressable(
                      haptic: true,
                      onTap: widget.onPurge,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              '彻底删除',
                              style: McText.micro.copyWith(
                                color: McTokens.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else if (widget.onDelete != null) ...[
                IconButton(
                  tooltip: '删除此文件',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    McIcons.trash2,
                    size: 16,
                    color: McTokens.textFaint,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onDelete!();
                  },
                ),
              ],
            ],
          ),
        ),
        if (trashed)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              _purgeCountdown(f.purgeAfter) +
                  (f.trashNote != null && f.trashNote!.isNotEmpty
                      ? ' · ${f.trashNote}'
                      : ''),
              style: McText.micro.faint,
            ),
          ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  '保存目录',
                  _directoryOf(f.filePath),
                  mono: true,
                  onTap: _copyPath,
                ),
                _detailRow(
                  '入库时间',
                  f.addedAt.isNotEmpty
                      ? '${f.addedAt.replaceFirst('T', ' ').substring(0, f.addedAt.length >= 16 ? 16 : f.addedAt.length)} · ${mcFromNowIso(f.addedAt)}'
                      : '—',
                ),
                _detailRow(
                  '来源',
                  f.origin.detail != null && f.origin.detail!.isNotEmpty
                      ? '${f.origin.label}\n${f.origin.detail}'
                      : f.origin.label,
                ),
                if (f.keptAt != null && f.keptAt!.isNotEmpty)
                  _detailRow('多版本保留', '已保留 (${mcFromNowIso(f.keptAt)})'),
                _detailRow('文件大小', mcFormatBytes(f.sizeBytes)),
                for (final r in specRows) _detailRow(r.label, r.value),
                const SizedBox(height: 6),
                Tooltip(
                  message: '复制文件完整路径',
                  child: McPressable(
                    haptic: true,
                    onTap: _copyPath,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.fileCopy,
                              size: 13,
                              color: McTokens.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '复制完整路径',
                              style:
                                  McText.micro.copyWith(color: McTokens.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          style: McText.micro.copyWith(color: color.withValues(alpha: 0.9)),
        ),
      );

  Widget _detailRow(
    String label,
    String value, {
    bool mono = false,
    VoidCallback? onTap,
  }) {
    final child = Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: McText.micro.faint),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: McText.micro.copyWith(
                fontFamily: mono ? 'monospace' : null,
                color: McTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onLongPress: onTap, child: child);
  }
}

/// 详情页底部外部词条链接栏（TMDB / IMDb / 豆瓣，通过 `ExternalMediaLink.open` 优先唤起豆瓣 App）。
class ExternalLinksBar extends StatelessWidget {
  const ExternalLinksBar({super.key, required this.entry});

  final DetailEntry entry;

  @override
  Widget build(BuildContext context) {
    final tmdb = entry.tmdbId ?? 0;
    final imdb = entry.imdbId;
    final douban = entry.doubanId;
    final hasImdb = imdb != null && imdb.isNotEmpty;
    final hasDouban = douban != null && douban.isNotEmpty;
    if (tmdb <= 0 && !hasImdb && !hasDouban) return const SizedBox.shrink();

    final tmdbKind = entry.isTv ? 'tv' : 'movie';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        22,
        McTokens.pagePadding,
        0,
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('外部词条', style: McText.caption.faint),
          if (tmdb > 0)
            _linkButton(
              'TMDB',
              'https://www.themoviedb.org/$tmdbKind/$tmdb',
            ),
          if (hasImdb)
            _linkButton(
              'IMDb',
              'https://www.imdb.com/title/$imdb/',
            ),
          if (hasDouban)
            _linkButton(
              '豆瓣',
              'https://movie.douban.com/subject/$douban/',
            ),
        ],
      ),
    );
  }

  Widget _linkButton(String label, String url) {
    return Tooltip(
      message: '在外部打开 $label',
      child: McPressable(
        haptic: true,
        onTap: () => ExternalMediaLink.open(url),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: McTokens.line),
              ),
              child: Text(
                '$label ↗',
                style: McText.caption.copyWith(
                  color: McTokens.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
