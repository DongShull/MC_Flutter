// AI 字幕生成页（对照安卓 `feature/detail/SubtitleGen.kt`）。
//
// 预检结果如实展示：blocker（不可生成的原因与建议）、pending（已有任务在跑）、
// 已生成、候选源、PGS 转码确认；提交后展示任务号并指引去活动页看进度。
// 文案与颜色走 Theme（不硬编码色值进页面）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/state_views.dart';
import '../state/subtitle_gen_controller.dart';

class SubtitleGenPage extends ConsumerWidget {
  const SubtitleGenPage({
    super.key,
    required this.fileId,
    required this.title,
  });

  final int fileId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subtitleGenControllerProvider(fileId));
    final notifier = ref.read(subtitleGenControllerProvider(fileId).notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final preview = state.preview;
    return Scaffold(
      appBar: AppBar(title: const Text('生成字幕')),
      body: state.loading && preview == null
          ? const McLoadingView()
          : state.error != null && preview == null
              ? McErrorView(
                  text: state.error!,
                  onRetry: notifier.load,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    if (preview?.blocker != null)
                      _NoticeCard(
                        title: preview!.blocker!.title,
                        body: preview.blocker!.message,
                        suggestions: preview.blocker!.suggestions,
                        tone: _NoticeTone.error,
                      ),
                    if (preview?.pending != null)
                      _NoticeCard(
                        title: '已有生成任务在进行',
                        body: preview!.pending!.message,
                        tone: _NoticeTone.info,
                      ),
                    if (preview?.alreadyGenerated == true)
                      const _NoticeCard(
                        title: '已生成过字幕',
                        body: '再次提交会重新生成并覆盖。',
                        tone: _NoticeTone.info,
                      ),
                    if (preview != null &&
                        preview.warnings.isNotEmpty) ...[
                      _NoticeCard(
                        title: '注意',
                        body: preview.warnings.join('\n'),
                        tone: _NoticeTone.warning,
                      ),
                    ],
                    if (preview?.referenceNotice != null &&
                        preview!.referenceNotice!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          preview.referenceNotice!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    if (preview != null) ...[
                      const _SectionTitle('目标语言'),
                      DropdownButtonFormField<String>(
                        value: state.targetLanguage,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final l in subtitleTargetLanguages)
                            DropdownMenuItem(
                              value: l.token,
                              child: Text(l.label),
                            ),
                        ],
                        onChanged: state.job != null
                            ? null
                            : (v) {
                                if (v != null) notifier.setTargetLanguage(v);
                              },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('双语字幕'),
                        subtitle: const Text('同时生成第二语言字幕'),
                        value: state.bilingual,
                        onChanged: state.job != null
                            ? null
                            : notifier.setBilingual,
                      ),
                      if (state.bilingual)
                        DropdownButtonFormField<String>(
                          value: state.secondaryLanguage,
                          decoration: const InputDecoration(
                            labelText: '第二语言',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final l in subtitleTargetLanguages)
                              if (l.token != state.targetLanguage)
                                DropdownMenuItem(
                                  value: l.token,
                                  child: Text(l.label),
                                ),
                          ],
                          onChanged: state.job != null
                              ? null
                              : notifier.setSecondaryLanguage,
                        ),
                      if (preview.candidates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const _SectionTitle('字幕来源'),
                        for (final c in preview.candidates)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              [
                                c.kind,
                                if (c.language != null) c.language!,
                                if (c.format != null) c.format!,
                              ].join(' · '),
                            ),
                            subtitle: c.reasons.isEmpty &&
                                    (c.excluded == null ||
                                        c.excluded!.isEmpty)
                                ? null
                                : Text([
                                    if (c.excluded != null &&
                                        c.excluded!.isNotEmpty)
                                      '不可用：${c.excluded}',
                                    ...c.reasons,
                                  ].join('\n')),
                            value: c.key,
                            groupValue: state.sourceCandidateKey,
                            onChanged: !c.selectable || state.job != null
                                ? null
                                : (v) {
                                    if (v != null) {
                                      notifier.selectCandidate(v);
                                    }
                                  },
                          ),
                      ],
                      if (preview.pgsConversion?.available == true) ...[
                        const SizedBox(height: 8),
                        const _SectionTitle('PGS 图片字幕转码'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('转码 PGS 字幕'),
                          subtitle: Text(
                            preview.pgsConversion!.message.isEmpty
                                ? '把图片字幕 OCR 转为文字字幕'
                                : preview.pgsConversion!.message,
                          ),
                          value: state.convertPgs,
                          onChanged: state.job != null
                              ? null
                              : notifier.setConvertPgs,
                        ),
                        if (state.convertPgs &&
                            preview.pgsConversion!
                                .languageConfirmationRequired)
                          _OcrLanguageField(
                            initialValue: state.pgsOcrLanguage,
                            label: preview.pgsConversion!.ocrLanguageLabel
                                        ?.isNotEmpty ==
                                    true
                                ? preview.pgsConversion!.ocrLanguageLabel
                                : 'OCR 语言',
                            onChanged: notifier.setPgsOcrLanguage,
                          ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (preview.outputFilename != null &&
                              preview.outputFilename!.isNotEmpty)
                            '输出：${preview.outputFilename}',
                          if (preview.eventCount > 0)
                            '约 ${preview.eventCount} 条',
                          if (preview.estimatedTokens > 0)
                            '约 ${preview.estimatedTokens} tokens',
                        ].join(' · '),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if (state.error != null && preview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          state.error!,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: scheme.error),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (state.job == null)
                      FilledButton(
                        onPressed: state.canSubmit ? notifier.submit : null,
                        child: Text(state.submitting ? '提交中…' : '开始生成'),
                      )
                    else
                      _JobCard(
                        jobId: state.job!.id,
                        status: state.job!.status,
                        onViewActivity: () => context.push('/activity'),
                      ),
                  ],
                ),
    );
  }
}

/// OCR 语言输入框：controller 由组件自己持有，避免 build 时重建丢焦点。
class _OcrLanguageField extends StatefulWidget {
  const _OcrLanguageField({
    required this.initialValue,
    required this.label,
    required this.onChanged,
  });

  final String initialValue;
  final String? label;
  final ValueChanged<String> onChanged;

  @override
  State<_OcrLanguageField> createState() => _OcrLanguageFieldState();
}

class _OcrLanguageFieldState extends State<_OcrLanguageField> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _input,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '如 chi（中文）/ eng（英语）',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
}

enum _NoticeTone { info, warning, error }

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.body,
    this.suggestions = const [],
    required this.tone,
  });

  final String title;
  final String body;
  final List<String> suggestions;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _NoticeTone.info => scheme.primary,
      _NoticeTone.warning => scheme.tertiary,
      _NoticeTone.error => scheme.error,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body),
          ],
          for (final s in suggestions) ...[
            const SizedBox(height: 4),
            Text('· $s'),
          ],
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.jobId,
    required this.status,
    required this.onViewActivity,
  });

  final String jobId;
  final String status;
  final VoidCallback onViewActivity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已提交生成任务',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('任务号：$jobId'),
          if (status.isNotEmpty) Text('状态：$status'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onViewActivity,
            icon: const Icon(Icons.list_alt),
            label: const Text('在活动页查看进度'),
          ),
        ],
      ),
    );
  }
}
