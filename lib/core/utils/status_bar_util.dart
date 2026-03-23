import 'package:datatransfer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatusBarUtil {
  StatusBarUtil._();

  /// Returns SystemUiOverlayStyle based on current theme
  static SystemUiOverlayStyle styleForTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );
  }
}
