import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 推送端到端加密异常原因（对齐 iOS `PushCrypto.Failure`）。
enum PushCryptoFailure {
  /// 不是合法的 `v1.<key_id>.<nonce>.<ciphertext>` 结构。
  malformed,

  /// 认证失败：密钥不匹配、密文被篡改或 `key_id` 被替换。
  authentication,
}

class PushCryptoException implements Exception {
  const PushCryptoException(this.failure, [this.message]);

  final PushCryptoFailure failure;
  final String? message;

  @override
  String toString() =>
      'PushCryptoException(${failure.name}${message != null ? ': $message' : ''})';
}

/// 解析后的密文信封（未解密，用于先取出 `key_id` 定位密钥）。
class PushEnvelope {
  const PushEnvelope({
    required this.keyId,
    required this.nonce,
    required this.sealed,
  });

  final String keyId;
  final Uint8List nonce;

  /// AES-256-GCM 密文 + 尾部 16 字节认证标签。
  final Uint8List sealed;
}

/// MovieClaw 推送端到端加解密实现（`v1.<key_id>.<nonce>.<ciphertext>`）。
///
/// 严格对齐 `PushShared/PushCrypto.swift`：
/// - 算法：AES-256-GCM（12 字节随机 nonce + 16 字节认证标签）
/// - AAD：ASCII/UTF-8 字节 `"v1.<key_id>"`
/// - 编码：nonce 与密文+标签均使用无填充 base64url（RFC 4648 §5）
abstract final class PushCrypto {
  static const version = 'v1';
  static const keyByteCount = 32;
  static const keyIdByteCount = 8;
  static const nonceByteCount = 12;
  static const tagByteCount = 16;

  static final AesGcm _algorithm = AesGcm.with256bits();
  static final Random _secureRandom = Random.secure();
  static final RegExp _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  /// 生成 32 字节（256 位）随机对称密钥。
  static Uint8List generateKey() => _randomBytes(keyByteCount);

  /// 生成 8 字节随机 `key_id`（16 位小写十六进制字符串）。
  static String generateKeyId() {
    final bytes = _randomBytes(keyIdByteCount);
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// 生成 12 字节随机 nonce。
  static Uint8List generateNonce() => _randomBytes(nonceByteCount);

  /// 无填充 base64url 编码（用于传输密钥、nonce 与密文）。
  static String encodeBase64Url(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// 严格无填充 base64url 解码（拒绝 `+`、`/` 与 `=`）。
  static Uint8List? decodeBase64Url(String text) {
    if (text.isEmpty || !_base64UrlPattern.hasMatch(text)) return null;
    final mod = text.length % 4;
    if (mod == 1) return null;
    final padded = mod == 0 ? text : text + ('=' * (4 - mod));
    try {
      return Uint8List.fromList(base64Url.decode(padded));
    } catch (_) {
      return null;
    }
  }

  /// 仅拆分密文信封格式，不解密。
  static PushEnvelope parse(String payload) {
    final parts = payload.split('.');
    if (parts.length != 4 || parts[0] != version || parts[1].isEmpty) {
      throw const PushCryptoException(
        PushCryptoFailure.malformed,
        'Expected v1.<key_id>.<nonce>.<ciphertext>',
      );
    }
    final nonce = decodeBase64Url(parts[2]);
    if (nonce == null || nonce.length != nonceByteCount) {
      throw const PushCryptoException(
        PushCryptoFailure.malformed,
        'Invalid 12-byte base64url nonce',
      );
    }
    final sealed = decodeBase64Url(parts[3]);
    if (sealed == null || sealed.length < tagByteCount) {
      throw const PushCryptoException(
        PushCryptoFailure.malformed,
        'Invalid base64url ciphertext+tag',
      );
    }
    return PushEnvelope(keyId: parts[1], nonce: nonce, sealed: sealed);
  }

  /// 将明文字节加密为 `v1.<key_id>.<nonce>.<ciphertext>`。
  static Future<String> encrypt(
    Uint8List plaintext, {
    required Uint8List key,
    required String keyId,
    Uint8List? nonce,
  }) async {
    if (key.length != keyByteCount) {
      throw const PushCryptoException(
        PushCryptoFailure.malformed,
        'Key must be 32 bytes',
      );
    }
    if (keyId.isEmpty) {
      throw const PushCryptoException(
        PushCryptoFailure.malformed,
        'keyId must not be empty',
      );
    }
    final effectiveNonce = nonce ?? generateNonce();
    if (effectiveNonce.length != nonceByteCount) {
      throw const PushCryptoException(
        PushCryptoFailure.malformed,
        'Nonce must be 12 bytes',
      );
    }
    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: effectiveNonce,
      aad: _aad(keyId),
    );
    final combined = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    )
      ..setAll(0, secretBox.cipherText)
      ..setAll(secretBox.cipherText.length, secretBox.mac.bytes);
    return '$version.$keyId.${encodeBase64Url(effectiveNonce)}.${encodeBase64Url(combined)}';
  }

