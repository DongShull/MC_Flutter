import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../api/subscriptions_api.dart';
import 'mc_chrome.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 规则组词表（1:1 对齐 iOS `RuleSetEditorModel.swift` 与后端 `movieclaw_matcher`）。
abstract final class RuleSetVocabulary {
  static const List<String> resolutions = ['2160p', '1080p', '720p'];

  static const List<({String value, String label})> mediaSources = [
    (value: 'remux', label: 'Remux'),
    (value: 'blu-ray', label: '蓝光'),
    (value: 'web-dl', label: 'WEB-DL'),
    (value: 'rip', label: '压制'),
    (value: 'tv', label: '电视录制'),
  ];

  static const List<({String label, List<String> values})> codecFamilies = [
    (label: 'H.265', values: ['x265', 'H.265', 'HEVC']),
    (label: 'H.264', values: ['x264', 'H.264', 'AVC']),
    (label: 'AV1', values: ['AV1']),
  ];

  static const List<String> hdrOptions = ['DV', 'HDR10+', 'HDR10', 'HLG', 'SDR'];

  /// 只能排除的 HDR 项（Profile 5 无 HDR10 兼容层，转码会偏绿偏紫）。
  static const List<String> hdrBlockOnly = ['DV P5'];

  static const List<({String value, String label})> subtitleLanguages = [
    (value: 'zh', label: '中文'),
    (value: 'zh-Hans', label: '简中'),
    (value: 'zh-Hant', label: '繁中'),
    (value: 'en', label: '英语'),
  ];

  static const List<({String value, String label})> audioLanguages = [
    (value: 'cmn', label: '国语'),
    (value: 'yue', label: '粤语'),
    (value: 'ja', label: '日语'),
    (value: 'en', label: '英语'),
  ];

  static const List<({String value, String label})> upgradeOptions = [
    (value: 'web-dl', label: 'WEB-DL'),
    (value: 'blu-ray', label: '蓝光'),
    (value: 'remux', label: 'Remux'),
  ];

  static const Map<String, String> upgradeSourceLabel = {
    'web-dl': 'WEB-DL',
    'blu-ray': '蓝光',
    'remux': 'Remux',
  };

  static const List<({String value, String label})> ladderOptions = [
    (value: 'resolution', label: '分辨率'),
    (value: 'source', label: '片源'),
    (value: 'hdr', label: 'HDR'),
    (value: 'video_codec', label: '编码'),
    (value: 'platform', label: '平台'),
  ];

  static const List<String> defaultLadder = ['resolution', 'source'];

  static const List<String> defaultResolutionLadder = [
    '4320p',
    '2160p',
    '1440p',
    '1080p',
    '720p',
    '576p',
    '480p',
  ];

  /// 编辑器常驻流媒体平台选项（与后端 PLATFORM 词表同值）。
  static const List<String> platformOptions = [
    'netflix',
    'disney_plus',
    'amazon',
    'hbo_max',
    'apple_tv_plus',
    'hulu',
    'paramount_plus',
    'peacock',
    'iqiyi',
    'wetv',
    'youku',
    'mangotv',
    'bilibili',
    'viu',
    'crunchyroll',
    'hotstar',
  ];

  static const Map<String, String> platformLabels = {
    'netflix': 'Netflix',
    'amazon': 'Prime Video',
    'disney_plus': 'Disney+',
    'hbo_max': 'HBO Max',
    'hulu': 'Hulu',
    'apple_tv_plus': 'Apple TV+',
    'paramount_plus': 'Paramount+',
    'peacock': 'Peacock',
    'showtime': 'Showtime',
    'starz': 'Starz',
    'discovery_plus': 'Discovery+',
    'crave': 'Crave',
    'stan': 'Stan',
    'roku': 'Roku',
    'google_tv': 'Google TV',
    'itunes': 'iTunes',
    'sony_core': 'Sony Pictures Core',
    'criterion': 'Criterion',
    'iqiyi': '爱奇艺',
    'wetv': '腾讯视频',
    'youku': '优酷',
    'mangotv': '芒果TV',
    'bilibili': 'B站',
    'viu': 'Viu',
    'nowplayer': 'Now player',
    'mytv_super': 'myTV SUPER',
    'hami_video': 'Hami Video',
    'line_tv': 'LINE TV',
    'kktv': 'KKTV',
    'tving': 'TVING',
    'wavve': 'Wavve',
    'coupang_play': 'Coupang Play',
    'kocowa': 'KOCOWA',
    'viki': 'Viki',
    'unext': 'U-NEXT',
    'tver': 'TVer',
    'fod': 'FOD',
    'dmm_tv': 'DMM TV',
    'hotstar': 'Hotstar',
    'crunchyroll': 'Crunchyroll',
    'hidive': 'HIDIVE',
    'abema': 'ABEMA',
    'adn': 'ADN',
    'funimation': 'Funimation',
    'vrv': 'VRV',
    'wakanim': 'Wakanim',
    'b_global': 'B-Global',
    'baha': 'Baha',
  };

  static String platformLabel(String id) => platformLabels[id] ?? id;

  static String mediaSourceLabel(String value) {
    for (final m in mediaSources) {
      if (m.value == value) return m.label;
    }
    return value;
  }

  static String subtitleLabel(String value) {
    for (final s in subtitleLanguages) {
      if (s.value == value) return s.label;
    }
    return value;
  }

  static String audioLabel(String value) {
    for (final a in audioLanguages) {
      if (a.value == value) return a.label;
    }
    return value;
  }

  static String ladderLabel(String value) {
    for (final l in ladderOptions) {
      if (l.value == value) return l.label;
    }
    return value;
  }
}

/// 规则组强类型 spec（1:1 对齐后端 `movieclaw_matcher.RuleSetSpec`）。
class RuleSetSpec {
  const RuleSetSpec({
    this.resolutions = const [],
    this.mediaSources = const [],
    this.videoCodecs = const [],
    this.platforms = const [],
    this.platformsBlock = const [],
    this.releaseGroupsAllow = const [],
    this.releaseGroupsBlock = const [],
    this.hdrLevels = const [],
    this.hdrBlock = const [],
    this.legacyHdr,
    this.legacyDv,
    this.freeOnly = false,
    this.minSeeders,
    this.sizeMinMb,
    this.sizeMaxMb,
    this.excludeHr = false,
    this.hrUnknownPolicy,
    this.subtitleLanguages = const [],
    this.audioLanguages = const [],
    this.upgradeSource,
    this.cutoffResolution,
    this.upgradeKeepOld = false,
    this.upgradeLadder,
    this.sites = const [],
    this.sitesBlock = const [],
    this.unknownExtra = const {},
  });

  final List<String> resolutions;
  final List<String> mediaSources;
  final List<String> videoCodecs;
  final List<String> platforms;
  final List<String> platformsBlock;
  final List<String> releaseGroupsAllow;
  final List<String> releaseGroupsBlock;
  final List<String> hdrLevels;
  final List<String> hdrBlock;
  final String? legacyHdr;
  final String? legacyDv;
  final bool freeOnly;
  final int? minSeeders;
  final int? sizeMinMb;
  final int? sizeMaxMb;
  final bool excludeHr;
  final String? hrUnknownPolicy;
  final List<String> subtitleLanguages;
  final List<String> audioLanguages;
  final String? upgradeSource;
  final String? cutoffResolution;
  final bool upgradeKeepOld;
  final List<String>? upgradeLadder;
  final List<String> sites;
  final List<String> sitesBlock;
  final Map<String, dynamic> unknownExtra;

