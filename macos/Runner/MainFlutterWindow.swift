import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Pont maison pour les security-scoped bookmarks (remplace le plugin
    // macos_secure_bookmarks, dont l'appel bookmark()/startAccessing()
    // renvoyait une erreur native non résolue en amont).
    let bookmarksChannel = FlutterMethodChannel(
      name: "com.opime/secure_bookmarks",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    bookmarksChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "createBookmark":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: "expected String path", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          _ = url.startAccessingSecurityScopedResource()
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(code: "bookmark_failed", message: error.localizedDescription, details: nil))
        }

      case "resolveAndAccess":
        guard let base64 = call.arguments as? String,
              let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "bad_args", message: "expected base64 String", details: nil))
          return
        }
        do {
          var isStale = false
          let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
          )
          let granted = url.startAccessingSecurityScopedResource()
          if !granted {
            result(FlutterError(code: "access_denied", message: "startAccessingSecurityScopedResource returned false", details: nil))
            return
          }
          result(url.path)
        } catch {
          result(FlutterError(code: "resolve_failed", message: error.localizedDescription, details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}