  /// 加密结构化 [PushPayload]。
  static Future<String> encryptPayload(
    PushPayload payload, {
    required Uint8List key,
    required String keyId,
    Uint8List? nonce,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload.toJson())));
    return encrypt(bytes, key: key, keyId: keyId, nonce: nonce);
  }

  /// 解密 `v1.<key_id>.<nonce>.<ciphertext>`，返回明文字节。
  static Future<Uint8List> decrypt(
    String payload, {
    required Uint8List key,
  }) {
    return decryptEnvelope(parse(payload), key: key);
  }

  /// 解密已拆分的 [PushEnvelope]，返回明文字节。
  static Future<Uint8List> decryptEnvelope(
    PushEnvelope envelope, {
    required Uint8List key,
  }) async {
    if (key.length != keyByteCount) {
      throw const PushCryptoException(
        PushCryptoFailure.authentication,
        'Key must be 32 bytes',
      );
    }
    final cipherLen = envelope.sealed.length - tagByteCount;
    final cipherText = envelope.sealed.sublist(0, cipherLen);
    final macBytes = envelope.sealed.sublist(cipherLen);
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(
          cipherText,
          nonce: envelope.nonce,
          mac: Mac(macBytes),
        ),
        secretKey: SecretKey(key),
        aad: _aad(envelope.keyId),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const PushCryptoException(
        PushCryptoFailure.authentication,
        'AES-GCM authentication failed',
      );
    } catch (e) {
      throw PushCryptoException(PushCryptoFailure.authentication, e.toString());
    }
  }

  /// 解密并解析为 [PushPayload]。
  static Future<PushPayload> decryptPayload(
    String payload, {
    required Uint8List key,
  }) async {
    final bytes = await decrypt(payload, key: key);
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const PushCryptoException(
          PushCryptoFailure.malformed,
          'Decrypted payload is not a JSON object',
        );
      }
      return PushPayload.fromJson(decoded.cast<String, dynamic>());
    } on PushCryptoException {
      rethrow;
    } catch (e) {
      throw PushCryptoException(PushCryptoFailure.malformed, e.toString());
    }
  }

  static List<int> _aad(String keyId) => utf8.encode('$version.$keyId');

  static Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _secureRandom.nextInt(256);
    }
    return out;
  }
}

/// 推送来源方（服务器或账号，对齐 `PushPlaintext.Party`）。
class PushParty {
  const PushParty({this.id, this.name});

  final String? id;
  final String? name;

  factory PushParty.fromJson(Map<String, dynamic> j) => PushParty(
        id: j['id']?.toString(),
        name: j['name']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
      };
}

/// 长按通知快捷动作（`play` / `open` / `mute`，对齐 `PushPlaintext.Action`）。
class PushAction {
  const PushAction({
    required this.id,
    required this.title,
    this.openPath,
    this.itemId,
  });

  final String id;
  final String title;
  final String? openPath;
  final int? itemId;

  factory PushAction.fromJson(Map<String, dynamic> j) => PushAction(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        openPath: PushPayload.sanitizeSitePath(j['open']?.toString()),
        itemId: j['item'] is num
            ? (j['item'] as num).toInt()
            : int.tryParse(j['item']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (openPath != null) 'open': openPath,
        if (itemId != null) 'item': itemId,
      };
}

/// 剧集分季格子状态（`s` 看过 / `d` 已入库 / `w` 下载中 / `m` 未找到 / `-` 其他）。
class PushSeasonGrid {
  const PushSeasonGrid({
    required this.season,
    required this.cells,
  });

  final int season;
  final String cells;

