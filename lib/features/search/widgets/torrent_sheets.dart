import 'package:flutter/material.dart';

import '../../../core/api/models.dart';
import '../state/torrent_models.dart';

/// 资源操作面板与下载目标弹窗（P2 移植自安卓
/// `feature/search/DownloadTargetSheet.kt` 的 `TorrentActionsSheet` /
/// `DownloadConfirmSheet` / `DownloadTargetSheet`）。
///
/// 本文件只含 UI：状态在 [DownloadFlow] / [TorrentSearchController] 里，
/// 动作全部经回调回控制器；不直接调 API，便于 widget 单测。

/// 资源操作面板的结果。
enum TorrentSheetAction { viewDetail, grab, download }

/// 资源操作面板（片名与站点信息 + 三个动作）。
/// 成员看不到「下载」（要一键下载权限），也不会有「投给订阅」
/// （那要订阅 + 资源搜索 + 一键下载三项能力）——调用方按权限决定
/// [canDirectDownload] / [canGrabForSubscription]。
Future<TorrentSheetAction?> showTorrentActionsSheet(
  BuildContext context, {
  required TorrentHit hit,
  required bool canDirectDownload,
  required bool canGrabForSubscription,
  String? grabTargetTitle,
  TorrentSubmitState downloadState = TorrentSubmitState.idle,
  TorrentSubmitState grabState = TorrentSubmitState.idle,
}) {
  return showModalBottomSheet<TorrentSheetAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hit.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (hit.siteName.isNotEmpty) hit.siteName,
                if (hit.category != null)
                  TorrentCategory.of(hit.category)?.label ?? hit.category!,
                if (hit.size != null && hit.size!.isNotEmpty) hit.size!,
              ].join(' · '),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (hit.detailUrl != null && hit.detailUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('查看详情'),
                onTap: () =>
                    Navigator.of(context).pop(TorrentSheetAction.viewDetail),
              ),
            if (canGrabForSubscription)
              ListTile(
                leading: const Icon(Icons.rss_feed),
                title: Text(
                  grabTargetTitle == null
                      ? '投给订阅'
                      : '投给订阅「$grabTargetTitle」',
                ),
                subtitle: grabState == TorrentSubmitState.idle
                    ? null
                    : Text(grabState.grabLabel),
                enabled: grabState != TorrentSubmitState.submitting &&
                    grabState != TorrentSubmitState.done &&
                    grabState != TorrentSubmitState.exists,
                onTap: () =>
                    Navigator.of(context).pop(TorrentSheetAction.grab),
              ),
            if (canDirectDownload)
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(downloadState.downloadLabel),
                enabled: downloadState != TorrentSubmitState.submitting &&
                    downloadState != TorrentSubmitState.done &&
                    downloadState != TorrentSubmitState.exists,
                onTap: () =>
                    Navigator.of(context).pop(TorrentSheetAction.download),
              ),
            if (!canDirectDownload && !canGrabForSubscription)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('当前账号没有下载权限',
                    style: TextStyle(color: Colors.white54)),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 确认条的结果。
enum DownloadConfirmAction { confirm, change, forget }

