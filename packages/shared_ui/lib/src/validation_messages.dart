import 'package:shared_localization/shared_localization.dart';
import 'package:shared_validation/shared_validation.dart';

/// The translated message for a validation [problem], or null when there is
/// no problem. For use as a form field `validator` result.
String? validationMessage(
  AbraLocalizations l10n,
  InputProblem? problem,
) => switch (problem) {
  null => null,
  InputProblem.required => l10n.text(AbraStrings.validationRequired),
  InputProblem.invalidPhone => l10n.text(AbraStrings.validationInvalidPhone),
  InputProblem.invalidEmail => l10n.text(AbraStrings.validationInvalidEmail),
  InputProblem.passwordTooShort => l10n.text(
    AbraStrings.validationPasswordTooShort,
    <String, Object?>{'min': InputLimits.passwordMinLength},
  ),
  InputProblem.passwordTooLong => l10n.text(
    AbraStrings.validationPasswordTooLong,
    <String, Object?>{'max': InputLimits.passwordMaxLength},
  ),
  InputProblem.passwordTooSimple => l10n.text(
    AbraStrings.validationPasswordTooSimple,
  ),
  InputProblem.passwordContainsIdentifier => l10n.text(
    AbraStrings.validationPasswordContainsIdentifier,
  ),
  InputProblem.invalidCode => l10n.text(AbraStrings.validationInvalidCode),
  InputProblem.nameTooShort => l10n.text(AbraStrings.validationNameTooShort),
  InputProblem.nameTooLong => l10n.text(AbraStrings.validationNameTooLong),
};
