import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

import 'async_value_view.dart';

/// Codes whose server message is written for the person using the
/// management app (what is wrong with the input or the record) and is shown
/// as it is. Everything else gets a general message.
const _explainedByServer = <String>{
  ApiErrorCodes.validationFailed,
  ApiErrorCodes.invalidStateTransition,
  ApiErrorCodes.alreadyRegistered,
  ApiErrorCodes.resourceNotFound,
};

/// What to tell a staff user about a failed request.
String failureText(AbraLocalizations l10n, Object error) {
  final failure = failureOf(error);
  return switch (failure) {
    ApiFailure(:final code, :final message)
        when _explainedByServer.contains(code) && message.isNotEmpty =>
      message,
    ApiFailure(isForbidden: true) => l10n.text(
      AbraStrings.stateForbiddenMessage,
    ),
    ApiFailure(statusCode: >= 500) ||
    ServerFailure() => l10n.text(AbraStrings.stateServerMessage),
    NetworkFailure() => l10n.text(AbraStrings.stateNetworkMessage),
    TimeoutFailure() => l10n.text(AbraStrings.stateTimeoutMessage),
    SessionExpiredFailure() => l10n.text(
      AbraStrings.stateSessionExpiredMessage,
    ),
    _ => l10n.text(AbraStrings.stateErrorMessage),
  };
}
