import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/offline/fmp4_fixup.dart';

/// 手造最小 fmp4（对照 Kotlin `Fmp4Fixup` 的盒子结构）。
Uint8List box(String type, List<int> payload) {
  final out = BytesBuilder();
  final header = ByteData(8);
  header.setUint32(0, 8 + payload.length);
  for (var i = 0; i < 4; i++) {
    header.setUint8(4 + i, type.codeUnitAt(i));
  }
  out.add(header.buffer.asUint8List());
  out.add(payload);
  return out.toBytes();
}

Uint8List u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
Uint8List i64(int v) => (ByteData(8)..setInt64(0, v)).buffer.asUint8List();

List<int> verFlags(int flags) => [
      0,
      (flags >> 16) & 0xFF,
      (flags >> 8) & 0xFF,
      flags & 0xFF,
    ];

Uint8List tfdtBox(int version, int time) {
  final vf = verFlags(0);
  vf[0] = version;
  return box(
    'tfdt',
    [
      ...vf,
      if (version == 1) ...i64(time) else ...u32(time),
    ],
  );
}

Uint8List tfhdBox(int flags, int trackId, {int? defaultDuration}) {
  final payload = <int>[
    ...verFlags(flags),
    ...u32(trackId),
  ];
  if (flags & 0x01 != 0) payload.addAll(List.filled(8, 0));
  if (flags & 0x02 != 0) payload.addAll(u32(1));
  if (flags & 0x08 != 0) payload.addAll(u32(defaultDuration ?? 0));
  return box('tfhd', payload);
}

Uint8List trunBox(List<int> durations) {
  final payload = <int>[
    ...verFlags(0x100),
    ...u32(durations.length),
  ];
  for (final d in durations) {
    payload.addAll(u32(d));
  }
  return box('trun', payload);
}

Uint8List moofBox(int tfdtTime, {int tfhdFlags = 0x020008}) => box(
      'moof',
      [
        ...box('mfhd', [...verFlags(0), ...u32(1)]),
        ...box('traf', [
          ...tfhdBox(tfhdFlags, 1, defaultDuration: 1000),
          ...tfdtBox(1, tfdtTime),
          ...trunBox([500, 500]),
        ]),
      ],
    );

Uint8List moovBox() {
  final tkhd = box('tkhd', [
    ...verFlags(0),
    ...u32(0), // creation
    ...u32(0), // modification
    ...u32(1), // track ID
  ]);
  final mdhd = box('mdhd', [
    ...verFlags(0),
    ...u32(0),
    ...u32(0),
    ...u32(1000), // timescale
    ...u32(0),
  ]);
  final hdlr = box('hdlr', [
    ...verFlags(0),
    ...u32(0),
    0x76, 0x69, 0x64, 0x65, // 'vide'
  ]);
  final mdia = box('mdia', [...mdhd, ...hdlr, ...box('minf', [])]);
  final trak = box('trak', [...tkhd, ...mdia]);
  final trex = box('trex', [
    ...verFlags(0),
    ...u32(1),
    ...u32(1),
    ...u32(1000), // default duration
    ...u32(0),
    ...u32(0),
  ]);
  final mvex = box('mvex', [...trex]);
  return box('moov', [...box('mvhd', [...verFlags(0)]), ...trak, ...mvex]);
}

/// 扫顶层盒子，返回 [(type, start, size)]。
List<(String, int, int)> topBoxes(Uint8List bytes) {
  final out = <(String, int, int)>[];
  var pos = 0;
  while (pos + 8 <= bytes.length) {
    final size = ByteData.sublistView(bytes, pos, pos + 4).getUint32(0);
    final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
    out.add((type, pos, size));
    if (size <= 0) break;
    pos += size;
  }
  return out;
}

