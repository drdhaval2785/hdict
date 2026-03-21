import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var activeURLs: [String: URL] = [:]

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let bookmarkChannel = FlutterMethodChannel(name: "com.drdhaval2785.hdict/bookmarks",
                                              binaryMessenger: controller.binaryMessenger)
    
    bookmarkChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "createBookmark" {
          self?.handleCreateBookmark(call: call, result: result)
      } else if call.method == "resolveBookmark" {
          self?.handleResolveBookmark(call: call, result: result)
      } else if call.method == "stopAccess" {
          self?.handleStopAccess(call: call, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  private func handleCreateBookmark(call: FlutterMethodCall, result: FlutterResult) {
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
          return
      }
      
      let url = URL(fileURLWithPath: path)
      do {
          // Security-scoped bookmark for app sandboxing
          let bookmarkData = try url.bookmarkData(options: .withSecurityScope, 
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
          let url = try URL(resolvingBookmarkData: bookmarkData, 
                           options: .withSecurityScope, 
                           relativeTo: nil, 
                           bookmarkDataIsStale: &isStale)
          
          if url.startAccessingSecurityScopedResource() {
              activeURLs[bookmarkBase64] = url
              result(url.path)
          } else {
              result(FlutterError(code: "ACCESS_DENIED", message: "Could not start access", details: nil))
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

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
