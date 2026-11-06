import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Permite arrastar listas horizontais com mouse no desktop/web.
class BrandDragScrollBehavior extends MaterialScrollBehavior {
  const BrandDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Identidade visual oficial Carajás 360 (verde-esmeralda, branco e dourado).
/// Base do design system da modernização; telas migradas usam estas cores.
abstract final class Brand {
  static const green = Color(0xFF006B35);
  static const greenDark = Color(0xFF003D24);
  static const greenMid = Color(0xFF0B8A4A);
  static const greenLight = Color(0xFFE7F5EB);
  static const gold = Color(0xFFFFC400);
  static const goldDeep = Color(0xFFB98A00);
  static const goldLight = Color(0xFFFFF4CC);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7FAF8);
  static const text = Color(0xFF17251D);
  static const textMuted = Color(0xFF66756C);
  static const border = Color(0xFFE2EAE5);

  static const heroGradient = LinearGradient(
    colors: [greenDark, green, greenMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const sidebarGradient = LinearGradient(
    colors: [greenDark, Color(0xFF00512F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? AppColors.darkSurface : white;

  static Color ink(BuildContext context) =>
      isDark(context) ? AppColors.darkTextHigh : text;

  static Color inkMuted(BuildContext context) =>
      isDark(context) ? AppColors.darkTextLow : textMuted;

  static Color line(BuildContext context) =>
      isDark(context) ? AppColors.darkBorder : border;

  static List<BoxShadow> shadow(BuildContext context) => [
        BoxShadow(
          color: (isDark(context) ? Colors.black : greenDark)
              .withValues(alpha: isDark(context) ? 0.3 : 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
