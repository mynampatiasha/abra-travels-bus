import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

import '../../l10n/customer_strings.dart';

/// What went wrong while signing in, in terms the user can act on. Server
/// messages, codes and request details are never shown.
enum SignInProblem {
  invalidPhone,

  /// The code was not accepted and has not run out of time. The server does
  /// not say why (wrong, already used, too many tries) on purpose.
  codeIncorrect,

  /// The code was not accepted and its time had run out on this device.
  codeExpired,
  tooManyAttempts,

  /// Phone sign-in is only for customer accounts.
  notCustomerAccount,
  accountDisabled,

  /// The server could not send the code on any channel.
  deliveryFailed,

  /// The account uses two-step verification, which this app does not
  /// support yet.
  twoStepNotSupported,
  network,
  timeout,
  server,
  unexpected,
}

/// The step that failed, which decides how some answers are read.
enum SignInStep { sendCode, verifyCode }

/// Maps a failure from the shared API client to a [SignInProblem].
/// [codeExpired] tells whether the code's time has run out on this device;
/// it turns `OTP_INVALID` into [SignInProblem.codeExpired].
SignInProblem signInProblemFor(
  AppFailure failure, {
  required SignInStep step,
  bool codeExpired = false,
}) => switch (failure) {
  NetworkFailure() => SignInProblem.network,
  TimeoutFailure() => SignInProblem.timeout,
  ServerFailure() => SignInProblem.server,
  SessionExpiredFailure() ||
  CancelledFailure() ||
  UnexpectedFailure() => SignInProblem.unexpected,
  ApiFailure(:final code) => switch (code) {
    ApiErrorCodes.otpInvalid =>
      codeExpired ? SignInProblem.codeExpired : SignInProblem.codeIncorrect,
    ApiErrorCodes.validationFailed => switch (step) {
      SignInStep.sendCode => SignInProblem.invalidPhone,
      SignInStep.verifyCode => SignInProblem.codeIncorrect,
    },
    ApiErrorCodes.rateLimited ||
    ApiErrorCodes.accountLocked => SignInProblem.tooManyAttempts,
    ApiErrorCodes.permissionDenied => SignInProblem.notCustomerAccount,
    ApiErrorCodes.accountDisabled => SignInProblem.accountDisabled,
    ApiErrorCodes.serviceUnavailable => switch (step) {
      SignInStep.sendCode => SignInProblem.deliveryFailed,
      SignInStep.verifyCode => SignInProblem.server,
    },
    _ when failure.statusCode >= 500 => SignInProblem.server,
    _ => SignInProblem.unexpected,
  },
};

/// The translated message for [problem].
String signInProblemMessage(AbraLocalizations l10n, SignInProblem problem) =>
    l10n.text(switch (problem) {
      SignInProblem.invalidPhone => AbraStrings.validationInvalidPhone,
      SignInProblem.codeIncorrect => CustomerStrings.authErrorCodeIncorrect,
      SignInProblem.codeExpired => CustomerStrings.authErrorCodeExpired,
      SignInProblem.tooManyAttempts => CustomerStrings.authErrorTooManyAttempts,
      SignInProblem.notCustomerAccount =>
        CustomerStrings.authErrorNotCustomerAccount,
      SignInProblem.accountDisabled => CustomerStrings.authErrorAccountDisabled,
      SignInProblem.deliveryFailed => CustomerStrings.authErrorDeliveryFailed,
      SignInProblem.twoStepNotSupported =>
        CustomerStrings.authErrorTwoStepNotSupported,
      SignInProblem.network => AbraStrings.stateNetworkMessage,
      SignInProblem.timeout => AbraStrings.stateTimeoutMessage,
      SignInProblem.server => AbraStrings.stateServerMessage,
      SignInProblem.unexpected => AbraStrings.stateErrorMessage,
    });
