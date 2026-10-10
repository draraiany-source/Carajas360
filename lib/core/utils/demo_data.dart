import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

/// Dados de demonstração NUNCA aparecem em homologação, produção ou
/// release. Em dev só com --dart-define=DEMO_DATA=true. Mesmo assim,
/// falha de backend não é mascarada: [orEmpty] só usa a demo quando
/// não há dados nem erro (ver chamadas com snapshot.hasError).
abstract final class DemoData {
  static bool get allow =>
      !kReleaseMode && AppEnv.isDev && AppEnv.demoDataRequested;

  static List<T> orEmpty<T>(List<T>? data, List<T> demo) {
    if (data != null) return data;
    return allow ? demo : const [];
  }
}
