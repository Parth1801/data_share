import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isEnabled = true,
    this.color,
    this.textColor = AppColors.white,
    this.borderRadius,
  });

  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isEnabled;
  final Color? color;
  final Color textColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isBtnEnabled = isEnabled && !isLoading;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: isBtnEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(borderRadius ?? 16.r),
        child: Ink(
          decoration: BoxDecoration(
            color: isBtnEnabled
                ? (color ?? AppColors.primary)
                : AppColors.textLight.withOpacity(0.2),
            borderRadius: BorderRadius.circular(borderRadius ?? 16.r),
            boxShadow: isBtnEnabled
                ? [
                    BoxShadow(
                      color: (color ?? AppColors.primary).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Container(
            height: 56.h,

            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    height: 24.h,
                    width: 24.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: textColor,
                    ),
                  )
                : Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isBtnEnabled
                          ? textColor
                          : AppColors.textSecondaryColor(
                              isDark,
                            ).withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
