import 'package:datatransfer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_strings.dart';

class AppDialogs {
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Future<void> showMessage({
    required BuildContext context,
    VoidCallback? callback,
    String? title,
    String? message,
    String? positiveButton,
    String? negativeButton,
    bool isTitleLeft = false,
    IconData? icon,
    Color? iconColor,
    Widget? logo,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Dialog",
      barrierColor: AppColors.black.withOpacity(
        isDarkMode(context) ? 0.5 : 0.6,
      ),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, _, __) => const SizedBox(),
      transitionBuilder: (context, anim, _, child) {
        final isDark = isDarkMode(context);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: Center(
              child: Material(
                color: AppColors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceColor(isDark),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 25,
                        color: AppColors.black.withOpacity(isDark ? 0.3 : 0.1),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (logo != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.08),
                          ),
                          child: logo,
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (icon != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (iconColor ?? AppColors.primary).withOpacity(
                              0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 44,
                            color: iconColor ?? AppColors.primary,
                          ),
                        ),
                      if (icon != null) const SizedBox(height: 20),

                      if ((title ?? '').isNotEmpty)
                        Text(
                          title!,
                          textAlign: isTitleLeft
                              ? TextAlign.left
                              : TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.white
                                : AppColors.textPrimaryColor(isDark),
                          ),
                        ),
                      if ((title ?? '').isNotEmpty) const SizedBox(height: 12),

                      if ((message ?? '').isNotEmpty)
                        Text(
                          message!,
                          textAlign: isTitleLeft
                              ? TextAlign.left
                              : TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textSecondaryColor(isDark),
                          ),
                        ),
                      const SizedBox(height: 28),

                      Row(
                        children: [
                          if ((negativeButton ?? '').isNotEmpty)
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color:
                                        (isDark
                                                ? AppColors.white
                                                : AppColors.primary)
                                            .withOpacity(0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  negativeButton!,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.white70
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          if ((negativeButton ?? '').isNotEmpty &&
                              (positiveButton ?? '').isNotEmpty)
                            const SizedBox(width: 12),
                          if ((positiveButton ?? '').isNotEmpty)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  callback?.call();
                                },
                                child: Text(
                                  positiveButton!,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> showExitDialog(
    BuildContext context,
    VoidCallback onConfirm,
  ) {
    return showMessage(
      context: context,
      title: DialogStrings.exitAppTitle,
      message: DialogStrings.exitAppMessage,
      positiveButton: DialogStrings.confirm,
      negativeButton: DialogStrings.cancel,
      icon: Icons.logout_rounded,
      iconColor: AppColors.error,
      callback: onConfirm,
    );
  }
}
