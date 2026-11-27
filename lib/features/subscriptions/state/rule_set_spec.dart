/// 规则组 spec → 中文摘要（委托 `core/designsystem/rule_set_editor_sheet.dart` 的真实后端字段口径）。
library;

import '../../../core/designsystem/rule_set_editor_sheet.dart';

export '../../../core/designsystem/rule_set_editor_sheet.dart'
    show
        RuleSetEditorSheet,
        RuleSetScope,
        RuleSetSpec,
        RuleSetSpecFormatter,
        RuleSetVocabulary,
        UpgradeLadderPreview,
        showRuleSetEditorSheet;

/// 把规则组的 spec（服务端下发的真实 snake_case JSON：`media_sources`、`video_codecs`、
/// `free_only`、`size_min_mb`/`size_max_mb`、`release_groups_allow`/`release_groups_block`、
/// `platforms`/`platforms_block`、`hdr_levels`/`hdr_block`、`subtitle_languages_require`、
/// `audio_languages_require`、`exclude_hr`/`hr_unknown_policy`、`upgrade_source`/
/// `cutoff_resolution`/`upgrade_keep_old`/`upgrade_ladder`）渲染成一句中文摘要。
String specSummary(Map<String, dynamic>? spec) {
  if (spec == null || spec.isEmpty) return '不限条件';
  final chips = RuleSetSpecFormatter.summaryChips(RuleSetSpec.fromJson(spec));
  return chips.isEmpty ? '不限条件' : chips.join(' · ');
}

/// 洗版目标标签；未配置洗版返回 null。
String? specUpgradeTarget(Map<String, dynamic>? spec) {
  if (spec == null || spec.isEmpty) return null;
  return RuleSetSpecFormatter.upgradeTargetLabel(RuleSetSpec.fromJson(spec));
}
