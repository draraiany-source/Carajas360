// ════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — Carajás 360
//
// Placeholders de staging. NÃO invente keys.
// Gere este arquivo automaticamente com:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=carajas360-a17c5
//
// IDs migrados (autorização da Raiany):
//   projectId  carajas360-a17c5
//   Android/iOS br.com.carajas360
//   Dart package carajas_360
// Ver CHECKLIST_FIREBASE_STAGING.md e IDENTIDADE_TECNICA.md.
// ════════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma não suportada');
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'COLE_SUA_ANDROID_API_KEY',
    appId: '1:NUMERO:android:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'carajas360-a17c5',
    storageBucket: 'carajas360-a17c5.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'COLE_SUA_IOS_API_KEY',
    appId: '1:NUMERO:ios:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'carajas360-a17c5',
    storageBucket: 'carajas360-a17c5.appspot.com',
    iosBundleId: 'br.com.carajas360',
  );

  static const web = FirebaseOptions(
    apiKey: 'COLE_SUA_WEB_API_KEY',
    appId: '1:NUMERO:web:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'carajas360-a17c5',
    storageBucket: 'carajas360-a17c5.appspot.com',
    authDomain: 'carajas360-a17c5.firebaseapp.com',
    measurementId: 'G-XXXXXXXXXX',
  );
}
