import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let deepLinkBridge = DeepLinkBridge.shared
  private var deepLinkMethodChannel: FlutterMethodChannel?
  private var deepLinkEventChannel: FlutterEventChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let urlContext = connectionOptions.urlContexts.first {
      deepLinkBridge.initialLink = urlContext.url.absoluteString
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    registerDeepLinkChannels()
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      deepLinkBridge.handle(url.absoluteString)
    }
  }

  private func registerDeepLinkChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let messenger = controller.binaryMessenger
    deepLinkMethodChannel = FlutterMethodChannel(
      name: "checkops/deep_links",
      binaryMessenger: messenger
    )
    deepLinkMethodChannel?.setMethodCallHandler { call, result in
      if call.method == "getInitialLink" {
        result(self.deepLinkBridge.takeInitialLink())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    deepLinkEventChannel = FlutterEventChannel(
      name: "checkops/deep_links/events",
      binaryMessenger: messenger
    )
    deepLinkEventChannel?.setStreamHandler(deepLinkBridge)
  }
}

class DeepLinkBridge: NSObject, FlutterStreamHandler {
  static let shared = DeepLinkBridge()

  var initialLink: String?
  private var eventSink: FlutterEventSink?

  func takeInitialLink() -> String? {
    let link = initialLink
    initialLink = nil
    return link
  }

  func handle(_ link: String) {
    if let eventSink {
      eventSink(link)
    } else {
      initialLink = link
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
