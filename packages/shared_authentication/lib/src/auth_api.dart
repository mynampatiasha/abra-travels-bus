import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

/// Details for customer registration (`POST /auth/register`).
final class RegistrationRequest {
  const RegistrationRequest({
    required this.phone,
    required this.code,
    required this.name,
    required this.acceptTerms,
    this.email,
    this.password,
    this.preferredLanguage,
    this.marketingConsent = false,
  });

  /// E.164 phone number verified by [code].
  final String phone;

  /// The SIGN_IN code received on WhatsApp or by SMS.
  final String code;
  final String name;
  final String? email;
  final String? password;

  /// Language code such as `en` or `kn`.
  final String? preferredLanguage;

  /// The user accepted the terms and the privacy policy. The server refuses
  /// registration unless this is true.
  final bool acceptTerms;
  final bool marketingConsent;
}

/// The authentication endpoints of the backend (documentation/
/// authentication.md §7), one method per endpoint. Every method throws
/// `AppException` on failure. Stateless: session handling is in
/// `AuthSessionManager`.
class AuthApi {
  AuthApi(this._client, {required ClientType clientType, this.deviceName})
    : _clientType = clientType;

  final ApiClient _client;
  final ClientType _clientType;

  /// Label the user sees in their device list, for example "Pixel 9".
  final String? deviceName;

  JsonMap get _device => <String, Object?>{
    'clientType': _clientType.wireValue,
    if (deviceName != null) 'deviceName': deviceName,
  };

  Future<OtpDispatch> sendOtp(
    String phone, {
    OtpPurpose purpose = OtpPurpose.signIn,
  }) async {
    final response = await _client.post(
      'auth/otp/send',
      body: <String, Object?>{'phone': phone, 'purpose': purpose.wireValue},
      authenticated: false,
    );
    return response.decodeObject(OtpDispatch.fromJson);
  }

  Future<SignInResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _client.post(
      'auth/otp/verify',
      body: <String, Object?>{'phone': phone, 'code': code, 'device': _device},
      authenticated: false,
    );
    return response.decodeObject(SignInResult.fromJson);
  }

  Future<AuthenticatedSession> register(RegistrationRequest request) async {
    final response = await _client.post(
      'auth/register',
      body: <String, Object?>{
        'phone': request.phone,
        'code': request.code,
        'name': request.name,
        if (request.email != null) 'email': request.email,
        if (request.password != null) 'password': request.password,
        if (request.preferredLanguage != null)
          'preferredLanguage': request.preferredLanguage,
        'acceptTerms': request.acceptTerms,
        'marketingConsent': request.marketingConsent,
        'device': _device,
      },
      authenticated: false,
    );
    return response.decodeObject(AuthenticatedSession.fromJson);
  }

  /// [identifier] is an email address or a phone number.
  Future<SignInResult> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      'auth/login',
      body: <String, Object?>{
        'identifier': identifier,
        'password': password,
        'device': _device,
      },
      authenticated: false,
    );
    return response.decodeObject(SignInResult.fromJson);
  }

  /// Completes a sign-in with exactly one of [code] (authenticator app) or
  /// [recoveryCode].
  Future<AuthenticatedSession> verifyMfa({
    required String mfaToken,
    String? code,
    String? recoveryCode,
  }) async {
    final response = await _client.post(
      'auth/mfa/verify',
      body: <String, Object?>{
        'mfaToken': mfaToken,
        'code': ?code,
        'recoveryCode': ?recoveryCode,
        'device': _device,
      },
      authenticated: false,
    );
    return response.decodeObject(AuthenticatedSession.fromJson);
  }

  /// Rotates the refresh token. [refreshToken] is null on web, where the
  /// browser sends the HttpOnly cookie.
  Future<AuthenticatedSession> refresh(String? refreshToken) async {
    final response = await _client.post(
      'auth/refresh',
      body: <String, Object?>{'refreshToken': ?refreshToken},
      authenticated: false,
    );
    return response.decodeObject(AuthenticatedSession.fromJson);
  }

  /// Ends the session of [refreshToken] (or of the cookie on web).
  Future<void> logout(String? refreshToken) async {
    await _client.post(
      'auth/logout',
      body: <String, Object?>{'refreshToken': ?refreshToken},
      authenticated: false,
    );
  }

  /// Ends every session of the account.
  Future<void> logoutAll() async {
    await _client.post('auth/logout-all');
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await _client.post(
      'auth/password/reset',
      body: <String, Object?>{
        'phone': phone,
        'code': code,
        'newPassword': newPassword,
      },
      authenticated: false,
    );
  }

  Future<CurrentUser> currentUser() async =>
      (await _client.get('me')).decodeObject(CurrentUser.fromJson);

  Future<List<SessionSummary>> sessions() async =>
      (await _client.get('me/sessions')).decodeList(SessionSummary.fromJson);

  Future<void> revokeSession(String sessionId) async {
    await _client.delete('me/sessions/$sessionId');
  }
}
