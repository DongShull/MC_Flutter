// 媒体库管理（对照 PARITY.md 第 15 行：此前无）。
//
// 三块，均走类型化 McApi，服务端无对应端点的不编造：
// - 回收站：`GET /libraries/trashed-files` + `POST …/restore`
//   （body `{ids: [...]}`；web 的彻底清理 purge 端点在 McApi 未收录，见页内说明）；
// - 重复文件：`GET /libraries/duplicate-files` + `POST …/scan`
//   （读上一轮扫描落库的结论；清理动作服务端未提供对应端点，只展示）；
// - 元数据刷新：`POST /libraries/{id}/metadata/refresh` + `…/stop`（按库）。
// 刮削覆盖：`LibraryPayload.scrape_overrides` 字段存在，但覆盖值的
// 编辑口径属设置域（库设置页），不在本浏览闭环内做——见 P2.md。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/models.dart';
import '../../../core/models/format.dart';

/// 回收站一行（web `TrashedItem` 子集；media_item 为 null 时以文件名代标题）。
class TrashedRow {
  const TrashedRow({
    required this.key,
    required this.libraryId,
    required this.libraryName,
    this.mediaItemId,
    this.title,
    this.year,
    this.posterUrl,
    required this.fileIds,
    required this.fileNames,
    required this.totalBytes,
  });

  factory TrashedRow.fromJson(Map<String, dynamic> o) {
    final media = o['media_item'];
    final mediaMap =
        media is Map ? media.cast<String, dynamic>() : <String, dynamic>{};
    final files = (o['files'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((f) => f.cast<String, dynamic>())
        .toList();
    var bytes = 0;
    final ids = <int>[];
    final names = <String>[];
    for (final f in files) {
      final id = (f['id'] as num?)?.toInt();
      if (id != null) ids.add(id);
      names.add((f['file_name'] ?? '').toString());
      bytes += (f['size_bytes'] as num? ?? 0).toInt();
    }
    final lib = o['library'];
    final libMap =
        lib is Map ? lib.cast<String, dynamic>() : <String, dynamic>{};
    return TrashedRow(
      key: (o['key'] ?? '').toString(),
      libraryId: (libMap['id'] as num? ?? 0).toInt(),
      libraryName: (libMap['name'] ?? '').toString(),
      mediaItemId: (mediaMap['id'] as num?)?.toInt(),
      title: mediaMap['title']?.toString(),
      year: (mediaMap['year'] as num?)?.toInt(),
      posterUrl: mediaMap['poster_url']?.toString(),
      fileIds: ids,
      fileNames: names,
      totalBytes: bytes,
    );
  }

  final String key;
  final int libraryId;
  final String libraryName;
  final int? mediaItemId;
  final String? title;
  final int? year;
  final String? posterUrl;
  final List<int> fileIds;
  final List<String> fileNames;
  final int totalBytes;

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    return fileNames.isNotEmpty ? fileNames.first : key;
  }

  String get sizeLabel => mcFormatBytes(totalBytes);
}

/// 重复文件一档摘要（web `DuplicateGroup`：label / hint / units / files / bytes）。
class DuplicateGroupRow {
  const DuplicateGroupRow({
    required this.key,
    required this.label,
    required this.hint,
    required this.units,
    required this.files,
    required this.bytes,
  });

  factory DuplicateGroupRow.fromJson(Map<String, dynamic> o) =>
      DuplicateGroupRow(
        key: (o['key'] ?? '').toString(),
        label: (o['label'] ?? '').toString(),
        hint: (o['hint'] ?? '').toString(),
        units: (o['units'] as num? ?? 0).toInt(),
        files: (o['files'] as num? ?? 0).toInt(),
        bytes: (o['bytes'] as num? ?? 0).toInt(),
      );

  final String key;
  final String label;
  final String hint;
  final int units;
  final int files;
  final int bytes;
}

/// 重复文件一条目（web `DuplicateItem`：库 + 条目 + 季列表）。
class DuplicateItemRow {
  const DuplicateItemRow({
    required this.libraryId,
    required this.libraryName,
    required this.mediaItemId,
    required this.title,
    this.year,
    this.posterUrl,
    required this.seasonCount,
  });

