import 'package:meta/meta.dart';

import 'api_error_codes.dart';

/// Why an operation did not succeed. Every failure an app can show to the
/// user is one of these types, so screens can switch over them exhaustively.
@immutable
sealed class AppFailure {
  const AppFailure();

  /// Short technical description for logs. Never shown to users and never
  /// contains credentials.
  String get debugMessage;

  @override
  String toString() => '$runtimeType($debugMessage)';
}

/// The backend answered with its error envelope
/// `{ success: false, error: { code, message, details, requestId } }`.
final class ApiFailure extends AppFailure {
  const ApiFailure({
    required this.code,
    required this.message,
    required this.statusCode,
    this.requestId,
    this.details = const <String, Object?>{},
  });

  /// One of [ApiErrorCodes].
  final String code;

  /// Human-readable message from the server.
  final String message;
  final int statusCode;

  /// Correlates the failure with the server logs; safe to show to support.
  final String? requestId;
  final Map<String, Object?> details;

  /// The caller is not signed in, or the session ended.
  bool get isUnauthenticated => statusCode == 401;

  /// The access token can be replaced by refreshing the session.
  bool get isRefreshable =>
      code == ApiErrorCodes.tokenExpired ||
      code == ApiErrorCodes.permissionsChanged;

  /// Signed in, but not allowed to do this.
  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  bool get isValidation => code == ApiErrorCodes.validationFailed;

  /// Seconds to wait before retrying, when the server says so
  /// (`RATE_LIMITED`, `ACCOUNT_LOCKED`).
  int? get retryAfterSeconds {
    final value = details['retryAfterSeconds'];
    return value is int ? value : null;
  }

  @override
  String get debugMessage => '$code ($statusCode) requestId=$requestId';
}

/// The device could not reach the server (offline, DNS, connection refused).
final class NetworkFailure extends AppFailure {
  const NetworkFailure([this.reason = 'network unreachable']);

  final String reason;

  @override
  String get debugMessage => reason;
}

/// The request did not complete in time.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([this.reason = 'request timed out']);

  final String reason;

  @override
  String get debugMessage => reason;
}

/// The server failed (5xx) or answered with something that is not the API
/// envelope.
final class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode, this.requestId});

  final int? statusCode;
  final String? requestId;

  @override
  String get debugMessage =>
      'server failure ($statusCode) requestId=$requestId';
}

/// The session ended and could not be renewed; the user must sign in again.
final class SessionExpiredFailure extends AppFailure {
  const SessionExpiredFailure();

  @override
  String get debugMessage => 'session expired';
}

/// The request was cancelled by the app (for example the screen closed).
final class CancelledFailure extends AppFailure {
  const CancelledFailure();

  @override
  String get debugMessage => 'cancelled';
}

/// Anything not covered above. Indicates a defect.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(this.reason);

  final String reason;

  @override
  String get debugMessage => reason;
}

/// Carries an [AppFailure] through code that uses exceptions.
final class AppException implements Exception {
  const AppException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'AppException(${failure.debugMessage})';
}
