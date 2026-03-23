import '../../core/constants/app_strings.dart';

/// ------------------------------------------------------------
/// VALIDATION RESULT (State-agnostic)
/// ------------------------------------------------------------
class ValidationResult {
  final String value;
  final String? error;
  final bool isValid;

  const ValidationResult({
    required this.value,
    this.error,
    required this.isValid,
  });

  factory ValidationResult.valid(String value) =>
      ValidationResult(value: value, isValid: true);

  factory ValidationResult.invalid(String value, String error) =>
      ValidationResult(value: value, error: error, isValid: false);
}

/// ------------------------------------------------------------
/// FIELD TYPES (replaces boolean explosion)
/// ------------------------------------------------------------
enum FieldType {
  otp,
  common,
  email,
  pincode,
  number,
  password,
  confirmPassword,
  selection,
}

/// ------------------------------------------------------------
/// MASTER VALIDATOR (PURE FUNCTION)
/// ------------------------------------------------------------
class FormValidator {
  static ValidationResult validate({
    required String value,
    required FieldType type,

    // optional messages
    String? error1,
    String? error2,
    String? error3,

    // optional dependencies
    String? confirmPasswordValue,
    double? totalAmount,
    String? mediumGroupValue,
    String? roleGroupValue,
  }) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );

    final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*?&]+$');

    /// ---------------- SELECTION ----------------
    if (type == FieldType.selection) {
      if (mediumGroupValue == '' || roleGroupValue == '') {
        return ValidationResult.invalid(value, error1 ?? ValidationStrings.selectionRequired);
      }
      return ValidationResult.valid(value);
    }

    /// ---------------- EMPTY ----------------
    if (value.isEmpty) {
      return ValidationResult.invalid(value, error1 ?? ValidationStrings.requiredField);
    }

    /// ---------------- SPACE ----------------
    if (value.startsWith(' ')) {
      return ValidationResult.invalid(
        value,
        ValidationStrings.removeSpaceAtBeginning,
      );
    }

    /// ---------------- TYPE VALIDATION ----------------
    switch (type) {
      case FieldType.otp:
        if (value.length != 4) {
          return ValidationResult.invalid(value, error2 ?? ValidationStrings.invalidOtp);
        }
        break;

      case FieldType.email:
        if (!value.contains('@')) {
          return ValidationResult.invalid(value, error2 ?? ValidationStrings.invalidEmail);
        }
        if (!emailRegex.hasMatch(value)) {
          return ValidationResult.invalid(value, error3 ?? ValidationStrings.invalidEmail);
        }
        break;

      case FieldType.pincode:
        if (value.length != 6) {
          return ValidationResult.invalid(value, error2 ?? ValidationStrings.invalidPincode);
        }
        break;

      case FieldType.number:
        final parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) {
          return ValidationResult.invalid(value, error1 ?? ValidationStrings.invalidNumber);
        }
        if (totalAmount != null && parsed > totalAmount) {
          return ValidationResult.invalid(
            value,
            error2 ?? ValidationStrings.amountExceedsTotal,
          );
        }
        break;

      case FieldType.password:
        if (value.contains(' ')) {
          return ValidationResult.invalid(value, error2 ?? ValidationStrings.noSpacesAllowed);
        }
        if (value.length < 8) {
          return ValidationResult.invalid(value, error3 ?? ValidationStrings.min8Chars);
        }
        if (value.length > 16) {
          return ValidationResult.invalid(
            value,
            ValidationStrings.passwordTooLong,
          );
        }
        if (!passwordRegex.hasMatch(value)) {
          return ValidationResult.invalid(
            value,
            ValidationStrings.lettersAndNumbers,
          );
        }
        break;

      case FieldType.confirmPassword:
        if (value != confirmPasswordValue) {
          return ValidationResult.invalid(
            value,
            error3 ?? ValidationStrings.passwordsDoNotMatch,
          );
        }
        break;

      case FieldType.common:
      case FieldType.selection:
        break;
    }

    return ValidationResult.valid(value);
  }
}
