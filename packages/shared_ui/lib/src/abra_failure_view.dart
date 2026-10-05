import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

import 'abra_state_view.dart';

/// Which screen state represents [failure].
AbraStateKind stateKindForFailure(AppFailure failure) => switch (failure) {
  NetworkFailure() => AbraStateKind.networkUnavailable,
  TimeoutFailure() => AbraStateKind.timeout,
  ServerFailure() => AbraStateKind.serverFailure,
  SessionExpiredFailure() => AbraStateKind.sessionExpired,
  CancelledFailure() || UnexpectedFailure() => AbraStateKind.error,
  ApiFailure() => _kindForApiFailure(failure),
};

AbraStateKind _kindForApiFailure(ApiFailure failure) {
  if (failure.code == ApiErrorCodes.rateLimited ||
      failure.code == ApiErrorCodes.accountLocked) {
    return AbraStateKind.rateLimited;
  }
  if (failure.code == ApiErrorCodes.serviceUnavailable ||
      failure.code == ApiErrorCodes.maintenanceMode ||
      failure.statusCode >= 500) {
    return AbraStateKind.serverFailure;
  }
  if (failure.isUnauthenticated) return AbraStateKind.unauthorized;
  if (failure.isForbidden) return AbraStateKind.forbidden;
  if (failure.isNotFound) return AbraStateKind.notFound;
  return AbraStateKind.error;
}

/// True when trying the same request again can succeed.
bool isRetryable(AppFailure failure) => switch (stateKindForFailure(failure)) {
  AbraStateKind.networkUnavailable ||
  AbraStateKind.timeout ||
  AbraStateKind.serverFailure ||
  AbraStateKind.rateLimited ||
  AbraStateKind.error => true,
  _ => false,
};

/// Shows an [AppFailure] as a screen state with the right wording and
/// actions:
/// - "Try again" when retrying can help and [onRetry] is given;
/// - "Sign in" when the session ended and [onSignIn] is given;
/// - the wait time when the server asked to slow down;
/// - the request reference, so support can find the failure in the logs.
///
/// Server messages are not shown: they are not translated and may be too
/// technical. The state is described with the app's own translated text.
class AbraFailureView extends StatelessWidget {
  const AbraFailureView({
    required this.failure,
    this.onRetry,
    this.onSignIn,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final kind = stateKindForFailure(failure);
    final needsSignIn =
        kind == AbraStateKind.sessionExpired ||
        kind == AbraStateKind.unauthorized;

    final current = failure;
    final requestId = switch (current) {
      ApiFailure(:final requestId) => requestId,
      ServerFailure(:final requestId) => requestId,
      _ => null,
    };
    final retryAfter = current is ApiFailure ? current.retryAfterSeconds : null;

    return AbraStateView(
      kind: kind,
      message: retryAfter == null
          ? null
          : l10n.text(AbraStrings.commonRetryInSeconds, <String, Object?>{
              'count': retryAfter,
            }),
      detail: requestId == null
          ? null
          : l10n.text(AbraStrings.commonRequestReference, <String, Object?>{
              'requestId': requestId,
            }),
      actionLabel: needsSignIn
          ? l10n.text(AbraStrings.commonSignIn)
          : isRetryable(failure)
          ? l10n.text(AbraStrings.commonRetry)
          : null,
      onAction: needsSignIn
          ? onSignIn
          : isRetryable(failure)
          ? onRetry
          : null,
    );
  }
}
