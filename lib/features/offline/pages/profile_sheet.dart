import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';
import '../state/offline_state.dart';

/// 当季智能范围 + 真实后端档位选择弹层（1:1 对齐 iOS `OfflineProfileSheet`）：
/// - 调用 `POST /api/v1/offline/profiles` 一次性查询全部范围文件的真实 `expectedBytes` 与可用档位（不展示高于源分辨率的假档位）；
/// - 单选画质档位并记住上次选择（`lastProfile`）；
/// - 剧集按当季收敛、自动去重已下载/下载中集数（"已下载 X 集 · 不重复下载"），动态给出「当前集 / 接下来 5 集 / 未看 N 集（默认优选）/ 剩余 N 集」；
/// - 使用真实 `seasonNumber` & `episodeNumber`，强制校验本机可用空间（含 2 GB 系统预留）。
Future<void> showOfflineDownloadSheet(
  BuildContext context, {
  required String title,
  int? fileId,
  OfflineDownloadChoices? choices,
  Future<OfflineDownloadChoices> Function()? loadChoices,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => OfflineDownloadSheet(
      title: title,
      fileId: fileId,
      choices: choices,
      loadChoices: loadChoices,
    ),
  );
}

/// 兼容旧 `DownloadCandidate` 入口（如 `detail_page.dart`）：自动转换为智能范围与真实后端档位查询。
Future<void> showDownloadProfileSheet(
  BuildContext context, {
  required DownloadCandidate candidate,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => DownloadProfileSheet(candidate: candidate),
  );
}

class DownloadProfileSheet extends ConsumerWidget {
  const DownloadProfileSheet({super.key, required this.candidate});

  final DownloadCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.read(offlineProvider);
    final leadId = int.tryParse(candidate.fileId);

    // 若调用方传入了结构化当季剧集，直接走当季智能范围算法（0f372ee4）。
    if (candidate.seasonEpisodes.isNotEmpty) {
      final hydrated = [
        for (final ep in candidate.seasonEpisodes)
          OfflineChoiceEpisode(
            season: ep.season,
            episode: ep.episode,
            fileId: ep.fileId,
            played: ep.played,
            local: ep.local ?? _localStateFor(offline, ep.fileId),
          ),
      ];
      final selectedPair = (candidate.seasonNumber != null &&
              candidate.episodeNumber != null)
          ? (
              season: candidate.seasonNumber!,
              episode: candidate.episodeNumber!,
            )
          : null;
      final choices = OfflineDownloadChoices.make(
        episodes: hydrated,
        selected: selectedPair,
        selectedFile: leadId,
        multiSeason: candidate.multiSeason,
        season: candidate.seasonNumber,
      );
      return OfflineDownloadSheet(
        title: candidate.title,
        choices: choices,
        fallbackProfiles: candidate.profiles,
      );
    }

    // 兼容仅传 `fileId` + `seasonFileIds` 的旧调用：同样自动去重本机已下/在下的文件。
    final allSeasonIds = <int>[
      for (final s in candidate.seasonFileIds)
        if (int.tryParse(s) != null) int.parse(s),
    ];
    final hasSeasonScope =
        candidate.scopes.length > 1 && allSeasonIds.length > 1;
    if (hasSeasonScope) {
      final doneCount = allSeasonIds
          .where((id) => _localStateFor(offline, id) == OfflineChoiceLocalState.done)
          .length;
      final activeCount = allSeasonIds
          .where((id) => _localStateFor(offline, id) == OfflineChoiceLocalState.active)
          .length;
      final remaining = allSeasonIds
          .where((id) => _localStateFor(offline, id) == null)
          .toList();
      final scopes = <OfflineDownloadScope>[];
      if (leadId != null && _localStateFor(offline, leadId) == null) {
        scopes.add(
          OfflineDownloadScope(
            id: 'selected',
            label: candidate.scopes.first,
            fileIds: [leadId],
            preferred: remaining.length <= 1,
          ),
        );
      }
      if (remaining.isNotEmpty &&
          (scopes.isEmpty || remaining.length > 1)) {
        scopes.add(
          OfflineDownloadScope(
            id: 'all',
            label: (doneCount + activeCount) > 0
                ? '剩余 ${remaining.length} 集'
                : '全部 ${remaining.length} 集',
            fileIds: remaining,
            preferred: scopes.isEmpty,
          ),
        );
      }
      final noteParts = <String>[
        if (doneCount > 0) '已下载 $doneCount 集',
        if (activeCount > 0) '下载中 $activeCount 集',
      ];
      return OfflineDownloadSheet(
        title: candidate.title,
        choices: OfflineDownloadChoices(
          scopes: scopes,
          note: noteParts.isEmpty ? null : '${noteParts.join('、')} · 不重复下载',
          hasLocal: doneCount + activeCount > 0,
        ),
        fallbackProfiles: candidate.profiles,
      );
    }

