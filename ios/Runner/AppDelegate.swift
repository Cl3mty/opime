import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Garde une référence forte le temps de la présentation du picker : sans
  // ça, le delegate est libéré avant que l'utilisateur ait choisi un
  // dossier et son callback ne se déclenche jamais.
  private var folderPickerDelegate: FolderPickerDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Pont maison pour les security-scoped bookmarks, miroir de
    // macos/Runner/MainFlutterWindow.swift avec le même canal et les mêmes
    // noms de méthode (createBookmark/resolveAndAccess) : sur iOS,
    // UIDocumentPickerViewController renvoie une URL à portée de sécurité qui
    // ne survit pas à un redémarrage sans bookmark persisté. Contrairement à
    // macOS (App Sandbox), il n'existe pas d'option `.withSecurityScope` côté
    // iOS — les options par défaut suffisent pour ce cas d'usage.
    let bookmarksChannel = FlutterMethodChannel(
      name: "com.opime/secure_bookmarks",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    bookmarksChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "pickFolder":
        self?.presentFolderPicker(result: result)

      case "createBookmark":
        // Utilisé côté macOS uniquement (voir vault_folder_service.dart) :
        // sur iOS, "pickFolder" ci-dessus crée le bookmark directement
        // depuis l'URL scopée du picker, seule façon fiable d'obtenir un
        // accès qui survit hors du bac à sable sur un vrai appareil.
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: "expected String path", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let data = try url.bookmarkData(
            options: [],
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
            options: [],
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
  }

  /// Présente le UIDocumentPickerViewController système pour choisir un
  /// dossier, et crée le bookmark directement depuis l'URL renvoyée par le
  /// delegate (pas via un chemin texte reconstruit ensuite : c'est ce qui
  /// fait perdre le "security scope" et provoque un `operation not
  /// permitted` à l'écriture, uniquement visible sur un vrai appareil).
  private func presentFolderPicker(result: @escaping FlutterResult) {
    guard
      let rootViewController = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
        .first?.rootViewController
    else {
      result(FlutterError(code: "no_view_controller", message: "Aucune fenêtre disponible", details: nil))
      return
    }

    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.allowsMultipleSelection = false

    let delegate = FolderPickerDelegate { [weak self] pickedURL in
      self?.folderPickerDelegate = nil
      guard let url = pickedURL else {
        result(nil)
        return
      }
      guard url.startAccessingSecurityScopedResource() else {
        result(FlutterError(code: "access_denied", message: "startAccessingSecurityScopedResource returned false", details: nil))
        return
      }
      do {
        let bookmark = try url.bookmarkData(
          options: [],
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        result([
          "path": url.path,
          "bookmarkData": bookmark.base64EncodedString(),
        ])
      } catch {
        result(FlutterError(code: "bookmark_failed", message: error.localizedDescription, details: nil))
      }
    }
    folderPickerDelegate = delegate
    picker.delegate = delegate
    rootViewController.present(picker, animated: true, completion: nil)
  }
}

private class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let completion: (URL?) -> Void

  init(completion: @escaping (URL?) -> Void) {
    self.completion = completion
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    completion(urls.first)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion(nil)
  }
}
