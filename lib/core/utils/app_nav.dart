import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Navegação segura: pop real ou fallback para a Home.
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
}
