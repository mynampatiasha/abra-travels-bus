/// What the API client needs from the authentication layer. Implemented by
/// `AuthSessionManager` in `shared_authentication`; declared here so the
/// network package does not depend on it.
abstract interface class AuthTokenSource {
  /// The current access token, or null when nobody is signed in.
  Future<String?> accessToken();

  /// Exchanges the refresh token for new tokens (rotation). Returns true
  /// when a new access token is available, false when the session has ended
  /// and the user must sign in again. Throws `AppException` when the
  /// attempt could not be made (offline, timeout) — the session is kept.
  ///
  /// Concurrent calls must share one refresh request.
  Future<bool> refreshAccessToken();

  /// The server rejected the session itself (revoked, account disabled).
  Future<void> onSessionRejected();
}
