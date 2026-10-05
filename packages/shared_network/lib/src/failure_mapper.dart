import 'package:dio/dio.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

/// Turns transport errors and HTTP responses into [AppFailure]s.
abstract final class FailureMapper {
  /// A request that never produced an HTTP response.
  static AppFailure fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badCertificate:
        return const NetworkFailure('untrusted certificate');
      case DioExceptionType.cancel:
        return const CancelledFailure();
      case DioExceptionType.badResponse:
        return ServerFailure(statusCode: exception.response?.statusCode);
      case DioExceptionType.unknown:
        // Compared by name so this file needs no dart:io (it also runs on web).
        final errorType = exception.error?.runtimeType.toString() ?? 'unknown';
        const transportErrors = <String>[
          'SocketException',
          'HandshakeException',
          'HttpException',
          'ClientException',
        ];
        if (transportErrors.any(errorType.contains)) {
          return const NetworkFailure();
        }
        return UnexpectedFailure(errorType);
    }
  }

  /// A response with a non-2xx status. A body that is the API error envelope
  /// becomes an [ApiFailure]; anything else (proxy page, empty body) a
  /// [ServerFailure].
  static AppFailure fromErrorResponse(
    int statusCode,
    Object? body, {
    String? requestIdHeader,
  }) {
    final error = ApiErrorBody.tryParse(body);
    if (error == null) {
      return ServerFailure(statusCode: statusCode, requestId: requestIdHeader);
    }
    return ApiFailure(
      code: error.code,
      message: error.message,
      statusCode: statusCode,
      requestId: error.requestId ?? requestIdHeader,
      details: error.details,
    );
  }
}
