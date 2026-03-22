import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var activeURLs: [String: URL] = [:]
  private var activePathURLs: [String: URL] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let registrar = self.registrar(forPlugin: "com.drdhaval2785.hdict.BookmarkPlugin")!
    let bookmarkChannel = FlutterMethodChannel(name: "com.drdhaval2785.hdict/bookmarks",
                                              binaryMessenger: registrar.messenger())
    
    bookmarkChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "createBookmark":
          self?.handleCreateBookmark(call: call, result: result)
      case "resolveBookmark":
          self?.handleResolveBookmark(call: call, result: result)
      case "stopAccess":
          self?.handleStopAccess(call: call, result: result)
      case "startAccessingPath":
          self?.handleStartAccessingPath(call: call, result: result)
      case "stopAccessingPath":
          self?.handleStopAccessingPath(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleCreateBookmark(call: FlutterMethodCall, result: FlutterResult) {
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
          return
      }
      
      let url = URL(fileURLWithPath: path)
      let startedAccess = url.startAccessingSecurityScopedResource()
      
      defer {
          if startedAccess {
              url.stopAccessingSecurityScopedResource()
          }
      }

      do {
          // Security-scoped bookmark for app sandboxing
          // On iOS, .withSecurityScope is not available; use empty options
          let bookmarkData = try url.bookmarkData(options: [], 
                                                 includingResourceValuesForKeys: nil, 
                                                 relativeTo: nil)
          result(bookmarkData.base64EncodedString())
      } catch {
          result(FlutterError(code: "BOOKMARK_ERROR", message: error.localizedDescription, details: nil))
      }
  }

  private func handleResolveBookmark(call: FlutterMethodCall, result: FlutterResult) {
      guard let args = call.arguments as? [String: Any],
            let bookmarkBase64 = args["bookmark"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Bookmark is required", details: nil))
          return
      }
      
      guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
          result(FlutterError(code: "INVALID_BOOKMARK", message: "Invalid base64", details: nil))
          return
      }
      
      do {
          var isStale = false
          // On iOS, use empty options for resolution as well
          let url = try URL(resolvingBookmarkData: bookmarkData, 
                           options: [], 
                           relativeTo: nil, 
                           bookmarkDataIsStale: &isStale)
          
          if url.startAccessingSecurityScopedResource() {
              activeURLs[bookmarkBase64] = url
              result(url.path)
          } else {
              result(FlutterError(code: "ACCESS_DENIED", message: "Could not start access to security-scoped resource", details: nil))
          }
      } catch {
          result(FlutterError(code: "RESOLVE_ERROR", message: error.localizedDescription, details: nil))
      }
  }

  private func handleStopAccess(call: FlutterMethodCall, result: FlutterResult) {
      guard let args = call.arguments as? [String: Any],
            let bookmarkBase64 = args["bookmark"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Bookmark is required", details: nil))
          return
      }
      
      if let url = activeURLs[bookmarkBase64] {
          url.stopAccessingSecurityScopedResource()
          activeURLs.removeValue(forKey: bookmarkBase64)
      }
      result(nil)
  }

  private func handleStartAccessingPath(call: FlutterMethodCall, result: FlutterResult) {
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
          return
      }
      
      let url = URL(fileURLWithPath: path)
      if url.startAccessingSecurityScopedResource() {
          activePathURLs[path] = url
          result(true)
      } else {
          // If it's not a security-scoped URL, startAccessing... returns false but it might still be accessible
          // (e.g. inside Documents but not picked via picker).
          // We return true if we can list it or if it exists.
          let fm = FileManager.default
          if fm.isReadableFile(atPath: path) {
              result(true)
          } else {
              result(false)
          }
      }
  }

  private func handleStopAccessingPath(call: FlutterMethodCall, result: FlutterResult) {
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
          return
      }
      
      if let url = activePathURLs[path] {
          url.stopAccessingSecurityScopedResource()
          activePathURLs.removeValue(forKey: path)
      }
      result(nil)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
