import 'dart:async';

/// 防抖 + 请求序号守卫（审核重构 #5：search/discover 两份同构实现下沉）。
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() => _timer?.cancel();
}

/// 请求序号守卫：异步返回时用 [isCurrent] 判断是否仍为最新一次请求。
class SeqGuard {
  int _seq = 0;

  int get next => ++_seq;

  bool isCurrent(int seq) => seq == _seq;
}
