// ════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — HOMOLOGAÇÃO (projeto `carajas360-hml`).
//
// Crie um projeto Firebase separado para homologação e gere com:
//   flutterfire configure --project=<id-do-projeto-hml> \
//     --out=lib/firebase_options_hml.dart \
//     --android-package-name=br.com.servicoconecta.hml \
//     --ios-bundle-id=br.com.servicoconecta.hml
// Se o id real for diferente de `carajas360-hml`, atualize também o
// alias "hml" em .firebaserc.
// ════════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

abstract final class HmlFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'COLE_SUA_ANDROID_API_KEY',
    appId: '1:NUMERO:android:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'carajas360-hml',
    storageBucket: 'carajas360-hml.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'COLE_SUA_IOS_API_KEY',
    appId: '1:NUMERO:ios:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'carajas360-hml',
    storageBucket: 'carajas360-hml.appspot.com',
    iosBundleId: 'br.com.servicoconecta.hml',
  );

  static const web = FirebaseOptions(
    apiKey: 'COLE_SUA_WEB_API_KEY',
    appId: '1:NUMERO:web:HASH',
    messagingSenderId: 'NUMERO',
    projectId: 'carajas360-hml',
    storageBucket: 'carajas360-hml.appspot.com',
    authDomain: 'carajas360-hml.firebaseapp.com',
    measurementId: 'G-XXXXXXXXXX',
  );
}
