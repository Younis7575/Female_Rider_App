import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Google Maps key read from Info.plist (GMSApiKey <- $(MAPS_API_KEY) from ios/Flutter/Maps.xcconfig).
  private var mapsConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.trimmingCharacters(in: .whitespaces).isEmpty,
       !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
      mapsConfigured = true
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.gopangitsolution.femalerider/platform",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isMapsConfigured":
        result(self?.mapsConfigured ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
