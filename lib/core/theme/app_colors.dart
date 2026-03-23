import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFF818CF8);

  // Secondary / Accent
  static const Color secondary = Color(0xFFEC4899);
  static const Color accent = Color(0xFF14B8A6);

  // Background
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B);

  static const Color surfaceGrey = Color(0xFFF1F5F9);
  static const Color surfaceGreyDark = Color(0xFF334155);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);

  static const Color textSecondary = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static const Color textLight = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Common Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF); // 70% opacity white
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // =========================
  // 🔥 THEME-AWARE HELPERS
  // =========================

  static Color scaffoldBackground(bool isDark) =>
      isDark ? backgroundDark : background;

  static Color surfaceColor(bool isDark) => isDark ? surfaceDark : surface;

  static Color surfaceGreyColor(bool isDark) =>
      isDark ? surfaceGreyDark : surfaceGrey;

  static Color textPrimaryColor(bool isDark) =>
      isDark ? textPrimaryDark : textPrimary;

  static Color textSecondaryColor(bool isDark) =>
      isDark ? textSecondaryDark : textSecondary;
}
