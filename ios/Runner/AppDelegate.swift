import AVFoundation
import AVKit
import Flutter
import MediaPlayer
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static var supportedOrientationMask: UIInterfaceOrientationMask = .allButUpsideDown

  private var channelsRegistered = false
  private var downloadBridge: McDownloadBridge?
  private var playerSystemBridge: McPlayerSystemBridge?
  private var pushBridge: McPushBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let push = McPushBridge.shared
    push.configureCenterDelegate()
    pushBridge = push

    // Activate background download sessions early so iOS can deliver pending events.
    McDownloadBridge.shared.activate()
    downloadBridge = McDownloadBridge.shared

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if !channelsRegistered,
       let controller = window?.rootViewController as? FlutterViewController {
      registerNativeChannels(messenger: controller.binaryMessenger)
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if !channelsRegistered,
       let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "McNativeChannels") {
      registerNativeChannels(messenger: registrar.messenger())
    }
  }

  private func registerNativeChannels(messenger: FlutterBinaryMessenger) {
    guard !channelsRegistered else { return }
    channelsRegistered = true

    // 1. Platform identification channel: mc/base/platform
    let platformChannel = FlutterMethodChannel(
      name: "mc/base/platform",
      binaryMessenger: messenger
    )
    platformChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isHarmonyOS":
        result(false)
      case "harmonyOSVersion":
        result(nil)
      default:
        result("ios")
      }
    }

    // 2. Background offline download channel: mc/native/download
    let dlBridge = McDownloadBridge.shared
    dlBridge.attach(messenger: messenger)
    downloadBridge = dlBridge

    // 3. Player system bridge: mc/player/system
    let playerBridge = McPlayerSystemBridge(messenger: messenger)
    playerSystemBridge = playerBridge

    // 4. Native APNs / UNUserNotificationCenter push bridge: mc/native/push
    let push = McPushBridge.shared
    push.attach(messenger: messenger)
    pushBridge = push
  }

  // MARK: - Orientation Lock

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return Self.supportedOrientationMask
  }

  // MARK: - Background URLSession Events

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    McDownloadBridge.shared.handleBackgroundSessionEvents(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }

  // MARK: - APNs Callbacks

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    McPushBridge.shared.didRegister(deviceToken: deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    McPushBridge.shared.didFailToRegister(error: error)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

// MARK: - Background Offline Download Bridge (mc/native/download)

private struct McDownloadTaskMeta: Codable {
  let id: String
  let url: String
  let savePath: String
  let headers: [String: String]
}

private final class McDownloadStreamHandler: NSObject, FlutterStreamHandler {
  private let onListenCallback: (FlutterEventSink?) -> Void
  private let onCancelCallback: () -> Void

  init(
    onListen: @escaping (FlutterEventSink?) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onListenCallback = onListen
    self.onCancelCallback = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenCallback(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancelCallback()
    return nil
  }
}

private final class McDownloadBridge: NSObject, URLSessionDownloadDelegate {
  static let shared = McDownloadBridge()

  static let wifiSessionId = "io.movieclaw.offline.wifi"
  static let cellularSessionId = "io.movieclaw.offline.cellular"

  private let lock = NSLock()
  private var messenger: FlutterBinaryMessenger?
  private var channel: FlutterMethodChannel?
  private var allowCellular = false

  private var eventChannels: [String: FlutterEventChannel] = [:]
  private var eventSinks: [String: FlutterEventSink] = [:]
  private var lastProgressEmit: [String: Date] = [:]
  private var taskMetaById: [String: McDownloadTaskMeta] = [:]
  private var pausedIds: Set<String> = []
  private var cancelledIds: Set<String> = []
  private var backgroundCompletions: [String: () -> Void] = [:]

  private lazy var wifiSession: URLSession = makeSession(identifier: Self.wifiSessionId, cellular: false)
  private lazy var cellularSession: URLSession = makeSession(identifier: Self.cellularSessionId, cellular: true)

  private var allSessions: [URLSession] { [wifiSession, cellularSession] }

  private override init() {
    super.init()
  }

  func activate() {
    _ = ensureOfflineDirectory()
    _ = wifiSession
    _ = cellularSession
  }

  func attach(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    let methodChannel = FlutterMethodChannel(name: "mc/native/download", binaryMessenger: messenger)
    self.channel = methodChannel
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
  }

  func handleBackgroundSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
    lock.lock()
    backgroundCompletions[identifier] = completionHandler
    lock.unlock()
    if identifier == Self.wifiSessionId {
      _ = wifiSession
    } else if identifier == Self.cellularSessionId {
      _ = cellularSession
    }
  }

  private func makeSession(identifier: String, cellular: Bool) -> URLSession {
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    config.allowsCellularAccess = cellular
    config.allowsExpensiveNetworkAccess = cellular
    config.allowsConstrainedNetworkAccess = cellular
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false
    config.httpMaximumConnectionsPerHost = 1
    config.httpCookieStorage = nil
    config.httpShouldSetCookies = false
    config.timeoutIntervalForRequest = 120
    config.timeoutIntervalForResource = 7 * 24 * 3600
    config.httpAdditionalHeaders = ["User-Agent": "MovieClaw-Flutter/1.0.0"]
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.name = identifier
    return URLSession(configuration: config, delegate: self, delegateQueue: queue)
  }

  private func ensureOfflineDirectory() -> URL {
    let fm = FileManager.default
    let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fm.temporaryDirectory
    var offlineDir = appSupport.appendingPathComponent("Offline", isDirectory: true)
    try? fm.createDirectory(at: offlineDir, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? offlineDir.setResourceValues(values)
    return offlineDir
  }

  private func resumeDataURL(for savePath: String) -> URL {
    return URL(fileURLWithPath: savePath + ".resume")
  }

  private func ensureEventChannel(for id: String) {
    guard let messenger = self.messenger else { return }
    let register = {
      self.lock.lock()
      let exists = self.eventChannels[id] != nil
      self.lock.unlock()
      if exists { return }

      let ec = FlutterEventChannel(
        name: "mc/native/download/progress/\(id)",
        binaryMessenger: messenger
      )
      let handler = McDownloadStreamHandler(
        onListen: { [weak self] sink in
          guard let self = self else { return }
          self.lock.lock()
          if let sink = sink {
            self.eventSinks[id] = sink
          }
          self.lock.unlock()
        },
        onCancel: { [weak self] in
          guard let self = self else { return }
          self.lock.lock()
          self.eventSinks.removeValue(forKey: id)
          self.lock.unlock()
        }
      )
      ec.setStreamHandler(handler)
      self.lock.lock()
      self.eventChannels[id] = ec
      self.lock.unlock()
    }
    if Thread.isMainThread {
      register()
    } else {
      DispatchQueue.main.sync(execute: register)
    }
  }

  private func emitProgress(
    id: String,
    received: Int64,
    total: Int64?,
    done: Bool,
    error: String?
  ) {
    var payload: [String: Any] = [
      "id": id,
      "received": received,
      "receivedBytes": received,
      "done": done,
    ]
    if let total = total, total > 0 {
      payload["totalBytes"] = total
      payload["currentLength"] = total
    }
    if let error = error {
      payload["error"] = error
    }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.lock.lock()
      let sink = self.eventSinks[id]
      self.lock.unlock()
      sink?(payload)
      if done || error != nil {
        sink?(FlutterEndOfEventStream)
        self.lock.lock()
        self.eventSinks.removeValue(forKey: id)
        self.lock.unlock()
      }
      if let error = error, !error.isEmpty {
        self.channel?.invokeMethod("onError", arguments: payload)
      } else if done {
        self.channel?.invokeMethod("onDone", arguments: payload)
      } else {
        self.channel?.invokeMethod("onProgress", arguments: payload)
      }
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "probeDownload":
      result("ok")

    case "getDownloadDirectory":
      result(ensureOfflineDirectory().path)

    case "setAllowCellular":
      if let allow = args["allow"] as? Bool {
        allowCellular = allow
      } else if let allow = args["allowCellular"] as? Bool {
        allowCellular = allow
      }
      result(nil)

    case "startDownload", "start":
      guard let id = args["id"] as? String, !id.isEmpty,
            let urlStr = args["url"] as? String, !urlStr.isEmpty else {
        result(FlutterError(code: "bad_args", message: "id and url are required", details: nil))
        return
      }
      let savePath = (args["savePath"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        ?? ensureOfflineDirectory().appendingPathComponent(id).path
      let headers = args["headers"] as? [String: String] ?? [:]
      let cellular = (args["allowCellular"] as? Bool) ?? allowCellular
      startTask(
        meta: McDownloadTaskMeta(id: id, url: urlStr, savePath: savePath, headers: headers),
        cellular: cellular
      )
      result(nil)

    case "pauseDownload", "pause":
      guard let id = args["id"] as? String, !id.isEmpty else {
        result(nil)
        return
      }
      pauseTask(id: id) {
        result(nil)
      }

    case "resumeDownload", "resume":
      guard let id = args["id"] as? String, !id.isEmpty else {
        result(nil)
        return
      }
      let cellular = (args["allowCellular"] as? Bool) ?? allowCellular
      if let urlStr = args["url"] as? String, !urlStr.isEmpty {
        let savePath = (args["savePath"] as? String).flatMap { $0.isEmpty ? nil : $0 }
          ?? ensureOfflineDirectory().appendingPathComponent(id).path
        let headers = args["headers"] as? [String: String] ?? [:]
        startTask(
          meta: McDownloadTaskMeta(id: id, url: urlStr, savePath: savePath, headers: headers),
          cellular: cellular
        )
      } else {
        lock.lock()
        let savedMeta = taskMetaById[id]
        lock.unlock()
        if let meta = savedMeta {
          startTask(meta: meta, cellular: cellular)
        }
      }
      result(nil)

    case "cancelDownload", "cancel":
      guard let id = args["id"] as? String, !id.isEmpty else {
        result(nil)
        return
      }
      cancelTask(id: id) {
        result(nil)
      }

    case "delete":
      guard let path = args["path"] as? String, !path.isEmpty else {
        result(false)
        return
      }
      result(deleteLocalFile(path: path))

    case "capacity":
      result(queryCapacity())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startTask(meta: McDownloadTaskMeta, cellular: Bool) {
    ensureEventChannel(for: meta.id)
    lock.lock()
    pausedIds.remove(meta.id)
    cancelledIds.remove(meta.id)
    taskMetaById[meta.id] = meta
    lock.unlock()

    let saveURL = URL(fileURLWithPath: meta.savePath)
    let parentDir = saveURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

    let targetSession = cellular ? cellularSession : wifiSession
    let otherSession = cellular ? wifiSession : cellularSession

    // Cancel any stale task with same id in the other session.
    otherSession.getAllTasks { tasks in
      for task in tasks {
        if self.decodeMeta(task.taskDescription)?.id == meta.id {
          task.cancel()
        }
      }
    }

    targetSession.getAllTasks { [weak self] tasks in
      guard let self = self else { return }
      // Idempotent: if already running in targetSession, resume it.
      if let existing = tasks.first(where: {
        self.decodeMeta($0.taskDescription)?.id == meta.id && $0.state != .canceling && $0.state != .completed
      }) {
        existing.resume()
        return
      }

      let resumeFile = self.resumeDataURL(for: meta.savePath)
      let task: URLSessionDownloadTask
      if let resumeData = try? Data(contentsOf: resumeFile),
         self.resumeData(resumeData, matchesURLString: meta.url) {
        try? FileManager.default.removeItem(at: resumeFile)
        task = targetSession.downloadTask(withResumeData: resumeData)
      } else {
        try? FileManager.default.removeItem(at: resumeFile)
        guard let url = URL(string: meta.url) else {
          self.emitProgress(id: meta.id, received: 0, total: nil, done: false, error: "Invalid URL")
          return
        }
        var request = URLRequest(url: url)
        for (k, v) in meta.headers {
          request.setValue(v, forHTTPHeaderField: k)
        }
        task = targetSession.downloadTask(with: request)
      }
      if let encoded = try? JSONEncoder().encode(meta),
         let desc = String(data: encoded, encoding: .utf8) {
        task.taskDescription = desc
      }
      task.resume()
    }
  }

  private func pauseTask(id: String, completion: @escaping () -> Void) {
    lock.lock()
    pausedIds.insert(id)
    let fallbackMeta = taskMetaById[id]
    lock.unlock()

    let group = DispatchGroup()
    for session in allSessions {
      group.enter()
      session.getAllTasks { [weak self] tasks in
        guard let self = self else {
          group.leave()
          return
        }
        let matching = tasks.compactMap { $0 as? URLSessionDownloadTask }.filter {
          self.decodeMeta($0.taskDescription)?.id == id
        }
        if matching.isEmpty {
          group.leave()
          return
        }
        let innerGroup = DispatchGroup()
        for dlTask in matching {
          let meta = self.decodeMeta(dlTask.taskDescription) ?? fallbackMeta
          innerGroup.enter()
          dlTask.cancel { resumeData in
            if let data = resumeData, let savePath = meta?.savePath {
              let resumeURL = self.resumeDataURL(for: savePath)
              try? data.write(to: resumeURL, options: .atomic)
            }
            innerGroup.leave()
          }
        }
        innerGroup.notify(queue: .main) {
          group.leave()
        }
      }
    }
    group.notify(queue: .main, execute: completion)
  }

  private func cancelTask(id: String, completion: @escaping () -> Void) {
    lock.lock()
    cancelledIds.insert(id)
    pausedIds.remove(id)
    let savedMeta = taskMetaById.removeValue(forKey: id)
    lock.unlock()

    let group = DispatchGroup()
    for session in allSessions {
      group.enter()
      session.getAllTasks { [weak self] tasks in
        guard let self = self else {
          group.leave()
          return
        }
        for task in tasks where self.decodeMeta(task.taskDescription)?.id == id {
          task.cancel()
        }
        group.leave()
      }
    }
    group.notify(queue: .main) { [weak self] in
      if let savePath = savedMeta?.savePath {
        try? FileManager.default.removeItem(at: self?.resumeDataURL(for: savePath) ?? URL(fileURLWithPath: savePath + ".resume"))
        try? FileManager.default.removeItem(atPath: savePath + ".part")
        try? FileManager.default.removeItem(atPath: savePath + ".part.meta")
      }
      self?.emitProgress(id: id, received: 0, total: nil, done: true, error: "Download was cancelled")
      completion()
    }
  }

  private func deleteLocalFile(path: String) -> Bool {
    let fm = FileManager.default
    let targetURL = URL(fileURLWithPath: path).standardizedFileURL
    let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path
    guard targetURL.path.hasPrefix(home) else { return false }

    var deleted = false
    for suffix in ["", ".resume", ".part", ".part.meta"] {
      let candidate = targetURL.path + suffix
      if fm.fileExists(atPath: candidate) {
        if (try? fm.removeItem(atPath: candidate)) != nil {
          if suffix.isEmpty { deleted = true }
        }
      }
    }
    return deleted
  }

  private func queryCapacity() -> [String: Any]? {
    let dir = ensureOfflineDirectory()
    if let values = try? dir.resourceValues(forKeys: [
      .volumeAvailableCapacityForImportantUsageKey,
      .volumeAvailableCapacityKey,
      .volumeTotalCapacityKey,
    ]) {
      let free = values.volumeAvailableCapacityForImportantUsage
        ?? values.volumeAvailableCapacity.map(Int64.init)
      let total = values.volumeTotalCapacity.map(Int64.init)
      if let free = free, let total = total {
        return ["freeBytes": free, "totalBytes": total]
      }
    }
    if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: dir.path),
       let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value,
       let total = (attrs[.systemSize] as? NSNumber)?.int64Value {
      return ["freeBytes": free, "totalBytes": total]
    }
    return nil
  }

  private func decodeMeta(_ raw: String?) -> McDownloadTaskMeta? {
    guard let raw = raw, let data = raw.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(McDownloadTaskMeta.self, from: data)
  }

  private func resumeData(_ data: Data, matchesURLString target: String) -> Bool {
    let key = "NSURLSessionDownloadURL"
    var recorded: String?
    if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
      recorded = plist[key] as? String
    }
    if recorded == nil,
       let archived = try? NSKeyedUnarchiver.unarchivedObject(
         ofClasses: [NSDictionary.self, NSString.self, NSNumber.self, NSData.self, NSURL.self],
         from: data
       ) as? [String: Any] {
      recorded = (archived[key] as? String) ?? (archived[key] as? URL)?.absoluteString
    }
    guard let recorded = recorded else { return true }
    return recorded == target
  }

  // MARK: - URLSessionDownloadDelegate

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let meta = decodeMeta(downloadTask.taskDescription) else { return }
    let now = Date()
    lock.lock()
    let last = lastProgressEmit[meta.id]
    let shouldEmit = last == nil || now.timeIntervalSince(last!) >= 0.15
      || (totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite)
    if shouldEmit {
      lastProgressEmit[meta.id] = now
    }
    lock.unlock()
    guard shouldEmit else { return }
    let expected: Int64? = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
    emitProgress(id: meta.id, received: totalBytesWritten, total: expected, done: false, error: nil)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let meta = decodeMeta(downloadTask.taskDescription) else { return }
    let http = downloadTask.response as? HTTPURLResponse
    let status = http?.statusCode ?? 200
    guard status == 200 || status == 206 else {
      emitProgress(
        id: meta.id,
        received: downloadTask.countOfBytesReceived,
        total: nil,
        done: false,
        error: "HTTP \(status) for \(meta.url)"
      )
      return
    }

    var destination = URL(fileURLWithPath: meta.savePath)
    let fm = FileManager.default
    do {
      try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      if fm.fileExists(atPath: destination.path) {
        try fm.removeItem(at: destination)
      }
      try fm.moveItem(at: location, to: destination)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? destination.setResourceValues(values)
      try? fm.removeItem(at: resumeDataURL(for: meta.savePath))
      let fileSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        ?? downloadTask.countOfBytesReceived
      lock.lock()
      lastProgressEmit.removeValue(forKey: meta.id)
      lock.unlock()
      emitProgress(id: meta.id, received: fileSize, total: fileSize, done: true, error: nil)
    } catch {
      emitProgress(
        id: meta.id,
        received: downloadTask.countOfBytesReceived,
        total: downloadTask.countOfBytesExpectedToReceive > 0 ? downloadTask.countOfBytesExpectedToReceive : nil,
        done: false,
        error: error.localizedDescription
      )
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let meta = decodeMeta(task.taskDescription) else { return }
    lock.lock()
    lastProgressEmit.removeValue(forKey: meta.id)
    let wasPaused = pausedIds.contains(meta.id)
    let wasCancelled = cancelledIds.contains(meta.id)
    lock.unlock()

    guard let error = error else { return }
    if wasPaused || wasCancelled { return }

    let nsError = error as NSError
    if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
      try? resumeData.write(to: resumeDataURL(for: meta.savePath), options: .atomic)
    }
    let expected: Int64? = task.countOfBytesExpectedToReceive > 0 ? task.countOfBytesExpectedToReceive : nil
    emitProgress(
      id: meta.id,
      received: task.countOfBytesReceived,
      total: expected,
      done: false,
      error: error.localizedDescription
    )
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    guard let identifier = session.configuration.identifier else { return }
    lock.lock()
    let handler = backgroundCompletions.removeValue(forKey: identifier)
    lock.unlock()
    if let handler = handler {
      DispatchQueue.main.async {
        handler()
      }
    }
  }
}

// MARK: - Player System Bridge (mc/player/system)

private final class McPlayerSystemBridge: NSObject {
  private let channel: FlutterMethodChannel
  private var initialBrightness: CGFloat?
  private var hiddenVolumeView: MPVolumeView?
  private var volumeObservation: NSKeyValueObservation?
  private var remoteTargets: [(MPRemoteCommand, Any)] = []
  private var remoteCommandsAttached = false
  private var cachedArtworkUrl: String?
  private var cachedArtwork: MPMediaItemArtwork?

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "mc/player/system", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    observeSystemVolume()
  }

  deinit {
    volumeObservation?.invalidate()
    detachRemoteCommands()
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getBrightness":
      DispatchQueue.main.async {
        result(Double(UIScreen.main.brightness))
      }

    case "setBrightness":
      let raw = (args["value"] as? NSNumber)?.doubleValue
        ?? (args["brightness"] as? NSNumber)?.doubleValue
      guard let value = raw else {
        result(FlutterError(code: "bad_args", message: "value required", details: nil))
        return
      }
      DispatchQueue.main.async { [weak self] in
        if self?.initialBrightness == nil {
          self?.initialBrightness = UIScreen.main.brightness
        }
        let clamped = max(0.0, min(1.0, value))
        UIScreen.main.brightness = CGFloat(clamped)
        result(clamped)
      }

    case "restoreBrightness":
      DispatchQueue.main.async { [weak self] in
        if let saved = self?.initialBrightness {
          UIScreen.main.brightness = saved
          self?.initialBrightness = nil
        }
        result(nil)
      }

    case "getVolume":
      DispatchQueue.main.async { [weak self] in
        self?.ensureAudioSessionObserved()
        result(Double(AVAudioSession.sharedInstance().outputVolume))
      }

    case "setVolume":
      let raw = (args["value"] as? NSNumber)?.doubleValue
        ?? (args["volume"] as? NSNumber)?.doubleValue
      guard let value = raw else {
        result(FlutterError(code: "bad_args", message: "value required", details: nil))
        return
      }
      let clamped = Float(max(0.0, min(1.0, value)))
      DispatchQueue.main.async { [weak self] in
        self?.setSystemVolume(clamped)
        result(Double(clamped))
      }

    case "setOrientation", "setOrientationMask":
      let mode = (args["mode"] as? String) ?? (args["orientation"] as? String) ?? "auto"
      let rawMask = args["mask"] as? Int
      DispatchQueue.main.async { [weak self] in
        self?.applyOrientation(mode: mode, rawMask: rawMask)
        result(nil)
      }

    case "showAirPlayPicker", "presentAirPlayPicker":
      DispatchQueue.main.async { [weak self] in
        self?.triggerAirPlayPicker()
        result(nil)
      }

    case "updateNowPlaying":
      DispatchQueue.main.async { [weak self] in
        self?.updateNowPlaying(args: args)
        result(nil)
      }

    case "updateNowPlayingPosition":
      DispatchQueue.main.async { [weak self] in
        self?.updateNowPlayingPosition(args: args)
        result(nil)
      }

    case "clearNowPlaying":
      DispatchQueue.main.async { [weak self] in
        self?.clearNowPlaying()
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - System Volume (MPVolumeView + AVAudioSession KVO)

  private func ensureAudioSessionObserved() {
    let audio = AVAudioSession.sharedInstance()
    try? audio.setActive(true)
    if volumeObservation == nil {
      observeSystemVolume()
    }
  }

  private func observeSystemVolume() {
    let audio = AVAudioSession.sharedInstance()
    volumeObservation = audio.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
      guard let newVal = change.newValue else { return }
      DispatchQueue.main.async {
        self?.channel.invokeMethod("onVolumeChanged", arguments: ["volume": Double(newVal)])
      }
    }
  }

  private func ensureHiddenVolumeView() -> MPVolumeView {
    if let existing = hiddenVolumeView {
      return existing
    }
    let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    view.clipsToBounds = true
    view.alpha = 0.0001
    if let window = activeKeyWindow() {
      window.addSubview(view)
    }
    hiddenVolumeView = view
    return view
  }

  private func setSystemVolume(_ value: Float) {
    let view = ensureHiddenVolumeView()
    if view.superview == nil, let window = activeKeyWindow() {
      window.addSubview(view)
    }
    if let slider = view.subviews.first(where: { $0 is UISlider }) as? UISlider {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        slider.value = value
      }
    }
  }

  // MARK: - Orientation Lock

  private func applyOrientation(mode: String, rawMask: Int?) {
    let mask: UIInterfaceOrientationMask
    if let rawMask = rawMask {
      mask = UIInterfaceOrientationMask(rawValue: UInt(rawMask))
    } else {
      switch mode.lowercased() {
      case "portrait":
        mask = .portrait
      case "landscape":
        mask = .landscape
      case "landscapeleft", "landscape_left":
        mask = .landscapeLeft
      case "landscaperight", "landscape_right":
        mask = .landscapeRight
      case "all":
        mask = .all
      default:
        mask = .allButUpsideDown
      }
    }
    AppDelegate.supportedOrientationMask = mask

    if #available(iOS 16.0, *) {
      if let scene = activeWindowScene() {
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        scene.requestGeometryUpdate(preferences) { _ in }
        activeKeyWindow()?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      }
    } else {
      let target: UIInterfaceOrientation
      switch mask {
      case .portrait:
        target = .portrait
      case .landscapeLeft:
        target = .landscapeLeft
      case .landscapeRight, .landscape:
        target = .landscapeRight
      default:
        target = .unknown
      }
      if target != .unknown {
        UIDevice.current.setValue(target.rawValue, forKey: "orientation")
      }
      UIViewController.attemptRotationToDeviceOrientation()
    }
  }

  // MARK: - AirPlay Route Picker

  private func triggerAirPlayPicker() {
    let picker = AVRoutePickerView(frame: CGRect(x: -100, y: -100, width: 44, height: 44))
    picker.prioritizesVideoDevices = true
    picker.isHidden = true
    if let window = activeKeyWindow() {
      window.addSubview(picker)
    }
    for subview in picker.subviews {
      if let button = subview as? UIButton {
        button.sendActions(for: .touchUpInside)
        break
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      picker.removeFromSuperview()
    }
  }

  // MARK: - Now Playing & Remote Commands

  private func attachRemoteCommandsIfNeeded() {
    guard !remoteCommandsAttached else { return }
    remoteCommandsAttached = true
    let center = MPRemoteCommandCenter.shared()
    center.skipForwardCommand.preferredIntervals = [10]
    center.skipBackwardCommand.preferredIntervals = [10]

    registerRemote(center.playCommand, name: "play")
    registerRemote(center.pauseCommand, name: "pause")
    registerRemote(center.togglePlayPauseCommand, name: "togglePlayPause")
    registerRemote(center.skipForwardCommand, name: "skipForward")
    registerRemote(center.skipBackwardCommand, name: "skipBackward")
    registerRemote(center.nextTrackCommand, name: "nextTrack")
    registerRemote(center.previousTrackCommand, name: "previousTrack")

    let seekTarget = center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      let ms = Int(event.positionTime * 1000.0)
      DispatchQueue.main.async {
        self?.channel.invokeMethod("onRemoteCommand", arguments: [
          "command": "seek",
          "positionMs": ms,
        ])
      }
      return .success
    }
    remoteTargets.append((center.changePlaybackPositionCommand, seekTarget))
  }

  private func registerRemote(_ command: MPRemoteCommand, name: String) {
    command.isEnabled = true
    let target = command.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("onRemoteCommand", arguments: ["command": name])
      }
      return .success
    }
    remoteTargets.append((command, target))
  }

  private func detachRemoteCommands() {
    for (command, target) in remoteTargets {
      command.removeTarget(target)
    }
    remoteTargets.removeAll()
    remoteCommandsAttached = false
  }

  private func updateNowPlaying(args: [String: Any]) {
    attachRemoteCommandsIfNeeded()
    let center = MPRemoteCommandCenter.shared()
    if let hasNext = args["hasNext"] as? Bool {
      center.nextTrackCommand.isEnabled = hasNext
    }
    if let hasPrevious = args["hasPrevious"] as? Bool {
      center.previousTrackCommand.isEnabled = hasPrevious
    }

    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    if let title = args["title"] as? String {
      info[MPMediaItemPropertyTitle] = title
    }
    if let subtitle = (args["subtitle"] as? String) ?? (args["artist"] as? String) {
      info[MPMediaItemPropertyArtist] = subtitle
    }
    info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
    if let artwork = cachedArtwork, (args["artworkUrl"] as? String) == cachedArtworkUrl {
      info[MPMediaItemPropertyArtwork] = artwork
    }
    applyTimingFields(args: args, info: &info)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info

    if let artworkUrl = args["artworkUrl"] as? String, !artworkUrl.isEmpty, artworkUrl != cachedArtworkUrl {
      let headers = args["artworkHeaders"] as? [String: String] ?? [:]
      loadArtwork(urlString: artworkUrl, headers: headers)
    }
  }

  private func updateNowPlayingPosition(args: [String: Any]) {
    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    applyTimingFields(args: args, info: &info)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func applyTimingFields(args: [String: Any], info: inout [String: Any]) {
    if let posMs = (args["positionMs"] as? NSNumber)?.doubleValue {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = posMs / 1000.0
    }
    if let durMs = (args["durationMs"] as? NSNumber)?.doubleValue, durMs > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = durMs / 1000.0
    }
    let isPlaying = (args["isPlaying"] as? Bool) ?? true
    let rate = (args["rate"] as? NSNumber)?.doubleValue ?? (isPlaying ? 1.0 : 0.0)
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0.0
    MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
  }

  private func loadArtwork(urlString: String, headers: [String: String]) {
    guard let url = URL(string: urlString) else { return }
    cachedArtworkUrl = urlString
    var request = URLRequest(url: url)
    for (k, v) in headers {
      request.setValue(v, forHTTPHeaderField: k)
    }
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      guard let data = data, let image = UIImage(data: data) else { return }
      let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
      DispatchQueue.main.async {
        guard let self = self, self.cachedArtworkUrl == urlString else { return }
        self.cachedArtwork = artwork
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }.resume()
  }

  private func clearNowPlaying() {
    detachRemoteCommands()
    cachedArtworkUrl = nil
    cachedArtwork = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
  }

  private func activeWindowScene() -> UIWindowScene? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first(where: { $0.activationState == .foregroundActive })
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
  }

  private func activeKeyWindow() -> UIWindow? {
    return activeWindowScene()?.windows.first(where: { $0.isKeyWindow })
      ?? activeWindowScene()?.windows.first
  }
}

