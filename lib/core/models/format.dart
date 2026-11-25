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

/// 两位补零（鸿蒙 Formatters.pad2）。
String mcPad2(int v) => v.toString().padLeft(2, '0');

/// 相对时间（鸿蒙 Formatters.fromNow = dayjs 口径）：
/// ≤44 秒「几秒」、≤89 秒「1 分钟」、≤44 分「N 分钟」、≤89 分「1 小时」、≤21 时「N 小时」、
/// ≤35 时「1 天」、≤25 天「N 天」、≤45 天「1 个月」、≤10 月「N 个月」、≤17 月「1 年」、再往后「N 年」。
String mcFromNow(DateTime date, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final delta = ref.difference(date).inMilliseconds;
  final seconds = delta.abs() / 1000;
  final days = seconds / 86400;
  final months = days / 30.4375;
  String text;
  if (seconds <= 44) {
    text = '几秒';
  } else if (seconds <= 89) {
    text = '1 分钟';
  } else if (seconds <= 44 * 60) {
    text = '${(seconds / 60).round().clamp(1, 1 << 30)} 分钟';
  } else if (seconds <= 89 * 60) {
    text = '1 小时';
  } else if (seconds <= 21 * 3600) {
    text = '${(seconds / 3600).round().clamp(1, 1 << 30)} 小时';
  } else if (seconds <= 35 * 3600) {
    text = '1 天';
  } else if (days <= 25) {
    text = '${days.round().clamp(1, 1 << 30)} 天';
  } else if (days <= 45) {
    text = '1 个月';
  } else if (months <= 10) {
    text = '${months.round().clamp(1, 1 << 30)} 个月';
  } else if (months <= 17) {
    text = '1 年';
  } else {
    text = '${(months / 12).round().clamp(1, 1 << 30)} 年';
  }
  return delta >= 0 ? '$text前' : '$text内';
}

/// 后端时间串 → 相对时间；空/解析失败返回 [empty]（鸿蒙 libraryFromNow 用「从未」）。
String mcFromNowIso(String? raw, {String empty = '从未'}) {
  final d = raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
  return d == null ? empty : mcFromNow(d.toLocal());
}

/// 集数标签 S01E02（season/episode 为 1 起；任一无效返回 '--'）。
String mcEpisodeLabel(int? season, int? episode) {
  if (season == null || episode == null) return '--';
  String two(int v) => v.toString().padLeft(2, '0');
  return 'S${two(season)}E${two(episode)}';
}
