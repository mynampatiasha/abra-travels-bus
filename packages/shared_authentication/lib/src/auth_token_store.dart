import 'package:shared_core/shared_core.dart';

/// Credentials of the current session.
typedef StoredCredentials = ({
  String accessToken,

  /// Null on web, where the refresh token is an HttpOnly cookie.
  String? refreshToken,
  String sessionId,
});

/// Keeps the session credentials in a [SecureStore] (platform keystore).
/// This is the only class that reads or writes tokens; they are never put
/// in preferences, logs or error messages.
class AuthTokenStore {
  AuthTokenStore(this._store);

  static const accessTokenKey = 'abra.auth.access_token';
  static const refreshTokenKey = 'abra.auth.refresh_token';
  static const sessionIdKey = 'abra.auth.session_id';

  final SecureStore _store;

  Future<StoredCredentials?> read() async {
    final accessToken = await _store.read(accessTokenKey);
    final sessionId = await _store.read(sessionIdKey);
    if (accessToken == null || sessionId == null) return null;
    return (
      accessToken: accessToken,
      refreshToken: await _store.read(refreshTokenKey),
      sessionId: sessionId,
    );
  }

  Future<String?> readAccessToken() => _store.read(accessTokenKey);

  Future<String?> readRefreshToken() => _store.read(refreshTokenKey);

  /// Replaces the stored credentials. An empty [refreshToken] (web) removes
  /// any stored one.
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String sessionId,
  }) async {
    await _store.write(accessTokenKey, accessToken);
    await _store.write(sessionIdKey, sessionId);
    if (refreshToken.isEmpty) {
      await _store.delete(refreshTokenKey);
    } else {
      await _store.write(refreshTokenKey, refreshToken);
    }
  }

  Future<void> clear() async {
    await _store.delete(accessTokenKey);
    await _store.delete(refreshTokenKey);
    await _store.delete(sessionIdKey);
  }
}
