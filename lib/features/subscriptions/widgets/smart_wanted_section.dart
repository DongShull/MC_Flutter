import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/subscriptions_api.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 传给 `SmartWantedSelection` 的上下文（对应 iOS `SmartWantedContext`）。
class SmartWantedContext {
  const SmartWantedContext({
    required this.wanted,
    required this.detail,
    required this.canManage,
    required this.onChanged,
    this.onOriginalRequested,
  });

  final WantedView wanted;
  final SubscriptionView detail;
  final bool canManage;
  final Future<void> Function() onChanged;

  /// 「这次先下原版」成功后通知详情页追问管理员是否看得懂该语言。
  final VoidCallback? onOriginalRequested;
}

/// 智能订阅分集决策详情与操作区（1:1 对齐 iOS `SmartWantedSelection.swift`）。
/// 挂在里程碑链的「搜索」节点下。
class SmartWantedSelection extends ConsumerStatefulWidget {
  const SmartWantedSelection({super.key, required this.contextData});

  final SmartWantedContext contextData;

  @override
  ConsumerState<SmartWantedSelection> createState() =>
      _SmartWantedSelectionState();
}

class _SmartWantedSelectionState extends ConsumerState<SmartWantedSelection> {
  bool _busy = false;
  bool _detailsOpen = false;
  String? _error;

