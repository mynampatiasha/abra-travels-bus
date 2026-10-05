import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A request as seen by [FakeHttpAdapter].
final class RecordedRequest {
  RecordedRequest(this.options, this.body);

  final RequestOptions options;

  /// Decoded JSON body, or null.
  final Object? body;

  String get method => options.method;

  /// Path below `/api/v1/`, for example `auth/login`.
  String get path => options.path;

  String? header(String name) => options.headers[name]?.toString();
}

/// What [FakeHttpAdapter] answers with.
final class FakeResponse {
  const FakeResponse(this.statusCode, this.body, {this.headers = const {}});

  /// A success envelope around [data].
  factory FakeResponse.ok(Object? data, {Map<String, Object?>? meta}) =>
      FakeResponse(200, <String, Object?>{
        'success': true,
        'data': data,
        'meta': <String, Object?>{'requestId': 'test-request', ...?meta},
      });

  /// An error envelope.
  factory FakeResponse.error(
    int statusCode,
    String code, {
    String message = 'error',
    Map<String, Object?>? details,
  }) => FakeResponse(statusCode, <String, Object?>{
    'success': false,
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'requestId': 'test-request',
      'details': ?details,
    },
  });

  final int statusCode;
  final Object? body;
  final Map<String, String> headers;
}

/// Test double for the HTTP layer: answers requests from a handler and
/// records them, so repositories and the API client can be tested without a
/// server. Lives in `lib/` so every package's tests can use it; it is never
/// used by application code.
final class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  /// Produces the response, or throws a [DioException] to simulate a
  /// transport failure.
  Future<FakeResponse> Function(RecordedRequest request) handler;

  final List<RecordedRequest> requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    }
    final request = RecordedRequest(options, body);
    requests.add(request);

    final response = await handler(request);
    final payload = response.body;
    return ResponseBody.fromString(
      payload is String ? payload : jsonEncode(payload),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[
          payload is String ? 'text/html' : Headers.jsonContentType,
        ],
        for (final entry in response.headers.entries)
          entry.key: <String>[entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
