import 'package:flutter/material.dart';

/// Identidade visual premium do ServiçoConecta.
/// Azul confiança + verde conclusão — sem roxo/creme genéricos de IA.
abstract class AppColors {
  static const primary = Color(0xFF0B3D91);
  static const primaryLight = Color(0xFF1565C0);
  static const primaryMid = Color(0xFF1E88E5);
  static const primarySoft = Color(0xFFE8F1FC);
  static const secondary = Color(0xFF1B7A4E);
  static const secondaryLight = Color(0xFF2E9B68);
  static const success = Color(0xFF12B76A);
  static const warning = Color(0xFFF5A524);
  static const error = Color(0xFFD92D20);
  static const info = Color(0xFF0E8F9E);
  static const health = Color(0xFF0F6B5C);
  static const delivery = Color(0xFFD4550A);
  static const navy = Color(0xFF0A2540);
  static const purple = Color(0xFF5B21B6);
  static const teal = Color(0xFF0E8F9E);
  static const orange = Color(0xFFD4550A);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF3F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF3F9);
  static const border = Color(0xFFD8E0EA);
  static const divider = Color(0xFFE6ECF2);
  static const textDark = Color(0xFF0F172A);
  static const textMedium = Color(0xFF334155);
  static const textLight = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const shimmerBase = Color(0xFFE2E8F0);
  static const pix = Color(0xFF32BCAD);
  static const gold = Color(0xFFE6A700);

  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF151D2E);
  static const darkBorder = Color(0xFF243044);
  static const darkDivider = Color(0xFF1E293B);
  static const darkTextHigh = Color(0xFFF1F5F9);
  static const darkTextMed = Color(0xFFCBD5E1);
  static const darkTextLow = Color(0xFF94A3B8);
}

abstract class AppGradients {
  static const splash = LinearGradient(
      colors: [Color(0xFF0A2540), Color(0xFF0B3D91), Color(0xFF1B7A4E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const primary = LinearGradient(
      colors: [AppColors.navy, AppColors.primary, AppColors.primaryMid],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const secondary = LinearGradient(
      colors: [AppColors.secondary, AppColors.secondaryLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const health = LinearGradient(
      colors: [AppColors.primary, AppColors.primaryLight, AppColors.teal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const delivery = LinearGradient(
      colors: [AppColors.delivery, Color(0xFFFF7A2F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const purple = LinearGradient(
      colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const pix = LinearGradient(
      colors: [AppColors.pix, Color(0xFF00BFA5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const dark = LinearGradient(
      colors: [Color(0xFF0B1220), Color(0xFF152238)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const gold = LinearGradient(
      colors: [Color(0xFFE6A700), Color(0xFFF5C542)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static const authHero = LinearGradient(
      colors: [Color(0xFF071A33), Color(0xFF0B3D91), Color(0xFF0F5C45)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter);
}
