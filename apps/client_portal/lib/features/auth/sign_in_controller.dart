import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

import '../../app/providers.dart';
import '../../l10n/portal_strings.dart';

@immutable
class SignInState {
  const SignInState({
    this.isBusy = false,
    this.challenge,
    this.messageKey,
    this.failure,
  });

  final bool isBusy;

  /// Set while the second step (two-step verification) is pending.
  final MfaChallenge? challenge;

  /// Message key of a problem the user can act on.
  final String? messageKey;

  /// A failure without a specific message (connection, server).
  final AppFailure? failure;

  bool get needsSecondStep => challenge != null;
}

final signInControllerProvider =
    NotifierProvider<SignInController, SignInState>(SignInController.new);

/// Staff sign-in: password, then two-step verification when the account has
/// it. The shared session manager stores the session; the router then
/// leaves the sign-in screen. Passwords and codes are never kept or logged.
class SignInController extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  void acceptGoogleChallenge(MfaChallenge challenge) {
    state = SignInState(challenge: challenge);
  }

  Future<void> signIn(String email, String password) async {
    if (state.isBusy) return;
    state = const SignInState(isBusy: true);
    try {
      final result = await ref
          .read(sessionManagerProvider)
          .signInWithPassword(identifier: email.trim(), password: password);
      if (!ref.mounted) return;
      state = switch (result) {
        MfaChallenge() => SignInState(challenge: result),
        AuthenticatedSession() => const SignInState(),
      };
    } on AppException catch (exception) {
      if (ref.mounted) state = _failed(exception.failure, null);
    }
  }

  /// Completes the sign-in with a code from the authenticator app, or with
  /// a recovery code.
  Future<void> verify({String? code, String? recoveryCode}) async {
    final challenge = state.challenge;
    if (challenge == null || state.isBusy) return;
    state = SignInState(isBusy: true, challenge: challenge);
    try {
      await ref
          .read(sessionManagerProvider)
          .completeMfa(challenge, code: code, recoveryCode: recoveryCode);
      if (ref.mounted) state = const SignInState();
    } on AppException catch (exception) {
      if (!ref.mounted) return;
      final failure = exception.failure;
      // The challenge itself has expired: start again from the password.
      final expired =
          failure is ApiFailure &&
          failure.isUnauthenticated &&
          failure.code != ApiErrorCodes.mfaInvalid;
      state = _failed(failure, expired ? null : challenge);
    }
  }

  void backToPassword() => state = const SignInState();

  SignInState _failed(AppFailure failure, MfaChallenge? challenge) {
    final key = failure is ApiFailure
        ? switch (failure.code) {
            ApiErrorCodes.invalidCredentials ||
            ApiErrorCodes.validationFailed =>
              PortalStrings.signInErrorCredentials,
            ApiErrorCodes.accountLocked ||
            ApiErrorCodes.rateLimited => PortalStrings.signInErrorLocked,
            ApiErrorCodes.accountDisabled => PortalStrings.signInErrorDisabled,
            ApiErrorCodes.mfaInvalid => PortalStrings.mfaErrorInvalid,
            _ when failure.isUnauthenticated => PortalStrings.mfaErrorInvalid,
            _ => null,
          }
        : null;
    return SignInState(
      challenge: challenge,
      messageKey: key,
      failure: key == null ? failure : null,
    );
  }
}