  static const _knownKeys = <String>{
    'resolutions',
    'media_sources',
    'video_codecs',
    'platforms',
    'platforms_block',
    'release_groups_allow',
    'release_groups_block',
    'hdr_levels',
    'hdr_block',
    'hdr',
    'dv',
    'free_only',
    'min_seeders',
    'size_min_mb',
    'size_max_mb',
    'exclude_hr',
    'hr_unknown_policy',
    'subtitle_languages_require',
    'audio_languages_require',
    'upgrade_source',
    'cutoff_resolution',
    'upgrade_keep_old',
    'upgrade_ladder',
    'sites',
    'sites_block',
  };

  factory RuleSetSpec.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const RuleSetSpec();
    List<String> strings(String key) {
      final v = raw[key];
      if (v is! List) return const [];
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    int? readInt(String key) {
      final v = raw[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    String? readStr(String key) {
      final v = raw[key];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    final extras = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (!_knownKeys.contains(entry.key)) {
        extras[entry.key] = entry.value;
      }
    }

    return RuleSetSpec(
      resolutions: strings('resolutions'),
      mediaSources: strings('media_sources'),
      videoCodecs: strings('video_codecs'),
      platforms: strings('platforms'),
      platformsBlock: strings('platforms_block'),
      releaseGroupsAllow: strings('release_groups_allow'),
      releaseGroupsBlock: strings('release_groups_block'),
      hdrLevels: strings('hdr_levels'),
      hdrBlock: strings('hdr_block'),
      legacyHdr: readStr('hdr'),
      legacyDv: readStr('dv'),
      freeOnly: raw['free_only'] == true,
      minSeeders: readInt('min_seeders'),
      sizeMinMb: readInt('size_min_mb'),
      sizeMaxMb: readInt('size_max_mb'),
      excludeHr: raw['exclude_hr'] == true,
      hrUnknownPolicy: readStr('hr_unknown_policy'),
      subtitleLanguages: strings('subtitle_languages_require'),
      audioLanguages: strings('audio_languages_require'),
      upgradeSource: readStr('upgrade_source'),
      cutoffResolution: readStr('cutoff_resolution'),
      upgradeKeepOld: raw['upgrade_keep_old'] == true,
      upgradeLadder: raw['upgrade_ladder'] is List
          ? strings('upgrade_ladder')
          : null,
      sites: strings('sites'),
      sitesBlock: strings('sites_block'),
      unknownExtra: extras,
    );
  }

  /// 旧三态 → (白名单, 黑名单)，与后端 `_hdr_from_legacy` 同表。
  ({List<String> levels, List<String> block}) get effectiveHdr {
    if (hdrLevels.isNotEmpty || hdrBlock.isNotEmpty) {
      return (levels: hdrLevels, block: hdrBlock);
    }
    final family =
        RuleSetVocabulary.hdrOptions.where((o) => o != 'SDR').toList();
    if (legacyHdr == 'forbid') return (levels: const ['SDR'], block: const []);
    if (legacyDv == 'require') return (levels: const ['DV'], block: const []);
    if (legacyHdr == 'require') {
      return legacyDv == 'forbid'
          ? (
              levels: family.where((o) => o != 'DV').toList(),
              block: const ['DV'],
            )
          : (levels: family, block: const []);
    }
    if (legacyDv == 'forbid') return (levels: const [], block: const ['DV']);
    return (levels: const [], block: const []);
  }

  /// 保存用的 JSON：只写设置过的键，并保留未知扩展字段不丢失。
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{...unknownExtra};
    void put(String key, List<String> values) {
      if (values.isNotEmpty) out[key] = values;
    }

    put('resolutions', resolutions);
    put('media_sources', mediaSources);
    put('video_codecs', videoCodecs);
    if (upgradeLadder != null && upgradeLadder!.isNotEmpty) {
      out['upgrade_ladder'] = upgradeLadder;
    }
    put('platforms', platforms);
    put('platforms_block', platformsBlock);
    put('hdr_levels', hdrLevels);
    put('hdr_block', hdrBlock);
    put('subtitle_languages_require', subtitleLanguages);
    put('audio_languages_require', audioLanguages);
    if (freeOnly) out['free_only'] = true;
    if (excludeHr) {
      out['exclude_hr'] = true;
      if (hrUnknownPolicy == 'strict') {
        out['hr_unknown_policy'] = 'strict';
      }
    }
    if (minSeeders != null && minSeeders! > 0) out['min_seeders'] = minSeeders;
    if (sizeMinMb != null && sizeMinMb! > 0) out['size_min_mb'] = sizeMinMb;
    if (sizeMaxMb != null && sizeMaxMb! > 0) out['size_max_mb'] = sizeMaxMb;
    put('release_groups_allow', releaseGroupsAllow);
    put('release_groups_block', releaseGroupsBlock);
    if (upgradeSource != null && upgradeSource!.isNotEmpty) {
      out['upgrade_source'] = upgradeSource;
      if (cutoffResolution != null && cutoffResolution!.isNotEmpty) {
        out['cutoff_resolution'] = cutoffResolution;
      }
      if (upgradeKeepOld) out['upgrade_keep_old'] = true;
    }
    put('sites', sites);
    put('sites_block', sitesBlock);
    return out;
  }
}

/// 规则组 spec → 中文摘要与洗版目标标签（供全 App 复用，包括 Subscriptions 与 Settings）。
abstract final class RuleSetSpecFormatter {
  static String hdrChipText(List<String> levels) {
    final family =
        RuleSetVocabulary.hdrOptions.where((o) => o != 'SDR').toList();
    if (levels.length == family.length && family.every(levels.contains)) {
      return '要求 HDR';
    }
    if (levels.length == 1 && levels.first == 'SDR') {
      return '排除 HDR';
    }
    return 'HDR ${levels.join('/')}';
  }

  /// 洗版目标标签（如「1080p WEB-DL · DV」）；未开启洗版返回 null。
  static String? upgradeTargetLabel(RuleSetSpec spec) {
    final source = spec.upgradeSource;
    if (source == null || source.isEmpty) return null;
    final resolution = spec.cutoffResolution ??
        (spec.resolutions.isNotEmpty ? spec.resolutions.first : '1080p');
    final parts = <String>[
      '$resolution ${RuleSetVocabulary.upgradeSourceLabel[source] ?? source}',
    ];
    final ladder = spec.upgradeLadder ?? RuleSetVocabulary.defaultLadder;
    if (ladder.contains('hdr') && spec.hdrLevels.isNotEmpty) {
      parts.add(spec.hdrLevels.first);
    }
    if (ladder.contains('video_codec') && spec.videoCodecs.isNotEmpty) {
      parts.add(spec.videoCodecs.first);
    }
    if (ladder.contains('platform') && spec.platforms.isNotEmpty) {
      parts.add(RuleSetVocabulary.platformLabel(spec.platforms.first));
    }
    return parts.join(' · ');
  }

