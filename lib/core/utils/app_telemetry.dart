import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics sem PII. Falha silenciosa — não quebra o app.
abstract final class AppTelemetry {
  static Future<void> event(String name, [Map<String, Object>? params]) async {
    if (kIsWeb) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: params,
      );
    } catch (e) {
      debugPrint('telemetry: $e');
    }
  }

  static Future<void> screen(String name) async {
    if (kIsWeb) return;
    try {
      await FirebaseAnalytics.instance.logScreenView(screenName: name);
    } catch (e) {
      debugPrint('telemetry screen: $e');
    }
  }
}
