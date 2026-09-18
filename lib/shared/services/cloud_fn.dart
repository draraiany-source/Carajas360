import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/auth/dev_bypass_auth.dart';
import '../../core/security/order_policy.dart';
import '../../firebase_options.dart';

export '../../core/security/order_policy.dart' show CloudCallException;

/// Callables autenticadas (região us-central1). Sem CORS aberto.
abstract final class CloudFn {
  static String get projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;
  static String get base =>
      'https://us-central1-$projectId.cloudfunctions.net';

  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> call(
      String name, [Map<String, dynamic>? data]) async {
    if (DevBypassAuth.enabled) {
      User? real;
      try {
        real = FirebaseAuth.instance.currentUser;
      } catch (_) {
        real = null;
      }
      if (real == null) {
        throw const CloudCallException(
          'Modo teste (DEV_BYPASS_LOGIN): callables exigem login Firebase real.',
          code: 'unauthenticated',
        );
      }
    }
    try {
      final result = await _fn.httpsCallable(name).call(data ?? {});
      final raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return {'data': raw};
    } on FirebaseFunctionsException catch (e) {
      throw CloudCallException(e.message ?? 'Falha na operação',
          code: e.code);
    }
  }
}
