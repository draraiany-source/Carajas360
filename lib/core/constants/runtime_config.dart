/// Configuração de runtime via --dart-define (sem secrets no repositório).
///
/// Exemplos:
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
///   flutter run --dart-define=MERCADOPAGO_PUBLIC_KEY=TEST-...
///   flutter run --dart-define=DEV_BYPASS_LOGIN=true  # só debug; ver DEV_BYPASS_LOGIN.md
///
/// Android Maps nativo: defina MAPS_API_KEY em android/local.properties
/// (ver comentário em android/app/build.gradle).
abstract final class RuntimeConfig {
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'COLE_SUA_GOOGLE_MAPS_API_KEY_AQUI',
  );

  static const mercadoPagoPublicKey = String.fromEnvironment(
    'MERCADOPAGO_PUBLIC_KEY',
    defaultValue: 'COLE_SUA_MERCADOPAGO_PUBLIC_KEY_AQUI',
  );

  /// App Check: só ligar depois das chaves reais (ver CHECKLIST_FIREBASE_STAGING.md).
  static const appCheckEnabled =
      bool.fromEnvironment('APP_CHECK_ENABLED', defaultValue: false);

  /// Site key reCAPTCHA v3 (Web). Vazio = não ativar provider web. Nunca inventar.
  static const appCheckWebRecaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static bool get hasPlaceholderMaps =>
      googleMapsApiKey.contains('COLE_SUA');

  static bool get hasPlaceholderMercadoPago =>
      mercadoPagoPublicKey.contains('COLE_SUA');

  static bool get hasAppCheckWebSiteKey =>
      appCheckWebRecaptchaSiteKey.isNotEmpty &&
      !appCheckWebRecaptchaSiteKey.contains('COLE_SUA');

  /// Smoke sem Firebase Auth. Default false. Release ignora (DevBypassAuth).
  static const devBypassLoginDefine =
      bool.fromEnvironment('DEV_BYPASS_LOGIN', defaultValue: false);
}
