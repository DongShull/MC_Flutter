import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MovieClaw 应用语言选项（支持跟随系统 + 4 种内置语言）。
enum McAppLanguage {
  system,
  zhHans,
  zhHant,
  en,
  de;

  /// 持久化与接口标识。
  String get code => switch (this) {
        McAppLanguage.system => 'system',
        McAppLanguage.zhHans => 'zh-Hans',
        McAppLanguage.zhHant => 'zh-Hant',
        McAppLanguage.en => 'en',
        McAppLanguage.de => 'de',
      };

  /// 传给 `MaterialApp.locale`；`system` 返回 `null` 以交由系统解析。
  Locale? get locale => switch (this) {
        McAppLanguage.system => null,
        McAppLanguage.zhHans =>
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        McAppLanguage.zhHant =>
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        McAppLanguage.en => const Locale('en'),
        McAppLanguage.de => const Locale('de'),
      };

  /// 语言自称（autonym）；`system` 按当前生效语言返回本地化名称。
  String get nativeName => switch (this) {
        McAppLanguage.system => McL10n.current.settingsLanguageSystem,
        McAppLanguage.zhHans => '简体中文',
        McAppLanguage.zhHant => '繁體中文',
        McAppLanguage.en => 'English',
        McAppLanguage.de => 'Deutsch',
      };

  /// 发给后端 HTTP 请求的 `Accept-Language` 头。
  String get acceptLanguageHeader {
    final resolved = this == McAppLanguage.system
        ? McAppLanguage.fromLocale(McL10n.current.locale)
        : this;
    return switch (resolved) {
      McAppLanguage.zhHans => 'zh-CN,zh-Hans;q=0.9,zh;q=0.8',
      McAppLanguage.zhHant => 'zh-TW,zh-Hant;q=0.9,zh;q=0.8',
      McAppLanguage.de => 'de-DE,de;q=0.9,en;q=0.5',
      McAppLanguage.en || McAppLanguage.system => 'en-US,en;q=0.9',
    };
  }

  static McAppLanguage fromCode(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty || v == 'system') return McAppLanguage.system;
    if (v == 'zh-hant' ||
        v == 'zh_hant' ||
        v == 'zh-tw' ||
        v == 'zh-hk' ||
        v == 'zh-mo') {
      return McAppLanguage.zhHant;
    }
    if (v.startsWith('zh')) return McAppLanguage.zhHans;
    if (v == 'de' || v.startsWith('de-') || v.startsWith('de_')) {
      return McAppLanguage.de;
    }
    if (v == 'en' || v.startsWith('en-') || v.startsWith('en_')) {
      return McAppLanguage.en;
    }
    return McAppLanguage.system;
  }

  static McAppLanguage fromLocale(Locale? locale) {
    if (locale == null) return McAppLanguage.zhHans;
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'zh') {
      final script = (locale.scriptCode ?? '').toLowerCase();
      final country = (locale.countryCode ?? '').toUpperCase();
      if (script == 'hant' ||
          country == 'TW' ||
          country == 'HK' ||
          country == 'MO') {
        return McAppLanguage.zhHant;
      }
      return McAppLanguage.zhHans;
    }
    if (lang == 'de') return McAppLanguage.de;
    return McAppLanguage.en;
  }
}

/// 语言偏好控制器（持久化于 SharedPreferences `mc_app_language`）。
class McLanguageController extends Notifier<McAppLanguage> {
  static const prefsKey = 'mc_app_language';
  bool _loaded = false;

  @override
  McAppLanguage build() {
    if (!_loaded) {
      _loaded = true;
      unawaited(_restore());
    }
    return McAppLanguage.system;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey);
      final parsed = McAppLanguage.fromCode(saved);
      if (parsed != state) {
        state = parsed;
      }
      if (parsed.locale != null) {
        McL10n.updateCurrent(parsed.locale!);
      }
    } catch (_) {
      // 测试环境或存储暂不可用时保持跟随系统。
    }
  }

  Future<void> setLanguage(McAppLanguage language) async {
    state = language;
    if (language.locale != null) {
      McL10n.updateCurrent(language.locale!);
    } else {
      final platformLocale = ui.PlatformDispatcher.instance.locale;
      McL10n.updateCurrent(platformLocale);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, language.code);
    } catch (_) {}
  }
}

final mcLanguageProvider =
    NotifierProvider<McLanguageController, McAppLanguage>(
  McLanguageController.new,
);

/// MovieClaw 4 语言本地化词典（`zh-Hans` / `zh-Hant` / `en` / `de`）。
class McL10n {
  McL10n._(this.locale, this._langKey);

  final Locale locale;
  final String _langKey;