    return OfflineDownloadSheet(
      title: candidate.title,
      fileId: leadId,
      fallbackProfiles: candidate.profiles,
    );
  }

  static OfflineChoiceLocalState? _localStateFor(
    OfflineState state,
    int? fileId,
  ) {
    if (fileId == null) return null;
    final unit = state.unitForFile(fileId);
    if (unit == null) return null;
    if (unit.playable) return OfflineChoiceLocalState.done;
    if (unit.isActive) return OfflineChoiceLocalState.active;
    return null;
  }
}

class OfflineDownloadSheet extends ConsumerStatefulWidget {
  const OfflineDownloadSheet({
    super.key,
    required this.title,
    this.fileId,
    this.choices,
    this.loadChoices,
    this.fallbackProfiles = const [],
  });

  final String title;
  final int? fileId;
  final OfflineDownloadChoices? choices;
  final Future<OfflineDownloadChoices> Function()? loadChoices;
  final List<DownloadProfile> fallbackProfiles;

  @override
  ConsumerState<OfflineDownloadSheet> createState() =>
      _OfflineDownloadSheetState();
}

class _OfflineDownloadSheetState extends ConsumerState<OfflineDownloadSheet> {
  OfflineDownloadChoices? _choices;
  String? _scopeId;
  Map<int, OfflineFileProfiles> _entries = const {};
  final Set<int> _asked = {};
  bool _loading = true;
  bool _starting = false;
  String? _error;
  String? _startError;
  String? _selectedProfileId;

  bool get _ranged => widget.choices != null || widget.loadChoices != null;

  OfflineDownloadScope? get _activeScope {
    final scopes = _choices?.scopes;
    if (scopes == null || scopes.isEmpty) return null;
    for (final s in scopes) {
      if (s.id == _scopeId) return s;
    }
    return scopes.first;
  }

  List<int> get _fileIds => _activeScope?.fileIds ?? const [];
  bool get _isBatch => _fileIds.length > 1;
  bool get _ready =>
      !_loading && _fileIds.isNotEmpty && _fileIds.every(_asked.contains);

  List<OfflineFileProfiles> get _currentFiles => [
        for (final id in _fileIds)
          if (_entries[id] != null) _entries[id]!,
      ];

