// ════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — Carajás 360
//
// Gerado a partir de `firebase apps:sdkconfig` no projeto
// carajas360-a17c5 (apps reais Android/iOS/Web). Não inventar keys.
// Regenerar se necessário:
//   firebase apps:sdkconfig ANDROID|IOS|WEB --project carajas360-a17c5
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
    apiKey: 'AIzaSyBUWj_amgBaD3Pqk5ImKgyRNwj-MObzA1c',
    appId: '1:943691582268:android:815702597e79223a9eec39',
    messagingSenderId: '943691582268',
    projectId: 'carajas360-a17c5',
    storageBucket: 'carajas360-a17c5.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCKosmKE7Sw6XKqb_Xuz6MIGtUW0kYQDLA',
    appId: '1:943691582268:ios:28b25a6c6d3c60279eec39',
    messagingSenderId: '943691582268',
    projectId: 'carajas360-a17c5',
    storageBucket: 'carajas360-a17c5.firebasestorage.app',
    iosBundleId: 'br.com.carajas360',
  );

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBjzEUtgteCKt_pus6YbYcQ6w1pECWETgY',
    appId: '1:943691582268:web:cd3e505962fd07059eec39',
    messagingSenderId: '943691582268',
    projectId: 'carajas360-a17c5',
    storageBucket: 'carajas360-a17c5.firebasestorage.app',
    authDomain: 'carajas360-a17c5.firebaseapp.com',
    measurementId: 'G-N9B19BCQJX',
  );
}