/// 读第一个 tfdt（version 1）的 int64 值。
int readFirstTfdt(Uint8List bytes) {
  for (final (type, start, size) in topBoxes(bytes)) {
    if (type != 'moof') continue;
    var pos = start + 8;
    final end = start + size;
    while (pos + 8 <= end) {
      final subSize =
          ByteData.sublistView(bytes, pos, pos + 4).getUint32(0);
      final subType = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
      if (subType == 'traf') {
        var tpos = pos + 8;
        final tend = pos + subSize;
        while (tpos + 8 <= tend) {
          final tSize =
              ByteData.sublistView(bytes, tpos, tpos + 4).getUint32(0);
          final tType =
              String.fromCharCodes(bytes.sublist(tpos + 4, tpos + 8));
          if (tType == 'tfdt') {
            final version = bytes[tpos + 8];
            if (version == 1) {
              return ByteData.sublistView(bytes, tpos + 12, tpos + 20)
                  .getInt64(0);
            }
          }
          tpos += tSize;
        }
      }
      pos += subSize;
    }
  }
  throw StateError('no tfdt found');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mc_fmp4_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('clampNegativeTfdt：负 tfdt 改成 0，文件长度不变；第二次 0 处', () async {
    final file = File('${tempDir.path}/neg.mp4');
    // 负 tfdt 文件（AAC 起始补偿，Kotlin 注释的实测值 -1024）。
    final neg = BytesBuilder()
      ..add(box('ftyp', [0x69, 0x73, 0x6F, 0x6D]))
      ..add(box(
          'moof',
          [
            ...box('mfhd', [...verFlags(0), ...u32(1)]),
            ...box('traf', [
              ...tfhdBox(0, 1),
              ...tfdtBox(1, -1024),
              ...trunBox([500, 500]),
            ]),
          ]))
      ..add(box('mdat', [1, 2, 3, 4]));
    final negBytes = neg.toBytes();
    final before = negBytes.length;
    await file.writeAsBytes(negBytes);
    expect(readFirstTfdt(await file.readAsBytes()), -1024);

    expect(await Fmp4Fixup.clampNegativeTfdt(file), 1);
    expect(await file.length(), before);
    expect(readFirstTfdt(await file.readAsBytes()), 0);
    expect(await Fmp4Fixup.clampNegativeTfdt(file), 0);
  });

  test('clampNegativeTfdt：正 tfdt 与 version 0 不动', () async {
    final file = File('${tempDir.path}/pos.mp4');
    await file.writeAsBytes([
      ...box('ftyp', [0x69, 0x73, 0x6F, 0x6D]),
      ...moofBox(500),
      ...box('mdat', [1, 2, 3, 4]),
    ]);
    expect(await Fmp4Fixup.clampNegativeTfdt(file), 0);
    expect(readFirstTfdt(await file.readAsBytes()), 500);

    final v0 = File('${tempDir.path}/v0.mp4');
    await v0.writeAsBytes([
      ...box('ftyp', [0x69, 0x73, 0x6F, 0x6D]),
      ...box(
          'moof',
          [
            ...box('mfhd', [...verFlags(0), ...u32(1)]),
            ...box('traf', [
              ...tfhdBox(0, 1),
              ...tfdtBox(0, 123),
              ...trunBox([500]),
            ]),
          ]),
      ...box('mdat', [1, 2, 3, 4]),
    ]);
    expect(await Fmp4Fixup.clampNegativeTfdt(v0), 0);
  });

  test('addSegmentIndex：moov 后插入 sidx，分片起点/时长正确', () async {
    final file = File('${tempDir.path}/idx.mp4');
    await file.writeAsBytes([
      ...box('ftyp', [0x69, 0x73, 0x6F, 0x6D]),
      ...moovBox(),
      ...moofBox(0),
      ...box('mdat', List.filled(16, 7)),
      ...moofBox(1000),
      ...box('mdat', List.filled(16, 8)),
    ]);
    final before = await file.length();
    expect(await Fmp4Fixup.addSegmentIndex(file), isTrue);
    expect(await file.length(), greaterThan(before));

    final bytes = await file.readAsBytes();
    final tops = topBoxes(bytes);
    expect(
        tops.map((t) => t.$1),
        ['ftyp', 'moov', 'sidx', 'moof', 'mdat', 'moof', 'mdat']);
    final sidx = tops.firstWhere((t) => t.$1 == 'sidx');
    final view = ByteData.sublistView(
        bytes, sidx.$2, sidx.$2 + sidx.$3);
    expect(view.getUint8(8), 1); // version
    expect(view.getUint32(12), 1); // reference_ID
    expect(view.getUint32(16), 1000); // timescale
    expect(view.getUint64(20), 0); // earliest_presentation_time
    expect(view.getUint64(28), 0); // first_offset
    expect(view.getUint16(38), 2); // reference_count
    // 两个引用：时长都是 1000（500+500）。
    expect(view.getUint32(44), 1000);
    expect(view.getUint32(56), 1000);

    // 已有 sidx：第二次返回 false，文件不动。
    final lenAfter = await file.length();
    expect(await Fmp4Fixup.addSegmentIndex(file), isFalse);
    expect(await file.length(), lenAfter);
  });

  test('addSegmentIndex：绝对 base_data_offset 的文件不动', () async {
    final file = File('${tempDir.path}/abs.mp4');
    await file.writeAsBytes([
      ...box('ftyp', [0x69, 0x73, 0x6F, 0x6D]),
      ...moovBox(),
      // tfhd flags 0x01 = base_data_offset_present（绝对偏移）。
      ...box(
          'moof',
          [
            ...box('mfhd', [...verFlags(0), ...u32(1)]),
            ...box('traf', [
              ...tfhdBox(0x01, 1),
              ...tfdtBox(1, 0),
              ...trunBox([500, 500]),
            ]),
          ]),
      ...box('mdat', [1, 2, 3, 4]),
    ]);
    final before = await file.length();
    expect(await Fmp4Fixup.addSegmentIndex(file), isFalse);
    expect(await file.length(), before);
  });

  test('Isolate.run 入口：clampNegativeTfdtForPath 跨 isolate 可用', () async {
    final file = File('${tempDir.path}/iso.mp4');
    await file.writeAsBytes([
      ...box('ftyp', [0x69, 0x73, 0x6F, 0x6D]),
      ...box(
          'moof',
          [
            ...box('mfhd', [...verFlags(0), ...u32(1)]),
            ...box('traf', [
              ...tfhdBox(0, 1),
              ...tfdtBox(1, -1024),
              ...trunBox([500]),
            ]),
          ]),
      ...box('mdat', [1, 2, 3, 4]),
    ]);
    final fixed = await Isolate.run(
        () => Fmp4Fixup.clampNegativeTfdtForPath(file.path));
    expect(fixed, 1);
    expect(readFirstTfdt(await file.readAsBytes()), 0);
  });
}
