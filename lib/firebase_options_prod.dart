// ════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — PRODUÇÃO (projeto `servicoconecta`).
//
// Gere com o projeto de PRODUÇÃO e substitua os placeholders:
//   flutterfire configure --project=servicoconecta \
//     --out=lib/firebase_options_prod.dart
// Não publique builds de produção a partir deste repositório sem
// autorização. IDs de aplicação preservados (br.com.servicoconecta).
// ════════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

abstract final class ProdFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'COLE_SUA_ANDROID_API_KEY',
    appId: '1:NUMERO:android:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'servicoconecta',
    storageBucket: 'servicoconecta.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'COLE_SUA_IOS_API_KEY',
    appId: '1:NUMERO:ios:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'servicoconecta',
    storageBucket: 'servicoconecta.appspot.com',
    iosBundleId: 'br.com.servicoconecta',
  );

  static const web = FirebaseOptions(
    apiKey: 'COLE_SUA_WEB_API_KEY',
    appId: '1:NUMERO:web:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'servicoconecta',
    storageBucket: 'servicoconecta.appspot.com',
    authDomain: 'servicoconecta.firebaseapp.com',
    measurementId: 'G-XXXXXXXXXX',
  );
}