  static const supportedLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('en'),
    Locale('de'),
  ];

  static const LocalizationsDelegate<McL10n> delegate = _McL10nDelegate();

  static McL10n _current = McL10n.forLocale(
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  );

  /// 脱离 `BuildContext` 使用的当前生效语言快照。
  static McL10n get current => _current;

  /// 更新全局快照（由 delegate 与语言切换器调用）。
  static void updateCurrent(Locale locale) {
    _current = McL10n.forLocale(locale);
  }

  static McL10n forLocale(Locale locale) {
    final lang = McAppLanguage.fromLocale(locale);
    return McL10n._(lang.locale ?? locale, lang.code);
  }

  static McL10n of(BuildContext context) {
    return Localizations.of<McL10n>(context, McL10n) ?? _current;
  }

  bool get isChinese => _langKey == 'zh-Hans' || _langKey == 'zh-Hant';
  String get languageCode => _langKey;

  /// 通用键查询（未命中时回落英文再回落键名）。
  String t(String key) {
    final table = _strings[_langKey] ?? _strings['en']!;
    return table[key] ?? _strings['en']![key] ?? key;
  }

  // ── 导航标签 ──
  String get tabLibrary => t('tab.library');
  String get tabSubscriptions => t('tab.subscriptions');
  String get tabDiscover => t('tab.discover');
  String get tabActivity => t('tab.activity');
  String get tabMore => t('tab.more');

  // ── 通用动作与状态 ──
  String get appName => 'MovieClaw';
  String get ok => t('common.ok');
  String get confirm => t('common.confirm');
  String get cancel => t('common.cancel');
  String get close => t('common.close');
  String get save => t('common.save');
  String get delete => t('common.delete');
  String get edit => t('common.edit');
  String get retry => t('common.retry');
  String get refresh => t('common.refresh');
  String get search => t('common.search');
  String get loading => t('common.loading');
  String get empty => t('common.empty');
  String get done => t('common.done');
  String get back => t('common.back');
  String get more => t('common.more');
  String get viewAll => t('common.view_all');
  String get copy => t('common.copy');
  String get copied => t('common.copied');
  String get share => t('common.share');
  String get openInBrowser => t('common.open_in_browser');
  String get play => t('common.play');
  String get pause => t('common.pause');
  String get resume => t('common.resume');
  String get continuePlay => t('common.continue_play');
  String get networkError => t('common.network_error');
  String get unknownError => t('common.unknown_error');
  String get enabled => t('common.enabled');
  String get disabled => t('common.disabled');

  // ── 设置 ──
  String get settingsTitle => t('settings.title');
  String get settingsHubTitle => t('settings.hub_title');
  String get settingsLanguage => t('settings.language');
  String get settingsLanguagePageTitle => t('settings.language_page_title');
  String get settingsLanguageHeader => t('settings.language_header');
  String get settingsLanguageFooter => t('settings.language_footer');
  String get settingsLanguageSystem => t('settings.language_system');
  String get settingsLanguageSystemSubtitle =>
      t('settings.language_system_subtitle');
  String get settingsProfile => t('settings.profile');
  String get settingsDevices => t('settings.devices');
  String get settingsMyDevices => t('settings.entry_devices');
  String get settingsNotifications => t('settings.notifications');
  String get settingsNotificationPrefs => t('settings.entry_notifications');
  String get settingsPlayback => t('settings.playback');
  String get settingsPlaybackTitle => t('settings.entry_playback');
  String get settingsStorage => t('settings.storage');
  String get settingsAbout => t('settings.about');
  String get settingsServer => t('settings.server');
  String get settingsSystem => t('settings.system');
  String get settingsAccount => t('settings.account');
  String get settingsDownloads => t('settings.downloads');
  String get settingsIntegrations => t('settings.integrations');
  String get settingsAppearance => t('settings.appearance');
  String get settingsMaintenance => t('settings.maintenance');
  String get settingsCheckUpdate => t('settings.check_update');
  String get settingsLogout => t('settings.logout');
  String get settingsSwitchAccount => t('settings.switch_account');
  String get settingsApproveLogin => t('settings.approve_login');
  String get settingsGroupPersonal => t('settings.group_personal');
  String get settingsGroupPlayback => t('settings.group_playback');
  String get settingsGroupAutomation => t('settings.group_automation');
  String get settingsGroupFamilyNotify => t('settings.group_family_notify');
  String get settingsGroupAiCloud => t('settings.group_ai_cloud');
  String get settingsGroupOps => t('settings.group_ops');
  String get settingsGroupGeneral => t('settings.group_general');
  String get settingsEntryLibraryManage => t('settings.entry_library_manage');
  String get settingsEntryScrape => t('settings.entry_scrape');
  String get settingsEntryOverview => t('settings.entry_overview');
  String get settingsEntryRules => t('settings.entry_rules');
  String get settingsEntrySites => t('settings.entry_sites');
  String get settingsEntryDownloaders => t('settings.entry_downloaders');
  String get settingsEntryMembers => t('settings.entry_members');
  String get settingsEntryPush => t('settings.entry_push');
  String get settingsEntryWebhook => t('settings.entry_webhook');
  String get settingsEntryAi => t('settings.entry_ai');
  String get settingsEntryMcp => t('settings.entry_mcp');
  String get settingsEntryCloud => t('settings.entry_cloud');
  String get settingsEntrySystem => t('settings.entry_system');
  String get settingsEntryMaintenance => t('settings.entry_maintenance');
  String get settingsEntryCheckUpdate => t('settings.entry_check_update');
  String get settingsSelectSectionHint => t('settings.select_section_hint');
  String get sidebarSearchPlaceholder => t('shell.search_commands');
  String get sidebarCollapseTooltip => t('shell.collapse_sidebar');
  String get sidebarExpandTooltip => t('shell.expand_sidebar');
  String get send => t('common.send');
  String get moreSectionConversations => t('more.section_conversations');
  String get moreSectionDownloads => t('more.section_downloads');
  String get moreSectionServer => t('more.section_server');

  // ── 播放器 ──
  String get playerSkipIntro => t('player.skip_intro');
  String get playerSkipOutro => t('player.skip_outro');
  String get playerSpeed => t('player.speed');
  String get playerAudioTrack => t('player.audio_track');
  String get playerSubtitles => t('player.subtitles');
  String get playerSubtitlesOff => t('player.subtitles_off');
  String get playerQuality => t('player.quality');
  String get playerOriginalQuality => t('player.original_quality');
  String get playerDisplayMode => t('player.display_mode');
  String get playerAspectFit => t('player.aspect_fit');
  String get playerAspectFill => t('player.aspect_fill');
  String get playerAspectStretch => t('player.aspect_stretch');
  String get playerEpisodes => t('player.episodes');
  String get playerNextEpisode => t('player.next_episode');
  String get playerPreviousEpisode => t('player.previous_episode');
  String get playerLockScreen => t('player.lock_screen');
  String get playerUnlockScreen => t('player.unlock_screen');
  String get playerAirPlay => t('player.airplay');
  String get playerCast => t('player.cast');
  String get playerBrightness => t('player.brightness');
  String get playerVolume => t('player.volume');
  String get playerTranscodeConfirm => t('player.transcode_confirm');
  String get playerFailed => t('player.failed');

  // ── 媒体库 ──
  String get libraryHome => t('library.home');
  String get libraryContinueWatching => t('library.continue_watching');
  String get libraryRecentlyAdded => t('library.recently_added');
  String get libraryFavorites => t('library.favorites');
  String get libraryCollections => t('library.collections');
  String get libraryMovies => t('library.movies');
  String get libraryTvShows => t('library.tv_shows');
  String get libraryVideos => t('library.videos');
  String get libraryCustomize => t('library.customize');
  String get libraryManage => t('library.manage');
  String get libraryReels => t('library.reels');
  String get libraryFilter => t('library.filter');
  String get librarySort => t('library.sort');
  String get libraryWatched => t('library.watched');
  String get libraryUnwatched => t('library.unwatched');

  // ── 离线下载 ──
  String get offlineTitle => t('offline.title');
  String get offlineDownloading => t('offline.downloading');
  String get offlineCompleted => t('offline.completed');
  String get offlinePaused => t('offline.paused');
  String get offlineFailed => t('offline.failed');
  String get offlineQueued => t('offline.queued');
  String get offlinePreparing => t('offline.preparing');
  String get offlineStorageUsed => t('offline.storage_used');
  String get offlineStorageAvailable => t('offline.storage_available');
  String get offlineAllowCellular => t('offline.allow_cellular');
  String get offlineDeleteConfirm => t('offline.delete_confirm');
  String get offlineNoDownloads => t('offline.no_downloads');
  String get offlinePrioritize => t('offline.prioritize');
  String get offlineDownload => t('offline.download');

  // ── 通知、活动与 AI 会话 ──
  String get noticesTitle => t('notices.title');
  String get noticesEmpty => t('notices.empty');
  String get noticesMarkAllRead => t('notices.mark_all_read');
  String get noticesUnread => t('notices.unread');
  String get activityTitle => t('activity.title');
  String get activityActive => t('activity.active');
  String get activityHistory => t('activity.history');
  String get activityRecentPlays => t('activity.recent_plays');
  String get activityStats => t('activity.stats');
  String get activitySeeding => t('activity.seeding');
  String get agentHandoffAnalyze => t('agent.handoff_analyze');
  String get agentHandoffPreparing => t('agent.handoff_preparing');
  String get agentHandoffFailed => t('agent.handoff_failed');
  String get agentTitle => t('agent.title');
  String get agentNewSession => t('agent.new_session');
  String get agentInputHint => t('agent.input_hint');

  // ── 推送状态与快捷动作 ──
  String get pushStatusAllowed => t('push.status_allowed');
  String get pushStatusProvisional => t('push.status_provisional');
  String get pushStatusEphemeral => t('push.status_ephemeral');
  String get pushStatusDenied => t('push.status_denied');
  String get pushStatusNotDetermined => t('push.status_not_determined');
  String get pushActionsViewAllEpisodes => t('push.actions_view_all_episodes');
  String get pushActionsMuteShow => t('push.actions_mute_show');
  String get pushTestSend => t('push.test_send');

  // ── 关于 ──
  String get aboutTitle => t('about.title');
  String get aboutVersion => t('about.version');
  String get aboutLicenses => t('about.licenses');
  String get aboutPrivacy => t('about.privacy');
  String get aboutServerVersion => t('about.server_version');
  String get aboutWebsite => t('about.website');
  String get aboutFeedback => t('about.feedback');

  // ── 带参格式化文案 ──
  String seasonLabel(int season) => switch (_langKey) {
        'zh-Hans' => '第 $season 季',
        'zh-Hant' => '第 $season 季',
        'de' => 'Staffel $season',
        _ => 'Season $season',
      };

  String episodeLabel(int season, int episode) {
    final s = season.toString().padLeft(2, '0');
    final e = episode.toString().padLeft(2, '0');
    return 'S${s}E$e';
  }

  String episodeNumberLabel(int episode) => switch (_langKey) {
        'zh-Hans' => '第 $episode 集',
        'zh-Hant' => '第 $episode 集',
        'de' => 'Folge $episode',
        _ => 'Episode $episode',
      };

  String episodeCount(int count) => switch (_langKey) {
        'zh-Hans' => '$count 集',
        'zh-Hant' => '$count 集',
        'de' => count == 1 ? '1 Folge' : '$count Folgen',
        _ => count == 1 ? '1 episode' : '$count episodes',
      };

  String itemCount(int count) => switch (_langKey) {
        'zh-Hans' => '$count 项',
        'zh-Hant' => '$count 項',
        'de' => count == 1 ? '1 Eintrag' : '$count Einträge',
        _ => count == 1 ? '1 item' : '$count items',
      };

  String newEpisodesCount(int count) => switch (_langKey) {
        'zh-Hans' => '新 $count 集',
        'zh-Hant' => '新 $count 集',
        'de' => '$count neu',
        _ => '$count new',
      };

  String minutesShort(int minutes) => switch (_langKey) {
        'zh-Hans' => '$minutes 分钟',
        'zh-Hant' => '$minutes 分鐘',
        'de' => '$minutes Min.',
        _ => '${minutes}m',
      };

  String hoursShort(int hours) => switch (_langKey) {
        'zh-Hans' => '$hours 小时',
        'zh-Hant' => '$hours 小時',
        'de' => '$hours Std.',
        _ => '${hours}h',
      };

  String hoursMinutes(int hours, int minutes) => switch (_langKey) {
        'zh-Hans' => '$hours 小时 $minutes 分钟',
        'zh-Hant' => '$hours 小時 $minutes 分鐘',
        'de' => '$hours Std. $minutes Min.',
        _ => '${hours}h ${minutes}m',
      };

  String languageSwitched(String languageName) => switch (_langKey) {
        'zh-Hans' => '语言已切换为 $languageName',
        'zh-Hant' => '語言已切換為 $languageName',
        'de' => 'Sprache geändert zu $languageName',
        _ => 'Language switched to $languageName',
      };
}

