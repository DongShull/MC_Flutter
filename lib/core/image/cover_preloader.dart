import 'package:flutter/widgets.dart';

/// 封面预加载管线（对齐飞牛 preloadArtwork，docs/design/09 §3.3）。
/// precacheImage 队列：并发上限 4、URL 去重；library/discover/reels
/// 在网格进入/翻页前把下一屏封面喂进来，用户滚动时零等待。
class CoverPreloader {
  CoverPreloader._();

  static const maxConcurrency = 4;

  static final Set<String> _pending = {};
  static final Set<String> _done = {};
  static final List<String> _queue = [];
  static Element? _host;
  static int _running = 0;

  /// 预加载一批封面 URL。首个调用方的 context 作为下载宿主。
  static void preload(BuildContext context, Iterable<String?> urls) {
    _host ??= context as Element;
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      if (_done.contains(url) || _pending.contains(url)) continue;
      _pending.add(url);
      _queue.add(url);
    }
    _drain();
  }

  static void _drain() {
    final host = _host;
    if (host == null || !host.mounted) {
      _queue.clear();
      return;
    }
    while (_running < maxConcurrency && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      _running += 1;
      // precacheImage 在宿主 element 上执行；异步回调不再触碰 BuildContext。
      precacheImage(NetworkImage(url), host).then((_) {
        _done.add(url);
      }).catchError((_) {
        // 失败不重试（交给真正的 Image 组件自己加载）。
      }).whenComplete(() {
        _pending.remove(url);
        _running -= 1;
        if (_queue.isNotEmpty) _drain();
      });
    }
  }

  /// 测试用：清空全部状态。
  static void reset() {
    _pending.clear();
    _done.clear();
    _queue.clear();
    _host = null;
    _running = 0;
  }

  /// 诊断：当前队列长度。
  static int get queued => _queue.length;
}
