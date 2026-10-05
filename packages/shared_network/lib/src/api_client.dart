import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

import 'auth_token_source.dart';
import 'failure_mapper.dart';

/// Creates the value of the `X-Request-Id` header.
typedef RequestIdFactory = String Function();

/// The single HTTP entry point to the Abra Travels API (`/api/v1`).
///
/// - Sends JSON, parses the `{ success, data, meta }` envelope.
/// - Throws [AppException] with a typed [AppFailure] for every failure.
/// - Adds the access token to authenticated requests; when the server
///   answers `TOKEN_EXPIRED` or `PERMISSIONS_CHANGED` it refreshes the
///   session once and repeats the request.
/// - Sends a request id and the preferred language.
/// - Logs method, path, status and request id only — never headers, bodies
///   or query strings.
class ApiClient {
  ApiClient({
    required AppConfig config,
    Dio? dio,
    AppLogger logger = const SilentLogger(),
    String Function()? languageTag,
    RequestIdFactory? requestIdFactory,
  }) : _config = config,
       _logger = logger,
       _languageTag = languageTag,
       _requestIdFactory = requestIdFactory ?? _randomRequestId,
       _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = config.apiV1Url.toString()
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..sendTimeout = config.connectTimeout
      ..responseType = ResponseType.json
      ..contentType = Headers.jsonContentType
      // Every status is handled here, so failures are mapped in one place.
      ..validateStatus = (_) => true;
  }

  final AppConfig _config;
  final Dio _dio;
  final AppLogger _logger;
  final String Function()? _languageTag;
  final RequestIdFactory _requestIdFactory;
  AuthTokenSource? _tokenSource;

  static final Random _random = Random.secure();

  static String _randomRequestId() => List<String>.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Connects the authentication layer. Called once by the session manager.
  void attachTokenSource(AuthTokenSource source) => _tokenSource = source;

  Future<ApiSuccess> get(
    String path, {
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _send('GET', path, query: query, authenticated: authenticated);

  Future<ApiSuccess> post(
    String path, {
    Object? body,
    bool authenticated = true,
    String? idempotencyKey,
  }) => _send(
    'POST',
    path,
    body: body,
    authenticated: authenticated,
    idempotencyKey: idempotencyKey,
  );

  Future<ApiSuccess> put(
    String path, {
    Object? body,
    bool authenticated = true,
    String? idempotencyKey,
  }) => _send(
    'PUT',
    path,
    body: body,
    authenticated: authenticated,
    idempotencyKey: idempotencyKey,
  );

  Future<ApiSuccess> delete(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('DELETE', path, body: body, authenticated: authenticated);

  Future<ApiSuccess> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    required bool authenticated,
    String? idempotencyKey,
    bool isRetryAfterRefresh = false,
  }) async {
    final tokenSource = _tokenSource;
    final accessToken = authenticated ? await tokenSource?.accessToken() : null;
    if (authenticated && accessToken == null) {
      throw const AppException(SessionExpiredFailure());
    }

    final requestId = _requestIdFactory();
    final languageTag = _languageTag?.call();
    final headers = <String, Object?>{
      'X-Request-Id': requestId,
      'Accept': Headers.jsonContentType,
      'Accept-Language': ?languageTag,
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      'Idempotency-Key': ?idempotencyKey,
      // Required by the server whenever the refresh cookie is relied upon.
      if (_config.clientType == ClientType.web) 'X-Abra-Client': 'web',
    };

    final stopwatch = Stopwatch()..start();
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        // Paths are relative to /api/v1/.
        path.startsWith('/') ? path.substring(1) : path,
        data: body,
        queryParameters: query == null
            ? null
            : <String, Object?>{
                for (final entry in query.entries)
                  if (entry.value != null) entry.key: entry.value,
              },
        options: Options(
          method: method,
          headers: headers,
          // Lets the browser send and store the HttpOnly refresh cookie.
          extra: <String, Object?>{
            if (_config.clientType == ClientType.web) 'withCredentials': true,
          },
        ),
      );
    } on DioException catch (exception) {
      final failure = FailureMapper.fromDioException(exception);
      _logger.warning(
        'API request failed',
        context: <String, Object?>{
          'method': method,
          'path': path,
          'requestId': requestId,
          'failure': failure.runtimeType.toString(),
        },
      );
      throw AppException(failure);
    }

    final status = response.statusCode ?? 0;
    final serverRequestId = response.headers.value('x-request-id') ?? requestId;
    _logger.debug(
      'API $method',
      context: <String, Object?>{
        'path': path,
        'status': status,
        'requestId': serverRequestId,
        'durationMs': stopwatch.elapsedMilliseconds,
      },
    );

    if (status >= 200 && status < 300) {
      final data = response.data;
      try {
        if (data is! Map) throw const ModelParseException('body is no object');
        return ApiSuccess.fromJson(asJsonMap(data));
      } on FormatException {
        throw AppException(
          ServerFailure(statusCode: status, requestId: serverRequestId),
        );
      }
    }

    final failure = FailureMapper.fromErrorResponse(
      status,
      response.data,
      requestIdHeader: serverRequestId,
    );
    if (failure is ApiFailure && authenticated && failure.isUnauthenticated) {
      return _recoverFromUnauthenticated(
        failure,
        isRetryAfterRefresh: isRetryAfterRefresh,
        retry: () => _send(
          method,
          path,
          query: query,
          body: body,
          authenticated: true,
          idempotencyKey: idempotencyKey,
          isRetryAfterRefresh: true,
        ),
      );
    }
    throw AppException(failure);
  }

  /// A 401 on an authenticated request: refresh once and retry when the
  /// token merely expired; otherwise the session is over.
  Future<ApiSuccess> _recoverFromUnauthenticated(
    ApiFailure failure, {
    required bool isRetryAfterRefresh,
    required Future<ApiSuccess> Function() retry,
  }) async {
    final tokenSource = _tokenSource;
    if (tokenSource == null) throw AppException(failure);

    if (failure.isRefreshable && !isRetryAfterRefresh) {
      // Throws when offline; the session is kept in that case.
      if (await tokenSource.refreshAccessToken()) return retry();
      throw const AppException(SessionExpiredFailure());
    }
    await tokenSource.onSessionRejected();
    throw const AppException(SessionExpiredFailure());
  }
}
