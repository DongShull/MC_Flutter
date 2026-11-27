import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/llm_capability_probe.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// AI 字幕生成全流程弹层（1:1 对齐 iOS `TrackSubtitleGen.swift`）：
/// - 探测 `LlmCapabilityProbe`（未接入模型时引导去接入）；
/// - 打开即调用 `generation-preview` 展示候选参考轨、PGS/VobSub OCR 语言确认、预计对白数与 Token 成本；
/// - 提交后留在弹层，通过 `McSseClient` 订阅 `/api/v1/jobs/stream`（+ 轮询兜底）实时渲染 5 阶段进度与停止任务按钮；
/// - 底部提供「交给智能体处理」按钮（`startAgentSession` 携带文件路径与 CLI 参数直达 Agent 会话）。
Future<void> showSubtitleGenSheet({
  required BuildContext context,
  required DetailController controller,
  int? fileId,
  DetailFileInfo? file,
  String? label,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 600,
    builder: (_) => _SubtitleGenSheet(
      controller: controller,
      fileId: fileId,
      file: file,
      label: label,
    ),
  );
}

class _SubtitleGenSheet extends ConsumerStatefulWidget {
  const _SubtitleGenSheet({
    required this.controller,
    this.fileId,
    this.file,
    this.label,
  });

  final DetailController controller;
  final int? fileId;
  final DetailFileInfo? file;
  final String? label;

  @override
  ConsumerState<_SubtitleGenSheet> createState() => _SubtitleGenSheetState();
}

enum _GenMode { preview, status }

class _SubtitleGenSheetState extends ConsumerState<_SubtitleGenSheet> {
  static const _outputLanguages = <(String, String)>[
    ('chs', '简体中文'),
    ('cht', '繁体中文'),
    ('eng', '英语'),
    ('jpn', '日语'),
    ('kor', '韩语'),
    ('fre', '法语'),
    ('ger', '德语'),
    ('spa', '西班牙语'),
    ('ita', '意大利语'),
    ('por', '葡萄牙语'),
    ('rus', '俄语'),
    ('tha', '泰语'),
  ];

  static const _stages = <(List<String>, String)>[
    (['preparing', 'extracting', 'ocr', 'syncing'], '准备与抽取参考字幕'),
    (['glossary'], '术语表与专有名词分析'),
    (['translating'], '大模型分块轴译'),
    (['validating', 'compressing'], '质量校验与断行压缩'),
    (['writing', 'refreshing'], '落盘并刷新媒体库'),
  ];

  static const _runningStatuses = {
    'queued',
    'running',
    'retry_wait',
    'cancelling',
    'waiting',
  };

  _GenMode _mode = _GenMode.preview;
  String _target = 'chs';
  bool _bilingual = false;
  String _secondary = 'eng';
  String? _sourceKey;
  String _pgsOcrLanguage = '';

  Map<String, dynamic>? _preview;
  bool _previewing = false;
  String? _pendingNotice;
  String? _error;

  Map<String, dynamic>? _job;
  bool _starting = false;
  bool _stopping = false;
  bool _agentStarting = false;

  int _previewSeq = 0;
  Timer? _pendingTimer;
  Timer? _pollTimer;
  StreamSubscription<SseEvent>? _sseSub;
  Timer? _sseDebounce;

  int? get _effectiveFileId =>
      widget.fileId ?? widget.file?.id ?? widget.controller.leadFileId;

  DetailFileInfo? get _effectiveFile {
    if (widget.file != null) return widget.file;
    final id = _effectiveFileId;
    if (id == null) return null;
    for (final f in widget.controller.current.entry?.files ?? const <DetailFileInfo>[]) {
      if (f.id == id) return f;
    }
    return null;
  }

  bool get _jobRunning {
    final s = (_job?['status'] ?? '').toString();
    return _runningStatuses.contains(s);
  }