class _McL10nDelegate extends LocalizationsDelegate<McL10n> {
  const _McL10nDelegate();

  @override
  bool isSupported(Locale locale) {
    return const {'zh', 'en', 'de'}.contains(locale.languageCode.toLowerCase());
  }

  @override
  Future<McL10n> load(Locale locale) async {
    final instance = McL10n.forLocale(locale);
    McL10n.updateCurrent(instance.locale);
    return instance;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<McL10n> old) => false;
}

/// 区域感知格式化工具（对齐 iOS `Shared/Localization/Formatting.swift`）。
abstract final class McFormatting {
  static String _langKey(Locale? locale) =>
      McAppLanguage.fromLocale(locale ?? McL10n.current.locale).code;

  static String _intlLocale(Locale? locale) => switch (_langKey(locale)) {
        'zh-Hans' => 'zh_CN',
        'zh-Hant' => 'zh_TW',
        'de' => 'de_DE',
        _ => 'en_US',
      };

  static bool _isChinese(Locale? locale) {
    final k = _langKey(locale);
    return k == 'zh-Hans' || k == 'zh-Hant';
  }

  /// 本地化整数（带千分位）。
  static String number(int value, {Locale? locale}) {
    try {
      return NumberFormat.decimalPattern(_intlLocale(locale)).format(value);
    } catch (_) {
      return NumberFormat.decimalPattern('en_US').format(value);
    }
  }

  /// 本地化日期时间（YYYY-MM-DD HH:mm / DE DD.MM.YYYY HH:mm）。
  static String dateTime(DateTime date, {Locale? locale}) {
    final local = date.toLocal();
    final k = _langKey(locale);
    final pattern = switch (k) {
      'zh-Hans' || 'zh-Hant' => 'yyyy/MM/dd HH:mm',
      'de' => 'dd.MM.yyyy HH:mm',
      _ => 'yyyy-MM-dd HH:mm',
    };
    return DateFormat(pattern).format(local);
  }

  /// 相对时间（对齐 iOS `RelativeDateTimeFormatter`，支持过去与未来）。
  static String relative(
    DateTime date, {
    DateTime? now,
    Locale? locale,
  }) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(date);
    final future = diff.isNegative;
    final abs = diff.abs();
    final k = _langKey(locale);

    if (abs.inSeconds < 45) {
      return switch (k) {
        'zh-Hans' => future ? '即将' : '刚刚',
        'zh-Hant' => future ? '即將' : '剛剛',
        'de' => future ? 'gleich' : 'gerade eben',
        _ => future ? 'in a moment' : 'just now',
      };
    }

    int value;
    String unitKey;
    if (abs.inMinutes < 60) {
      value = abs.inMinutes;
      unitKey = 'min';
    } else if (abs.inHours < 24) {
      value = abs.inHours;
      unitKey = 'hour';
    } else if (abs.inDays < 30) {
      value = abs.inDays;
      unitKey = 'day';
    } else if (abs.inDays < 365) {
      value = (abs.inDays / 30).floor();
      unitKey = 'month';
    } else {
      value = (abs.inDays / 365).floor();
      unitKey = 'year';
    }

