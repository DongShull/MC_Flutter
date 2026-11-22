// AI 字幕生成页的状态（对照安卓 `feature/detail/SubtitleGen.kt`）。
//
// 全程走类型化 McApi：
// - 预检 `GET /libraries/files/{fileId}/subtitles/generation-preview`
//   → [SubtitleGenPreviewView]（候选源 / 已生成 / blocker / pending / PGS 转换）；
// - 提交 `POST /libraries/files/{fileId}/subtitles/generations`
//   → [JobView]（任务号，进度在活动页查看）。
// 不写占位：预检失败、blocker、pending 均如实展示，不以 toast 冒充完成。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/models.dart';

/// 目标语言选项（对照安卓 `SubtitleGenText.outputLanguages`）。
const subtitleTargetLanguages = <({String token, String label})>[
  (token: 'chs', label: '简体中文'),
  (token: 'cht', label: '繁体中文'),
  (token: 'eng', label: '英语'),
  (token: 'jpn', label: '日语'),
  (token: 'kor', label: '韩语'),
  (token: 'fre', label: '法语'),
  (token: 'ger', label: '德语'),
  (token: 'spa', label: '西班牙语'),
];

String subtitleLanguageLabel(String token) {
  for (final l in subtitleTargetLanguages) {
    if (l.token == token) return l.label;
  }
  return token.toUpperCase();
}

class SubtitleGenState {
  const SubtitleGenState({
    this.loading = true,
    this.error,
    this.preview,
    this.targetLanguage = 'chs',
    this.bilingual = false,
    this.secondaryLanguage,
    this.sourceCandidateKey,
    this.convertPgs = false,
    this.pgsOcrLanguage = '',
    this.submitting = false,
    this.job,
  });

  final bool loading;
  final String? error;
  final SubtitleGenPreviewView? preview;
  final String targetLanguage;
  final bool bilingual;
  final String? secondaryLanguage;
  final String? sourceCandidateKey;
  final bool convertPgs;
  final String pgsOcrLanguage;
  final bool submitting;
  final JobView? job;

  /// 提交按钮是否可点：预检通过（无 blocker、无待处理）、不在提交中。
  /// PGS 转码需确认 OCR 语言时（安卓同规则），须先填语言。
  bool get canSubmit {
    final p = preview;
    if (p == null || loading || submitting || job != null) return false;
    if (p.blocker != null) return false;
    if (p.pending != null) return false;
    final pgs = p.pgsConversion;
    if (convertPgs &&
        pgs != null &&
        pgs.languageConfirmationRequired &&
        pgsOcrLanguage.trim().isEmpty) {
      return false;
    }
    return true;
  }

  SubtitleGenState copyWith({
    bool? loading,
    Object? error = _sentinel,
    SubtitleGenPreviewView? preview,
    String? targetLanguage,
    bool? bilingual,
    Object? secondaryLanguage = _sentinel,
    Object? sourceCandidateKey = _sentinel,
    bool? convertPgs,
    String? pgsOcrLanguage,
    bool? submitting,
    JobView? job,
  }) =>
      SubtitleGenState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        preview: preview ?? this.preview,
        targetLanguage: targetLanguage ?? this.targetLanguage,
        bilingual: bilingual ?? this.bilingual,
        secondaryLanguage: identical(secondaryLanguage, _sentinel)
            ? this.secondaryLanguage
            : secondaryLanguage as String?,
        sourceCandidateKey: identical(sourceCandidateKey, _sentinel)
            ? this.sourceCandidateKey
            : sourceCandidateKey as String?,
        convertPgs: convertPgs ?? this.convertPgs,
        pgsOcrLanguage: pgsOcrLanguage ?? this.pgsOcrLanguage,
        submitting: submitting ?? this.submitting,
        job: job ?? this.job,
      );

  static const _sentinel = Object();
}

class SubtitleGenController extends FamilyNotifier<SubtitleGenState, int> {
  McApi get _api => ref.read(mcApiProvider);

  @override
  SubtitleGenState build(int fileId) {
    Future.microtask(() => load());
    return const SubtitleGenState();
  }

  /// 预检：候选源 / 已生成 / blocker / pending / PGS 转换一次拿全。
  Future<void> load() async {
    final fileId = arg;
    state = state.copyWith(loading: true, error: null);
    try {
      final preview = await _api.subtitleGenerationPreview(
        fileId,
        targetLanguage: state.targetLanguage,
      );
      state = state.copyWith(
        loading: false,
        preview: preview,
        // 服务端已选中的源候选作为默认；没有则取第一个可选候选。
        sourceCandidateKey: preview.chosenKey ??
            preview.selectedSourceKey ??
            preview.candidates
                .where((c) => c.selectable)
                .firstOrNull
                ?.key,
        convertPgs:
            preview.pgsConversion?.available == true ? state.convertPgs : false,
        pgsOcrLanguage:
            preview.pgsConversion?.ocrLanguage ?? state.pgsOcrLanguage,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  void setTargetLanguage(String token) {
    state = state.copyWith(targetLanguage: token);
    // 目标语言影响预检（候选源按语言过滤），改后重拉一次。
    unawaited(load());
  }

  void setBilingual(bool value) => state = state.copyWith(
        bilingual: value,
        secondaryLanguage: value ? state.secondaryLanguage : null,
      );

  void setSecondaryLanguage(String? token) =>
      state = state.copyWith(secondaryLanguage: token);

  void selectCandidate(String key) =>
      state = state.copyWith(sourceCandidateKey: key);

  void setConvertPgs(bool value) => state = state.copyWith(convertPgs: value);

  void setPgsOcrLanguage(String value) =>
      state = state.copyWith(pgsOcrLanguage: value);

  /// 提交生成任务：成功后 state.job 带任务号，页面展示并指引去活动页看进度。
  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(submitting: true, error: null);
    try {
      final job = await _api.startSubtitleGeneration(
        arg,
        body: SubtitleGenStartPayload(
          targetLanguage: state.targetLanguage,
          secondaryLanguage:
              state.bilingual ? state.secondaryLanguage : null,
          sourceCandidateKey: state.sourceCandidateKey,
          convertPgs: state.convertPgs,
          pgsOcrLanguage:
              state.convertPgs && state.pgsOcrLanguage.trim().isNotEmpty
                  ? state.pgsOcrLanguage.trim()
                  : null,
        ),
      );
      state = state.copyWith(submitting: false, job: job);
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(submitting: false, error: '提交失败：$e');
    }
  }
}

/// 字幕生成控制器 family：key = fileId。
final subtitleGenControllerProvider =
    NotifierProvider.family<SubtitleGenController, SubtitleGenState, int>(
  SubtitleGenController.new,
);