  int get _missingCount => _fileIds.where((id) => _entries[id] == null).length;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    ref.read(offlineProvider.notifier).refreshStorage();
    try {
      final OfflineDownloadChoices resolved;
      if (widget.choices != null) {
        resolved = widget.choices!;
      } else if (widget.loadChoices != null) {
        resolved = await widget.loadChoices!();
      } else {
        resolved = OfflineDownloadChoices(
          scopes: [
            if (widget.fileId != null && widget.fileId! > 0)
              OfflineDownloadScope(
                id: 'file',
                label: widget.title,
                fileIds: [widget.fileId!],
                preferred: true,
              ),
          ],
        );
      }
      if (!mounted) return;
      final preferred = resolved.scopes.where((s) => s.preferred).firstOrNull ??
          resolved.scopes.firstOrNull;
      setState(() {
        _choices = resolved;
        _scopeId = preferred?.id;
      });

      final allIds = <int>[];
      for (final s in resolved.scopes) {
        for (final id in s.fileIds) {
          if (!allIds.contains(id)) allIds.add(id);
        }
      }
      if (allIds.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      try {
        final fetched =
            await ref.read(offlineProvider.notifier).fetchProfiles(allIds);
        if (!mounted) return;
        setState(() {
          _entries = fetched;
          _asked.addAll(allIds);
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        // 若服务器离线或报错，仅当传入了兜底档位且单文件时展示错误提示，避免展示虚假档位。
        setState(() {
          _error = e.toString();
          _asked.addAll(allIds);
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _effectiveProfile(OfflineFileProfiles first) {
    if (_selectedProfileId != null &&
        first.profiles.any((p) => p.id == _selectedProfileId)) {
      return _selectedProfileId!;
    }
    final last = ref.read(offlineProvider).lastProfile;
    if (last != null && first.profiles.any((p) => p.id == last)) {
      return last;
    }
    return first.profiles.isNotEmpty ? first.profiles.first.id : 'original';
  }

  static DownloadProfile? _pickProfile(
    String profileId,
    OfflineFileProfiles entry,
  ) {
    if (entry.profiles.isEmpty) return null;
    for (final p in entry.profiles) {
      if (p.id == profileId) return p;
    }
    return entry.profiles.first;
  }

  static int _totalBytes(String profileId, List<OfflineFileProfiles> files) {
    var sum = 0;
    for (final entry in files) {
      if (entry.unavailableReason != null &&
          entry.unavailableReason!.isNotEmpty) {
        continue;
      }
      sum += _pickProfile(profileId, entry)?.expectedBytes ?? 0;
    }
    return sum;
  }

  static bool _isEstimate(String profileId, List<OfflineFileProfiles> files) {
    return files.any((entry) {
      if (entry.unavailableReason != null &&
          entry.unavailableReason!.isNotEmpty) {
        return false;
      }
      return (_pickProfile(profileId, entry)?.id ?? 'original') != 'original';
    });
  }

  Future<void> _start() async {
    final files = _currentFiles
        .where(
          (f) => f.unavailableReason == null || f.unavailableReason!.isEmpty,
        )
        .toList();
    if (files.isEmpty) {
      setState(
        () => _startError = _currentFiles.firstOrNull?.unavailableReason ??
            '当前没有可下载的文件',
      );
      return;
    }
    final profileId = _effectiveProfile(files.first);
    final controller = ref.read(offlineProvider.notifier);

    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final lead = files.first;
      final leadManifest = await controller.fetchManifest(lead.fileId);
      final leadProfile = leadManifest.profiles
              .where((p) => p.id == profileId)
              .firstOrNull ??
          leadManifest.profiles.firstOrNull ??
          _pickProfile(profileId, lead);
      if (leadProfile == null) {
        setState(() {
          _starting = false;
          _startError = leadManifest.unavailableReason ?? '该文件不支持下载';
        });
        return;
      }
      await controller.startFromManifest(
        manifest: leadManifest,
        profile: leadProfile,
        fallbackTitle: widget.title,
      );

      var started = 1;
      var skipped = _missingCount + (_currentFiles.length - files.length);
      for (final entry in files.skip(1)) {
        final chosen = _pickProfile(profileId, entry);
        if (chosen == null) {
          skipped++;
          continue;
        }
        try {
          await controller.enqueueFromProfile(
            entry: entry,
            profile: chosen,
            title: leadManifest.itemTitle.isNotEmpty
                ? leadManifest.itemTitle
                : widget.title,
            kind: leadManifest.itemKind,
            libraryId: leadManifest.libraryId,
            libraryName: leadManifest.libraryName,
            posterUrl: leadManifest.itemPosterUrl,
            backdropUrl: leadManifest.itemBackdropUrl,
            year: leadManifest.itemYear,
          );
          started++;
        } catch (_) {
          skipped++;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      if (_isBatch) {
        McToast.success(
          skipped > 0 ? '已加入下载 $started 集，跳过 $skipped 集' : '已加入下载 $started 集',
        );
      } else {
        McToast.success('已开始离线下载');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final storage = offline.storage;
    final choices = _choices;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.titleSm,
                    ),
                    if (choices?.note != null && choices!.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        choices.note!,
                        style: McText.caption.muted,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              McGlassIconButton(
                icon: McIcons.close,
                size: 32,
                iconSize: 16,
                tooltip: '取消',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (choices != null && choices.scopes.isEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(McTokens.cardRadius),
                border: Border.all(color: McTokens.line),
              ),
              child: Row(
                children: [
                  Icon(
                    choices.hasLocal ? McIcons.checkCircleFill : McIcons.movie,
                    color: choices.hasLocal ? McTokens.ok : McTokens.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      choices.hasLocal
                          ? (choices.seasonLabel != null
                              ? '${choices.seasonLabel}的所有剧集都已下载或正在下载'
                              : '所有剧集都已下载或正在下载')
                          : (choices.seasonLabel != null
                              ? '${choices.seasonLabel}暂无可下载片源'
                              : '暂无可下载片源'),
                      style: McText.sub.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            if (_ranged && choices != null && choices.scopes.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (choices.seasonLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '下载范围 · ${choices.seasonLabel}',
                    style: McText.caption.muted,
                  ),
                ),
              if (choices.scopes.length > 1)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final scope in choices.scopes)
                      McChip(
                        label: scope.label,
                        selected: scope.id == _activeScope?.id,
                        onTap: () => setState(() {
                          _scopeId = scope.id;
                          _startError = null;
                        }),
                      ),
                  ],
                )
              else
                Text(choices.scopes.first.label, style: McText.sub.semibold),
              if (_activeScope?.detail != null &&
                  _activeScope!.detail!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _activeScope!.detail! +
                      (_ready && _missingCount > 0
                          ? '（跳过 $_missingCount 集无信息）'
                          : ''),
                  style: McText.caption.muted.tabular,
                ),
              ],
            ],
            const SizedBox(height: 12),
            if (!_ready)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: McTokens.accentStrong,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isBatch
                          ? '正在计算 ${_fileIds.length} 集的大小…'
                          : '正在读取可用画质…',
                      style: McText.sub.muted,
                    ),
                  ],
                ),
              )
            else if (_currentFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _error ?? '无法获取下载信息，请确认网络连接',
                  style: McText.sub.copyWith(color: McTokens.warning),
                ),
              )
            else
              _buildProfilesBody(storage, offline.allowCellular),
          ],
        ],
      ),
    );
  }