/// 有保存位置记忆时先弹确认条（记忆是策略时由服务端按身份重新路由）。
Future<DownloadConfirmAction?> showDownloadConfirmSheet(
  BuildContext context, {
  required DownloadTargetRequest request,
  required DownloadTargetPrefView remembered,
}) {
  final label = switch (remembered.kind) {
    'smart' => '智能入库（自动识别条目并入库）',
    'dir' => '保存到 ${remembered.savePath ?? ''}',
    _ => '下载器默认目录',
  };
  return showModalBottomSheet<DownloadConfirmAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.identityTitle ?? request.hint ?? '下载这条种子',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('上次的保存位置：$label',
                style: const TextStyle(color: Colors.white70)),
            if (remembered.downloaderName != null &&
                remembered.downloaderName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('下载器：${remembered.downloaderName}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(DownloadConfirmAction.confirm),
              child: const Text('确认下载'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pop(DownloadConfirmAction.change),
                    child: const Text('更改'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pop(DownloadConfirmAction.forget),
                    child: const Text('不再记住'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 完整落点弹窗：候选识别（「这是哪部作品」）+ 保存目标三层候选 +
/// 下载器选择 + 「记住本次选择」。
class DownloadTargetSheet extends StatefulWidget {
  const DownloadTargetSheet({
    super.key,
    required this.flow,
    required this.options,
    required this.isAdmin,
    required this.onSelectOption,
    required this.onToggleRemember,
    required this.onShowOther,
    required this.onSelectDownloader,
    required this.onHintChanged,
    required this.onSearchHint,
    required this.onSelectCandidate,
    required this.onConfirm,
  });

  final DownloadFlow flow;
  final List<TargetOption> options;
  final bool isAdmin;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<bool> onToggleRemember;
  final VoidCallback onShowOther;
  final ValueChanged<int> onSelectDownloader;
  final ValueChanged<String> onHintChanged;
  final VoidCallback onSearchHint;
  final ValueChanged<ManualDownloadCandidateView> onSelectCandidate;
  final VoidCallback onConfirm;

  @override
  State<DownloadTargetSheet> createState() => _DownloadTargetSheetState();
}

class _DownloadTargetSheetState extends State<DownloadTargetSheet> {
  late final TextEditingController _hint;

  @override
  void initState() {
    super.initState();
    _hint = TextEditingController(text: widget.flow.hintDraft);
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final request = flow.request;
    if (request == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.identityTitle ?? request.hint ?? '选择保存位置',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              if (request.reason != null) ...[
                const SizedBox(height: 8),
                Text(request.reason!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13)),
              ],
              if (flow.picking) ...[
                const SizedBox(height: 16),
                const Text('这是哪部作品？',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hint,
                        textInputAction: TextInputAction.search,
                        onChanged: widget.onHintChanged,
                        onSubmitted: (_) => widget.onSearchHint(),
                        decoration: const InputDecoration(
                          hintText: '输入片名搜索 TMDB 候选',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: widget.onSearchHint,
                      tooltip: '搜索候选',
                    ),
                  ],
                ),
                if (flow.candidates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final c in flow.candidates)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${c.title}${c.year == null ? '' : ' (${c.year})'}'),
                      subtitle: Text(
                          '${libraryKindLabel(c.kind)}${c.episodeCount == null ? '' : ' · ${c.episodeCount} 集'}'),
                      trailing: flow.selectedCandidate?.tmdbId == c.tmdbId
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () => widget.onSelectCandidate(c),
                    ),
                ],
              ],
              if (flow.loadingTarget)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (flow.target != null &&
                  flow.target!.status == 'ready' &&
                  !(flow.target!.ok)) ...[
                const SizedBox(height: 8),
                Text(
                  flow.target!.warning ?? '该条目暂不能自动入库，请选择其他保存位置。',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
              if (widget.options.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('保存位置',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final o in widget.options)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.label),
                    subtitle:
                        o.detail == null ? null : Text(o.detail!),
                    value: o.id,
                    groupValue: flow.selected,
                    onChanged: (v) {
                      if (v != null) widget.onSelectOption(v);
                    },
                  ),
              ],
              if (!flow.showOther)
                TextButton.icon(
                  onPressed: widget.onShowOther,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('其他保存位置'),
                ),
              if (flow.showOther && flow.downloaders.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: flow.downloaderId,
                  decoration: const InputDecoration(
                    labelText: '下载器',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final d in flow.downloaders)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) widget.onSelectDownloader(v);
                  },
                ),
              ],
              if (flow.loadingDownloaders)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (widget.isAdmin)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('记住本次选择'),
                  subtitle: const Text('下次同类种子直接按这个位置下载'),
                  value: flow.remember,
                  onChanged: (v) {
                    if (v != null) widget.onToggleRemember(v);
                  },
                ),
              if (flow.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(flow.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: flow.busy || flow.selected == null
                    ? null
                    : widget.onConfirm,
                child: Text(flow.busy ? '提交中…' : '确认下载'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
