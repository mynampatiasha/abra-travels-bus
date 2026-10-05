import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';

/// Why nobody is signed in.
enum SignedOutReason {
  /// No stored session, or the user signed out.
  signedOut,

  /// The session ended on the server (expired, revoked, reused refresh
  /// token, account disabled). The app should explain this to the user.
  sessionExpired,
}

/// Authentication state observed by an app to choose between the sign-in
/// flow and the signed-in shell.
@immutable
sealed class AuthState {
  const AuthState();
}

/// Start-up: the stored session has not been checked yet.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut([this.reason = SignedOutReason.signedOut]);

  final SignedOutReason reason;

  @override
  bool operator ==(Object other) =>
      other is AuthSignedOut && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.user,
    required this.sessionId,
    required this.mfaEnrollmentRequired,
  });

  final UserProfile user;
  final String sessionId;

  /// The server only accepts the MFA enrolment endpoints for this session
  /// until two-step verification is set up.
  final bool mfaEnrollmentRequired;
}
