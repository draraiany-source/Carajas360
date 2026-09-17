import 'package:flutter/foundation.dart';

/// Em release/Play Store nunca usa listas fictícias.
/// Em debug/profile permite fallback demo só para desenvolvimento local.
abstract final class DemoData {
  static bool get allow => !kReleaseMode;

  static List<T> orEmpty<T>(List<T>? data, List<T> demo) {
    if (data != null) return data;
    return allow ? demo : const [];
  }
}
