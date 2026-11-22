import 'dart:io';

import '../../../core/api/mc_error.dart';



/// reels 画质档位（TODO(reels-quality) 落地）：按当前网络接口选档展示。
/// 蜂窝接口（rmnet/ccmni/pdp/wwan 前缀）→ '720p'，其余（Wi-Fi/有线）→ '原画'。
/// 只用 dart:io 的 [NetworkInterface] 判接口名，不引第三方包；当前仅展示不生效。
class NetworkTier {
  const NetworkTier._();

  static const _cellularPrefixes = <String>['rmnet', 'ccmni', 'pdp', 'wwan'];

  static Future<String> current() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final itf in interfaces) {
        final name = itf.name.toLowerCase();
        for (final prefix in _cellularPrefixes) {
          if (name.startsWith(prefix)) return '720p';
        }
      }
    } catch (e) {
      // 接口枚举失败（个别平台受限）按原画兜底（记日志，不静默）。
      McErrorLog.log(e, context: 'reels.networkTier');
    }
    return '原画';
  }
}
