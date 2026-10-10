// ════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — DESENVOLVIMENTO (somente emuladores locais).
//
// Projeto `demo-carajas360`: o prefixo "demo-" faz os emuladores do
// Firebase funcionarem sem nenhum recurso na nuvem. Inicie com:
//   firebase emulators:start --project demo-carajas360
// ════════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

abstract final class DevFirebaseOptions {
  static const projectId = 'demo-carajas360';

  static const android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
    iosBundleId: 'br.com.servicoconecta.dev',
  );

  static const web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
    authDomain: '$projectId.firebaseapp.com',
  );
}
