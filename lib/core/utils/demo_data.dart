import 'package:flutter/foundation.dart';

/// Listas fictícias **só em debug**.
/// Nunca em release. Nunca substituem uma resposta real do backend
/// (lista vazia do servidor permanece vazia).
abstract final class DemoData {
  /// Guard explícito — testável sem depender de kReleaseMode.
  static bool enabledFor({
    required bool releaseMode,
    required bool debugMode,
  }) {
    if (releaseMode) return false;
    return debugMode;
  }

  static bool get allow {
    final on = enabledFor(releaseMode: kReleaseMode, debugMode: kDebugMode);
    assert(() {
      if (kReleaseMode && on) {
        throw StateError('DemoData.allow não pode ser true em release');
      }
      return true;
    }());
    if (kReleaseMode) return false;
    return on;
  }

  /// [data] não-nulo (inclui `[]`) = backend real — nunca mescla demo.
  /// [data] nulo só cai no demo em debug, para telas locais sem Firebase.
  static List<T> orEmpty<T>(List<T>? data, List<T> demo) {
    if (kReleaseMode) {
      assert(!allow);
      return data ?? const [];
    }
    if (data != null) return data;
    return allow ? demo : const [];
  }
}
