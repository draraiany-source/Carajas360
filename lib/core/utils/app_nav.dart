import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

abstract final class AppNav {
  static void safeBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushNamedAndRemoveUntil(Routes.main, (_) => false);
  }

  static bool canPop(BuildContext context) =>
      Navigator.of(context).canPop();

  /// Página interna: há histórico ou a rota não é a raiz do app
  /// (link direto). Nesses casos o voltar usa [safeBack].
  static bool isInnerPage(BuildContext context) {
    if (canPop(context)) return true;
    final name = ModalRoute.of(context)?.settings.name;
    return name != null && name != Routes.splash && name != Routes.main;
  }
}