  bool get _jobSucceeded => (_job?['status'] ?? '').toString() == 'succeeded';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final client = ref.read(mcClientProvider);
      unawaited(ref.read(llmCapabilityProbeProvider).ensure(client));
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _pollTimer?.cancel();
    _sseDebounce?.cancel();
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final fid = _effectiveFileId;
    if (fid == null) {
      setState(() => _error = '没有在位媒体文件，无法生成字幕');
      return;
    }
    final latest = await widget.controller.fetchLatestSubtitleJob(fid);
    if (!mounted) return;
    if (latest != null && _runningStatuses.contains((latest['status'] ?? '').toString())) {
      setState(() {
        _job = latest;
        _mode = _GenMode.status;
      });
      _startJobTracking(fid);
      return;
    }
    await _loadPreview();
  }

  Future<void> _loadPreview({String? sourceKey}) async {
    final fid = _effectiveFileId;
    if (fid == null) return;
    _pendingTimer?.cancel();
    final seq = ++_previewSeq;
    setState(() {
      _mode = _GenMode.preview;
      _preview = null;
      _previewing = true;
      _pendingNotice = null;
      _error = null;
      _pgsOcrLanguage = '';
    });

    try {
      final res = await widget.controller.previewSubtitleGen(
        fileId: fid,
        targetLanguage: _target,
        secondaryLanguage: _bilingual ? _secondary : null,
        sourceCandidateKey: sourceKey,
      );
      if (!mounted || seq != _previewSeq) return;

      final pending = res['pending'];
      if (pending is Map) {
        final pm = pending.cast<String, dynamic>();
        final msg = J.s(pm, ['message']) ?? '正在抽取内封字幕轨道…';
        final retryMs = (J.i(pm, ['retry_after_ms']) ?? 2000).clamp(1000, 15000);
        setState(() => _pendingNotice = msg);
        _pendingTimer = Timer(
          Duration(milliseconds: retryMs),
          () => _loadPreview(sourceKey: sourceKey),
        );
        return;
      }

      final pgs = res['pgs_conversion'] is Map
          ? (res['pgs_conversion'] as Map).cast<String, dynamic>()
          : null;
      setState(() {
        _preview = res;
        _sourceKey = J.s(res, ['selected_source_key']) ?? _sourceKey;
        _pgsOcrLanguage = J.s(pgs ?? const {}, ['ocr_language']) ?? '';
        _previewing = false;
        _pendingNotice = null;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _error = e.friendlyMessage;
        _previewing = false;
        _pendingNotice = null;
      });
    } catch (e) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _error = '预检失败：$e';
        _previewing = false;
        _pendingNotice = null;
      });
    }
  }

  String _nextSecondary(String target, String current) {
    if (target != current) return current;
    for (final (code, _) in _outputLanguages) {
      if (code != target) return code;
    }
    return 'eng';
  }

  String _langLabel(String? code) {
    if (code == null || code.isEmpty) return '未知语言';
    final lower = code.toLowerCase();
    for (final (k, v) in _outputLanguages) {
      if (k == lower) return v;
    }
    if (lower == 'chi' || lower == 'zho' || lower == 'cmn') return '中文';
    if (lower == 'fra') return '法语';
    if (lower == 'deu') return '德语';
    return code.toUpperCase();
  }

  String _outputLabel(String target, String? secondary) {
    final p = _langLabel(target);
    if (secondary == null || secondary.isEmpty) return p;
    return '$p + ${_langLabel(secondary)} 双语';
  }

  String _candidateKey(Map<String, dynamic> c) =>
      '${c['kind'] ?? ''}:${c['key'] ?? ''}';

  String _candidateLabel(Map<String, dynamic> c) {
    final kind = (c['kind'] ?? '').toString();
    final key = (c['key'] ?? '').toString();
    final embedded = kind == 'embedded';
    final location = embedded ? '内封' : '外挂';
    final idx = int.tryParse(key);
    final identity = embedded && idx != null ? '轨 ${idx + 1}' : key;
    final ocr = c['requires_ocr'] == true ? ' (需 OCR)' : '';
    final prov = switch ((c['provenance'] ?? '').toString()) {
      'original' => '原始',
      'pgs_ocr' => 'PGS OCR',
      'ai' => 'AI 生成',
      'ai_bilingual' => 'AI 双语',
      final s => s,
    };
    final fmt = switch ((c['format'] ?? '').toString().toLowerCase()) {
      'hdmv_pgs_subtitle' => 'PGS',
      'dvd_subtitle' => 'VobSub',
      'subrip' || 'srt' => 'SRT',
      'ass' => 'ASS',
      'ssa' => 'SSA',
      'webvtt' || 'vtt' => 'VTT',
      final s => s.isEmpty ? '字幕' : s.toUpperCase(),
    };
    return '${_langLabel(c['language']?.toString())} · $fmt · $prov · $location $identity$ocr';
  }

  bool get _canPreparePgs {
    final p = _preview;
    if (p == null) return false;
    final blocker = p['blocker'] is Map
        ? (p['blocker'] as Map).cast<String, dynamic>()
        : null;
    final pgs = p['pgs_conversion'] is Map
        ? (p['pgs_conversion'] as Map).cast<String, dynamic>()
        : null;
    return blocker?['code'] == 'pgs_conversion_required' &&
        pgs?['available'] == true;
  }

  bool get _canConvertPgs {
    if (!_canPreparePgs) return false;
    final pgs = (_preview!['pgs_conversion'] as Map).cast<String, dynamic>();
    final needConfirm = pgs['language_confirmation_required'] == true;
    return !needConfirm || _pgsOcrLanguage.isNotEmpty;
  }

  bool get _blockedWithoutPgs =>
      _preview?['blocker'] is Map && !_canPreparePgs;

  Map<String, dynamic>? get _chosenCandidate {
    final p = _preview;
    if (p == null) return null;
    final chosenKey = J.s(p, ['chosen_key']);
    if (chosenKey == null) return null;
    for (final c in J.listOfMap(p, ['candidates'])) {
      if (_candidateKey(c) == chosenKey) return c;
    }
    return null;
  }

  bool get _canStart {
    if (_previewing || _starting || _preview == null) return false;
    if (_canPreparePgs) return _canConvertPgs;
    return _preview!['blocker'] == null && _chosenCandidate != null;
  }

  Future<void> _startGeneration() async {
    final fid = _effectiveFileId;
    if (fid == null || !_canStart) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    final convertPgs = _canPreparePgs;
    try {
      final job = await widget.controller.startSubtitleGenJob(
        fileId: fid,
        targetLanguage: _target,
        secondaryLanguage: _bilingual ? _secondary : null,
        sourceCandidateKey: _sourceKey,
        convertPgs: convertPgs,
        pgsOcrLanguage:
            convertPgs && _pgsOcrLanguage.isNotEmpty ? _pgsOcrLanguage : null,
      );
      if (!mounted) return;
      setState(() {
        _job = job;
        _starting = false;
        _mode = _GenMode.status;
      });
      _startJobTracking(fid);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.friendlyMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = '提交生成失败：$e';
      });
    }
  }

  void _startJobTracking(int fileId) {
    _stopJobTracking();
    // 1. 订阅 /api/v1/jobs/stream SSE，收到 ready/job 事件去抖 120ms 刷新当前任务
    final session = ref.read(sessionStoreProvider);
    final sse = McSseClient(session);
    _sseSub = sse.stream('/api/v1/jobs/stream', autoReconnect: true).listen(
      (event) {
        if (event.name == 'ready' || event.name == 'job') {
          _sseDebounce?.cancel();
          _sseDebounce = Timer(
            const Duration(milliseconds: 120),
            () => _refreshJob(fileId),
          );
        }
      },
      onError: (_) {
        // SSE 不受支持或网络中断时自动依靠下方轮询兜底
      },
    );
    // 2. 3 秒定时轮询兜底，保证无 SSE 环境依然实时推进 5 阶段进度
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshJob(fileId),
    );
  }

  void _stopJobTracking() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseDebounce?.cancel();
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refreshJob(int fileId) async {
    final prevStatus = (_job?['status'] ?? '').toString();
    final prevId = (_job?['id'] ?? '').toString();
    final next = prevId.isNotEmpty
        ? (await widget.controller.fetchJob(prevId) ??
            await widget.controller.fetchLatestSubtitleJob(fileId))
        : await widget.controller.fetchLatestSubtitleJob(fileId);
    if (!mounted || next == null) return;

    final nextStatus = (next['status'] ?? '').toString();
    setState(() => _job = next);

    if (!_runningStatuses.contains(nextStatus)) {
      _stopJobTracking();
      if (_runningStatuses.contains(prevStatus) && nextStatus == 'succeeded') {
        unawaited(widget.controller.load(silent: true));
      }
    }
  }

  Future<void> _cancelJob() async {
    final jobId = (_job?['id'] ?? '').toString();
    if (jobId.isEmpty || _stopping) return;
    setState(() {
      _stopping = true;
      _error = null;
    });
    try {
      final updated = await widget.controller.cancelJob(jobId);
      if (!mounted) return;
      setState(() {
        _stopping = false;
        if (updated != null) _job = updated;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stopping = false;
        _error = e.friendlyMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stopping = false;
        _error = '停止任务失败：$e';
      });
    }
  }

  Future<void> _handOffToAgent(String reason) async {
    final fid = _effectiveFileId;
    if (fid == null || _agentStarting) return;
    setState(() {
      _agentStarting = true;
      _error = null;
    });
    final f = _effectiveFile;
    final secondary = _bilingual ? _secondary : null;
    final params = StringBuffer('--target-language $_target');
    if (secondary != null && secondary.isNotEmpty) {
      params.write(' --secondary-language $secondary');
    }
    if (_sourceKey != null && _sourceKey!.isNotEmpty) {
      params.write(' --source-candidate-key $_sourceKey');
    }
    final lines = <String>[
      '请帮我处理这个媒体文件的 AI 字幕生成问题：',
      '文件名：${f?.fileName ?? widget.label ?? 'file#$fid'}',
      '文件 ID：$fid',
      if (f != null && f.filePath.isNotEmpty) '文件路径：${f.filePath}',
      '期望输出：${_outputLabel(_target, secondary)}',
      '参考 CLI 参数：$params',
      '当前问题：$reason',
      '请先检查该文件的字幕轨道与环境能力，再给出可行方案或协助完成字幕生成。',
    ];
    try {
      final sid = await widget.controller.startAgentSession(lines.join('\n'));
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/agent/session/${Uri.encodeComponent(sid)}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _agentStarting = false;
        _error = e.friendlyMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agentStarting = false;
        _error = '转交智能体失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final probe = ref.watch(llmCapabilityProbeProvider);
    final headerTitle = _mode == _GenMode.status
        ? (_jobRunning
            ? '正在生成 · ${_outputLabel(_target, _bilingual ? _secondary : null)}'
            : '字幕生成结果')
        : (widget.label != null ? 'AI 字幕 · ${widget.label}' : 'AI 生成智能字幕');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  McIcons.aiStarFill,
                  size: 18,
                  color: McTokens.accentStrong,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(headerTitle, style: McText.titleSm)),
                if (!_starting && !_agentStarting)
                  McGlassIconButton(
                    icon: McIcons.close,
                    iconSize: 16,
                    onTap: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListenableBuilder(
                listenable: probe,
                builder: (context, _) {
                  if (_mode == _GenMode.preview &&
                      probe.state == LlmCapabilityState.missing) {
                    return _buildMissingLlmCard();
                  }
                  return SingleChildScrollView(
                    child: _mode == _GenMode.status
                        ? _buildStatusBody()
                        : _buildPreviewBody(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingLlmCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: McTokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '尚未接入 AI 大模型',
            style: McText.ui.copyWith(
              color: McTokens.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '请先在「设置 → AI 模型」中配置至少一个可用的模型供应商，即可解锁单语 / 双语 AI 字幕生成。',
            style: McText.caption.muted,
          ),
          const SizedBox(height: 16),
          McActionPill(
            label: '前往接入大模型',
            icon: McIcons.setting1,
            primary: true,
            expanded: true,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings/ai?section=llm');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBody() {
    final p = _preview;
    final candidates = p == null ? const <Map<String, dynamic>>[] : J.listOfMap(p, ['candidates']);
    final blocker = p?['blocker'] is Map
        ? (p!['blocker'] as Map).cast<String, dynamic>()
        : null;
    final pgs = p?['pgs_conversion'] is Map
        ? (p!['pgs_conversion'] as Map).cast<String, dynamic>()
        : null;
    final chosen = _chosenCandidate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('目标字幕语言', style: McText.caption.muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, name) in _outputLanguages.take(6))
              McChip(
                label: name,
                compact: true,
                selected: _target == code,
                onTap: _starting
                    ? null
                    : () {
                        setState(() {
                          _target = code;
                          _secondary = _nextSecondary(code, _secondary);
                        });
                        unawaited(_loadPreview());
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),
        McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              title: '生成双语对照字幕',
              subtitle: _bilingual
                  ? '主语言 ${_langLabel(_target)} + 副语言 ${_langLabel(_secondary)}'
                  : '同时保留外语原文字幕，上下双行展示',
              trailing: Switch(
                value: _bilingual,
                onChanged: _starting
                    ? null
                    : (v) {
                        setState(() {
                          _bilingual = v;
                          _secondary = _nextSecondary(_target, _secondary);
                        });
                        unawaited(_loadPreview());
                      },
              ),
              onTap: _starting
                  ? null
                  : () {
                      setState(() {
                        _bilingual = !_bilingual;
                        _secondary = _nextSecondary(_target, _secondary);
                      });
                      unawaited(_loadPreview());
                    },
            ),
          ],
        ),
        if (_bilingual) ...[
          const SizedBox(height: 10),
          Text('双语副语言', style: McText.caption.muted),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, name)
                  in _outputLanguages.where((e) => e.$1 != _target).take(6))
                McChip(
                  label: name,
                  compact: true,
                  selected: _secondary == code,
                  onTap: _starting
                      ? null
                      : () {
                          setState(() => _secondary = code);
                          unawaited(_loadPreview());
                        },
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (_previewing)
          _box(
            McTokens.surfaceRaised,
            McTokens.line,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: McTokens.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pendingNotice ?? '正在预检候选字幕轨与估算成本…',
                        style: McText.sub.copyWith(color: McTokens.text),
                      ),
                      if (_pendingNotice != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '内封轨首次读取需扫描容器，完成后自动缓存。',
                          style: McText.micro.muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (candidates.isNotEmpty) ...[
            Text('参考源字幕轨', style: McText.caption.muted),
            const SizedBox(height: 6),
            McInsetGroup(
              margin: EdgeInsets.zero,
              dividerIndent: 14,
              children: [
                for (final c in candidates)
                  Builder(
                    builder: (_) {
                      final key = _candidateKey(c);
                      final selectable = c['selectable'] != false;
                      final selected = key == _sourceKey;
                      final excluded = J.s(c, ['excluded']);
                      return Opacity(
                        opacity: selectable ? 1.0 : 0.45,
                        child: McInsetRow(
                          leading: Icon(
                            selected
                                ? McIcons.checkCircleFill
                                : McIcons.circler,
                            size: 18,
                            color: selected
                                ? McTokens.accentStrong
                                : McTokens.textFaint,
                          ),
                          title: _candidateLabel(c),
                          subtitle: !selectable && excluded != null
                              ? '不可用：$excluded'
                              : null,
                          onTap: !selectable || _starting
                              ? null
                              : () {
                                  setState(() => _sourceKey = key);
                                  unawaited(_loadPreview(sourceKey: key));
                                },
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_canPreparePgs && pgs != null) ...[
            _buildPgsSection(pgs),
            const SizedBox(height: 12),
          ],
          if (_blockedWithoutPgs && blocker != null) ...[
            _buildBlockerSection(blocker, pgs),
            const SizedBox(height: 12),
          ],
          if (p != null && blocker == null && chosen != null) ...[
            _buildChosenSummary(p, chosen),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            _box(
              McTokens.danger.withValues(alpha: 0.08),
              McTokens.danger.withValues(alpha: 0.3),
              Text(
                _error!,
                style: McText.caption.copyWith(color: McTokens.danger),
              ),
            ),
            const SizedBox(height: 12),
          ],
          McActionPill(
            label: _starting
                ? '正在启动生成…'
                : (_canPreparePgs
                    ? '先 OCR 识别并生成字幕'
                    : '确认开始生成 · ${_outputLabel(_target, _bilingual ? _secondary : null)}'),
            icon: McIcons.aiStarFill,
            primary: true,
            expanded: true,
            height: 44,
            busy: _starting,
            onTap: _canStart ? _startGeneration : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_blockedWithoutPgs || _error != null) ...[
                Expanded(
                  child: McActionPill(
                    label: '重新预检',
                    icon: McIcons.refreshS,
                    primary: false,
                    expanded: true,
                    onTap: () => _loadPreview(sourceKey: _sourceKey),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: McActionPill(
                  label: _agentStarting ? '正在转交…' : '交给智能体处理',
                  icon: McIcons.aiSearch2,
                  primary: false,
                  expanded: true,
                  busy: _agentStarting,
                  onTap: _agentStarting
                      ? null
                      : () => _handOffToAgent(
                            _error ??
                                J.s(blocker ?? const {}, ['message']) ??
                                '请协助为该媒体文件生成 ${_outputLabel(_target, _bilingual ? _secondary : null)} 字幕',
                          ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPgsSection(Map<String, dynamic> pgs) {
    final needConfirm = pgs['language_confirmation_required'] == true;
    final options = J.listOfMap(pgs, ['language_options']);
    final detectedLabel = J.s(pgs, ['ocr_language_label']) ?? '自动识别';

    return _box(
      McTokens.warning.withValues(alpha: 0.08),
      McTokens.warning.withValues(alpha: 0.32),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needConfirm ? '需要确认图片字幕（PGS/VobSub）原语言' : '将先执行 OCR 文字识别再翻译',
            style: McText.sub.copyWith(
              color: McTokens.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '所选参考轨是图形字幕，系统会先调用本地 OCR 引擎识别出文字时间轴，再翻译为目标语言。',
            style: McText.caption.muted,
          ),
          const SizedBox(height: 10),
          if (needConfirm && options.isNotEmpty) ...[
            Text('选择图片字幕原语言：', style: McText.micro.faint),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final opt in options)
                  McChip(
                    label: (opt['label'] ?? opt['code'] ?? '').toString(),
                    compact: true,
                    selected: _pgsOcrLanguage == (opt['code'] ?? '').toString(),
                    onTap: () => setState(
                      () => _pgsOcrLanguage = (opt['code'] ?? '').toString(),
                    ),
                  ),
              ],
            ),
          ] else
            Text(
              '识别原语言：$detectedLabel',
              style: McText.caption.copyWith(color: McTokens.text),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockerSection(
    Map<String, dynamic> blocker,
    Map<String, dynamic>? pgs,
  ) {
    final title = J.s(blocker, ['title']) ?? '暂无法直接生成字幕';
    final msg = J.s(blocker, ['message']) ?? '';
    final suggestions = J.list(blocker, ['suggestions']);
    return _box(
      McTokens.danger.withValues(alpha: 0.08),
      McTokens.danger.withValues(alpha: 0.32),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: McText.sub.copyWith(
              color: McTokens.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(msg, style: McText.caption.copyWith(color: McTokens.text)),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $s', style: McText.caption.muted),
              ),
          ],
          if (pgs != null && J.s(pgs, ['message']) != null) ...[
            const SizedBox(height: 8),
            Text(
              '诊断：${pgs['platform'] ?? ''} ${pgs['architecture'] ?? ''} · '
              '${pgs['engine'] ?? '无可用引擎'} · ${pgs['message']}',
              style: McText.micro.faint,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChosenSummary(
    Map<String, dynamic> preview,
    Map<String, dynamic> chosen,
  ) {
    final eventCount = J.i(preview, ['event_count']) ?? 0;
    final tokens = J.i(preview, ['estimated_tokens']) ?? 0;
    final refNotice = J.s(preview, ['reference_notice']);
    final outputName = J.s(preview, ['output_filename']);
    final alreadyGen = preview['already_generated'] == true;

    String tokenStr(int t) {
      if (t <= 0) return '读取后估算';
      if (t < 1000) return '约 $t token';
      return '约 ${(t / 1000).toStringAsFixed(t < 10000 ? 1 : 0)}k token';
    }

    final costLine = refNotice != null
        ? (tokens > 0 ? '按片长粗估：${tokenStr(tokens)}' : '读取内封轨后估算 Token 消耗')
        : '共 $eventCount 条对白 · 预计消耗 ${tokenStr(tokens)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _box(
          McTokens.surfaceRaised,
          McTokens.line,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_candidateLabel(chosen)}  →  '
                '${_outputLabel(_target, _bilingual ? _secondary : null)}',
                style: McText.sub.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(costLine, style: McText.caption.muted.tabular),
              if (outputName != null && outputName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '输出文件：$outputName',
                  style: McText.micro.faint,
                ),
              ],
            ],
          ),
        ),
        if (refNotice != null && refNotice.isNotEmpty) ...[
          const SizedBox(height: 8),
          _box(
            McTokens.info.withValues(alpha: 0.08),
            McTokens.info.withValues(alpha: 0.3),
            Text(
              refNotice,
              style: McText.caption.copyWith(color: McTokens.info),
            ),
          ),
        ],
        if (alreadyGen) ...[
          const SizedBox(height: 8),
          _box(
            McTokens.warning.withValues(alpha: 0.08),
            McTokens.warning.withValues(alpha: 0.3),
            Text(
              '该目标语言已存在 AI 生成字幕，重新生成将覆盖旧文件。',
              style: McText.caption.copyWith(color: McTokens.warning),
            ),
          ),
        ],
      ],
    );
  }

  /// 5 阶段实时进度状态视图（提交后留在弹层内实时展示）。
  Widget _buildStatusBody() {
    final job = _job;
    if (job == null) return const SizedBox(height: 120, child: McLoadingView());

    final progressMap = J.map(job, 'progress');
    final details = J.map(progressMap, 'details');
    final usage = J.map(job, 'usage');
    final phase = J.s(progressMap, ['phase']) ?? 'preparing';
    final message = J.s(progressMap, ['message']) ?? '正在准备字幕生成任务…';
    final percent = J.d(progressMap, ['percent']);
    final doneBlocks = J.i(details, ['done_blocks']) ?? 0;
    final totalBlocks = J.i(details, ['total_blocks']) ?? 0;
    final doneEvents = J.i(details, ['done_events']) ?? 0;
    final totalEvents = J.i(details, ['total_events']) ?? 0;
    final modelRequests = J.i(usage, ['request_count']) ?? 0;
    final modelTokens = J.i(usage, ['total_tokens']) ?? 0;
    final usesOcr = details['uses_ocr'] == true;
    final rateLimits = J.i(details, ['rate_limit_count']) ?? 0;
    final retries = J.i(details, ['validation_retries']) ?? 0;

    var stageIdx = 0;
    for (var i = 0; i < _stages.length; i++) {
      if (_stages[i].$1.contains(phase)) {
        stageIdx = i;
        break;
      }
    }

    final startedAt = DateTime.tryParse(J.s(job, ['started_at']) ?? '');
    final elapsedSec = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inSeconds.clamp(0, 1 << 30);
    final elapsedStr = elapsedSec < 60
        ? '$elapsedSec 秒'
        : '${elapsedSec ~/ 60} 分 ${elapsedSec % 60} 秒';

    final errMap = J.map(job, 'error');
    final resMap = J.map(job, 'result');
    final endMessage = J.s(errMap, ['message']) ??
        J.s(resMap, ['message']) ??
        (_jobSucceeded ? '字幕已生成并写入媒体目录' : '任务已结束');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_jobRunning) ...[
          _box(
            McTokens.surfaceRaised,
            McTokens.line,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: McText.sub.copyWith(
                          color: McTokens.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (percent != null)
                      Text(
                        '${percent.floor().clamp(0, 100)}%',
                        style: McText.sub
                            .copyWith(
                              color: McTokens.info,
                              fontWeight: FontWeight.w600,
                            )
                            .tabular,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent != null
                        ? (percent / 100.0).clamp(0.02, 1.0)
                        : null,
                    minHeight: 5,
                    backgroundColor: const Color(0x26FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(McTokens.info),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (totalBlocks > 0)
                      Text(
                        '分块 $doneBlocks/$totalBlocks',
                        style: McText.micro.muted.tabular,
                      ),
                    if (totalEvents > 0)
                      Text(
                        '对白 $doneEvents/$totalEvents',
                        style: McText.micro.muted.tabular,
                      ),
                    if (modelRequests > 0)
                      Text(
                        '请求 $modelRequests 次'
                        '${modelTokens > 0 ? ' · $modelTokens token' : ''}',
                        style: McText.micro.muted.tabular,
                      ),
                    Text('已耗时 $elapsedStr', style: McText.micro.muted.tabular),
                  ],
                ),
                if (rateLimits > 0 || retries > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (rateLimits > 0) '触发限流重试 $rateLimits 次',
                      if (retries > 0) '格式校验重试 $retries 次',
                    ].join(' · '),
                    style: McText.micro.copyWith(color: McTokens.warning),
                  ),
                ],
                const SizedBox(height: 14),
                for (var i = 0; i < _stages.length; i++) ...[
                  _stageRow(
                    index: i,
                    label: (i == 0 && usesOcr) ? 'PGS/VobSub OCR 识别' : _stages[i].$2,
                    completed: i < stageIdx,
                    current: i == stageIdx,
                  ),
                  if (i < _stages.length - 1) const SizedBox(height: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          McActionPill(
            label: _stopping ? '正在停止任务…' : '停止生成任务',
            icon: McIcons.stopFilled,
            primary: false,
            tone: McGlassTone.danger,
            expanded: true,
            busy: _stopping,
            onTap: _stopping ? null : _cancelJob,
          ),
        ] else ...[
          _box(
            (_jobSucceeded ? McTokens.ok : McTokens.danger)
                .withValues(alpha: 0.08),
            (_jobSucceeded ? McTokens.ok : McTokens.danger)
                .withValues(alpha: 0.32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _jobSucceeded ? McIcons.checkCircleFill : McIcons.alert1,
                  size: 18,
                  color: _jobSucceeded ? McTokens.ok : McTokens.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _jobSucceeded ? 'AI 字幕生成完成' : '字幕生成未完成',
                        style: McText.sub.copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(endMessage, style: McText.caption.muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_jobSucceeded)
            McActionPill(
              label: '完成',
              primary: true,
              expanded: true,
              onTap: () => Navigator.of(context).pop(),
            )
          else
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '重新预检',
                    icon: McIcons.refreshS,
                    primary: false,
                    expanded: true,
                    onTap: () => _loadPreview(sourceKey: _sourceKey),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: McActionPill(
                    label: _agentStarting ? '正在转交…' : '交给智能体处理',
                    icon: McIcons.aiSearch2,
                    primary: true,
                    expanded: true,
                    busy: _agentStarting,
                    onTap: _agentStarting
                        ? null
                        : () => _handOffToAgent(endMessage),
                  ),
                ),
              ],
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: McText.caption.copyWith(color: McTokens.danger),
          ),
        ],
      ],
    );
  }

  Widget _stageRow({
    required int index,
    required String label,
    required bool completed,
    required bool current,
  }) {
    final fg = current
        ? McTokens.info
        : completed
            ? Colors.white.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.34);
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current
                ? McTokens.info.withValues(alpha: 0.16)
                : completed
                    ? McTokens.ok.withValues(alpha: 0.14)
                    : Colors.transparent,
            border: Border.all(
              color: current
                  ? McTokens.info
                  : completed
                      ? McTokens.ok.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            completed ? '✓' : '${index + 1}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: completed
                  ? McTokens.ok
                  : current
                      ? McTokens.info
                      : McTokens.textFaint,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: McText.caption.copyWith(
              color: fg,
              fontWeight: current ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (current)
          Text('进行中', style: McText.micro.copyWith(color: McTokens.textMuted)),
      ],
    );
  }

  Widget _box(Color bg, Color border, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: child,
      );
}
