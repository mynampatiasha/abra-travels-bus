import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

import 'async_value_view.dart';

/// Codes whose server message is written for the person using the
/// bus owner portal (what is wrong with the input or the record) and is shown
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
    ApiFailure() when failure.code == ApiErrorCodes.validationFailed =>
      _validationText(failure),
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

/// The server's message, with the fields that failed when it lists them:
/// "Owner's phone: must be a valid mobile number, ...".
String _validationText(ApiFailure failure) {
  final issues = failure.details['issues'];
  if (issues is! List || issues.isEmpty) return failure.message;
  final lines = <String>{
    for (final issue in issues.whereType<Map<Object?, Object?>>())
      _issueLine('${issue['path'] ?? ''}', '${issue['message'] ?? ''}'),
  }..remove('');
  return lines.isEmpty ? failure.message : lines.join(String.fromCharCode(10));
}

String _issueLine(String path, String message) {
  if (message.isEmpty) return '';
  final field = path.split('.').last;
  if (field.isEmpty) return message;
  final words = field
      .replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')
      .trim();
  final label = words.isEmpty
      ? field
      : words[0].toUpperCase() + words.substring(1);
  // Raw type errors are for developers: say what a person can act on.
  final clean = message.startsWith('Invalid input: expected')
      ? 'is required'
      : message;
  return '$label $clean';
}
