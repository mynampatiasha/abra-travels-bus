import 'dart:async';

import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import 'auth_api.dart';
import 'auth_state.dart';
import 'auth_token_store.dart';

/// Owns the session of the app: who is signed in, the stored credentials,
/// and their renewal. One instance per app.
///
/// - [restore] at start-up decides between signed in and signed out.
/// - The sign-in methods store the tokens and publish [AuthSignedIn].
/// - As [AuthTokenSource] it gives the API client the access token and
///   renews it. The backend rotates the refresh token on every use, so
///   concurrent renewals share one request (a second request with the
///   same token would be rejected).
/// - A session that ends on the server becomes
///   `AuthSignedOut(SignedOutReason.sessionExpired)`.
/// - Being offline never signs the user out.
class AuthSessionManager implements AuthTokenSource {
  AuthSessionManager({
    required AuthApi api,
    required ApiClient client,
    required AuthTokenStore tokenStore,
    required ClientType clientType,
    AppLogger logger = const SilentLogger(),
  }) : _api = api,
       _tokenStore = tokenStore,
       _clientType = clientType,
       _logger = logger {
    client.attachTokenSource(this);
  }

  final AuthApi _api;
  final AuthTokenStore _tokenStore;
  final ClientType _clientType;
  final AppLogger _logger;

  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast();
  AuthState _state = const AuthUnknown();
  Future<bool>? _refreshInFlight;

  /// The current state.
  AuthState get state => _state;

  /// Every state change, starting with the next one.
  Stream<AuthState> get states => _states.stream;

  void _publish(AuthState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// Checks the stored session at start-up. Ends in [AuthSignedIn] or
  /// [AuthSignedOut]; when the server cannot be reached the state stays
  /// [AuthUnknown] and the failure is returned, so the app can offer a
  /// retry without discarding the session.
  Future<Result<AuthState>> restore() async {
    final credentials = await _tokenStore.read();
    if (credentials == null && _clientType == ClientType.mobile) {
      _publish(const AuthSignedOut());
      return Result<AuthState>.success(_state);
    }
    try {
      // On web there may be no stored access token; the cookie renews it.
      if (credentials == null && !await refreshAccessToken()) {
        _publish(const AuthSignedOut());
        return Result<AuthState>.success(_state);
      }
      final current = await _api.currentUser();
      _publish(
        AuthSignedIn(
          user: current.user,
          sessionId: current.sessionId,
          mfaEnrollmentRequired: current.mfaEnrollmentRequired,
        ),
      );
      return Result<AuthState>.success(_state);
    } on AppException catch (exception) {
      final failure = exception.failure;
      if (failure is SessionExpiredFailure ||
          (failure is ApiFailure && failure.isUnauthenticated)) {
        if (_state is! AuthSignedOut) await _endSession(expired: true);
        return Result<AuthState>.success(_state);
      }
      return Result<AuthState>.failure(failure);
    }
  }

  /// Sends a one-time code to [phone].
  Future<OtpDispatch> sendOtp(
    String phone, {
    OtpPurpose purpose = OtpPurpose.signIn,
  }) => _api.sendOtp(phone, purpose: purpose);

  /// Signs in with a one-time code. Returns an [MfaChallenge] when the
  /// account uses two-step verification.
  Future<SignInResult> signInWithOtp({
    required String phone,
    required String code,
  }) async => _accept(await _api.verifyOtp(phone: phone, code: code));

  Future<SignInResult> signInWithPassword({
    required String identifier,
    required String password,
  }) async =>
      _accept(await _api.login(identifier: identifier, password: password));

  Future<AuthenticatedSession> register(RegistrationRequest request) async {
    final session = await _api.register(request);
    await _startSession(session);
    return session;
  }

  /// Second step of a sign-in: [challenge] plus a code from the
  /// authenticator app, or a recovery code.
  Future<AuthenticatedSession> completeMfa(
    MfaChallenge challenge, {
    String? code,
    String? recoveryCode,
  }) async {
    final session = await _api.verifyMfa(
      mfaToken: challenge.mfaToken,
      code: code,
      recoveryCode: recoveryCode,
    );
    await _startSession(session);
    return session;
  }

  /// Signs out this device. The local session always ends, even when the
  /// server cannot be reached.
  Future<void> signOut() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    try {
      await _api.logout(refreshToken);
    } on AppException catch (exception) {
      _logger.warning(
        'Sign-out request failed; local session cleared',
        context: <String, Object?>{'failure': exception.failure.debugMessage},
      );
    }
    await _endSession(expired: false);
  }

  /// Signs out every device of the account.
  Future<void> signOutEverywhere() async {
    await _api.logoutAll();
    await _endSession(expired: false);
  }

  /// Reloads the profile after it changed (for example MFA was enabled).
  Future<void> reloadUser() async {
    final current = await _api.currentUser();
    _publish(
      AuthSignedIn(
        user: current.user,
        sessionId: current.sessionId,
        mfaEnrollmentRequired: current.mfaEnrollmentRequired,
      ),
    );
  }

  @override
  Future<String?> accessToken() => _tokenStore.readAccessToken();

  @override
  Future<bool> refreshAccessToken() {
    // Single flight: rotation makes a second concurrent refresh fail.
    return _refreshInFlight ??= _refresh().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<bool> _refresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null && _clientType == ClientType.mobile) {
      await _endSession(expired: true);
      return false;
    }
    try {
      final session = await _api.refresh(refreshToken);
      await _tokenStore.save(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        sessionId: session.sessionId,
      );
      return true;
    } on AppException catch (exception) {
      final failure = exception.failure;
      // Only a definite answer from the server ends the session. Offline,
      // timeouts and server errors keep it, so the user is not signed out
      // by a bad connection.
      final rejected = failure is ApiFailure && failure.statusCode < 500;
      if (!rejected) rethrow;
      await _endSession(expired: true);
      return false;
    }
  }

  @override
  Future<void> onSessionRejected() => _endSession(expired: true);

  Future<SignInResult> _accept(SignInResult result) async {
    if (result is AuthenticatedSession) await _startSession(result);
    return result;
  }

  Future<void> _startSession(AuthenticatedSession session) async {
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      sessionId: session.sessionId,
    );
    _publish(
      AuthSignedIn(
        user: session.user,
        sessionId: session.sessionId,
        mfaEnrollmentRequired: session.mfaEnrollmentRequired,
      ),
    );
  }

  Future<void> _endSession({required bool expired}) async {
    await _tokenStore.clear();
    _publish(
      AuthSignedOut(
        expired ? SignedOutReason.sessionExpired : SignedOutReason.signedOut,
      ),
    );
  }

  /// Releases the state stream. Call when the app shuts down.
  Future<void> dispose() => _states.close();
}