    return switch (k) {
      'zh-Hans' => () {
          final unit = switch (unitKey) {
            'min' => '分钟',
            'hour' => '小时',
            'day' => '天',
            'month' => '个月',
            _ => '年',
          };
          return future ? '$value $unit后' : '$value $unit前';
        }(),
      'zh-Hant' => () {
          final unit = switch (unitKey) {
            'min' => '分鐘',
            'hour' => '小時',
            'day' => '天',
            'month' => '個月',
            _ => '年',
          };
          return future ? '$value $unit後' : '$value $unit前';
        }(),
      'de' => () {
          final unit = switch (unitKey) {
            'min' => value == 1 ? 'Minute' : 'Minuten',
            'hour' => value == 1 ? 'Stunde' : 'Stunden',
            'day' => value == 1 ? 'Tag' : 'Tagen',
            'month' => value == 1 ? 'Monat' : 'Monaten',
            _ => value == 1 ? 'Jahr' : 'Jahren',
          };
          return future ? 'in $value $unit' : 'vor $value $unit';
        }(),
      _ => () {
          final unit = switch (unitKey) {
            'min' => value == 1 ? 'minute' : 'minutes',
            'hour' => value == 1 ? 'hour' : 'hours',
            'day' => value == 1 ? 'day' : 'days',
            'month' => value == 1 ? 'month' : 'months',
            _ => value == 1 ? 'year' : 'years',
          };
          return future ? 'in $value $unit' : '$value $unit ago';
        }(),
    };
  }

  /// 本地化字节容量（二进制 1024 换算，对齐 iOS `.byteCount(style: .binary)`）。
  static String bytes(int value, {Locale? locale}) {
    if (value < 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var size = value.toDouble();
    var idx = 0;
    while (size >= 1024 && idx < units.length - 1) {
      size /= 1024;
      idx++;
    }
    final decimals = idx <= 1 ? 0 : (size >= 100 ? 0 : (size >= 10 ? 1 : 2));
    final k = _langKey(locale);
    final raw = size.toStringAsFixed(decimals);
    final formatted = k == 'de' ? raw.replaceAll('.', ',') : raw;
    return '$formatted ${units[idx]}';
  }

  /// 本地化秒级时长（对齐 iOS `Duration.seconds(...).formatted(.units(...))`）。
  static String duration(int seconds, {Locale? locale}) {
    final total = seconds < 0 ? 0 : seconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final k = _langKey(locale);

    final parts = <String>[];
    if (h > 0) {
      parts.add(switch (k) {
        'zh-Hans' => '$h小时',
        'zh-Hant' => '$h小時',
        'de' => '$h Std.',
        _ => '${h}h',
      });
    }
    if (m > 0 || (h > 0 && s > 0)) {
      parts.add(switch (k) {
        'zh-Hans' => '$m分',
        'zh-Hant' => '$m分',
        'de' => '$m Min.',
        _ => '${m}m',
      });
    }
    if (s > 0 || parts.isEmpty) {
      parts.add(switch (k) {
        'zh-Hans' || 'zh-Hant' => '$s秒',
        'de' => '$s Sek.',
        _ => '${s}s',
      });
    }
    return parts.join(_isChinese(locale) ? '' : ' ');
  }

  /// 片长格式化（分钟 -> `1 小时 42 分钟` / `1h 42m`）。
  static String runtime(int minutes, {Locale? locale}) {
    final l10n = locale != null ? McL10n.forLocale(locale) : McL10n.current;
    final clamped = minutes < 0 ? 0 : minutes;
    final hours = clamped ~/ 60;
    final rem = clamped % 60;
    if (hours == 0) return l10n.minutesShort(rem);
    if (rem == 0) return l10n.hoursShort(hours);
    return l10n.hoursMinutes(hours, rem);
  }

  /// 行内并列列表分隔符：中文「、」，其余语言「, 」。
  static String list(List<String> items, {Locale? locale}) {
    final sep = _isChinese(locale) ? '、' : ', ';
    return items.where((e) => e.isNotEmpty).join(sep);
  }

  /// 单行独立分句分隔符：中文「；」，其余语言「; 」。
  static String clauses(List<String> items, {Locale? locale}) {
    final sep = _isChinese(locale) ? '；' : '; ';
    return items.where((e) => e.isNotEmpty).join(sep);
  }

  /// 连续句子拼接：中文紧接，其余语言空格分隔。
  static String sentences(List<String> items, {Locale? locale}) {
    final sep = _isChinese(locale) ? '' : ' ';
    return items.where((e) => e.isNotEmpty).join(sep);
  }
}