  /// spec → 中文芯片列表（空列表表示全不限）。
  static List<String> summaryChips(
    RuleSetSpec spec, {
    bool withoutUpgrade = false,
  }) {
    final chips = <String>[];
    if (spec.resolutions.isNotEmpty) {
      chips.add(spec.resolutions.join(' > '));
    }
    if (spec.mediaSources.isNotEmpty) {
      chips.add(
        spec.mediaSources
            .map(RuleSetVocabulary.mediaSourceLabel)
            .join(' > '),
      );
    }
    if (!withoutUpgrade) {
      final target = upgradeTargetLabel(spec);
      if (target != null) {
        chips.add(spec.upgradeKeepOld ? '洗到 $target（保留旧版）' : '洗到 $target');
      }
    }
    if (spec.videoCodecs.isNotEmpty) {
      final rest = [...spec.videoCodecs];
      final labels = <String>[];
      for (final family in RuleSetVocabulary.codecFamilies) {
        if (family.values.any(rest.contains)) {
          labels.add(family.label);
          rest.removeWhere(family.values.contains);
        }
      }
      labels.addAll(rest);
      chips.add(labels.join('/'));
    }
    if (spec.platforms.isNotEmpty) {
      chips.add(
        '平台 ${spec.platforms.map(RuleSetVocabulary.platformLabel).join('/')}',
      );
    }
    if (spec.platformsBlock.isNotEmpty) {
      chips.add(
        '排除 ${spec.platformsBlock.map(RuleSetVocabulary.platformLabel).join('/')}',
      );
    }
    final hdr = spec.effectiveHdr;
    if (hdr.levels.isNotEmpty) chips.add(hdrChipText(hdr.levels));
    if (hdr.block.isNotEmpty) chips.add('排除 ${hdr.block.join('/')}');
    if (spec.subtitleLanguages.isNotEmpty) {
      chips.add(
        '字幕 ${spec.subtitleLanguages.map(RuleSetVocabulary.subtitleLabel).join('/')}',
      );
    }
    if (spec.audioLanguages.isNotEmpty) {
      chips.add(
        '音轨 ${spec.audioLanguages.map(RuleSetVocabulary.audioLabel).join('/')}',
      );
    }
    if (spec.freeOnly) chips.add('仅免费');
    if (spec.minSeeders != null && spec.minSeeders! > 0) {
      chips.add('做种 ≥ ${spec.minSeeders}');
    }
    if (spec.sizeMinMb != null || spec.sizeMaxMb != null) {
      if (spec.sizeMinMb != null && spec.sizeMaxMb != null) {
        chips.add('单集 ${spec.sizeMinMb}–${spec.sizeMaxMb} MB');
      } else if (spec.sizeMinMb != null) {
        chips.add('单集 ≥ ${spec.sizeMinMb} MB');
      } else if (spec.sizeMaxMb != null) {
        chips.add('单集 ≤ ${spec.sizeMaxMb} MB');
      }
    }
    if (spec.excludeHr) {
      chips.add(spec.hrUnknownPolicy == 'strict' ? '排除 H&R（严格）' : '排除 H&R');
    }
    if (spec.releaseGroupsAllow.isNotEmpty) {
      chips.add('制作组白名单 ${spec.releaseGroupsAllow.length} 个');
    }
    if (spec.releaseGroupsBlock.isNotEmpty) {
      chips.add('制作组黑名单 ${spec.releaseGroupsBlock.length} 个');
    }
    return chips;
  }

  /// 一句话摘要（供列表行与设置页调用）。
  static String summaryFromRaw(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return '不限条件';
    final chips = summaryChips(RuleSetSpec.fromJson(raw));
    return chips.isEmpty ? '不限条件' : chips.join(' · ');
  }
}

/// 洗版阶梯预览（1:1 对齐 iOS `UpgradeLadderPreview`）。
class UpgradeLadderPreview {
  const UpgradeLadderPreview({
    required this.dimensions,
    required this.target,
    this.ceiling,
    required this.below,
    required this.moreBelow,
  });

  final List<String> dimensions;
  final String target;
  final String? ceiling;
  final List<String> below;
  final int moreBelow;

  static const int _maxRungsBelow = 5;

  static UpgradeLadderPreview? build(RuleSetSpec spec) {
    final upgradeSource = spec.upgradeSource;
    if (upgradeSource == null || upgradeSource.isEmpty) return null;
    final known = RuleSetVocabulary.ladderOptions.map((e) => e.value).toSet();
    var dims = (spec.upgradeLadder ?? RuleSetVocabulary.defaultLadder)
        .where(
          (dim) =>
              known.contains(dim) &&
              !(dim == 'hdr' && spec.hdrLevels.isEmpty) &&
              !(dim == 'video_codec' && spec.videoCodecs.isEmpty) &&
              !(dim == 'platform' && spec.platforms.isEmpty),
        )
        .toList();
    if (dims.isEmpty) dims = [...RuleSetVocabulary.defaultLadder];

    final sourceLabelMap = {
      for (final m in RuleSetVocabulary.mediaSources) m.value: m.label,
    };

    List<String> axisOf(String dim) {
      switch (dim) {
        case 'resolution':
          return spec.resolutions.isEmpty
              ? RuleSetVocabulary.defaultResolutionLadder
              : spec.resolutions;
        case 'source':
          final chosen = spec.mediaSources.isEmpty
              ? RuleSetVocabulary.mediaSources.map((e) => e.value).toList()
              : spec.mediaSources;
          return chosen.map((v) => sourceLabelMap[v] ?? v).toList();
        case 'hdr':
          return spec.hdrLevels;
        case 'video_codec':
          final result = <String>[];
          for (final value in spec.videoCodecs) {
            String family = value;
            for (final f in RuleSetVocabulary.codecFamilies) {
              if (f.values.any((x) => x.toLowerCase() == value.toLowerCase())) {
                family = f.label;
                break;
              }
            }
            if (!result.contains(family)) result.add(family);
          }
          return result;
        default:
          return spec.platforms.map(RuleSetVocabulary.platformLabel).toList();
      }
    }

    final axes = dims.map(axisOf).toList();
    final digits = <int>[];
    for (var i = 0; i < dims.length; i++) {
      final dim = dims[i];
      if (dim == 'resolution') {
        final cutoff = spec.cutoffResolution ??
            (spec.resolutions.isNotEmpty ? spec.resolutions.first : '1080p');
        digits.add(axes[i].indexOf(cutoff));
      } else if (dim == 'source') {
        digits.add(axes[i].indexOf(sourceLabelMap[upgradeSource] ?? ''));
      } else {
        digits.add(0);
      }
    }
    if (digits.any((d) => d < 0) || axes.any((a) => a.isEmpty)) return null;

    String comboLabel(List<int> combo) => [
          for (var i = 0; i < combo.length; i++) axes[i][combo[i]],
        ].join(' · ');

    var total = 1;
    var ordinal = 0;
    for (var i = 0; i < axes.length; i++) {
      total *= axes[i].length;
      ordinal = ordinal * axes[i].length + digits[i];
    }

    List<int> decode(int value) {
      final combo = List<int>.filled(axes.length, 0);
      var rest = value;
      for (var i = axes.length - 1; i >= 0; i--) {
        combo[i] = rest % axes[i].length;
        rest ~/= axes[i].length;
      }
      return combo;
    }

    final belowCount = total - 1 - ordinal;
    final shown = belowCount < _maxRungsBelow ? belowCount : _maxRungsBelow;
    return UpgradeLadderPreview(
      dimensions: dims.map(RuleSetVocabulary.ladderLabel).toList(),
      target: comboLabel(digits),
      ceiling: ordinal > 0 ? comboLabel(List<int>.filled(axes.length, 0)) : null,
      below: [
        for (var i = 1; i <= shown; i++) comboLabel(decode(ordinal + i)),
      ],
      moreBelow: belowCount - shown,
    );
  }
}

/// 规则组适用范围（`match_rules`）。
class RuleSetScope {
  const RuleSetScope({
    this.kind,
    this.regions = const [],
    this.genres = const [],
  });

