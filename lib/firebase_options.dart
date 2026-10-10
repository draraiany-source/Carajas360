// ════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — seletor por ambiente (dev / hml / prod).
//
// Cada ambiente tem seu arquivo:
//   firebase_options_dev.dart  → emuladores (demo-carajas360)
//   firebase_options_hml.dart  → homologação
//   firebase_options_prod.dart → produção (servicoconecta)
// O ambiente vem de --dart-define=APP_ENV (ver core/config/app_env.dart).
// ════════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'core/config/app_env.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_hml.dart';
import 'firebase_options_prod.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      forEnvironment(AppEnv.current);

  static FirebaseOptions forEnvironment(AppEnvironment env) {
    final platform = kIsWeb ? null : defaultTargetPlatform;
    return switch (env) {
      AppEnvironment.dev => _pick(platform, DevFirebaseOptions.android,
          DevFirebaseOptions.ios, DevFirebaseOptions.web),
      AppEnvironment.hml => _pick(platform, HmlFirebaseOptions.android,
          HmlFirebaseOptions.ios, HmlFirebaseOptions.web),
      AppEnvironment.prod => _pick(platform, ProdFirebaseOptions.android,
          ProdFirebaseOptions.ios, ProdFirebaseOptions.web),
    };
  }

  static FirebaseOptions _pick(TargetPlatform? platform, FirebaseOptions android,
      FirebaseOptions ios, FirebaseOptions web) {
    if (platform == null) return web;
    switch (platform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma não suportada');
    }
  }
}
