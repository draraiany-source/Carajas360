import Flutter
import UIKit
#if canImport(GoogleMaps)
import GoogleMaps
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleMaps()
    // Firebase NAO e configurado aqui: o Dart inicializa com as opcoes do
    // ambiente (lib/firebase_options_<env>.dart, via APP_ENV). Configurar
    // nativamente a partir de um unico GoogleService-Info.plist misturaria
    // ambientes. O token APNs chega ao Firebase Messaging pelo proxy do
    // AppDelegate (FirebaseAppDelegateProxyEnabled habilitado por padrao).
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Le a chave do Info.plist (GMSApiKey = $(MAPS_API_KEY), definida em
  /// ios/Flutter/MapsKey.xcconfig, nao versionado). Sem chave: mapas
  /// desabilitados, sem crash.
  private func configureGoogleMaps() {
    let raw = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
    let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !key.isEmpty, !key.hasPrefix("$("), !key.hasPrefix("COLE_") else {
      NSLog("Carajas360: MAPS_API_KEY ausente; Google Maps desabilitado.")
      return
    }
    #if canImport(GoogleMaps)
    GMSServices.provideAPIKey(key)
    #else
    #warning("Carajas360: modulo GoogleMaps indisponivel para o Runner; chave do Maps nao sera aplicada.")
    NSLog("Carajas360: modulo GoogleMaps indisponivel.")
    #endif
  }
}
