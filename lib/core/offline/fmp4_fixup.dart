/// 分片 MP4 修复（P3 纯 Dart 移植）。
///
/// 来源：安卓 `apps/android/app/src/main/java/io/movieclaw/android/core/offline/Fmp4Fixup.kt`。
/// 触发条件与 Kotlin 一致：只对**转码档**跑（调用方见
/// `OfflineController._finishDownload`），原画不动。
///
/// - [clampNegativeTfdt]：转码导出按文件绝对时间转码（`-copyts`），
///   音轨第一个分片的 `tfdt` 是负的（AAC 起始补偿，实测 −1024）。
///   iOS 的引擎（FFmpeg）照读；Exo 的 FragmentedMp4Extractor 读到负值
///   直接报错（「Top bit not zero」），整份打不开。这里把负的 `tfdt`
///   原地改成 0（只动这 8 个字节，第一段音频晚约 20 毫秒，
///   其余分片不受影响）。只读盒子头、按偏移跳着走，
///   几百 MB 的文件也是毫秒级。返回改了几处。
/// - [addSegmentIndex]：补一个分片索引（`sidx`）：导出是边转边写的
///   分片 MP4，没有索引；没有 `sidx` Exo 就当成不能拖动（续播点、
///   拖进度条全部从头放）。按视频轨每个分片的起点与时长写一张表，
///   插在 `moov` 之后（整份改写一次）。分片里的数据偏移都相对
///   `moof`（default-base-is-moof）时才动；不是这种写法的返回 false。
///   已有 `sidx`、解析失败、分片数 > 65535 时返回 false，不动文件。
/// 单元测试见 `test/fmp4_fixup_test.dart`（手造最小 fmp4 驗證）。
library;

import 'dart:io';
import 'dart:typed_data';

/// 盒子（总长、类型、头长）。
typedef _Box = ({int size, String type, int header});

/// 一个分片（[start] 含前面的 `styp`，[end] 是下一分片起点或文件尾）。
class _Fragment {
  _Fragment(this.start, this.end);
  final int start;
  int end;
  int? time;
  int duration = 0;
}

abstract final class Fmp4Fixup {
  /// 把负的 `tfdt`（version 1）原地改成 0；返回改了几处。
  static Future<int> clampNegativeTfdt(File file) async {
    var fixed = 0;
    // 注意：FileMode.write 会截断文件（实测 open 后 length=0），
    // 只能用 append 模式做原地读写（实测 setPosition 后写落在指定偏移，
    // 不追加到文件尾；长度不变由测试 fmp4_fixup_test 兜底）。
    final raf = await file.open(mode: FileMode.append);
    try {
      final length = await raf.length();
      var pos = 0;
      while (pos + 8 <= length) {
        final box = await _box(raf, pos, length);
        if (box == null) break;
        if (box.type == 'moof') {
          fixed += await _walk(raf, pos + box.header, pos + box.size, {'traf'});
        }
        pos += box.size;
      }
    } finally {
      await raf.close();
    }
    return fixed;
  }

  /// [Isolate.run] 入口（路径可跨 isolate 传递，[File] 不行）。
  static Future<int> clampNegativeTfdtForPath(String path) =>
      clampNegativeTfdt(File(path));

  /// 在 [start, end) 里找容器 [containers] 往下走，遇到 tfdt 就修。
  static Future<int> _walk(
      RandomAccessFile raf, int start, int end, Set<String> containers) async {
    var fixed = 0;
    var pos = start;
    while (pos + 8 <= end) {
      final box = await _box(raf, pos, end);
      if (box == null) break;
      if (containers.contains(box.type)) {
        fixed += await _walk(raf, pos + box.header, pos + box.size, const {});
      } else if (box.type == 'tfdt') {
        await raf.setPosition(pos + box.header);
        final version = await raf.readByte();
        if (version == 1) {
          await raf.setPosition(pos + box.header + 4);
          final value = await _readInt64(raf);
          if (value < 0) {
            await raf.setPosition(pos + box.header + 4);
            await _writeInt64(raf, 0);
            fixed += 1;
          }
        }
      }
      pos += box.size;
    }
    return fixed;
  }

