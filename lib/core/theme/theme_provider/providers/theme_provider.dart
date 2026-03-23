import 'package:datatransfer/core/services/shared_prefs_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  // This should be overridden in ProviderScope
  return ThemeNotifier(ThemeMode.light);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(ThemeMode initialMode) : super(initialMode);

  void toggleTheme(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    await SharedPrefsService().setDarkMode(isDark);
  }
}