  final String? kind; // null | 'movie' | 'tv'
  final List<String> regions;
  final List<int> genres;

  factory RuleSetScope.fromRules(List<Map<String, dynamic>> rules) {
    List<dynamic> valuesOf(String field) {
      for (final r in rules) {
        if (r['field'] == field && r['values'] is List) {
          return r['values'] as List<dynamic>;
        }
      }
      return const [];
    }

    final kinds = valuesOf('kind').map((e) => e.toString()).toList();
    final kind =
        kinds.length == 1 && (kinds.first == 'movie' || kinds.first == 'tv')
            ? kinds.first
            : null;
    final regions = valuesOf('origin_countries')
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final genres = valuesOf('genres')
        .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
        .whereType<int>()
        .toList();
    return RuleSetScope(kind: kind, regions: regions, genres: genres);
  }

  List<Map<String, dynamic>> toRules() {
    final out = <Map<String, dynamic>>[];
    if (kind != null) {
      out.add({
        'field': 'kind',
        'op': 'any_of',
        'values': [kind],
      });
    }
    if (regions.isNotEmpty) {
      out.add({
        'field': 'origin_countries',
        'op': 'any_of',
        'values': regions,
      });
    }
    if (genres.isNotEmpty) {
      out.add({
        'field': 'genres',
        'op': 'any_of',
        'values': genres,
      });
    }
    return out;
  }

  String? summary(LibraryRoutingOptions? options) {
    if (kind == null && regions.isEmpty && genres.isEmpty) return null;
    final parts = <String>[];
    if (kind != null) parts.add(kind == 'movie' ? '电影' : '剧集');
    if (regions.isNotEmpty) {
      parts.add(
        options != null
            ? options.regionLabels(regions).join('/')
            : '${regions.length} 个地区',
      );
    }
    if (genres.isNotEmpty) {
      parts.add(
        options != null
            ? options
                .genresFor(kind)
                .where((g) => genres.contains(g.id))
                .map((g) => g.label)
                .join('/')
            : '${genres.length} 个类型',
      );
    }
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }
}

/// 弹出完整可视化规则组编辑器（订阅弹层、洗版弹层与设置页共用）。
Future<SubscribeRuleSetOption?> showRuleSetEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  SubscribeRuleSetOption? ruleSet,
  ({String name, RuleSetSpec spec})? template,
}) {
  return showMcSheet<SubscribeRuleSetOption>(
    context: context,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
      ),
      child: RuleSetEditorSheet(
        ruleSet: ruleSet,
        template: template,
      ),
    ),
  );
}

enum _TriState { off, include, exclude }

/// 完整可视化规则组编辑器（1:1 对齐 iOS `RuleSetEditorView.swift`）。
class RuleSetEditorSheet extends ConsumerStatefulWidget {
  const RuleSetEditorSheet({
    super.key,
    this.ruleSet,
    this.template,
    this.onSaved,
  });

  final SubscribeRuleSetOption? ruleSet;
  final ({String name, RuleSetSpec spec})? template;
  final ValueChanged<SubscribeRuleSetOption>? onSaved;

  @override
  ConsumerState<RuleSetEditorSheet> createState() => _RuleSetEditorSheetState();
}

class _RuleSetEditorSheetState extends ConsumerState<RuleSetEditorSheet> {
  late final SubscriptionsApi _api = SubscriptionsApi(
    McClient(session: ref.read(sessionStoreProvider)),
  );

  late final TextEditingController _nameCtrl;
  late final TextEditingController _minSeedersCtrl;
  late final TextEditingController _sizeMinCtrl;
  late final TextEditingController _sizeMaxCtrl;
  late final TextEditingController _groupsAllowCtrl;
  late final TextEditingController _groupsBlockCtrl;

  late RuleSetSpec _original;
  String? _scopeKind;
  List<String> _scopeRegions = [];
  List<int> _scopeGenres = [];
  LibraryRoutingOptions? _routingOptions;

  List<String> _resolutions = [];
  List<String> _mediaSources = [];
  Set<String> _codecFamilies = {};
  List<String> _platformsAllow = [];
  List<String> _platformsBlock = [];
  List<String> _hdrLevels = [];
  List<String> _hdrBlock = [];
  List<String> _subLangs = [];
  List<String> _audioLangs = [];
  bool _freeOnly = false;
  bool _excludeHr = false;
  bool _hrStrict = false;

  String _upgradeSource = '';
  bool _upgradeKeepOld = false;
  String _cutoffResolution = '';
  List<String> _upgradeLadder = [...RuleSetVocabulary.defaultLadder];

  bool _ladderOpen = false;
  bool _ladderPreviewOpen = false;
  final Set<String> _openSections = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final spec = widget.ruleSet != null
        ? RuleSetSpec.fromJson(widget.ruleSet!.spec)
        : (widget.template?.spec ?? const RuleSetSpec());
    _original = spec;
    final scope = widget.ruleSet != null
        ? RuleSetScope.fromRules(widget.ruleSet!.matchRules)
        : const RuleSetScope();

    _nameCtrl = TextEditingController(
      text: widget.ruleSet?.name ?? widget.template?.name ?? '',
    );
    _scopeKind = scope.kind;
    _scopeRegions = [...scope.regions];
    _scopeGenres = [...scope.genres];
    _resolutions = [...spec.resolutions];
    _mediaSources = [...spec.mediaSources];
    _codecFamilies = {
      for (final f in RuleSetVocabulary.codecFamilies)
        if (f.values.any(spec.videoCodecs.contains)) f.label,
    };
    _platformsAllow = spec.platforms
        .where(RuleSetVocabulary.platformOptions.contains)
        .toList();
    _platformsBlock = spec.platformsBlock
        .where(RuleSetVocabulary.platformOptions.contains)
        .toList();
    final hdr = spec.effectiveHdr;
    _hdrLevels = [...hdr.levels];
    _hdrBlock = [...hdr.block];
    _subLangs = [...spec.subtitleLanguages];
    _audioLangs = [...spec.audioLanguages];
    _freeOnly = spec.freeOnly;
    _excludeHr = spec.excludeHr;
    _hrStrict = spec.hrUnknownPolicy == 'strict';
    _minSeedersCtrl = TextEditingController(
      text: spec.minSeeders?.toString() ?? '',
    );
    _sizeMinCtrl = TextEditingController(
      text: spec.sizeMinMb?.toString() ?? '',
    );
    _sizeMaxCtrl = TextEditingController(
      text: spec.sizeMaxMb?.toString() ?? '',
    );
    _groupsAllowCtrl = TextEditingController(
      text: spec.releaseGroupsAllow.join(', '),
    );
    _groupsBlockCtrl = TextEditingController(
      text: spec.releaseGroupsBlock.join(', '),
    );
    _upgradeSource = spec.upgradeSource ?? '';
    _upgradeKeepOld = spec.upgradeKeepOld;
    _cutoffResolution = spec.cutoffResolution ?? '';
    _upgradeLadder = spec.upgradeLadder != null && spec.upgradeLadder!.isNotEmpty
        ? [...spec.upgradeLadder!]
        : [...RuleSetVocabulary.defaultLadder];