  /// 补 `sidx`；成功返回 true，任何不满足条件的情况返回 false 且不动文件。
  static Future<bool> addSegmentIndex(File file) async {
    final fragments = <_Fragment>[];
    var moovEnd = -1;
    var refTrack = -1;
    var timescale = 0;
    final trexDuration = <int, int>{};
    final raf = await file.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      var pos = 0;
      int? pendingStyp;
      while (pos + 8 <= length) {
        final box = await _box(raf, pos, length);
        if (box == null) return false;
        switch (box.type) {
          case 'sidx':
            return false;
          case 'moov':
            moovEnd = pos + box.size;
            final tracks = <(int id, String handler, int scale)>[];
            await _children(raf, pos + box.header, pos + box.size,
                (cPos, cSize, cType, cHeader) async {
              switch (cType) {
                case 'trak':
                  final track = await _readTrack(
                      raf, cPos + cHeader, cPos + cSize);
                  if (track != null) tracks.add(track);
                case 'mvex':
                  await _children(raf, cPos + cHeader, cPos + cSize,
                      (tPos, _, tType, tHeader) async {
                    if (tType == 'trex') {
                      await raf.setPosition(tPos + tHeader + 4);
                      final id = await _readUint32(raf);
                      await _readUint32(raf);
                      trexDuration[id] = await _readUint32(raf);
                    }
                  });
              }
            });
            (int, String, int)? ref;
            for (final t in tracks) {
              if (t.$2 == 'vide') {
                ref = t;
                break;
              }
            }
            ref ??= tracks.isEmpty ? null : tracks.first;
            if (ref == null) return false;
            refTrack = ref.$1;
            timescale = ref.$3;
          case 'styp':
            pendingStyp = pos;
          case 'moof':
            if (fragments.isNotEmpty) {
              fragments.last.end = pendingStyp ?? pos;
            }
            final fragment = _Fragment(pendingStyp ?? pos, length);
            pendingStyp = null;
            final ok = await _readFragment(
              raf,
              pos + box.header,
              pos + box.size,
              refTrack,
              trexDuration[refTrack] ?? 0,
              (time, duration) {
                fragment.time = time;
                fragment.duration = duration;
              },
            );
            if (!ok) return false;
            fragments.add(fragment);
        }
        pos += box.size;
      }
    } finally {
      await raf.close();
    }
    if (moovEnd < 0 ||
        timescale <= 0 ||
        fragments.isEmpty ||
        fragments.length > 65535 ||
        fragments.any((f) => f.time == null)) {
      return false;
    }
    final count = fragments.length;
    // 盒子总长 = 头 8 + version/flags 4 + refID 4 + timescale 4
    //   + earliest 8 + first_offset 8 + reserved 2 + count 2
    //   + 每分片 12 = 40 + 12 * count。
    final sidx = ByteData(40 + 12 * count);
    var o = 0;
    sidx.setUint32(o, 40 + 12 * count);
    o += 4;
    sidx.setUint8(o++, 0x73); // s
    sidx.setUint8(o++, 0x69); // i
    sidx.setUint8(o++, 0x64); // d
    sidx.setUint8(o++, 0x78); // x
    sidx.setUint8(o++, 1); // version
    o += 3; // flags
    sidx.setUint32(o, refTrack);
    o += 4;
    sidx.setUint32(o, timescale);
    o += 4;
    sidx.setUint64(o, fragments.first.time!);
    o += 8;
    sidx.setUint64(o, 0); // first_offset
    o += 8;
    o += 2; // reserved
    sidx.setUint16(o, count);
    o += 2;
    for (final f in fragments) {
      final size = f.end - f.start;
      if (size <= 0 || size > 0x7FFFFFFF) return false;
      sidx.setUint32(o, size);
      o += 4;
      sidx.setUint32(o, f.duration);
      o += 4;
      sidx.setUint32(o, 0x90000000);
      o += 4;
    }
    // 整份改写：[0, moovEnd) + sidx + [moovEnd, length)。
    final tmp = File('${file.path}.idx');
    final input = await file.open(mode: FileMode.read);
    final output = await tmp.open(mode: FileMode.write);
    try {
      final length = await input.length();
      await _copyRange(input, output, 0, moovEnd);
      output.writeFromSync(sidx.buffer.asUint8List());
      await _copyRange(input, output, moovEnd, length);
      await output.flush();
    } finally {
      await input.close();
      await output.close();
    }
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await tmp.delete().catchError((_) => tmp);
      return false;
    }
    return true;
  }

  /// [Isolate.run] 入口。
  static Future<bool> addSegmentIndexForPath(String path) =>
      addSegmentIndex(File(path));

  static Future<void> _copyRange(
      RandomAccessFile input, RandomAccessFile output, int from, int to) async {
    const chunk = 1024 * 1024;
    var pos = from;
    await input.setPosition(from);
    while (pos < to) {
      final n = (to - pos) < chunk ? to - pos : chunk;
      final bytes = await input.read(n);
      if (bytes.isEmpty) break;
      await output.writeFrom(bytes);
      pos += bytes.length;
    }
  }

  static Future<void> _children(RandomAccessFile raf, int start, int end,
      Future<void> Function(int pos, int size, String type, int header) visit) async {
    var pos = start;
    while (pos + 8 <= end) {
      final box = await _box(raf, pos, end);
      if (box == null) return;
      await visit(pos, box.size, box.type, box.header);
      pos += box.size;
    }
  }

  /// trak 里的（轨号、类型、时间刻度）。
  static Future<(int, String, int)?> _readTrack(
      RandomAccessFile raf, int start, int end) async {
    var id = -1;
    var handler = '';
    var scale = 0;
    await _children(raf, start, end, (pos, size, type, header) async {
      switch (type) {
        case 'tkhd':
          await raf.setPosition(pos + header);
          final version = await raf.readByte();
          await raf.setPosition(pos + header + (version == 1 ? 20 : 12));
          id = await _readUint32(raf);
        case 'mdia':
          await _children(raf, pos + header, pos + size,
              (mPos, _, mType, mHeader) async {
            switch (mType) {
              case 'mdhd':
                await raf.setPosition(mPos + mHeader);
                final version = await raf.readByte();
                await raf.setPosition(
                    mPos + mHeader + (version == 1 ? 20 : 12));
                scale = await _readUint32(raf);
              case 'hdlr':
                await raf.setPosition(mPos + mHeader + 8);
                final bytes = await raf.read(4);
                handler = String.fromCharCodes(bytes);
            }
          });
      }
    });
    return id >= 0 ? (id, handler, scale) : null;
  }

  /// moof 里参考轨那一段的（起点、时长）；数据偏移不是相对 moof 的返回 false。
  static Future<bool> _readFragment(
    RandomAccessFile raf,
    int start,
    int end,
    int track,
    int trexDuration,
    void Function(int time, int duration) found,
  ) async {
    var ok = true;
    await _children(raf, start, end, (pos, size, type, header) async {
      if (type != 'traf') return;
      var id = -1;
      var defaultDuration = trexDuration;
      int? time;
      var duration = 0;
      await _children(raf, pos + header, pos + size,
          (tPos, _, tType, tHeader) async {
        switch (tType) {
          case 'tfhd':
            await raf.setPosition(tPos + tHeader);
            final flags = await _readUint32(raf) & 0xFFFFFF;
            id = await _readUint32(raf);
            // 绝对的 base_data_offset：插字节会错位。
            if (flags & 0x01 != 0) ok = false;
            var skip = 0;
            if (flags & 0x01 != 0) skip += 8;
            if (flags & 0x02 != 0) skip += 4;
            if (flags & 0x08 != 0) {
              await raf.setPosition(tPos + tHeader + 8 + skip);
              defaultDuration = await _readUint32(raf);
            }
          case 'tfdt':
            await raf.setPosition(tPos + tHeader);
            final version = await raf.readByte();
            await raf.setPosition(tPos + tHeader + 4);
            time = version == 1
                ? await _readInt64(raf)
                : await _readUint32(raf);
          case 'trun':
            await raf.setPosition(tPos + tHeader);
            final flags = await _readUint32(raf) & 0xFFFFFF;
            final samples = await _readUint32(raf);
            if (flags & 0x100 == 0) {
              duration += samples * defaultDuration;
            } else {
              var offset = 8;
              if (flags & 0x01 != 0) offset += 4;
              if (flags & 0x04 != 0) offset += 4;
              final perSample = [0x100, 0x200, 0x400, 0x800]
                      .where((b) => flags & b != 0)
                      .length *
                  4;
              for (var i = 0; i < samples; i++) {
                await raf.setPosition(tPos + tHeader + offset + i * perSample);
                duration += await _readUint32(raf);
              }
            }
        }
      });
      if (id == track && time != null) found(time!, duration);
    });
    return ok;
  }

  /// 盒子的（总长、类型、头长）；长度不合理时返回 null。
  static Future<_Box?> _box(RandomAccessFile raf, int pos, int end) async {
    await raf.setPosition(pos);
    var size = await _readUint32(raf);
    final typeBytes = await raf.read(4);
    if (typeBytes.length < 4) return null;
    final type = String.fromCharCodes(typeBytes);
    var header = 8;
    if (size == 1) {
      size = await _readUint64(raf);
      header = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < header || pos + size > end) return null;
    return (size: size, type: type, header: header);
  }

  static Future<int> _readUint32(RandomAccessFile raf) async {
    final bytes = await raf.read(4);
    if (bytes.length < 4) throw const FormatException('unexpected EOF');
    return ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(0);
  }

  static Future<int> _readUint64(RandomAccessFile raf) async {
    final bytes = await raf.read(8);
    if (bytes.length < 8) throw const FormatException('unexpected EOF');
    return ByteData.sublistView(Uint8List.fromList(bytes)).getUint64(0);
  }

  static Future<int> _readInt64(RandomAccessFile raf) async {
    final bytes = await raf.read(8);
    if (bytes.length < 8) throw const FormatException('unexpected EOF');
    return ByteData.sublistView(Uint8List.fromList(bytes)).getInt64(0);
  }

  static Future<void> _writeInt64(RandomAccessFile raf, int value) async {
    final bytes = ByteData(8)..setInt64(0, value);
    await raf.writeFrom(bytes.buffer.asUint8List());
  }
}
