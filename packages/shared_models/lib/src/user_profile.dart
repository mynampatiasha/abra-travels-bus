import 'package:meta/meta.dart';

import 'enums.dart';
import 'json_reader.dart';

/// A user as returned by `GET /me` and by the sign-in endpoints
/// (`UserProfile` in the backend). Never contains credentials.
@immutable
final class UserProfile {
  const UserProfile({
    required this.id,
    required this.userType,
    required this.status,
    required this.preferredLanguage,
    required this.emailVerified,
    required this.phoneVerified,
    required this.hasPassword,
    required this.mfaEnabled,
    this.name,
    this.email,
    this.phone,
    this.operatorId,
    this.partnerId,
    this.lastLoginAt,
    this.createdAt,
  });

  factory UserProfile.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return UserProfile(
      id: reader.string('id'),
      name: reader.stringOrNull('name'),
      email: reader.stringOrNull('email'),
      phone: reader.stringOrNull('phone'),
      emailVerified: reader.boolean('emailVerified'),
      phoneVerified: reader.boolean('phoneVerified'),
      userType: UserType.fromWire(reader.string('userType')),
      status: UserStatus.fromWire(reader.string('status')),
      operatorId: reader.stringOrNull('operatorId'),
      partnerId: reader.stringOrNull('partnerId'),
      preferredLanguage: reader.string('preferredLanguage'),
      hasPassword: reader.boolean('hasPassword'),
      mfaEnabled: reader.boolean('mfaEnabled'),
      lastLoginAt: reader.dateTimeOrNull('lastLoginAt'),
      createdAt: reader.dateTimeOrNull('createdAt'),
    );
  }

  final String id;
  final String? name;
  final String? email;

  /// E.164.
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final UserType userType;
  final UserStatus status;
  final String? operatorId;
  final String? partnerId;

  /// BCP-47 language tag stored on the account.
  final String preferredLanguage;
  final bool hasPassword;
  final bool mfaEnabled;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'emailVerified': emailVerified,
    'phoneVerified': phoneVerified,
    'userType': userType.wireValue,
    'status': status.wireValue,
    'operatorId': operatorId,
    'partnerId': partnerId,
    'preferredLanguage': preferredLanguage,
    'hasPassword': hasPassword,
    'mfaEnabled': mfaEnabled,
    'lastLoginAt': lastLoginAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// Response of `GET /me`: the profile plus the current session.
@immutable
final class CurrentUser {
  const CurrentUser({
    required this.user,
    required this.sessionId,
    required this.mfaEnrollmentRequired,
  });

  factory CurrentUser.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    final session = JsonReader(reader.object('session'));
    return CurrentUser(
      user: UserProfile.fromJson(reader.object('user')),
      sessionId: session.string('id'),
      mfaEnrollmentRequired: session.boolean('mfaEnrollmentRequired'),
    );
  }

  final UserProfile user;
  final String sessionId;

  /// The session can only complete MFA enrolment until MFA is enabled.
  final bool mfaEnrollmentRequired;
}