  factory DuplicateItemRow.fromJson(Map<String, dynamic> o) {
    final media = o['media_item'];
    final mediaMap =
        media is Map ? media.cast<String, dynamic>() : <String, dynamic>{};
    final lib = o['library'];
    final libMap =
        lib is Map ? lib.cast<String, dynamic>() : <String, dynamic>{};
    return DuplicateItemRow(
      libraryId: (libMap['id'] as num? ?? 0).toInt(),
      libraryName: (libMap['name'] ?? '').toString(),
      mediaItemId: (mediaMap['id'] as num? ?? 0).toInt(),
      title: (mediaMap['title'] ?? '').toString(),
      year: (mediaMap['year'] as num?)?.toInt(),
      posterUrl: mediaMap['poster_url']?.toString(),
      seasonCount: (o['seasons'] as List<dynamic>? ?? const []).length,
    );
  }

  final int libraryId;
  final String libraryName;
  final int mediaItemId;
  final String title;
  final int? year;
  final String? posterUrl;
  final int seasonCount;
}

class LibraryManageState {
  const LibraryManageState({
    this.loading = true,
    this.error,
    this.trashed = const [],
    this.trashedLoaded = false,
    this.restoringKey,
    this.duplicateGroups = const [],
    this.duplicateItems = const [],
    this.duplicateTotals,
    this.scanStatus,
    this.scanMessage,
    this.scannedAt,
    this.duplicatesLoaded = false,
    this.scanning = false,
    this.libraries = const [],
    this.refreshingLibraryId,
    this.notice,
  });

  final bool loading;
  final String? error;
  final List<TrashedRow> trashed;
  final bool trashedLoaded;
  final String? restoringKey;
  final List<DuplicateGroupRow> duplicateGroups;
  final List<DuplicateItemRow> duplicateItems;
  final ({int units, int files, int bytes, int items})? duplicateTotals;
  final String? scanStatus;
  final String? scanMessage;
  final String? scannedAt;
  final bool duplicatesLoaded;
  final bool scanning;
  final List<LibraryView> libraries;
  final int? refreshingLibraryId;
  final String? notice;

  LibraryManageState copyWith({
    bool? loading,
    Object? error = _sentinel,
    List<TrashedRow>? trashed,
    bool? trashedLoaded,
    Object? restoringKey = _sentinel,
    List<DuplicateGroupRow>? duplicateGroups,
    List<DuplicateItemRow>? duplicateItems,
    Object? duplicateTotals = _sentinel,
    Object? scanStatus = _sentinel,
    Object? scanMessage = _sentinel,
    Object? scannedAt = _sentinel,
    bool? duplicatesLoaded,
    bool? scanning,
    List<LibraryView>? libraries,
    Object? refreshingLibraryId = _sentinel,
    Object? notice = _sentinel,
  }) =>
      LibraryManageState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        trashed: trashed ?? this.trashed,
        trashedLoaded: trashedLoaded ?? this.trashedLoaded,
        restoringKey: identical(restoringKey, _sentinel)
            ? this.restoringKey
            : restoringKey as String?,
        duplicateGroups: duplicateGroups ?? this.duplicateGroups,
        duplicateItems: duplicateItems ?? this.duplicateItems,
        duplicateTotals: identical(duplicateTotals, _sentinel)
            ? this.duplicateTotals
            : duplicateTotals as ({int units, int files, int bytes, int items})?,
        scanStatus: identical(scanStatus, _sentinel)
            ? this.scanStatus
            : scanStatus as String?,
        scanMessage: identical(scanMessage, _sentinel)
            ? this.scanMessage
            : scanMessage as String?,
        scannedAt: identical(scannedAt, _sentinel)
            ? this.scannedAt
            : scannedAt as String?,
        duplicatesLoaded: duplicatesLoaded ?? this.duplicatesLoaded,
        scanning: scanning ?? this.scanning,
        libraries: libraries ?? this.libraries,
        refreshingLibraryId: identical(refreshingLibraryId, _sentinel)
            ? this.refreshingLibraryId
            : refreshingLibraryId as int?,
        notice:
            identical(notice, _sentinel) ? this.notice : notice as String?,
      );

  static const _sentinel = Object();
}

class LibraryManageController extends Notifier<LibraryManageState> {
  McApi get _api => ref.read(mcApiProvider);

  @override
  LibraryManageState build() {
    Future.microtask(load);
    return const LibraryManageState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    await Future.wait([loadTrashed(), loadDuplicates(), loadLibraries()]);
    state = state.copyWith(loading: false);
  }

  Future<void> loadTrashed() async {
    try {
      final data = await _api.trashedFiles();
      final rawItems = data is Map
          ? (data['items'] as List<dynamic>? ?? const [])
          : data is List
              ? data
              : const [];
      final items = rawItems
          .whereType<Map>()
          .map((m) => TrashedRow.fromJson(m.cast<String, dynamic>()))
          .toList();
      state = state.copyWith(trashed: items, trashedLoaded: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.friendlyMessage, trashedLoaded: true);
    } catch (e) {
      state = state.copyWith(error: '回收站加载失败：$e', trashedLoaded: true);
    }
  }