  factory PushSeasonGrid.fromJson(Map<String, dynamic> j) => PushSeasonGrid(
        season: j['season'] is num
            ? (j['season'] as num).toInt()
            : int.tryParse(j['season']?.toString() ?? '') ?? 1,
        cells: (j['cells'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'season': season,
        'cells': cells,
      };
}

/// 推送明文载荷（对齐 `PushShared/PushPayload.swift`）。
///
/// 采用宽松解析：单个字段类型不匹配时仅忽略该字段，避免整条通知退回通用文案。
class PushPayload {
  const PushPayload({
    this.version = supportedVersion,
    this.type = 'alert',
    this.sentAt,
    this.server,
    this.account,
    this.title,
    this.subtitle,
    this.body,
    this.openPath,
    this.category,
    this.itemId,
    this.episodeLabel,
    this.imageUrl,
    this.thread,
    this.sound,
    this.source,
    this.actions = const [],
    this.seasonGrid,
  });

  static const int supportedVersion = 1;

  final int version;
  final String type;
  final int? sentAt;
  final PushParty? server;
  final PushParty? account;
  final String? title;
  final String? subtitle;
  final String? body;
  final String? openPath;
  final String? category;
  final int? itemId;
  final String? episodeLabel;
  final String? imageUrl;
  final String? thread;
  final String? sound;
  final String? source;
  final List<PushAction> actions;
  final PushSeasonGrid? seasonGrid;

  bool get isNewer => version > supportedVersion;
  bool get isAlert => type == 'alert';

  /// 仅接受合法站内相对路径（以 `/` 开头，拒绝 `//` 与 `\`）。
  static String? sanitizeSitePath(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('/') ||
        trimmed.startsWith('//') ||
        trimmed.contains('\\')) {
      return null;
    }
    return trimmed;
  }

  factory PushPayload.fromJson(Map<String, dynamic> j) {
    String? str(String key) {
      final v = j[key];
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    int? integer(String key) {
      final v = j[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    PushParty? party(String key) {
      final v = j[key];
      if (v is Map) return PushParty.fromJson(v.cast<String, dynamic>());
      return null;
    }

    final parsedActions = <PushAction>[];
    final rawActions = j['actions'];
    if (rawActions is List) {
      for (final a in rawActions) {
        if (a is Map) {
          final action = PushAction.fromJson(a.cast<String, dynamic>());
          if (action.id.isNotEmpty) parsedActions.add(action);
        }
      }
    }

    PushSeasonGrid? parsedGrid;
    final rawGrid = j['grid'] ?? j['season_grid'];
    if (rawGrid is Map) {
      parsedGrid = PushSeasonGrid.fromJson(rawGrid.cast<String, dynamic>());
    }

    int? resolvedItemId = integer('item_id') ?? integer('item');
    if (resolvedItemId == null) {
      for (final a in parsedActions) {
        if (a.id == 'mute' && a.itemId != null) {
          resolvedItemId = a.itemId;
          break;
        }
      }
    }

    final rawImage = str('image') ?? str('image_url');

    return PushPayload(
      version: integer('v') ?? supportedVersion,
      type: str('type') ?? 'alert',
      sentAt: integer('sent_at'),
      server: party('server'),
      account: party('account'),
      title: str('title'),
      subtitle: str('subtitle'),
      body: str('body'),
      openPath: sanitizeSitePath(str('open') ?? str('open_path')),
      category: str('category'),
      itemId: resolvedItemId,
      episodeLabel: str('episode_label'),
      imageUrl: rawImage,
      thread: str('thread'),
      sound: str('sound'),
      source: str('source'),
      actions: parsedActions,
      seasonGrid: parsedGrid,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        'type': type,
        if (sentAt != null) 'sent_at': sentAt,
        if (server != null) 'server': server!.toJson(),
        if (account != null) 'account': account!.toJson(),
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (body != null) 'body': body,
        if (openPath != null) 'open': openPath,
        if (category != null) 'category': category,
        if (itemId != null) 'item_id': itemId,
        if (episodeLabel != null) 'episode_label': episodeLabel,
        if (imageUrl != null) 'image': imageUrl,
        if (thread != null) 'thread': thread,
        if (sound != null) 'sound': sound,
        if (source != null) 'source': source,
        if (actions.isNotEmpty)
          'actions': actions.map((a) => a.toJson()).toList(),
        if (seasonGrid != null) 'grid': seasonGrid!.toJson(),
      };
}
