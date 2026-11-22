import Flutter
import UIKit

/// iOS 侧 `mc/native/download` 通道（P3 新增；此前 iOS 完全没有原生实现，
/// `capacity` 一律 MissingPluginException，容量页静默留空）。
///
/// 只实现容量与目录两个只读方法；下载本身（start/pause/cancel）继续走
/// Dart 纯保底下载器（HttpClient + Range），其余方法一律
/// `FlutterMethodNotImplemented`（Dart 侧按 MissingPluginException
/// 降级保底，行为不变）。
///
/// 容量口径与安卓 `MainActivity.McDownloadPlugin` 一致：
/// `capacity` → `{freeBytes, totalBytes}`（FileManager
/// `systemFreeSize` / `systemSize`，应用沙盒所在卷）。
///
/// 未编译验证：本机无 Xcode/macOS，合入前须在 macOS 上
/// `flutter build ios` 验证；若注册方式与当前 Flutter 隐式引擎
/// 不兼容，以编译报错为准调整（见 `AppDelegate` 注册处注释）。
public class McDownloadPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mc/native/download",
      binaryMessenger: registrar.messenger())
    let instance = McDownloadPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "probeDownload":
      result("ok")
    case "getDownloadDirectory":
      result(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path)
    case "capacity":
      do {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
        result(["freeBytes": free, "totalBytes": total])
      } catch {
        result(FlutterError(
          code: "capacity_failed",
          message: error.localizedDescription,
          details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
