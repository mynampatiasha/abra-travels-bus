import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

/// Turns the `data` of a response into models. A payload that does not have
/// the documented shape is a server-side contract problem, so it surfaces
/// as a [ServerFailure] (with the request id) like any other bad response —
/// never as a raw parsing error in the UI.
extension ApiResponseDecoding on ApiSuccess {
  AppException get _malformed =>
      AppException(ServerFailure(statusCode: 200, requestId: requestId));

  /// Decodes `data` as one object.
  T decodeObject<T>(T Function(JsonMap json) fromJson) {
    final payload = data;
    if (payload is! Map) throw _malformed;
    try {
      return fromJson(asJsonMap(payload));
    } on FormatException {
      throw _malformed;
    }
  }

  /// Decodes `data` as a list of objects.
  List<T> decodeList<T>(T Function(JsonMap json) fromJson) {
    final payload = data;
    if (payload is! List) throw _malformed;
    try {
      return <T>[
        for (final item in payload)
          if (item is Map) fromJson(asJsonMap(item)) else throw _malformed,
      ];
    } on FormatException {
      throw _malformed;
    }
  }
}
