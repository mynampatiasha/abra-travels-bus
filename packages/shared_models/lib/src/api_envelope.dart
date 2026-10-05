import 'package:meta/meta.dart';

import 'json_reader.dart';

/// Paging values of a list response (`meta.page`, `meta.pageSize`,
/// `meta.total`).
@immutable
final class PageInfo {
  const PageInfo({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;
}

/// The success envelope of every API response:
/// `{ success: true, data, meta: { requestId, page?, pageSize?, total? } }`.
@immutable
final class ApiSuccess {
  const ApiSuccess({required this.data, this.requestId, this.page});

  /// Parses the envelope. Throws [ModelParseException] when [json] is not a
  /// success envelope.
  factory ApiSuccess.fromJson(JsonMap json) {
    if (json['success'] != true || !json.containsKey('data')) {
      throw const ModelParseException('not a success envelope');
    }
    final meta = json['meta'];
    final metaMap = meta is Map ? asJsonMap(meta) : const <String, Object?>{};
    final page = metaMap['page'];
    final pageSize = metaMap['pageSize'];
    final total = metaMap['total'];
    return ApiSuccess(
      data: json['data'],
      requestId: metaMap['requestId'] as String?,
      page: page is num && pageSize is num && total is num
          ? PageInfo(
              page: page.toInt(),
              pageSize: pageSize.toInt(),
              total: total.toInt(),
            )
          : null,
    );
  }

  /// The payload: an object, a list, or null.
  final Object? data;
  final String? requestId;

  /// Present for paginated lists.
  final PageInfo? page;
}

/// The `error` object of a failed API response:
/// `{ success: false, error: { code, message, details?, requestId } }`.
@immutable
final class ApiErrorBody {
  const ApiErrorBody({
    required this.code,
    required this.message,
    this.requestId,
    this.details = const <String, Object?>{},
  });

  /// Parses the envelope, or returns null when [json] is not an error
  /// envelope (for example an HTML page from a proxy).
  static ApiErrorBody? tryParse(Object? json) {
    if (json is! Map || json['success'] != false) return null;
    final error = json['error'];
    if (error is! Map) return null;
    final code = error['code'];
    final message = error['message'];
    if (code is! String || message is! String) return null;
    final details = error['details'];
    return ApiErrorBody(
      code: code,
      message: message,
      requestId: error['requestId'] as String?,
      details: details is Map ? asJsonMap(details) : const <String, Object?>{},
    );
  }

  final String code;
  final String message;
  final String? requestId;
  final JsonMap details;
}

/// One field problem of a `VALIDATION_FAILED` response
/// (`details.issues[]`).
@immutable
final class ValidationIssue {
  const ValidationIssue({required this.path, required this.message});

  /// Field path such as `phone` or `device.clientType`.
  final String path;
  final String message;

  /// Reads `details.issues` of a validation error; empty when absent.
  static List<ValidationIssue> listFrom(JsonMap details) {
    final issues = details['issues'];
    if (issues is! List) return const <ValidationIssue>[];
    return <ValidationIssue>[
      for (final issue in issues)
        if (issue is Map &&
            issue['path'] is String &&
            issue['message'] is String)
          ValidationIssue(
            path: issue['path'] as String,
            message: issue['message'] as String,
          ),
    ];
  }
}