const Map<String, Map<String, String>> _strings = {
  'zh-Hans': {
    // Navigation tabs
    'tab.library': '媒体库',
    'tab.subscriptions': '订阅',
    'tab.discover': '发现',
    'tab.activity': '活动',
    'tab.more': '我的',
    // Common
    'common.ok': '好',
    'common.confirm': '确定',
    'common.cancel': '取消',
    'common.close': '关闭',
    'common.save': '保存',
    'common.delete': '删除',
    'common.edit': '编辑',
    'common.retry': '重试',
    'common.refresh': '刷新',
    'common.search': '搜索',
    'common.loading': '加载中…',
    'common.empty': '暂无内容',
    'common.done': '完成',
    'common.back': '返回',
    'common.more': '更多',
    'common.view_all': '查看全部',
    'common.copy': '复制',
    'common.copied': '已复制',
    'common.share': '分享',
    'common.open_in_browser': '在浏览器中打开',
    'common.play': '播放',
    'common.pause': '暂停',
    'common.resume': '继续',
    'common.continue_play': '继续播放',
    'common.network_error': '网络错误，请检查连接后重试',
    'common.unknown_error': '发生未知错误',
    'common.enabled': '已开启',
    'common.disabled': '已关闭',
    'common.send': '发送',
    // Shell & More
    'shell.search_commands': '搜索与命令…',
    'shell.collapse_sidebar': '收起侧边栏',
    'shell.expand_sidebar': '展开侧边栏',
    'more.section_conversations': '会话',
    'more.section_downloads': '下载',
    'more.section_server': '服务器',
    // Settings
    'settings.title': '设置',
    'settings.hub_title': '设置与控制中心',
    'settings.language': '语言',
    'settings.language_page_title': '语言设置',
    'settings.language_header': '应用界面语言',
    'settings.language_footer': '切换后立即生效，并同步作为请求头 Accept-Language 发送给 MovieClaw 服务器。',
    'settings.language_system': '跟随系统',
    'settings.language_system_subtitle': '随操作系统语言自动切换',
    'settings.profile': '个人信息',
    'settings.devices': '设备',
    'settings.entry_devices': '我的设备',
    'settings.notifications': '通知',
    'settings.entry_notifications': '通知偏好',
    'settings.playback': '播放',
    'settings.entry_playback': '播放设置',
    'settings.storage': '存储',
    'settings.about': '关于',
    'settings.server': '服务器',
    'settings.system': '系统',
    'settings.account': '账号',
    'settings.downloads': '下载',
    'settings.integrations': '集成与 AI',
    'settings.appearance': '外观',
    'settings.maintenance': '更新与维护',
    'settings.check_update': '检查更新',
    'settings.logout': '退出登录',
    'settings.switch_account': '切换账号',
    'settings.approve_login': '批准登录',
    'settings.group_personal': '个人与终端',
    'settings.group_playback': '播放与媒体',
    'settings.group_automation': '自动化追更引擎',
    'settings.group_family_notify': '家庭与通知通道',
    'settings.group_ai_cloud': 'AI 与云端服务',
    'settings.group_ops': '系统运维',
    'settings.group_general': '通用与关于',
    'settings.entry_library_manage': '媒体库与异常文件管控',
    'settings.entry_scrape': '刮削与整理',
    'settings.entry_overview': '自动化流水线巡检',
    'settings.entry_rules': '选种规则组',
    'settings.entry_sites': 'PT 索引站点与插件同步',
    'settings.entry_downloaders': '下载器与目录监控',
    'settings.entry_members': '家庭成员',
    'settings.entry_push': 'IM 推送通道',
    'settings.entry_webhook': 'Webhook',
    'settings.entry_ai': '大模型、AI 默认与联网搜索',
    'settings.entry_mcp': 'MCP 服务',
    'settings.entry_cloud': 'MovieClaw Cloud',
    'settings.entry_system': '网络、定时任务与系统日志',
    'settings.entry_maintenance': '更新、缓存与维护',
    'settings.entry_check_update': '检查客户端更新',
    'settings.select_section_hint': '请在左侧选择分区',
    // Player
    'player.skip_intro': '跳过片头',
    'player.skip_outro': '跳过片尾',
    'player.speed': '倍速',
    'player.audio_track': '音轨',
    'player.subtitles': '字幕',
    'player.subtitles_off': '关闭字幕',
    'player.quality': '画质',
    'player.original_quality': '原画',
    'player.display_mode': '画面比例',
    'player.aspect_fit': '适应屏幕',
    'player.aspect_fill': '铺满屏幕',
    'player.aspect_stretch': '拉伸填充',
    'player.episodes': '选集',
    'player.next_episode': '下一集',
    'player.previous_episode': '上一集',
    'player.lock_screen': '锁定屏幕',
    'player.unlock_screen': '解锁屏幕',
    'player.airplay': '隔空播放',
    'player.cast': '投屏',
    'player.brightness': '亮度',
    'player.volume': '音量',
    'player.transcode_confirm': '该片源需要服务器转码后播放，可能增加延迟与功耗，是否继续？',
    'player.failed': '播放失败',
    // Library
    'library.home': '媒体库',
    'library.continue_watching': '继续观看',
    'library.recently_added': '最近入库',
    'library.favorites': '我的收藏',
    'library.collections': '合集',
    'library.movies': '电影',
    'library.tv_shows': '剧集',
    'library.videos': '视频',
    'library.customize': '自定义首页',
    'library.manage': '管理媒体库',
    'library.reels': '片段',
    'library.filter': '筛选',
    'library.sort': '排序',
    'library.watched': '已看',
    'library.unwatched': '未看',
    // Offline
    'offline.title': '离线下载',
    'offline.downloading': '下载中',
    'offline.completed': '已下载',
    'offline.paused': '已暂停',
    'offline.failed': '下载失败',
    'offline.queued': '排队中',
    'offline.preparing': '准备中',
    'offline.storage_used': '已用空间',
    'offline.storage_available': '可用空间',
    'offline.allow_cellular': '允许蜂窝网络下载',
    'offline.delete_confirm': '确定删除此离线缓存？',
    'offline.no_downloads': '暂无离线下载',
    'offline.prioritize': '优先下载',
    'offline.download': '下载',
    // Notices & Activity & Agent
    'notices.title': '通知与提醒',
    'notices.empty': '暂无待处理提醒',
    'notices.mark_all_read': '全部已读',
    'notices.unread': '未读',
    'activity.title': '活动',
    'activity.active': '进行中',
    'activity.history': '历史记录',
    'activity.recent_plays': '最近播放',
    'activity.stats': '观看统计',
    'activity.seeding': '做种',
    'agent.handoff_analyze': '交给 AI 分析',
    'agent.handoff_preparing': '正在整理现场…',
    'agent.handoff_failed': '发起 AI 分析失败，请稍后重试',
    'agent.title': 'AI 助手',
    'agent.new_session': '新建会话',
    'agent.input_hint': '给 AI 助手发消息',
    // Push
    'push.status_allowed': '已允许',
    'push.status_provisional': '临时允许',
    'push.status_ephemeral': '临时会话',
    'push.status_denied': '已关闭',
    'push.status_not_determined': '尚未决定',
    'push.actions_view_all_episodes': '查看全部剧集',
    'push.actions_mute_show': '这部剧不再提醒',
    'push.test_send': '发送测试通知',
    // About
    'about.title': '关于 MovieClaw',
    'about.version': '应用版本',
    'about.licenses': '开源许可',
    'about.privacy': '隐私说明',
    'about.server_version': '服务器版本',
    'about.website': '官方网站',
    'about.feedback': '问题反馈',
  },
  'zh-Hant': {
    // Navigation tabs
    'tab.library': '媒體庫',
    'tab.subscriptions': '訂閱',
    'tab.discover': '探索',
    'tab.activity': '活動',
    'tab.more': '我的',
    // Common
    'common.ok': '好',
    'common.confirm': '確定',
    'common.cancel': '取消',
    'common.close': '關閉',
    'common.save': '儲存',
    'common.delete': '刪除',
    'common.edit': '編輯',
    'common.retry': '重試',
    'common.refresh': '重新整理',
    'common.search': '搜尋',
    'common.loading': '載入中…',
    'common.empty': '暫無內容',
    'common.done': '完成',
    'common.back': '返回',
    'common.more': '更多',
    'common.view_all': '查看全部',
    'common.copy': '複製',
    'common.copied': '已複製',
    'common.share': '分享',
    'common.open_in_browser': '在瀏覽器中開啟',
    'common.play': '播放',
    'common.pause': '暫停',
    'common.resume': '繼續',
    'common.continue_play': '繼續播放',
    'common.network_error': '網路錯誤，請檢查連線後重試',
    'common.unknown_error': '發生未知錯誤',
    'common.enabled': '已開啟',
    'common.disabled': '已關閉',
    'common.send': '傳送',
    // Shell & More
    'shell.search_commands': '搜尋與命令…',
    'shell.collapse_sidebar': '收合側邊欄',
    'shell.expand_sidebar': '展開側邊欄',
    'more.section_conversations': '對話',
    'more.section_downloads': '下載',
    'more.section_server': '伺服器',
    // Settings
    'settings.title': '設定',
    'settings.hub_title': '設定與控制中心',
    'settings.language': '語言',
    'settings.language_page_title': '語言設定',
    'settings.language_header': '應用程式介面語言',
    'settings.language_footer': '切換後立即生效，並同步作為請求標頭 Accept-Language 傳送給 MovieClaw 伺服器。',
    'settings.language_system': '跟隨系統',
    'settings.language_system_subtitle': '隨作業系統語言自動切換',
    'settings.profile': '個人資訊',
    'settings.devices': '裝置',
    'settings.entry_devices': '我的裝置',
    'settings.notifications': '通知',
    'settings.entry_notifications': '通知偏好',
    'settings.playback': '播放',
    'settings.entry_playback': '播放設定',
    'settings.storage': '儲存空間',
    'settings.about': '關於',
    'settings.server': '伺服器',
    'settings.system': '系統',
    'settings.account': '帳號',
    'settings.downloads': '下載',
    'settings.integrations': '整合與 AI',
    'settings.appearance': '外觀',
    'settings.maintenance': '更新與維護',
    'settings.check_update': '檢查更新',
    'settings.logout': '登出',
    'settings.switch_account': '切換帳號',
    'settings.approve_login': '核准登入',
    'settings.group_personal': '個人與裝置',
    'settings.group_playback': '播放與媒體',
    'settings.group_automation': '自動化追更引擎',
    'settings.group_family_notify': '家庭與通知管道',
    'settings.group_ai_cloud': 'AI 與雲端服務',
    'settings.group_ops': '系統維運',
    'settings.group_general': '一般與關於',
    'settings.entry_library_manage': '媒體庫與異常檔案控管',
    'settings.entry_scrape': '刮削與整理',
    'settings.entry_overview': '自動化流水線巡檢',
    'settings.entry_rules': '選種規則組',
    'settings.entry_sites': 'PT 索引站點與外掛同步',
    'settings.entry_downloaders': '下載器與目錄監控',
    'settings.entry_members': '家庭成員',
    'settings.entry_push': 'IM 推播管道',
    'settings.entry_webhook': 'Webhook',
    'settings.entry_ai': '大模型、AI 預設與聯網搜尋',
    'settings.entry_mcp': 'MCP 服務',
    'settings.entry_cloud': 'MovieClaw Cloud',
    'settings.entry_system': '網路、排程任務與系統日誌',
    'settings.entry_maintenance': '更新、快取與維護',
    'settings.entry_check_update': '檢查用戶端更新',
    'settings.select_section_hint': '請在左側選擇分區',
    // Player
    'player.skip_intro': '略過片頭',
    'player.skip_outro': '略過片尾',
    'player.speed': '倍速',
    'player.audio_track': '音軌',
    'player.subtitles': '字幕',
    'player.subtitles_off': '關閉字幕',
    'player.quality': '畫質',
    'player.original_quality': '原畫',
    'player.display_mode': '畫面比例',
    'player.aspect_fit': '適應螢幕',
    'player.aspect_fill': '填滿螢幕',
    'player.aspect_stretch': '拉伸填滿',
    'player.episodes': '選集',
    'player.next_episode': '下一集',
    'player.previous_episode': '上一集',
    'player.lock_screen': '鎖定螢幕',
    'player.unlock_screen': '解鎖螢幕',
    'player.airplay': 'AirPlay',
    'player.cast': '投屏',
    'player.brightness': '亮度',
    'player.volume': '音量',
    'player.transcode_confirm': '此片源需要伺服器轉碼後播放，可能增加延遲與耗電，是否繼續？',
    'player.failed': '播放失敗',
    // Library
    'library.home': '媒體庫',
    'library.continue_watching': '繼續觀看',
    'library.recently_added': '最近入庫',
    'library.favorites': '我的收藏',
    'library.collections': '合集',
    'library.movies': '電影',
    'library.tv_shows': '影集',
    'library.videos': '影片',
    'library.customize': '自訂首頁',
    'library.manage': '管理媒體庫',
    'library.reels': '片段',
    'library.filter': '篩選',
    'library.sort': '排序',
    'library.watched': '已看',
    'library.unwatched': '未看',
    // Offline
    'offline.title': '離線下載',
    'offline.downloading': '下載中',
    'offline.completed': '已下載',
    'offline.paused': '已暫停',
    'offline.failed': '下載失敗',
    'offline.queued': '排隊中',
    'offline.preparing': '準備中',
    'offline.storage_used': '已用空間',
    'offline.storage_available': '可用空間',
    'offline.allow_cellular': '允許行動網路下載',
    'offline.delete_confirm': '確定刪除此離線快取？',
    'offline.no_downloads': '暫無離線下載',
    'offline.prioritize': '優先下載',
    'offline.download': '下載',
    // Notices & Activity & Agent
    'notices.title': '通知與提醒',
    'notices.empty': '暫無待處理提醒',
    'notices.mark_all_read': '全部已讀',
    'notices.unread': '未讀',
    'activity.title': '活動',
    'activity.active': '進行中',
    'activity.history': '歷史紀錄',
    'activity.recent_plays': '最近播放',
    'activity.stats': '觀看統計',
    'activity.seeding': '做種',
    'agent.handoff_analyze': '交給 AI 分析',
    'agent.handoff_preparing': '正在整理現場…',
    'agent.handoff_failed': '發起 AI 分析失敗，請稍後重試',
    'agent.title': 'AI 助手',
    'agent.new_session': '新建對話',
    'agent.input_hint': '傳送訊息給 AI 助手',
    // Push
    'push.status_allowed': '已允許',
    'push.status_provisional': '暫時允許',
    'push.status_ephemeral': '臨時階段',
    'push.status_denied': '已關閉',
    'push.status_not_determined': '尚未決定',
    'push.actions_view_all_episodes': '查看全部集數',
    'push.actions_mute_show': '這部劇不再提醒',
    'push.test_send': '傳送測試通知',
    // About
    'about.title': '關於 MovieClaw',
    'about.version': '應用程式版本',
    'about.licenses': '開源授權',
    'about.privacy': '隱私說明',
    'about.server_version': '伺服器版本',
    'about.website': '官方網站',
    'about.feedback': '意見回饋',
  },
  'en': {
    // Navigation tabs
    'tab.library': 'Library',
    'tab.subscriptions': 'Subscriptions',
    'tab.discover': 'Discover',
    'tab.activity': 'Activity',
    'tab.more': 'Me',
    // Common
    'common.ok': 'OK',
    'common.confirm': 'Confirm',
    'common.cancel': 'Cancel',
    'common.close': 'Close',
    'common.save': 'Save',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.retry': 'Retry',
    'common.refresh': 'Refresh',
    'common.search': 'Search',
    'common.loading': 'Loading…',
    'common.empty': 'Nothing here yet',
    'common.done': 'Done',
    'common.back': 'Back',
    'common.more': 'More',
    'common.view_all': 'View All',
    'common.copy': 'Copy',
    'common.copied': 'Copied',
    'common.share': 'Share',
    'common.open_in_browser': 'Open in Browser',
    'common.play': 'Play',
    'common.pause': 'Pause',
    'common.resume': 'Resume',
    'common.continue_play': 'Continue Watching',
    'common.network_error': 'Network error. Please check your connection and retry.',
    'common.unknown_error': 'An unexpected error occurred',
    'common.enabled': 'On',
    'common.disabled': 'Off',
    'common.send': 'Send',
    // Shell & More
    'shell.search_commands': 'Search & commands…',
    'shell.collapse_sidebar': 'Collapse sidebar',
    'shell.expand_sidebar': 'Expand sidebar',
    'more.section_conversations': 'Chats',
    'more.section_downloads': 'Downloads',
    'more.section_server': 'Server',
    // Settings
    'settings.title': 'Settings',
    'settings.hub_title': 'Settings & Control Center',
    'settings.language': 'Language',
    'settings.language_page_title': 'Language',
    'settings.language_header': 'App Interface Language',
    'settings.language_footer':
        'Takes effect immediately and is also sent to the MovieClaw server via Accept-Language.',
    'settings.language_system': 'System Default',
    'settings.language_system_subtitle': 'Follow operating system language',
    'settings.profile': 'Profile',
    'settings.devices': 'Devices',
    'settings.entry_devices': 'My Devices',
    'settings.notifications': 'Notifications',
    'settings.entry_notifications': 'Notifications',
    'settings.playback': 'Playback',
    'settings.entry_playback': 'Playback Settings',
    'settings.storage': 'Storage',
    'settings.about': 'About',
    'settings.server': 'Server',
    'settings.system': 'System',
    'settings.account': 'Account',
    'settings.downloads': 'Downloads',
    'settings.integrations': 'Integrations & AI',
    'settings.appearance': 'Appearance',
    'settings.maintenance': 'Updates & Maintenance',
    'settings.check_update': 'Check for Updates',
    'settings.logout': 'Sign Out',
    'settings.switch_account': 'Switch Account',
    'settings.approve_login': 'Approve Sign-In',
    'settings.group_personal': 'Account & Devices',
    'settings.group_playback': 'Playback & Media',
    'settings.group_automation': 'Automation Engine',
    'settings.group_family_notify': 'Family & Notifications',
    'settings.group_ai_cloud': 'AI & Cloud',
    'settings.group_ops': 'System Operations',
    'settings.group_general': 'General & About',
    'settings.entry_library_manage': 'Libraries & Media Files',
    'settings.entry_scrape': 'Metadata & Organizing',
    'settings.entry_overview': 'Automation Overview',
    'settings.entry_rules': 'Release Rule Sets',
    'settings.entry_sites': 'Indexers & Plugin Sync',
    'settings.entry_downloaders': 'Downloaders & Watch Folders',
    'settings.entry_members': 'Family Members',
    'settings.entry_push': 'IM Push Channels',
    'settings.entry_webhook': 'Webhook',
    'settings.entry_ai': 'LLMs, AI Defaults & Web Search',
    'settings.entry_mcp': 'MCP Server',
    'settings.entry_cloud': 'MovieClaw Cloud',
    'settings.entry_system': 'Network, Tasks & System Logs',
    'settings.entry_maintenance': 'Updates, Cache & Maintenance',
    'settings.entry_check_update': 'Check for App Updates',
    'settings.select_section_hint': 'Select a section on the left',
    // Player
    'player.skip_intro': 'Skip Intro',
    'player.skip_outro': 'Skip Credits',
    'player.speed': 'Speed',
    'player.audio_track': 'Audio',
    'player.subtitles': 'Subtitles',
    'player.subtitles_off': 'Off',
    'player.quality': 'Quality',
    'player.original_quality': 'Original',
    'player.display_mode': 'Aspect Ratio',
    'player.aspect_fit': 'Fit',
    'player.aspect_fill': 'Fill',
    'player.aspect_stretch': 'Stretch',
    'player.episodes': 'Episodes',
    'player.next_episode': 'Next Episode',
    'player.previous_episode': 'Previous Episode',
    'player.lock_screen': 'Lock Screen',
    'player.unlock_screen': 'Unlock Screen',
    'player.airplay': 'AirPlay',
    'player.cast': 'Cast',
    'player.brightness': 'Brightness',
    'player.volume': 'Volume',
    'player.transcode_confirm':
        'This title requires server transcoding, which may increase latency and power use. Continue?',
    'player.failed': 'Playback failed',
    // Library
    'library.home': 'Library',
    'library.continue_watching': 'Continue Watching',
    'library.recently_added': 'Recently Added',
    'library.favorites': 'Favorites',
    'library.collections': 'Collections',
    'library.movies': 'Movies',
    'library.tv_shows': 'TV Shows',
    'library.videos': 'Videos',
    'library.customize': 'Customize Home',
    'library.manage': 'Manage Libraries',
    'library.reels': 'Reels',
    'library.filter': 'Filter',
    'library.sort': 'Sort',
    'library.watched': 'Watched',
    'library.unwatched': 'Unwatched',
    // Offline
    'offline.title': 'Downloads',
    'offline.downloading': 'Downloading',
    'offline.completed': 'Downloaded',
    'offline.paused': 'Paused',
    'offline.failed': 'Failed',
    'offline.queued': 'Queued',
    'offline.preparing': 'Preparing',
    'offline.storage_used': 'Used Storage',
    'offline.storage_available': 'Available Storage',
    'offline.allow_cellular': 'Download over Cellular',
    'offline.delete_confirm': 'Delete this offline download?',
    'offline.no_downloads': 'No offline downloads',
    'offline.prioritize': 'Prioritize',
    'offline.download': 'Download',
    // Notices & Activity & Agent
    'notices.title': 'Notices',
    'notices.empty': 'No pending notices',
    'notices.mark_all_read': 'Mark All Read',
    'notices.unread': 'Unread',
    'activity.title': 'Activity',
    'activity.active': 'Active',
    'activity.history': 'History',
    'activity.recent_plays': 'Recent Plays',
    'activity.stats': 'Watch Stats',
    'activity.seeding': 'Seeding',
    'agent.handoff_analyze': 'Ask AI to Analyze',
    'agent.handoff_preparing': 'Preparing diagnostics…',
    'agent.handoff_failed': 'Failed to start AI analysis. Please retry.',
    'agent.title': 'AI Assistant',
    'agent.new_session': 'New Session',
    'agent.input_hint': 'Message AI assistant',
    // Push
    'push.status_allowed': 'Allowed',
    'push.status_provisional': 'Provisional',
    'push.status_ephemeral': 'Ephemeral',
    'push.status_denied': 'Off',
    'push.status_not_determined': 'Not Set',
    'push.actions_view_all_episodes': 'View All Episodes',
    'push.actions_mute_show': 'Mute This Show',
    'push.test_send': 'Send Test Notification',
    // About
    'about.title': 'About MovieClaw',
    'about.version': 'App Version',
    'about.licenses': 'Open Source Licenses',
    'about.privacy': 'Privacy Policy',
    'about.server_version': 'Server Version',
    'about.website': 'Website',
    'about.feedback': 'Feedback',
  },
  'de': {
    // Navigation tabs
    'tab.library': 'Mediathek',
    'tab.subscriptions': 'Abos',
    'tab.discover': 'Entdecken',
    'tab.activity': 'Aktivität',
    'tab.more': 'Ich',
    // Common
    'common.ok': 'OK',
    'common.confirm': 'Bestätigen',
    'common.cancel': 'Abbrechen',
    'common.close': 'Schließen',
    'common.save': 'Speichern',
    'common.delete': 'Löschen',
    'common.edit': 'Bearbeiten',
    'common.retry': 'Erneut versuchen',
    'common.refresh': 'Aktualisieren',
    'common.search': 'Suchen',
    'common.loading': 'Wird geladen…',
    'common.empty': 'Noch keine Inhalte',
    'common.done': 'Fertig',
    'common.back': 'Zurück',
    'common.more': 'Mehr',
    'common.view_all': 'Alle anzeigen',
    'common.copy': 'Kopieren',
    'common.copied': 'Kopiert',
    'common.share': 'Teilen',
    'common.open_in_browser': 'Im Browser öffnen',
    'common.play': 'Abspielen',
    'common.pause': 'Pausieren',
    'common.resume': 'Fortsetzen',
    'common.continue_play': 'Weiterschauen',
    'common.network_error': 'Netzwerkfehler. Bitte Verbindung prüfen und erneut versuchen.',
    'common.unknown_error': 'Ein unerwarteter Fehler ist aufgetreten',
    'common.enabled': 'Ein',
    'common.disabled': 'Aus',
    'common.send': 'Senden',
    // Shell & More
    'shell.search_commands': 'Suchen & Befehle…',
    'shell.collapse_sidebar': 'Seitenleiste einklappen',
    'shell.expand_sidebar': 'Seitenleiste ausklappen',
    'more.section_conversations': 'Chats',
    'more.section_downloads': 'Downloads',
    'more.section_server': 'Server',
    // Settings
    'settings.title': 'Einstellungen',
    'settings.hub_title': 'Einstellungen & Kontrollzentrum',
    'settings.language': 'Sprache',
    'settings.language_page_title': 'Sprache',
    'settings.language_header': 'App-Sprache',
    'settings.language_footer':
        'Wird sofort übernommen und über Accept-Language an den MovieClaw-Server gesendet.',
    'settings.language_system': 'Systemstandard',
    'settings.language_system_subtitle': 'Automatisch an die Systemsprache anpassen',
    'settings.profile': 'Profil',
    'settings.devices': 'Geräte',
    'settings.entry_devices': 'Meine Geräte',
    'settings.notifications': 'Mitteilungen',
    'settings.entry_notifications': 'Mitteilungen',
    'settings.playback': 'Wiedergabe',
    'settings.entry_playback': 'Wiedergabe',
    'settings.storage': 'Speicher',
    'settings.about': 'Über',
    'settings.server': 'Server',
    'settings.system': 'System',
    'settings.account': 'Konto',
    'settings.downloads': 'Downloads',
    'settings.integrations': 'Integrationen & KI',
    'settings.appearance': 'Erscheinungsbild',
    'settings.maintenance': 'Updates & Wartung',
    'settings.check_update': 'Nach Updates suchen',
    'settings.logout': 'Abmelden',
    'settings.switch_account': 'Konto wechseln',
    'settings.approve_login': 'Anmeldung bestätigen',
    'settings.group_personal': 'Konto & Geräte',
    'settings.group_playback': 'Wiedergabe & Medien',
    'settings.group_automation': 'Automatisierung',
    'settings.group_family_notify': 'Familie & Benachrichtigungen',
    'settings.group_ai_cloud': 'KI & Cloud',
    'settings.group_ops': 'Systembetrieb',
    'settings.group_general': 'Allgemein & Über',
    'settings.entry_library_manage': 'Mediatheken & Dateien',
    'settings.entry_scrape': 'Metadaten & Organisation',
    'settings.entry_overview': 'Automatisierungsübersicht',
    'settings.entry_rules': 'Regelsätze',
    'settings.entry_sites': 'Indexer & Plugin-Sync',
    'settings.entry_downloaders': 'Downloader & Überwachung',
    'settings.entry_members': 'Familienmitglieder',
    'settings.entry_push': 'IM-Benachrichtigungen',
    'settings.entry_webhook': 'Webhook',
    'settings.entry_ai': 'LLMs, KI & Websuche',
    'settings.entry_mcp': 'MCP-Dienst',
    'settings.entry_cloud': 'MovieClaw Cloud',
    'settings.entry_system': 'Netzwerk, Aufgaben & Protokolle',
    'settings.entry_maintenance': 'Updates, Cache & Wartung',
    'settings.entry_check_update': 'Nach App-Updates suchen',
    'settings.select_section_hint': 'Bereich links auswählen',
    // Player
    'player.skip_intro': 'Intro überspringen',
    'player.skip_outro': 'Abspann überspringen',
    'player.speed': 'Tempo',
    'player.audio_track': 'Tonspur',
    'player.subtitles': 'Untertitel',
    'player.subtitles_off': 'Aus',
    'player.quality': 'Qualität',
    'player.original_quality': 'Original',
    'player.display_mode': 'Seitenverhältnis',
    'player.aspect_fit': 'Anpassen',
    'player.aspect_fill': 'Ausfüllen',
    'player.aspect_stretch': 'Strecken',
    'player.episodes': 'Folgen',
    'player.next_episode': 'Nächste Folge',
    'player.previous_episode': 'Vorherige Folge',
    'player.lock_screen': 'Bildschirm sperren',
    'player.unlock_screen': 'Entsperren',
    'player.airplay': 'AirPlay',
    'player.cast': 'Übertragen',
    'player.brightness': 'Helligkeit',
    'player.volume': 'Lautstärke',
    'player.transcode_confirm':
        'Dieser Titel erfordert Server-Transkodierung. Möchten Sie fortfahren?',
    'player.failed': 'Wiedergabe fehlgeschlagen',
    // Library
    'library.home': 'Mediathek',
    'library.continue_watching': 'Weiterschauen',
    'library.recently_added': 'Zuletzt hinzugefügt',
    'library.favorites': 'Favoriten',
    'library.collections': 'Sammlungen',
    'library.movies': 'Filme',
    'library.tv_shows': 'Serien',
    'library.videos': 'Videos',
    'library.customize': 'Startseite anpassen',
    'library.manage': 'Mediatheken verwalten',
    'library.reels': 'Clips',
    'library.filter': 'Filtern',
    'library.sort': 'Sortieren',
    'library.watched': 'Gesehen',
    'library.unwatched': 'Ungesehen',
    // Offline
    'offline.title': 'Downloads',
    'offline.downloading': 'Wird geladen',
    'offline.completed': 'Heruntergeladen',
    'offline.paused': 'Pausiert',
    'offline.failed': 'Fehlgeschlagen',
    'offline.queued': 'In Warteschlange',
    'offline.preparing': 'Wird vorbereitet',
    'offline.storage_used': 'Belegter Speicher',
    'offline.storage_available': 'Verfügbarer Speicher',
    'offline.allow_cellular': 'Über Mobilfunk laden',
    'offline.delete_confirm': 'Diesen Offline-Download löschen?',
    'offline.no_downloads': 'Keine Offline-Downloads',
    'offline.prioritize': 'Priorisieren',
    'offline.download': 'Herunterladen',
    // Notices & Activity & Agent
    'notices.title': 'Hinweise',
    'notices.empty': 'Keine offenen Hinweise',
    'notices.mark_all_read': 'Alle als gelesen markieren',
    'notices.unread': 'Ungelesen',
    'activity.title': 'Aktivität',
    'activity.active': 'Aktiv',
    'activity.history': 'Verlauf',
    'activity.recent_plays': 'Zuletzt gespielt',
    'activity.stats': 'Statistiken',
    'activity.seeding': 'Seeding',
    'agent.handoff_analyze': 'Von KI analysieren lassen',
    'agent.handoff_preparing': 'Diagnose wird erstellt…',
    'agent.handoff_failed': 'KI-Analyse konnte nicht gestartet werden',
    'agent.title': 'KI-Assistent',
    'agent.new_session': 'Neue Sitzung',
    'agent.input_hint': 'Nachricht an KI-Assistent',
    // Push
    'push.status_allowed': 'Erlaubt',
    'push.status_provisional': 'Vorläufig',
    'push.status_ephemeral': 'Temporär',
    'push.status_denied': 'Aus',
    'push.status_not_determined': 'Nicht festgelegt',
    'push.actions_view_all_episodes': 'Alle Folgen anzeigen',
    'push.actions_mute_show': 'Serie stummschalten',
    'push.test_send': 'Testmitteilung senden',
    // About
    'about.title': 'Über MovieClaw',
    'about.version': 'App-Version',
    'about.licenses': 'Open-Source-Lizenzen',
    'about.privacy': 'Datenschutz',
    'about.server_version': 'Serverversion',
    'about.website': 'Webseite',
    'about.feedback': 'Feedback',
  },
};
