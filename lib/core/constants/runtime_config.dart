/// Configuração de runtime via --dart-define (sem secrets no repositório).
///
/// Exemplos:
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
///   flutter run --dart-define=MERCADOPAGO_PUBLIC_KEY=APP_USR-...
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

  static bool get hasPlaceholderMaps =>
      googleMapsApiKey.contains('COLE_SUA');

  static bool get hasPlaceholderMercadoPago =>
      mercadoPagoPublicKey.contains('COLE_SUA');
}
