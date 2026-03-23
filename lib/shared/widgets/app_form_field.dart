import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// ------------------------------------------------------------
/// FIELD CONTROLLER (Text + Focus)
/// ------------------------------------------------------------
class FieldController {
  final TextEditingController text;
  final FocusNode focus;

  FieldController() : text = TextEditingController(), focus = FocusNode();

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

/// ------------------------------------------------------------
/// FIELD VARIANT
/// ------------------------------------------------------------
enum FieldVariant { normal, password, search, dropdown }

/// ------------------------------------------------------------
/// APP TEXT FIELD (PURE UI)
/// ------------------------------------------------------------
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.errorText,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.readOnly = false,
    this.variant = FieldVariant.normal,
    this.onTap,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.validator,
    this.autovalidateMode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final bool enabled;
  final bool readOnly;
  final FieldVariant variant;
  final VoidCallback? onTap;
  final Widget? prefix;
  final Widget? suffix;
  final int maxLines;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.variant == FieldVariant.password;
  }

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.variant == FieldVariant.password;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: AppColors.textLight.withOpacity(0.6),
        ),
        errorText: widget.errorText,
        prefixIcon: widget.prefix != null
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: IconTheme(
                  data: IconThemeData(
                    color: widget.focusNode.hasFocus
                        ? AppColors.primary
                        : AppColors.textLight,
                    size: 22.sp,
                  ),
                  child: widget.prefix!,
                ),
              )
            : null,
        prefixIconConstraints: BoxConstraints(minWidth: 40.w),
        suffixIcon: isPassword
            ? GestureDetector(
                onTap: () => setState(() => _obscureText = !_obscureText),
                child: Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: Icon(
                    _obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 22.sp,
                    color: _obscureText
                        ? AppColors.textLight
                        : AppColors.primary,
                  ),
                ),
              )
            : widget.suffix != null
            ? Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: widget.suffix,
              )
            : null,
        suffixIconConstraints: BoxConstraints(minWidth: 40.w),
        filled: true,
        fillColor: widget.enabled
            ? (widget.focusNode.hasFocus
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.surfaceGreyColor(isDark).withOpacity(0.5))
            : AppColors.surfaceGreyColor(isDark),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: _buildBorder(AppColors.textLight.withOpacity(0.2)),
        enabledBorder: _buildBorder(AppColors.textLight.withOpacity(0.1)),
        focusedBorder: _buildBorder(AppColors.primary, width: 1.5),
        errorBorder: _buildBorder(AppColors.error),
        focusedErrorBorder: _buildBorder(AppColors.error, width: 1.5),
        disabledBorder: _buildBorder(AppColors.textLight.withOpacity(0.05)),
      ),
    );
  }

  OutlineInputBorder _buildBorder(Color color, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// ------------------------------------------------------------
/// LABEL + FIELD WRAPPER
/// ------------------------------------------------------------
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.errorText,
    this.onChanged,
    this.isRequired = false,
    this.variant = FieldVariant.normal,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.validator,
    this.autovalidateMode,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool isRequired;
  final FieldVariant variant;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? prefix;
  final Widget? suffix;
  final int maxLines;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: RichText(
            text: TextSpan(
              text: label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryColor(
                  theme.brightness == Brightness.dark,
                ).withOpacity(0.7),
              ),
              children: [
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.error, fontSize: 14.sp),
                  ),
              ],
            ),
          ),
        ),
        AppTextField(
          controller: controller,
          focusNode: focusNode,
          hint: hint,
          errorText: errorText,
          onChanged: onChanged,
          keyboardType: keyboardType,
          variant: variant,
          readOnly: readOnly,
          onTap: onTap,
          prefix: prefix,
          suffix: suffix,
          maxLines: maxLines,
          validator: validator,
          autovalidateMode: autovalidateMode,
        ),
      ],
    );
  }
}
