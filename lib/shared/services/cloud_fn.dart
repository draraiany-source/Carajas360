import 'package:cloud_functions/cloud_functions.dart';

import '../../core/security/order_policy.dart';
import '../../firebase_options.dart';

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
