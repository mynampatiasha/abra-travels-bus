import 'package:meta/meta.dart';

import 'json_reader.dart';
import 'user_profile.dart';

/// Result of a sign-in step: either tokens or a request for the second
/// factor. Parsed from `/auth/login`, `/auth/otp/verify`, `/auth/register`,
/// `/auth/mfa/verify` and `/auth/refresh`.
@immutable
sealed class SignInResult {
  const SignInResult();

  /// Chooses the type by the `mfaRequired` marker of the response.
  factory SignInResult.fromJson(JsonMap json) => json['mfaRequired'] == true
      ? MfaChallenge.fromJson(json)
      : AuthenticatedSession.fromJson(json);
}

/// A completed sign-in or refresh (`AuthenticationResult` in the backend).
final class AuthenticatedSession extends SignInResult {
  const AuthenticatedSession({
    required this.accessToken,
    required this.accessTokenExpiresInSeconds,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.sessionId,
    required this.mfaEnrollmentRequired,
    required this.user,
  });

  factory AuthenticatedSession.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return AuthenticatedSession(
      accessToken: reader.string('accessToken'),
      accessTokenExpiresInSeconds: reader.integer(
        'accessTokenExpiresInSeconds',
      ),
      refreshToken: reader.string('refreshToken'),
      refreshTokenExpiresAt: reader.dateTime('refreshTokenExpiresAt'),
      sessionId: reader.string('sessionId'),
      mfaEnrollmentRequired: reader.boolean('mfaEnrollmentRequired'),
      user: UserProfile.fromJson(reader.object('user')),
    );
  }

  final String accessToken;
  final int accessTokenExpiresInSeconds;

  /// Opaque. Empty for web clients, which receive it as an HttpOnly cookie.
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String sessionId;

  /// The session can only complete MFA enrolment until MFA is enabled.
  final bool mfaEnrollmentRequired;
  final UserProfile user;

  // Tokens must never end up in logs through string interpolation.
  @override
  String toString() => 'AuthenticatedSession(sessionId: $sessionId)';
}

/// The password or OTP was accepted, but the account has two-step
/// verification: send [mfaToken] with a code to `/auth/mfa/verify`.
final class MfaChallenge extends SignInResult {
  const MfaChallenge({required this.mfaToken, required this.expiresInSeconds});

  factory MfaChallenge.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return MfaChallenge(
      mfaToken: reader.string('mfaToken'),
      expiresInSeconds: reader.integer('mfaTokenExpiresInSeconds'),
    );
  }

  final String mfaToken;
  final int expiresInSeconds;

  @override
  String toString() => 'MfaChallenge(expiresInSeconds: $expiresInSeconds)';
}

/// Response of `POST /auth/otp/send`.
@immutable
final class OtpDispatch {
  const OtpDispatch({
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  factory OtpDispatch.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return OtpDispatch(
      expiresInSeconds: reader.integer('expiresInSeconds'),
      resendAfterSeconds: reader.integer('resendAfterSeconds'),
    );
  }

  final int expiresInSeconds;
  final int resendAfterSeconds;
}
