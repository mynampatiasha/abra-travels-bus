/// Input validators that mirror the backend rules, so a form can point out a
/// problem before the request is sent. The server validates everything again
/// and remains the authority.
///
/// Validators return an [InputProblem] (or null when the value is fine)
/// rather than text, so the message can be translated by the app.
library;

final RegExp _e164 = RegExp(r'^\+[1-9]\d{7,14}$');
final RegExp _indianMobile = RegExp(r'^[6-9]\d{9}$');
final RegExp _email = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$",
);
final RegExp _otp = RegExp(r'^\d{4,8}$');
final RegExp _totp = RegExp(r'^\d{6}$');

/// What is wrong with a value. Apps map each case to a translated message.
enum InputProblem {
  required,
  invalidPhone,
  invalidEmail,
  passwordTooShort,
  passwordTooLong,
  passwordTooSimple,
  passwordContainsIdentifier,
  invalidCode,
  nameTooShort,
  nameTooLong,
}

/// Limits shared with the backend (`password-policy.ts`, DTO schemas).
abstract final class InputLimits {
  static const passwordMinLength = 10;
  static const passwordMaxLength = 128;
  static const nameMinLength = 2;
  static const nameMaxLength = 120;
}

/// Phone numbers in the form the backend stores and compares (E.164).
abstract final class PhoneNumbers {
  /// Returns [input] in E.164 form, or null when it is not a usable number.
  /// A bare 10-digit Indian mobile number becomes `+91XXXXXXXXXX`; spaces,
  /// dashes and brackets are ignored. Same rule as the backend.
  static String? normalize(String input) {
    final compact = input.replaceAll(RegExp(r'[\s()-]'), '');
    if (_indianMobile.hasMatch(compact)) return '+91$compact';
    return _e164.hasMatch(compact) ? compact : null;
  }

  static InputProblem? validate(String? input) {
    if (input == null || input.trim().isEmpty) return InputProblem.required;
    return normalize(input) == null ? InputProblem.invalidPhone : null;
  }

  /// Hides most of the number for display: `+91******3210`.
  static String mask(String phone) => phone.length <= 7
      ? '***'
      : '${phone.substring(0, 3)}******${phone.substring(phone.length - 4)}';
}

abstract final class Emails {
  static String normalize(String input) => input.trim().toLowerCase();

  static InputProblem? validate(String? input, {bool isRequired = true}) {
    if (input == null || input.trim().isEmpty) {
      return isRequired ? InputProblem.required : null;
    }
    final value = normalize(input);
    return value.length <= 254 && _email.hasMatch(value)
        ? null
        : InputProblem.invalidEmail;
  }
}

abstract final class Passwords {
  /// Checks a new password against the backend policy: 10 to 128
  /// characters, at least four distinct characters, and not built from the
  /// account's own email address or phone number.
  static InputProblem? validateNew(
    String? password, {
    String? email,
    String? phone,
  }) {
    if (password == null || password.isEmpty) return InputProblem.required;
    if (password.length < InputLimits.passwordMinLength) {
      return InputProblem.passwordTooShort;
    }
    if (password.length > InputLimits.passwordMaxLength) {
      return InputProblem.passwordTooLong;
    }
    final lowered = password.toLowerCase();
    if (lowered.split('').toSet().length < 4) {
      return InputProblem.passwordTooSimple;
    }
    final personal = <String?>[
      email,
      email?.split('@').first,
      phone,
      if (phone != null && phone.length >= 10)
        phone.substring(phone.length - 10),
    ].whereType<String>().where((value) => value.length >= 6);
    if (personal.any((value) => lowered.contains(value.toLowerCase()))) {
      return InputProblem.passwordContainsIdentifier;
    }
    return null;
  }
}

abstract final class VerificationCodes {
  /// A code received by SMS (4 to 8 digits).
  static InputProblem? validateOtp(String? code) {
    if (code == null || code.isEmpty) return InputProblem.required;
    return _otp.hasMatch(code) ? null : InputProblem.invalidCode;
  }

  /// A code from an authenticator app (6 digits).
  static InputProblem? validateTotp(String? code) {
    if (code == null || code.isEmpty) return InputProblem.required;
    return _totp.hasMatch(code) ? null : InputProblem.invalidCode;
  }
}

abstract final class PersonNames {
  static InputProblem? validate(String? name) {
    final value = name?.trim() ?? '';
    if (value.isEmpty) return InputProblem.required;
    if (value.length < InputLimits.nameMinLength) {
      return InputProblem.nameTooShort;
    }
    if (value.length > InputLimits.nameMaxLength) {
      return InputProblem.nameTooLong;
    }
    return null;
  }
}
