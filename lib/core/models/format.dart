// 全局唯一格式化工具（对齐 Kotlin McFormat 口径）。
// 审核重构 #2：合并 settings/offline/activity/library 四份口径不一的实现。

/// 字节数（library 版为准：KB..PB，>=100 去小数，否则 1 位小数）。
String mcFormatBytes(num bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// 速度（B/s 起，同 mcFormatBytes 口径 + '/s'）。
String mcFormatSpeed(num bytesPerSec) => '${mcFormatBytes(bytesPerSec)}/s';

/// 秒 → h:mm:ss / mm:ss（player 时钟口径）。
String mcFormatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// 毫秒 → 「x 小时 y 分钟」（观看时长口径）。
String mcFormatWatched(int milliseconds) {
  final total = milliseconds ~/ 60000;
  if (total < 60) return '$total 分钟';
  return '${total ~/ 60} 小时 ${total % 60} 分钟';
}

/// 集数标签 S01E02（season/episode 为 1 起；任一无效返回 '--'）。
String mcEpisodeLabel(int? season, int? episode) {
  if (season == null || episode == null) return '--';
  String two(int v) => v.toString().padLeft(2, '0');
  return 'S${two(season)}E${two(episode)}';
}