  Widget _buildProfilesBody(StorageInfo? storage, bool allowCellular) {
    final files = _currentFiles;
    final first = files.first;
    if (!_isBatch &&
        first.unavailableReason != null &&
        first.unavailableReason!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          first.unavailableReason!,
          style: McText.sub.copyWith(color: McTokens.warning),
        ),
      );
    }

    final selectedId = _effectiveProfile(first);
    final selectedTotal = _totalBytes(selectedId, files);
    final selectedEstimated = _isEstimate(selectedId, files);
    final neededBytes = selectedTotal + OfflineController.reserveBytes;
    final enoughSpace = storage == null ||
        selectedTotal <= 0 ||
        storage.availableBytes >= neededBytes;
    final canStart = !_starting &&
        first.profiles.isNotEmpty &&
        enoughSpace &&
        files.any(
          (f) => f.unavailableReason == null || f.unavailableReason!.isEmpty,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McInsetGroup(
          margin: EdgeInsets.zero,
          dividerIndent: 46,
          children: [
            for (final profile in first.profiles)
              _buildProfileRow(
                profile: profile,
                selected: profile.id == selectedId,
                totalBytes: _totalBytes(profile.id, files),
                isEstimate: _isEstimate(profile.id, files),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!enoughSpace)
          Text(
            '空间不够：需要 ${selectedEstimated ? '≈ ' : ''}${mcFormatBytes(neededBytes)}（含 2 GB 预留），本机可用 ${mcFormatBytes(storage.availableBytes)}',
            style: McText.caption.copyWith(color: McTokens.danger),
          )
        else
          Text(
            [
              if (storage != null)
                '本机可用 ${mcFormatBytes(storage.availableBytes)}',
              allowCellular ? '允许蜂窝网络下载' : '仅在 Wi-Fi 下下载',
            ].join(' · '),
            style: McText.caption.muted,
          ),
        if (_startError != null) ...[
          const SizedBox(height: 8),
          Text(
            _startError!,
            style: McText.caption.copyWith(color: McTokens.danger),
          ),
        ],
        const SizedBox(height: 16),
        McActionPill(
          label: _starting
              ? '正在加入队列…'
              : (_isBatch ? '开始下载（${_fileIds.length} 集）' : '开始下载'),
          icon: McIcons.fileDownload,
          primary: true,
          busy: _starting,
          expanded: true,
          height: 44,
          onTap: canStart ? _start : null,
        ),
      ],
    );
  }

  Widget _buildProfileRow({
    required DownloadProfile profile,
    required bool selected,
    required int totalBytes,
    required bool isEstimate,
  }) {
    final sizeText = totalBytes > 0
        ? '${_isBatch ? '共 ' : ''}${isEstimate ? '≈ ' : ''}${mcFormatBytes(totalBytes)}'
        : null;
    return McInsetRow(
      leading: Icon(
        selected ? McIcons.checkCircleFill : McIcons.circler,
        size: 20,
        color: selected ? McTokens.accentStrong : McTokens.textFaint,
      ),
      title: profile.label,
      subtitle: profile.isOriginal ? '与源文件完全一致' : '服务器转码后下载，体积更小',
      trailing: sizeText != null
          ? Text(sizeText, style: McText.caption.muted.tabular)
          : null,
      onTap: () => setState(() {
        _selectedProfileId = profile.id;
        _startError = null;
      }),
    );
  }
}