  Future<bool> _sendAction(SmartWaitPayload payload) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    var succeeded = false;
    try {
      await ref.read(subscriptionsApiProvider).changeSmartWait(
            subscriptionId: widget.contextData.detail.id,
            wantedId: widget.contextData.wanted.id,
            payload: payload,
          );
      succeeded = true;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendlyMessage);
    } catch (e) {
      if (mounted) setState(() => _error = '操作失败：$e');
    }
    // 成功或版本冲突都重新拉取，保证下次操作携带最新 selection_version 与候选
    await widget.contextData.onChanged();
    if (mounted) setState(() => _busy = false);
    return succeeded;
  }

  @override
  Widget build(BuildContext context) {
    final state = SmartSelection.fromWanted(widget.contextData.wanted);
    if (state == null) return const SizedBox.shrink();

    final detail = widget.contextData.detail;
    final canAct = widget.contextData.canManage &&
        detail.status == 'active' &&
        detail.smartStatus == 'active';

    // 分支 1：身份未确认
    if (state.reason == 'identity_unconfirmed') {
      final explanation = state.str('identity_explanation');
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('无需手动干预，核实匹配后会自动继续。', style: McText.caption.muted),
            if (explanation != null) ...[
              const SizedBox(height: 6),
              _collapsibleDetails(
                label: '查看核实详情',
                child: SelectableText(
                  explanation,
                  style: McText.micro.muted,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 分支 2：等待中文字幕
    if (state.awaitingSubtitles) {
      final waitExp = state.str('wait_explanation');
      final subLine = detail.smartSubtitle?.line;
      final deadline =
          state.reason == 'awaiting_subtitles' ? state.str('deadline') : null;
      final candidateTitle = state.str('candidate_title');
      final candidateKey = state.str('candidate_key');

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: McText.caption.copyWith(color: SubsColor.danger),
              ),
              const SizedBox(height: 6),
            ],
            if (waitExp != null) ...[
              Text(waitExp, style: McText.caption.muted),
              const SizedBox(height: 4),
            ],
            if (subLine != null && subLine.isNotEmpty) ...[
              Text(subLine, style: McText.caption.muted),
              const SizedBox(height: 4),
            ],
            if (deadline != null) ...[
              Text(
                '最晚等待至 ${SubsFormat.dateTime(deadline)}',
                style: McText.caption.semibold.copyWith(color: McTokens.text),
              ),
              const SizedBox(height: 4),
            ],
            if (candidateTitle != null) ...[
              SelectableText(
                '当前原版候选：$candidateTitle',
                style: McText.micro.muted,
              ),
              const SizedBox(height: 8),
            ],
            if (canAct && candidateKey != null)
              McActionPill(
                label: _busy ? '正在提交…' : '这次先下原版',
                primary: false,
                height: 34,
                busy: _busy,
                onTap: _busy
                    ? null
                    : () async {
                        final ok = await _sendAction(
                          SmartWaitPayload(
                            version:
                                widget.contextData.wanted.selectionVersion ?? 0,
                            candidateKey: candidateKey,
                          ),
                        );
                        if (ok) {
                          widget.contextData.onOriginalRequested?.call();
                        }
                      },
              ),
          ],
        ),
      );
    }

    // 分支 3：通用智能选源观察 / 等待目标 / 等待系列版本
    final deadline = state.str('deadline');
    final candidateTitle = state.str('candidate_title');
    final following = state.followingLabel;
    final waitExp = state.str('wait_explanation');
    final choiceExp = state.str('choice_explanation');
    final candidateKey = state.str('candidate_key');
    final isMovie = detail.media.kind == 'movie';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: McText.caption.copyWith(color: SubsColor.danger),
            ),
            const SizedBox(height: 6),
          ],
          if (deadline != null) ...[
            Text(
              '决策截止：${SubsFormat.dateTime(deadline)}',
              style: McText.caption.semibold.copyWith(color: McTokens.text),
            ),
            const SizedBox(height: 4),
          ],
          if (candidateTitle != null) ...[
            SelectableText(
              '当前最佳候选：$candidateTitle',
              style: McText.micro.muted,
            ),
            const SizedBox(height: 4),
          ],
          if (following != null) ...[
            Text('跟随本剧规格：$following', style: McText.micro.muted),
            const SizedBox(height: 4),
          ],
          if (waitExp != null) ...[
            Text(waitExp, style: McText.caption.muted),
            const SizedBox(height: 4),
          ],
          if (choiceExp != null) ...[
            Text(choiceExp, style: McText.caption.muted),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          _collapsibleDetails(
            label: '查看判断依据',
            child: _reasoningBody(state),
          ),
          if (canAct) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (candidateKey != null)
                  McActionPill(
                    label: _busy ? '正在提交…' : '立刻下载当前候选',
                    primary: true,
                    height: 34,
                    busy: _busy,
                    onTap: _busy
                        ? null
                        : () => _sendAction(
                              SmartWaitPayload(
                                version: widget
                                        .contextData.wanted.selectionVersion ??
                                    0,
                                candidateKey: candidateKey,
                              ),
                            ),
                  ),
                McActionPill(
                  label: isMovie ? '延长等待 1 天' : '延长等待 2 小时',
                  primary: false,
                  height: 34,
                  onTap: _busy
                      ? null
                      : () => _sendAction(
                            SmartWaitPayload(
                              version:
                                  widget.contextData.wanted.selectionVersion ??
                                      0,
                              extendSeconds: isMovie ? 86400 : 7200,
                            ),
                          ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _reasoningBody(SmartSelection state) {
    final anchor = state.str('anchor');
    final anchorSource = state.str('anchor_source');
    final obsEnd = state.str('observation_end');
    final predRaw = state.values['prediction'];
    final pred = predRaw is Map ? predRaw.cast<String, dynamic>() : null;
    final predEpisodes = pred?['episodes'] is List ? pred!['episodes'] as List : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anchor != null)
          Text(
            anchorSource == 'published_at'
                ? '计时起点（资源发布时间）：${SubsFormat.dateTime(anchor)}'
                : '计时起点（首次发现时间）：${SubsFormat.dateTime(anchor)}',
            style: McText.micro.muted,
          ),
        const SizedBox(height: 4),
        if (pred != null && predEpisodes != null)
          Text(
            '出种窗口预测（参考 ${predEpisodes.length} 集）：${SubsFormat.dateTime(pred['start']?.toString())} – ${SubsFormat.dateTime(pred['end']?.toString())}',
            style: McText.micro.muted,
          )
        else
          Text('暂无历史出种窗口预测', style: McText.micro.faint),
        if (obsEnd != null) ...[
          const SizedBox(height: 4),
          Text(
            '观察结束时间：${SubsFormat.dateTime(obsEnd)}',
            style: McText.micro.muted,
          ),
        ],
      ],
    );
  }

  Widget _collapsibleDetails({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _detailsOpen = !_detailsOpen),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: McText.micro.copyWith(color: SubsColor.info),
              ),
              const SizedBox(width: 4),
              Icon(
                _detailsOpen ? McIcons.arrowDownS : McIcons.chevronRight,
                size: 13,
                color: SubsColor.info,
              ),
            ],
          ),
        ),
        if (_detailsOpen) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: McTokens.glassFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: McTokens.line),
            ),
            child: child,
          ),
        ],
      ],
    );
  }
}