// MARK: - Native Push Bridge (mc/native/push)

private final class McPushBridge: NSObject, UNUserNotificationCenterDelegate {
  static let shared = McPushBridge()

  private var channel: FlutterMethodChannel?
  private var lastDeviceToken: String?
  private var unsupportedBuild = false
  private var visibleSessionPath: String?
  private var pendingInitialNotification: [String: Any]?

  private override init() {
    super.init()
  }

  func configureCenterDelegate() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    registerNotificationCategories()
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: "mc/native/push", binaryMessenger: messenger)
    self.channel = methodChannel
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
  }

  private func registerNotificationCategories() {
    let item = UNNotificationCategory(
      identifier: "item",
      actions: [
        UNNotificationAction(
          identifier: "play",
          title: "Play",
          options: [.foreground],
          icon: UNNotificationActionIcon(systemImageName: "play.fill")
        ),
        UNNotificationAction(
          identifier: "open",
          title: "View All Episodes",
          options: [.foreground],
          icon: UNNotificationActionIcon(systemImageName: "list.bullet")
        ),
        UNNotificationAction(
          identifier: "mute",
          title: "Mute Show",
          options: [.destructive],
          icon: UNNotificationActionIcon(systemImageName: "bell.slash")
        ),
      ],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([item])
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "registerForRemoteNotifications":
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      }

    case "getAuthorizationStatus", "getPermission":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          result(Self.statusString(settings.authorizationStatus))
        }
      }

    case "requestAuthorization", "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            result(Self.statusString(settings.authorizationStatus))
          }
        }
      }

    case "getApsEnvironment":
      result(Self.currentApsEnvironment())

    case "getPushInfo":
      UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
        DispatchQueue.main.async {
          guard let self = self else {
            result(nil)
            return
          }
          var map: [String: Any] = [
            "apsEnvironment": Self.currentApsEnvironment(),
            "topic": Bundle.main.bundleIdentifier ?? "",
            "permission": Self.statusString(settings.authorizationStatus),
            "unsupportedBuild": self.unsupportedBuild,
          ]
          if let token = self.lastDeviceToken {
            map["apnsToken"] = token
          }
          result(map)
        }
      }

    case "setVisibleSessionPath":
      visibleSessionPath = args["path"] as? String
      result(nil)

    case "getInitialNotification":
      let initial = pendingInitialNotification
      pendingInitialNotification = nil
      result(initial)

    case "registerCategories":
      registerNotificationCategories()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func didRegister(deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    lastDeviceToken = hex
    unsupportedBuild = false
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onDeviceToken", arguments: [
        "token": hex,
        "apsEnvironment": Self.currentApsEnvironment(),
        "topic": Bundle.main.bundleIdentifier ?? "",
      ])
    }
  }

  func didFailToRegister(error: Error) {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain && nsError.code == 3000 {
      unsupportedBuild = true
    }
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onRegisterError", arguments: [
        "message": error.localizedDescription,
        "code": nsError.code,
        "unsupportedBuild": self?.unsupportedBuild ?? false,
      ])
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    let passive: Bool
    if #available(iOS 15.0, *) {
      passive = notification.request.content.interruptionLevel == .passive
    } else {
      passive = false
    }
    if let openPath = userInfo["open"] as? String,
       let visible = visibleSessionPath,
       !visible.isEmpty,
       openPath == visible {
      completionHandler([])
      return
    }
    if passive {
      completionHandler([.list])
    } else {
      completionHandler([.banner, .list, .sound])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let payload: [String: Any] = [
      "actionIdentifier": response.actionIdentifier,
      "userInfo": Self.sanitizeUserInfo(response.notification.request.content.userInfo),
    ]
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        completionHandler()
        return
      }
      if let ch = self.channel {
        ch.invokeMethod("onNotificationTap", arguments: payload)
      } else {
        self.pendingInitialNotification = payload
      }
      completionHandler()
    }
  }

  // MARK: - Helpers

  private static func statusString(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized:
      return "authorized"
    case .provisional:
      return "provisional"
    case .ephemeral:
      return "ephemeral"
    case .denied:
      return "denied"
    case .notDetermined:
      return "not_determined"
    @unknown default:
      return "not_determined"
    }
  }

  /// Reads `aps-environment` from `embedded.mobileprovision` (matches PushCenter.swift).
  static func currentApsEnvironment() -> String {
    #if targetEnvironment(simulator)
    return "development"
    #else
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1),
          let start = text.range(of: "<?xml"),
          let end = text.range(of: "</plist>", range: start.upperBound..<text.endIndex),
          let plistData = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
          let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
          let entitlements = plist["Entitlements"] as? [String: Any],
          let env = entitlements["aps-environment"] as? String else {
      return "production"
    }
    return env == "development" ? "development" : "production"
    #endif
  }

  private static func sanitizeUserInfo(_ raw: [AnyHashable: Any]) -> [String: Any] {
    var out: [String: Any] = [:]
    for (key, value) in raw {
      let keyStr = String(describing: key)
      if let v = sanitizeValue(value) {
        out[keyStr] = v
      }
    }
    return out
  }

  private static func sanitizeValue(_ value: Any) -> Any? {
    switch value {
    case let v as String:
      return v
    case let v as NSNumber:
      return v
    case let v as [AnyHashable: Any]:
      return sanitizeUserInfo(v)
    case let v as [Any]:
      return v.compactMap { sanitizeValue($0) }
    default:
      return String(describing: value)
    }
  }
}
