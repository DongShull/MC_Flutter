import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // P3：注册手写原生下载通道（容量/目录只读方法；下载仍走 Dart 保底）。
    // 若此注册方式与当前 Flutter 隐式引擎不兼容（编译报错），
    // 改为在 `application(_:didFinishLaunchingWithOptions:)` 里用
    // `FlutterViewController` 的 binaryMessenger 注册。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "McDownloadPlugin") {
      McDownloadPlugin.register(with: registrar)
    }
  }
}
