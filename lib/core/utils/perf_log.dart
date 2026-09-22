import 'package:flutter/foundation.dart';
import 'firebase_bootstrap.dart';

/// Logs de diagnóstico só em homologação (placeholders) ou debug.
/// Nunca registra senha, token, CPF, cartão ou PII sensível.
abstract final class PerfLog {
  static bool get enabled =>
      kDebugMode || FirebaseBootstrap.hasPlaceholderKeys;

  static void screen(String name) {
    if (!enabled) return;
    debugPrint('[PERF] screen=$name t=${DateTime.now().toIso8601String()}');
  }

  static void query(String name, {String? category, int? limit, int? ms}) {
    if (!enabled) return;
    final cat = (category == null || category.isEmpty) ? '-' : category;
    final lim = limit?.toString() ?? '-';
    final dur = ms == null ? '' : ' ms=$ms';
    debugPrint('[PERF] query=$name category=$cat limit=$lim$dur');
  }

  static void error(String where, Object error) {
    if (!enabled) return;
    debugPrint('[PERF] error where=$where err=$error');
  }

  static void auth(String event) {
    if (!enabled) return;
    debugPrint('[PERF] auth=$event');
  }

  static void nav(String action, {String? route}) {
    if (!enabled) return;
    debugPrint('[PERF] nav=$action route=${route ?? '-'}');
  }
}
