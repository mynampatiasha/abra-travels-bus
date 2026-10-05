/// Keys of the shared messages (`l10n/app_en.arb` is the reference).
///
/// Naming: `<area><Meaning>` in lower camel case — `common…` for words used
/// everywhere, `state…` for screen states, `validation…` for form errors.
/// Each app adds its own keys in its own resource files with its own
/// prefix. `abra_strings_test.dart` checks that this list and the English
/// resource contain exactly the same keys.
abstract final class AbraStrings {
  static const commonOk = 'commonOk';
  static const commonCancel = 'commonCancel';
  static const commonClose = 'commonClose';
  static const commonContinue = 'commonContinue';
  static const commonBack = 'commonBack';
  static const commonSave = 'commonSave';
  static const commonRetry = 'commonRetry';
  static const commonLoading = 'commonLoading';
  static const commonSignIn = 'commonSignIn';
  static const commonSignOut = 'commonSignOut';

  /// Argument: `requestId`.
  static const commonRequestReference = 'commonRequestReference';

  /// Plural. Argument: `count`.
  static const commonRetryInSeconds = 'commonRetryInSeconds';

  static const languageFollowDevice = 'languageFollowDevice';

  static const stateEmptyTitle = 'stateEmptyTitle';
  static const stateEmptyMessage = 'stateEmptyMessage';
  static const stateErrorTitle = 'stateErrorTitle';
  static const stateErrorMessage = 'stateErrorMessage';
  static const stateNetworkTitle = 'stateNetworkTitle';
  static const stateNetworkMessage = 'stateNetworkMessage';
  static const stateTimeoutTitle = 'stateTimeoutTitle';
  static const stateTimeoutMessage = 'stateTimeoutMessage';
  static const stateServerTitle = 'stateServerTitle';
  static const stateServerMessage = 'stateServerMessage';
  static const stateUnauthorizedTitle = 'stateUnauthorizedTitle';
  static const stateUnauthorizedMessage = 'stateUnauthorizedMessage';
  static const stateForbiddenTitle = 'stateForbiddenTitle';
  static const stateForbiddenMessage = 'stateForbiddenMessage';
  static const stateNotFoundTitle = 'stateNotFoundTitle';
  static const stateNotFoundMessage = 'stateNotFoundMessage';
  static const stateSessionExpiredTitle = 'stateSessionExpiredTitle';
  static const stateSessionExpiredMessage = 'stateSessionExpiredMessage';
  static const stateRateLimitedTitle = 'stateRateLimitedTitle';
  static const stateRateLimitedMessage = 'stateRateLimitedMessage';
  static const stateSuccessTitle = 'stateSuccessTitle';

  static const validationRequired = 'validationRequired';
  static const validationInvalidPhone = 'validationInvalidPhone';
  static const validationInvalidEmail = 'validationInvalidEmail';

  /// Argument: `min`.
  static const validationPasswordTooShort = 'validationPasswordTooShort';

  /// Argument: `max`.
  static const validationPasswordTooLong = 'validationPasswordTooLong';
  static const validationPasswordTooSimple = 'validationPasswordTooSimple';
  static const validationPasswordContainsIdentifier =
      'validationPasswordContainsIdentifier';
  static const validationInvalidCode = 'validationInvalidCode';
  static const validationNameTooShort = 'validationNameTooShort';
  static const validationNameTooLong = 'validationNameTooLong';

  /// Every key above.
  static const Set<String> all = <String>{
    commonOk,
    commonCancel,
    commonClose,
    commonContinue,
    commonBack,
    commonSave,
    commonRetry,
    commonLoading,
    commonSignIn,
    commonSignOut,
    commonRequestReference,
    commonRetryInSeconds,
    languageFollowDevice,
    stateEmptyTitle,
    stateEmptyMessage,
    stateErrorTitle,
    stateErrorMessage,
    stateNetworkTitle,
    stateNetworkMessage,
    stateTimeoutTitle,
    stateTimeoutMessage,
    stateServerTitle,
    stateServerMessage,
    stateUnauthorizedTitle,
    stateUnauthorizedMessage,
    stateForbiddenTitle,
    stateForbiddenMessage,
    stateNotFoundTitle,
    stateNotFoundMessage,
    stateSessionExpiredTitle,
    stateSessionExpiredMessage,
    stateRateLimitedTitle,
    stateRateLimitedMessage,
    stateSuccessTitle,
    validationRequired,
    validationInvalidPhone,
    validationInvalidEmail,
    validationPasswordTooShort,
    validationPasswordTooLong,
    validationPasswordTooSimple,
    validationPasswordContainsIdentifier,
    validationInvalidCode,
    validationNameTooShort,
    validationNameTooLong,
  };
}
