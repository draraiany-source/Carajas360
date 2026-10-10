import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../../firebase_options.dart';
import '../config/app_env.dart';

/// Falha de configuração: o app mostra indisponibilidade explícita em vez
/// de aparentar operação válida.
class AppConfigurationException implements Exception {
  final List<String> problems;
  const AppConfigurationException(this.problems);
  @override
  String toString() => problems.join('\n');
}

/// Inicializa Firebase conforme o ambiente (dev/hml/prod).
/// Emuladores: somente em dev (ou USE_FIREBASE_EMULATOR=true), e nunca em
/// release.
abstract final class FirebaseBootstrap {
  static const useEmulatorDefine =
      bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);

  static bool get hasPlaceholderKeys {
    final key = DefaultFirebaseOptions.currentPlatform.apiKey;
    return key.contains('COLE_SUA') || key.contains('demo-api-key');
  }

  static bool get shouldUseEmulator {
    if (kReleaseMode) return false;
    return useEmulatorDefine || AppEnv.isDev;
  }

  static List<String> get configurationProblems =>
      AppEnv.configurationProblems(
        releaseMode: kReleaseMode,
        define: AppEnv.rawDefine,
        flavor: appFlavor,
        firebasePlaceholder: hasPlaceholderKeys,
        useEmulator: shouldUseEmulator,
      );

  static String get _emulatorHost {
    const custom = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    if (custom.isNotEmpty) return custom;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    if (kIsWeb) return 'localhost';
    return '127.0.0.1';
  }

  static Future<void> initialize() async {
    final problems = configurationProblems;
    if (problems.isNotEmpty) throw AppConfigurationException(problems);

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    if (!shouldUseEmulator) return;

    final host = _emulatorHost;
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      debugPrint('Firestore clearPersistence: $e');
    }

    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator(host, 5001);

    try {
      await FirebaseFirestore.instance.disableNetwork();
      await FirebaseFirestore.instance.enableNetwork();
    } catch (e) {
      debugPrint('Firestore network toggle: $e');
    }

    debugPrint('Firebase (${AppEnv.label}) em emuladores: '
        'Auth/Firestore/Storage/Functions em $host');
  }
}
