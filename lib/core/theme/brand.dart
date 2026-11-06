import 'package:flutter/material.dart';

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
}
