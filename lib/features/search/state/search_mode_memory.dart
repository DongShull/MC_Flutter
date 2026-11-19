// IMPLEMENTED — 1:1 重写自 MovieClaw feature/search/SearchModeMemory.kt。
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索页持久化（本机 SharedPreferences）：
/// - last_mode：上次停留的分区（进搜索时预选，不改写用户记过的资源分类）；
/// - 历史记录 mc_search_history：最近 20 条搜索词。
class SearchModeMemory {
  SearchModeMemory._();

  static final SearchModeMemory instance = SearchModeMemory._();

  static const _modeKey = 'mc_search_mode';
  static const _historyKey = 'mc_search_history';
  static const _maxHistory = 20;

  String? _mode;
  bool _loaded = false;

  /// 上次停留的分区；还没读过盘时为 null（调用方按库内起步）。
  String? get mode => _mode;

  /// 冷启动读一次（幂等）。
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_modeKey);
    _loaded = true;
  }

  Future<void> remember(String mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode);
  }

  Future<List<String>> readHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? const [];
  }

  /// 追加（去重、最新在前、封顶 20），返回新列表。
  Future<List<String>> appendHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return readHistory();
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getStringList(_historyKey) ?? <String>[];
    final next = [q, ...old.where((e) => e != q)].take(_maxHistory).toList();
    await prefs.setStringList(_historyKey, next);
    return next;
  }

  Future<List<String>> removeHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getStringList(_historyKey) ?? <String>[];
    final next = old.where((e) => e != query).toList();
    await prefs.setStringList(_historyKey, next);
    return next;
  }

  Future<List<String>> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, const []);
    return const [];
  }
}