    _loadRoutingOptions();
  }

  Future<void> _loadRoutingOptions() async {
    try {
      final opts = await _api.routingOptions();
      if (mounted) setState(() => _routingOptions = opts);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minSeedersCtrl.dispose();
    _sizeMinCtrl.dispose();
    _sizeMaxCtrl.dispose();
    _groupsAllowCtrl.dispose();
    _groupsBlockCtrl.dispose();
    super.dispose();
  }

  List<String> get _codecExtras => _original.videoCodecs
      .where(
        (v) => !RuleSetVocabulary.codecFamilies.any((f) => f.values.contains(v)),
      )
      .toList();

  ({List<String> allow, List<String> block}) get _platformExtras => (
        allow: _original.platforms
            .where((p) => !RuleSetVocabulary.platformOptions.contains(p))
            .toList(),
        block: _original.platformsBlock
            .where((p) => !RuleSetVocabulary.platformOptions.contains(p))
            .toList(),
      );

  bool _ladderUnconfigured(String dim) {
    if (dim == 'hdr') return _hdrLevels.isEmpty;
    if (dim == 'video_codec') {
      return _codecFamilies.isEmpty && _codecExtras.isEmpty;
    }
    if (dim == 'platform') {
      return _platformsAllow.isEmpty && _platformExtras.allow.isEmpty;
    }
    return false;
  }

  RuleSetScope get _validScope {
    var genres = [..._scopeGenres];
    if (_routingOptions != null) {
      final allowed =
          _routingOptions!.genresFor(_scopeKind).map((g) => g.id).toSet();
      genres = genres.where(allowed.contains).toList();
    }
    return RuleSetScope(
      kind: _scopeKind,
      regions: _scopeRegions,
      genres: genres,
    );
  }

  ({RuleSetSpec spec, String? error}) _buildDraft() {
    int? parseInt(String text) {
      final n = int.tryParse(text.trim());
      return (n != null && n >= 0) ? n : null;
    }

    List<String> parseGroups(String text) => text
        .split(RegExp(r'[,，、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final codecs = <String>[
      for (final f in RuleSetVocabulary.codecFamilies)
        if (_codecFamilies.contains(f.label)) ...f.values,
      ..._codecExtras,
    ];
    final minSeeders = parseInt(_minSeedersCtrl.text);
    final sizeMin = parseInt(_sizeMinCtrl.text);
    final sizeMax = parseInt(_sizeMaxCtrl.text);

    String? err;
    if (sizeMin != null &&
        sizeMax != null &&
        sizeMin > 0 &&
        sizeMax > 0 &&
        sizeMin > sizeMax) {
      err = '最小体积不能大于最大体积';
    }

    String? upgradeSource;
    String? cutoffRes;
    List<String>? upgradeLadder;
    var upgradeKeepOld = false;

    if (_upgradeSource.isNotEmpty) {
      if (_mediaSources.isNotEmpty && !_mediaSources.contains(_upgradeSource)) {
        err ??= '洗版目标片源必须在片源白名单内';
      } else {
        upgradeSource = _upgradeSource;
        if (_cutoffResolution.isNotEmpty &&
            _cutoffResolution !=
                (_resolutions.isNotEmpty ? _resolutions.first : '')) {
          if (_resolutions.isNotEmpty &&
              !_resolutions.contains(_cutoffResolution)) {
            err ??= '洗版目标分辨率必须在分辨率白名单内';
          } else {
            cutoffRes = _cutoffResolution;
          }
        }
        upgradeKeepOld = _upgradeKeepOld;
        if (_upgradeLadder.join(',') !=
            RuleSetVocabulary.defaultLadder.join(',')) {
          upgradeLadder = [..._upgradeLadder];
        }
      }
    }

    final spec = RuleSetSpec(
      resolutions: [..._resolutions],
      mediaSources: [..._mediaSources],
      videoCodecs: codecs,
      platforms: [..._platformsAllow, ..._platformExtras.allow],
      platformsBlock: [..._platformsBlock, ..._platformExtras.block],
      releaseGroupsAllow: parseGroups(_groupsAllowCtrl.text),
      releaseGroupsBlock: parseGroups(_groupsBlockCtrl.text),
      hdrLevels: [..._hdrLevels],
      hdrBlock: [..._hdrBlock],
      freeOnly: _freeOnly,
      minSeeders: (minSeeders != null && minSeeders > 0) ? minSeeders : null,
      sizeMinMb: (sizeMin != null && sizeMin > 0) ? sizeMin : null,
      sizeMaxMb: (sizeMax != null && sizeMax > 0) ? sizeMax : null,
      excludeHr: _excludeHr,
      hrUnknownPolicy: (_excludeHr && _hrStrict) ? 'strict' : null,
      subtitleLanguages: [..._subLangs],
      audioLanguages: [..._audioLangs],
      upgradeSource: upgradeSource,
      cutoffResolution: cutoffRes,
      upgradeKeepOld: upgradeKeepOld,
      upgradeLadder: upgradeLadder,
      sites: _original.sites,
      sitesBlock: _original.sitesBlock,
      unknownExtra: _original.unknownExtra,
    );
    return (spec: spec, error: err);
  }

  String get _qualitySummary {
    final parts = <String>[
      if (_codecFamilies.isNotEmpty)
        RuleSetVocabulary.codecFamilies
            .map((f) => f.label)
            .where(_codecFamilies.contains)
            .join('/'),
      if (_platformsAllow.isNotEmpty)
        _platformsAllow.map(RuleSetVocabulary.platformLabel).join('/'),
      if (_platformsBlock.isNotEmpty)
        '排除 ${_platformsBlock.map(RuleSetVocabulary.platformLabel).join('/')}',
      if (_hdrLevels.isNotEmpty) RuleSetSpecFormatter.hdrChipText(_hdrLevels),
      if (_hdrBlock.isNotEmpty) '排除 ${_hdrBlock.join('/')}',
      if (_groupsAllowCtrl.text.trim().isNotEmpty)
        '白名单 ${_groupsAllowCtrl.text.trim()}',
      if (_groupsBlockCtrl.text.trim().isNotEmpty)
        '黑名单 ${_groupsBlockCtrl.text.trim()}',
    ];
    return parts.isEmpty ? '不限' : parts.join(' · ');
  }

  String get _limitSummary {
    final min = _sizeMinCtrl.text.trim();
    final max = _sizeMaxCtrl.text.trim();
    final parts = <String>[
      if (_subLangs.isNotEmpty)
        '字幕 ${_subLangs.map(RuleSetVocabulary.subtitleLabel).join('/')}',
      if (_audioLangs.isNotEmpty)
        '音轨 ${_audioLangs.map(RuleSetVocabulary.audioLabel).join('/')}',
      if (_freeOnly) '仅免费',
      if (_excludeHr) '排除 H&R',
      if (_minSeedersCtrl.text.trim().isNotEmpty)
        '做种 ≥ ${_minSeedersCtrl.text.trim()}',
      if (min.isNotEmpty || max.isNotEmpty)
        max.isEmpty ? '≥ ${min.isEmpty ? '0' : min} MB' : '${min.isEmpty ? '0' : min}–$max MB',
    ];
    return parts.isEmpty ? '不限' : parts.join(' · ');
  }

  void _toggleList(List<String> list, String value) {
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
  }

  _TriState _triStateOf(String v, List<String> allow, List<String> block) {
    if (allow.contains(v)) return _TriState.include;
    if (block.contains(v)) return _TriState.exclude;
    return _TriState.off;
  }

  void _cycleTriState(String v, List<String> allow, List<String> block) {
    if (allow.contains(v)) {
      allow.remove(v);
      block.add(v);
    } else if (block.contains(v)) {
      block.remove(v);
    } else {
      allow.add(v);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入规则组名称');
      return;
    }
    final draft = _buildDraft();
    if (draft.error != null) {
      setState(() => _error = draft.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = widget.ruleSet != null
          ? await _api.updateRuleSet(
              widget.ruleSet!.id,
              name: name,
              spec: draft.spec.toJson(),
              matchRules: _validScope.toRules(),
            )
          : await _api.createRuleSet(
              name: name,
              spec: draft.spec.toJson(),
              matchRules: _validScope.toRules(),
            );
      widget.onSaved?.call(saved);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '保存失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _buildDraft();
    final ladderPreview = UpgradeLadderPreview.build(draft.spec);
    final draftChips = RuleSetSpecFormatter.summaryChips(
      draft.spec,
      withoutUpgrade: ladderPreview != null,
    );
    final isEdit = widget.ruleSet != null;
    final canSave = _nameCtrl.text.trim().isNotEmpty && !_busy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEdit ? '编辑规则组' : '新建规则组', style: McText.title),
                    const SizedBox(height: 2),
                    Text('按点击顺序决定偏好优先级，不选则不限', style: McText.caption.muted),
                  ],
                ),
              ),
              McActionPill(
                label: _busy ? '保存中…' : '保存',
                primary: true,
                busy: _busy,
                height: 36,
                onTap: canSave ? _submit : null,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  _NoticeBanner(text: _error!, tone: _BannerTone.error),
                  const SizedBox(height: 12),
                ],
                if (widget.ruleSet != null &&
                    widget.ruleSet!.referenceCount > 0) ...[
                  _NoticeBanner(
                    text:
                        '当前有 ${widget.ruleSet!.referenceCount} 条订阅正在使用此规则组，保存后将影响后续资源匹配。',
                    tone: _BannerTone.warn,
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. 名称
                const _FieldLabel('名称'),
                const SizedBox(height: 6),
                _RuleTextField(
                  controller: _nameCtrl,
                  hint: '例如：4K 电影洗版 / 日韩剧 1080p',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // 2. 适用范围（折叠）
                _CollapsibleCard(
                  title: '适用范围',
                  summary:
                      _validScope.summary(_routingOptions) ?? '未声明（仅手选或默认兜底）',
                  open: _openSections.contains('scope'),
                  onToggle: () => setState(() {
                    if (!_openSections.remove('scope')) {
                      _openSections.add('scope');
                    }
                  }),
                  child: _buildScopeSection(),
                ),
                const SizedBox(height: 14),

                // 3. 分辨率（有序偏好）
                _SectionCard(
                  title: '分辨率',
                  hint: '按点击顺序决定优先级，留空表示不限分辨率',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opt in RuleSetVocabulary.resolutions)
                        _OrderedChip(
                          label: opt,
                          active: _resolutions.contains(opt),
                          order: _resolutions.length > 1 &&
                                  _resolutions.contains(opt)
                              ? _resolutions.indexOf(opt) + 1
                              : null,
                          onTap: () => setState(
                            () => _toggleList(_resolutions, opt),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. 片源（有序偏好）
                _SectionCard(
                  title: '片源',
                  hint: '按点击顺序决定优先级；收窄白名单时会自动清除不在范围内的洗版目标',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opt in RuleSetVocabulary.mediaSources)
                        _OrderedChip(
                          label: opt.label,
                          active: _mediaSources.contains(opt.value),
                          order: _mediaSources.length > 1 &&
                                  _mediaSources.contains(opt.value)
                              ? _mediaSources.indexOf(opt.value) + 1
                              : null,
                          onTap: () => setState(() {
                            _toggleList(_mediaSources, opt.value);
                            if (_upgradeSource.isNotEmpty &&
                                _mediaSources.isNotEmpty &&
                                !_mediaSources.contains(_upgradeSource)) {
                              _upgradeSource = '';
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. 画质与来源（折叠）
                _CollapsibleCard(
                  title: '画质与来源',
                  summary: _qualitySummary,
                  open: _openSections.contains('quality'),
                  onToggle: () => setState(() {
                    if (!_openSections.remove('quality')) {
                      _openSections.add('quality');
                    }
                  }),
                  child: _buildQualitySection(),
                ),
                const SizedBox(height: 14),

                // 6. 下载与限制（折叠）
                _CollapsibleCard(
                  title: '下载与限制',
                  summary: _limitSummary,
                  open: _openSections.contains('limits'),
                  onToggle: () => setState(() {
                    if (!_openSections.remove('limits')) {
                      _openSections.add('limits');
                    }
                  }),
                  child: _buildLimitsSection(),
                ),
                const SizedBox(height: 14),

                // 7. 洗版设置
                _buildUpgradeSection(),
                const SizedBox(height: 14),

                // 8. 底部实时回执与洗版阶梯预览
                _SectionCard(
                  title: ladderPreview != null ? '首轮筛选条件' : '当前筛选摘要',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draftChips.isEmpty
                            ? '未限制任何条件（会接受任意合格资源）'
                            : draftChips.join(' · '),
                        style: McText.sub.copyWith(
                          color: McTokens.text.withValues(alpha: 0.88),
                        ),
                      ),
                      if (ladderPreview != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: McTokens.line),
                        const SizedBox(height: 10),
                        _buildLadderPreview(ladderPreview),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeSection() {
    final opts = _routingOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '新订阅未手动选组时，按以下条件自动匹配本规则组（条件间为「且」）。',
          style: McText.caption.muted,
        ),
        const SizedBox(height: 10),
        const _FieldLabel('类型'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OrderedChip(
              label: '不限',
              active: _scopeKind == null,
              onTap: () => setState(() => _scopeKind = null),
            ),
            _OrderedChip(
              label: '电影',
              active: _scopeKind == 'movie',
              onTap: () => setState(() => _scopeKind = 'movie'),
            ),
            _OrderedChip(
              label: '剧集',
              active: _scopeKind == 'tv',
              onTap: () => setState(() => _scopeKind = 'tv'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (opts == null)
          Text('正在加载地区与类型选项…', style: McText.caption.faint)
        else ...[
          const _FieldLabel('国家 / 地区'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _OrderedChip(
                label: opts.countryNames.keys.every(_scopeRegions.contains)
                    ? '清空'
                    : '全选',
                active: false,
                onTap: () => setState(() {
                  final all = opts.countryNames.keys.toList();
                  if (all.every(_scopeRegions.contains)) {
                    _scopeRegions.clear();
                  } else {
                    _scopeRegions = {..._scopeRegions, ...all}.toList()..sort();
                  }
                }),
              ),
              for (final preset in opts.regionPresets)
                _OrderedChip(
                  label: preset.label,
                  active: preset.countries.isNotEmpty &&
                      preset.countries.every(_scopeRegions.contains),
                  onTap: () => setState(() {
                    final active = preset.countries.every(_scopeRegions.contains);
                    if (active) {
                      _scopeRegions.removeWhere(preset.countries.contains);
                    } else {
                      for (final c in preset.countries) {
                        if (!_scopeRegions.contains(c)) _scopeRegions.add(c);
                      }
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in opts.sortedCountries)
                _OrderedChip(
                  label: c.name,
                  active: _scopeRegions.contains(c.code),
                  onTap: () => setState(() => _toggleList(_scopeRegions, c.code)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('题材类型'),
          const SizedBox(height: 6),
          Builder(
            builder: (_) {
              final genres = opts.genresFor(_scopeKind);
              final allOn = genres.isNotEmpty &&
                  genres.every((g) => _scopeGenres.contains(g.id));
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OrderedChip(
                    label: allOn ? '清空' : '全选',
                    active: false,
                    onTap: () => setState(() {
                      if (allOn) {
                        _scopeGenres.clear();
                      } else {
                        _scopeGenres = {
                          ..._scopeGenres,
                          ...genres.map((g) => g.id),
                        }.toList();
                      }
                    }),
                  ),
                  for (final g in genres)
                    _OrderedChip(
                      label: g.label,
                      active: _scopeGenres.contains(g.id),
                      onTap: () => setState(() {
                        if (_scopeGenres.contains(g.id)) {
                          _scopeGenres.remove(g.id);
                        } else {
                          _scopeGenres.add(g.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildQualitySection() {
    final extras = [..._platformExtras.allow, ..._platformExtras.block];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('视频编码'),
        const SizedBox(height: 4),
        Text('按编码家族匹配（如 H.265 同时包含 x265 / HEVC）', style: McText.caption.faint),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in RuleSetVocabulary.codecFamilies)
              _OrderedChip(
                label: f.label,
                active: _codecFamilies.contains(f.label),
                onTap: () => setState(() {
                  if (!_codecFamilies.remove(f.label)) {
                    _codecFamilies.add(f.label);
                  }
                }),
              ),
          ],
        ),
        if (_codecExtras.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('保留已有自定义编码：${_codecExtras.join('、')}', style: McText.micro.faint),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('流媒体平台（点击循环：不限 → 只要 → 排除）'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in RuleSetVocabulary.platformOptions)
              _TriStateChip(
                label: RuleSetVocabulary.platformLabel(id),
                state: _triStateOf(id, _platformsAllow, _platformsBlock),
                onTap: () => setState(
                  () => _cycleTriState(id, _platformsAllow, _platformsBlock),
                ),
              ),
          ],
        ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '保留已有自定义平台：${extras.map(RuleSetVocabulary.platformLabel).join('、')}',
            style: McText.micro.faint,
          ),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('HDR / 杜比视界（点击循环：不限 → 只要 → 排除）'),
        const SizedBox(height: 4),
        Text('DV P5 仅支持排除（避免无 HDR10 兼容层导致偏色）', style: McText.caption.faint),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in RuleSetVocabulary.hdrOptions)
              _TriStateChip(
                label: v,
                state: _triStateOf(v, _hdrLevels, _hdrBlock),
                onTap: () => setState(() => _cycleTriState(v, _hdrLevels, _hdrBlock)),
              ),
            for (final v in RuleSetVocabulary.hdrBlockOnly)
              _TriStateChip(
                label: v,
                state: _hdrBlock.contains(v) ? _TriState.exclude : _TriState.off,
                onTap: () => setState(() => _toggleList(_hdrBlock, v)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const _FieldLabel('制作组白名单'),
        const SizedBox(height: 6),
        _RuleTextField(
          controller: _groupsAllowCtrl,
          hint: '逗号分隔，留空不限（如 FRDS, Wiki）',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('制作组黑名单'),
        const SizedBox(height: 6),
        _RuleTextField(
          controller: _groupsBlockCtrl,
          hint: '逗号分隔，留空不启用',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildLimitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('字幕语言要求'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in RuleSetVocabulary.subtitleLanguages)
              _OrderedChip(
                label: s.label,
                active: _subLangs.contains(s.value),
                onTap: () => setState(() => _toggleList(_subLangs, s.value)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _FieldLabel('音轨语言要求'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in RuleSetVocabulary.audioLanguages)
              _OrderedChip(
                label: a.label,
                active: _audioLangs.contains(a.value),
                onTap: () => setState(() => _toggleList(_audioLangs, a.value)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _SwitchRow(
          title: '仅免费种',
          subtitle: '只选标记为 Free / 2xFree 的资源',
          value: _freeOnly,
          onChanged: (v) => setState(() => _freeOnly = v),
        ),
        const Divider(height: 1, color: McTokens.line),
        _SwitchRow(
          title: '排除 H&R',
          subtitle: '自动跳过需要考核做种时长的种子',
          value: _excludeHr,
          onChanged: (v) => setState(() => _excludeHr = v),
        ),
        if (_excludeHr) ...[
          const Divider(height: 1, color: McTokens.line),
          _SwitchRow(
            title: '未知 H&R 状态也排除（严格模式）',
            subtitle: '站点未声明 H&R 标记时默认按 H&R 处理',
            value: _hrStrict,
            onChanged: (v) => setState(() => _hrStrict = v),
          ),
        ],
        const SizedBox(height: 12),
        _NumberRow(
          label: '最少做种数',
          controller: _minSeedersCtrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _NumberRow(
          label: '单集最小体积 (MB)',
          controller: _sizeMinCtrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _NumberRow(
          label: '单集最大体积 (MB)',
          controller: _sizeMaxCtrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text('整季合集包会按集数均摊计算单集体积。', style: McText.caption.faint),
      ],
    );
  }

  Widget _buildUpgradeSection() {
    final allowedUpgrade = RuleSetVocabulary.upgradeOptions
        .where(
          (o) => _mediaSources.isEmpty || _mediaSources.contains(o.value),
        )
        .toList();
    final resChoices = _resolutions.isEmpty
        ? RuleSetVocabulary.resolutions
        : _resolutions;
    final effectiveCutoff = _cutoffResolution.isEmpty
        ? (_resolutions.isNotEmpty ? _resolutions.first : '1080p')
        : _cutoffResolution;
    final effectiveLadder =
        _upgradeLadder.where((d) => !_ladderUnconfigured(d)).toList();
    final platIndex = effectiveLadder.indexOf('platform');
    final showPlatformWarn =
        platIndex >= 0 && platIndex < effectiveLadder.length - 1;

    return _SectionCard(
      title: '自动洗版',
      hint: '先抓可用版本，待出现更高档位资源时自动升级替换，达到目标档位后停止',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OrderedChip(
                label: '不洗版',
                active: _upgradeSource.isEmpty,
                onTap: () => setState(() => _upgradeSource = ''),
              ),
              for (final opt in allowedUpgrade)
                _OrderedChip(
                  label: '洗到 ${opt.label}',
                  active: _upgradeSource == opt.value,
                  onTap: () => setState(() => _upgradeSource = opt.value),
                ),
            ],
          ),
          if (_upgradeSource.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _FieldLabel('目标分辨率'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in resChoices)
                  _OrderedChip(
                    label: r,
                    active: effectiveCutoff == r,
                    onTap: () => setState(() {
                      _cutoffResolution =
                          r == (_resolutions.isNotEmpty ? _resolutions.first : '')
                              ? ''
                              : r;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _SwitchRow(
              title: '洗版后保留旧版本',
              subtitle: '关闭时旧版文件会移入媒体库回收站',
              value: _upgradeKeepOld,
              onChanged: (v) => setState(() => _upgradeKeepOld = v),
            ),
            const Divider(height: 1, color: McTokens.line),
            InkWell(
              onTap: () => setState(() => _ladderOpen = !_ladderOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text('洗版比较优先级', style: McText.sub.copyWith(color: McTokens.text)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        effectiveLadder
                            .map(RuleSetVocabulary.ladderLabel)
                            .join(' › '),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.muted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _ladderOpen ? McIcons.arrowDownS : McIcons.chevronRight,
                      size: 14,
                      color: McTokens.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (_ladderOpen) ...[
              Text('按点击顺序决定高维到低维的比较优先级：', style: McText.caption.faint),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final dim in RuleSetVocabulary.ladderOptions)
                    Builder(
                      builder: (_) {
                        final idx = _upgradeLadder.indexOf(dim.value);
                        final unconf = idx >= 0 && _ladderUnconfigured(dim.value);
                        return _OrderedChip(
                          label: unconf ? '${dim.label}（未配置）' : dim.label,
                          active: idx >= 0,
                          order: idx >= 0 && _upgradeLadder.length > 1
                              ? idx + 1
                              : null,
                          onTap: () => setState(() {
                            if (idx >= 0) {
                              if (_upgradeLadder.length > 1) {
                                _upgradeLadder.removeAt(idx);
                              }
                            } else {
                              _upgradeLadder.add(dim.value);
                            }
                          }),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (showPlatformWarn) ...[
              const SizedBox(height: 6),
              const _NoticeBanner(
                text: '「平台」排在其他维度之前会导致仅高优先级平台的低画质版本压过更高画质版本，建议把平台放在末尾。',
                tone: _BannerTone.warn,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLadderPreview(UpgradeLadderPreview preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _ladderPreviewOpen = !_ladderPreviewOpen),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '洗版终点：',
                    style: McText.sub.muted,
                    children: [
                      TextSpan(
                        text: preview.target,
                        style: McText.sub.semibold.copyWith(color: McTokens.text),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _ladderPreviewOpen ? '收起' : '查看阶梯',
                style: McText.caption.faint,
              ),
              const SizedBox(width: 4),
              Icon(
                _ladderPreviewOpen ? McIcons.arrowDownS : McIcons.chevronRight,
                size: 14,
                color: McTokens.textFaint,
              ),
            ],
          ),
        ),
        if (_ladderPreviewOpen) ...[
          const SizedBox(height: 8),
          Text(
            '比较顺序：${preview.dimensions.join(' › ')}',
            style: McText.micro.faint,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x222DD4BF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x662DD4BF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x3D2DD4BF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '终点',
                        style: McText.micro.copyWith(
                          color: const Color(0xFF5EEAD4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preview.target,
                        style: McText.sub.semibold.copyWith(color: McTokens.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${preview.ceiling != null ? '达到此档位或更高（最高 ${preview.ceiling}）即停止洗版。' : '达到此档位即停止洗版。'}'
                  '${_upgradeKeepOld ? '洗版后保留旧版。' : '旧版文件移入回收站。'}',
                  style: McText.micro.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (preview.below.isEmpty)
            Text('当前目标已是白名单内的最低档，不会触发二次洗版。', style: McText.caption.faint)
          else ...[
            Text('以下过渡档会先抓，后续出现更高档时自动升级：', style: McText.micro.faint),
            const SizedBox(height: 4),
            for (final rung in preview.below)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('↑  ', style: McText.caption.faint),
                    Expanded(child: Text(rung, style: McText.caption.muted)),
                  ],
                ),
              ),
            if (preview.moreBelow > 0)
              Text('↑  还有 ${preview.moreBelow} 个更低过渡档', style: McText.micro.faint),
          ],
        ],
      ],
    );
  }
}

// ── 规则编辑器私有小组件 ──

enum _BannerTone { warn, error }

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text, required this.tone});

  final String text;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == _BannerTone.error ? McTokens.danger : McTokens.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(text, style: McText.caption.copyWith(color: color)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: McText.caption.semibold.copyWith(color: McTokens.textMuted),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.hint,
    required this.child,
  });

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: McText.ui.semibold),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(hint!, style: McText.caption.faint),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.title,
    required this.summary,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final String summary;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(title, style: McText.ui.semibold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: McText.caption.muted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    open ? McIcons.arrowDownS : McIcons.chevronRight,
                    size: 14,
                    color: McTokens.textFaint,
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: McTokens.line),
            Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderedChip extends StatelessWidget {
  const _OrderedChip({
    required this.label,
    required this.active,
    this.order,
    required this.onTap,
  });

  final String label;
  final bool active;
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? McTokens.accentStrong : McTokens.glassFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.transparent : McTokens.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order != null) ...[
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: McTokens.onAccent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$order',
                  style: McText.micro.copyWith(
                    fontSize: 10,
                    color: McTokens.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: McText.caption.semibold.copyWith(
                color: active ? McTokens.onAccent : McTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriStateChip extends StatelessWidget {
  const _TriStateChip({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _TriState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _TriState.include => McTokens.ok.withValues(alpha: 0.2),
      _TriState.exclude => McTokens.danger.withValues(alpha: 0.2),
      _TriState.off => McTokens.glassFill,
    };
    final border = switch (state) {
      _TriState.include => McTokens.ok.withValues(alpha: 0.5),
      _TriState.exclude => McTokens.danger.withValues(alpha: 0.5),
      _TriState.off => McTokens.line,
    };
    final fg = switch (state) {
      _TriState.include => McTokens.ok,
      _TriState.exclude => McTokens.danger,
      _TriState.off => McTokens.textMuted,
    };
    final prefix = switch (state) {
      _TriState.include => '+ ',
      _TriState.exclude => '− ',
      _TriState.off => '',
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          '$prefix$label',
          style: McText.caption.semibold.copyWith(color: fg),
        ),
      ),
    );
  }
}

class _RuleTextField extends StatelessWidget {
  const _RuleTextField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: McText.sub.copyWith(color: McTokens.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: McText.sub.faint,
        isDense: true,
        filled: true,
        fillColor: McTokens.glassFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: McTokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: McTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: McTokens.lineStrong),
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: McText.sub.copyWith(color: McTokens.text)),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: McText.sub.copyWith(color: McTokens.text).tabular,
            decoration: InputDecoration(
              hintText: '不限',
              hintStyle: McText.sub.faint,
              isDense: true,
              filled: true,
              fillColor: McTokens.glassFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: McTokens.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: McTokens.line),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: McText.sub.copyWith(color: McTokens.text)),
                if (subtitle != null)
                  Text(subtitle!, style: McText.micro.faint),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