  Future<void> loadDuplicates() async {
    try {
      final data = await _api.duplicateFiles();
      if (data is! Map) {
        state = state.copyWith(duplicatesLoaded: true);
        return;
      }
      final scan = data['scan'];
      final scanMap =
          scan is Map ? scan.cast<String, dynamic>() : <String, dynamic>{};
      final groups = (data['tiers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => DuplicateGroupRow.fromJson(m.cast<String, dynamic>()))
          .toList();
      final review = (data['review_groups'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => DuplicateGroupRow.fromJson(m.cast<String, dynamic>()))
          .toList();
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => DuplicateItemRow.fromJson(m.cast<String, dynamic>()))
          .toList();
      state = state.copyWith(
        duplicateGroups: [...groups, ...review],
        duplicateItems: items,
        duplicateTotals: (
          units: (data['total_units'] as num? ?? 0).toInt(),
          files: (data['total_files'] as num? ?? 0).toInt(),
          bytes: (data['total_bytes'] as num? ?? 0).toInt(),
          items: (data['total_items'] as num? ?? 0).toInt(),
        ),
        scanStatus: scanMap['status']?.toString(),
        scanMessage: scanMap['message']?.toString(),
        scannedAt: scanMap['scanned_at']?.toString(),
        duplicatesLoaded: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e.friendlyMessage, duplicatesLoaded: true);
    } catch (e) {
      state = state.copyWith(error: '重复文件加载失败：$e', duplicatesLoaded: true);
    }
  }

  Future<void> loadLibraries() async {
    try {
      final libs = await _api.libraries();
      state = state.copyWith(libraries: libs);
    } catch (e) {
      // 库列表失败不阻塞回收站/重复文件两区（记错在 error 上，页内展示）。
      state = state.copyWith(error: '媒体库列表加载失败：$e');
    }
  }

  /// 恢复回收站的一行（按文件 id 批量恢复；可逆，不需确认）。
  Future<void> restoreTrashed(TrashedRow row) async {
    if (row.fileIds.isEmpty || state.restoringKey != null) return;
    state = state.copyWith(restoringKey: row.key, error: null, notice: null);
    try {
      await _api.restoreTrashed(body: {'ids': row.fileIds});
      state = state.copyWith(
        restoringKey: null,
        trashed: state.trashed.where((t) => t.key != row.key).toList(),
        notice: '已恢复「${row.displayTitle}」',
      );
    } on ApiException catch (e) {
      state = state.copyWith(restoringKey: null, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(restoringKey: null, error: '恢复失败：$e');
    }
  }

  /// 重新扫描重复文件（服务端异步扫；扫完重拉结论）。
  Future<void> scanDuplicates() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, error: null, notice: null);
    try {
      await _api.scanDuplicates();
      await loadDuplicates();
      state = state.copyWith(
        scanning: false,
        notice: '已提交重复文件扫描，结论稍后更新',
      );
    } on ApiException catch (e) {
      state = state.copyWith(scanning: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(scanning: false, error: '扫描失败：$e');
    }
  }

  /// 刷新指定库的元数据（整库刮削；停止用 stop 端点）。
  Future<void> refreshLibraryMetadata(int libraryId) async {
    if (state.refreshingLibraryId != null) return;
    state = state.copyWith(
      refreshingLibraryId: libraryId,
      error: null,
      notice: null,
    );
    try {
      await _api.refreshLibraryMetadata(libraryId);
      state = state.copyWith(
        refreshingLibraryId: null,
        notice: '已提交元数据刷新任务',
      );
    } on ApiException catch (e) {
      state = state.copyWith(refreshingLibraryId: null, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(refreshingLibraryId: null, error: '刷新失败：$e');
    }
  }

  Future<void> stopLibraryMetadataRefresh(int libraryId) async {
    try {
      await _api.stopLibraryMetadataRefresh(libraryId);
      state = state.copyWith(notice: '已停止元数据刷新');
    } on ApiException catch (e) {
      state = state.copyWith(error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(error: '停止失败：$e');
    }
  }

  void consumeNotice() => state = state.copyWith(notice: null);
}

final libraryManageProvider =
    NotifierProvider<LibraryManageController, LibraryManageState>(
  LibraryManageController.new,
);
