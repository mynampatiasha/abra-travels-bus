import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

/// Payloads below have the exact shape the backend returns (see the
/// controllers and view types of the authentication and rbac modules).
const JsonMap userJson = <String, Object?>{
  'id': '66f0c0ffee00000000000001',
  'name': 'Asha',
  'email': null,
  'phone': '+919876543210',
  'emailVerified': false,
  'phoneVerified': true,
  'userType': 'CUSTOMER',
  'status': 'ACTIVE',
  'operatorId': null,
  'partnerId': null,
  'preferredLanguage': 'kn',
  'hasPassword': false,
  'mfaEnabled': false,
  'lastLoginAt': '2026-10-01T05:15:01.000Z',
  'createdAt': '2026-09-30T10:00:00.000Z',
};

const JsonMap sessionJson = <String, Object?>{
  'tokenType': 'Bearer',
  'accessToken': 'access.jwt.value',
  'accessTokenExpiresInSeconds': 900,
  'refreshToken': '66f0c0ffee00000000000002.secret',
  'refreshTokenExpiresAt': '2026-10-31T05:15:01.000Z',
  'sessionId': '66f0c0ffee00000000000002',
  'mfaEnrollmentRequired': false,
  'user': userJson,
};

void main() {
  group('API envelope', () {
    test('parses a success envelope with request id', () {
      final success = ApiSuccess.fromJson(<String, Object?>{
        'success': true,
        'data': <String, Object?>{'status': 'ok'},
        'meta': <String, Object?>{'requestId': 'req-1'},
      });
      expect(success.data, {'status': 'ok'});
      expect(success.requestId, 'req-1');
      expect(success.page, isNull);
    });

    test('parses paging from meta', () {
      final success = ApiSuccess.fromJson(<String, Object?>{
        'success': true,
        'data': <Object?>[],
        'meta': <String, Object?>{
          'requestId': 'r',
          'page': 2,
          'pageSize': 20,
          'total': 45,
        },
      });
      expect(success.page!.page, 2);
      expect(success.page!.hasMore, isTrue);
      expect(const PageInfo(page: 3, pageSize: 20, total: 45).hasMore, isFalse);
    });

    test(
      'accepts null data and rejects anything that is not a success envelope',
      () {
        expect(
          ApiSuccess.fromJson(<String, Object?>{
            'success': true,
            'data': null,
            'meta': <String, Object?>{},
          }).data,
          isNull,
        );
        for (final json in <JsonMap>[
          {'success': false, 'error': <String, Object?>{}},
          {'data': 1},
          {'success': true},
        ]) {
          expect(
            () => ApiSuccess.fromJson(json),
            throwsA(isA<ModelParseException>()),
          );
        }
      },
    );

    test('parses the error envelope', () {
      final error = ApiErrorBody.tryParse(<String, Object?>{
        'success': false,
        'error': <String, Object?>{
          'code': 'ACCOUNT_LOCKED',
          'message': 'Too many failed attempts.',
          'details': <String, Object?>{'retryAfterSeconds': 900},
          'requestId': 'req-9',
        },
      })!;
      expect(error.code, 'ACCOUNT_LOCKED');
      expect(error.requestId, 'req-9');
      expect(error.details['retryAfterSeconds'], 900);
    });

    test('returns null for bodies that are not the error envelope', () {
      for (final body in <Object?>[
        null,
        '<html>502 Bad Gateway</html>',
        <String, Object?>{'success': true, 'data': 1},
        <String, Object?>{'success': false},
        <String, Object?>{
          'success': false,
          'error': <String, Object?>{'code': 5},
        },
      ]) {
        expect(ApiErrorBody.tryParse(body), isNull);
      }
    });

    test('reads validation issues', () {
      final issues = ValidationIssue.listFrom(<String, Object?>{
        'location': 'body',
        'issues': <Object?>[
          <String, Object?>{
            'path': 'phone',
            'code': 'custom',
            'message': 'must be a valid mobile number',
          },
          <String, Object?>{'broken': true},
        ],
      });
      expect(issues, hasLength(1));
      expect(issues.single.path, 'phone');
      expect(ValidationIssue.listFrom(const <String, Object?>{}), isEmpty);
    });
  });

  group('UserProfile', () {
    test('parses the backend profile and round-trips', () {
      final user = UserProfile.fromJson(userJson);
      expect(user.id, '66f0c0ffee00000000000001');
      expect(user.userType, UserType.customer);
      expect(user.status, UserStatus.active);
      expect(user.email, isNull);
      expect(user.preferredLanguage, 'kn');
      expect(user.lastLoginAt, DateTime.utc(2026, 10, 1, 5, 15, 1));
      expect(UserProfile.fromJson(user.toJson()).toJson(), user.toJson());
    });

    test('never carries credential fields', () {
      final keys = UserProfile.fromJson(userJson).toJson().keys.toSet();
      for (final forbidden in [
        'password',
        'passwordHash',
        'accessToken',
        'refreshToken',
        'mfa',
        'secretEncrypted',
        'recoveryCodeHashes',
      ]) {
        expect(keys, isNot(contains(forbidden)));
      }
    });

    test(
      'an unknown enum value from a newer server does not break parsing',
      () {
        final user = UserProfile.fromJson(<String, Object?>{
          ...userJson,
          'userType': 'AUDITOR',
          'status': 'ARCHIVED',
        });
        expect(user.userType, UserType.unknown);
        expect(user.status, UserStatus.unknown);
      },
    );

    test('a missing or wrongly typed required field names the field', () {
      final broken = <String, Object?>{...userJson}..remove('userType');
      expect(
        () => UserProfile.fromJson(broken),
        throwsA(
          isA<ModelParseException>().having(
            (e) => e.message,
            'message',
            contains('userType'),
          ),
        ),
      );
      expect(
        () => UserProfile.fromJson(<String, Object?>{
          ...userJson,
          'mfaEnabled': 'yes',
        }),
        throwsA(
          isA<ModelParseException>().having(
            (e) => e.message,
            'message',
            contains('mfaEnabled'),
          ),
        ),
      );
    });

    test('parses GET /me', () {
      final current = CurrentUser.fromJson(<String, Object?>{
        'user': userJson,
        'session': <String, Object?>{'id': 's1', 'mfaEnrollmentRequired': true},
      });
      expect(current.sessionId, 's1');
      expect(current.mfaEnrollmentRequired, isTrue);
      expect(current.user.name, 'Asha');
    });
  });

  group('sign-in results', () {
    test('tokens parse as AuthenticatedSession', () {
      final result = SignInResult.fromJson(sessionJson);
      expect(result, isA<AuthenticatedSession>());
      final session = result as AuthenticatedSession;
      expect(session.accessTokenExpiresInSeconds, 900);
      expect(session.refreshTokenExpiresAt.isUtc, isTrue);
      expect(session.user.phone, '+919876543210');
    });

    test('an MFA response parses as MfaChallenge', () {
      final result = SignInResult.fromJson(const <String, Object?>{
        'mfaRequired': true,
        'mfaToken': 'mfa.challenge.token',
        'mfaTokenExpiresInSeconds': 300,
      });
      expect(result, isA<MfaChallenge>());
      expect((result as MfaChallenge).expiresInSeconds, 300);
    });

    test('toString never reveals tokens', () {
      final session = AuthenticatedSession.fromJson(sessionJson);
      expect(session.toString(), isNot(contains('access.jwt.value')));
      expect(session.toString(), isNot(contains('secret')));
      const challenge = MfaChallenge(
        mfaToken: 'mfa.challenge.token',
        expiresInSeconds: 300,
      );
      expect('$challenge', isNot(contains('mfa.challenge.token')));
    });

    test('web sessions have an empty refresh token', () {
      final session = AuthenticatedSession.fromJson(<String, Object?>{
        ...sessionJson,
        'refreshToken': '',
      });
      expect(session.refreshToken, isEmpty);
    });

    test('parses OTP dispatch and session summaries', () {
      final dispatch = OtpDispatch.fromJson(const <String, Object?>{
        'expiresInSeconds': 300,
        'resendAfterSeconds': 30,
      });
      expect(dispatch.resendAfterSeconds, 30);

      final session = SessionSummary.fromJson(const <String, Object?>{
        'id': 's1',
        'current': true,
        'clientType': 'MOBILE',
        'deviceName': 'Pixel 9',
        'ip': '203.0.113.7',
        'userAgent': null,
        'createdAt': '2026-10-01T05:00:00.000Z',
        'lastUsedAt': '2026-10-01T05:15:00.000Z',
        'expiresAt': '2026-10-31T05:15:00.000Z',
      });
      expect(session.current, isTrue);
      expect(session.clientType, SessionClientType.mobile);
      expect(session.userAgent, isNull);
    });
  });

  group('authorization models', () {
    const mineJson = <String, Object?>{
      'userId': 'u1',
      'userType': 'OPERATOR_STAFF',
      'roles': <Object?>[
        <String, Object?>{'key': 'BOOKING_STAFF', 'name': 'Booking staff'},
      ],
      'permissionVersion': 4,
      'dataScope': <String, Object?>{
        'type': 'OWN_OPERATOR',
        'operatorIds': <Object?>['op-a'],
      },
      'operatorId': 'op-a',
      'partnerId': null,
      'permissions': <Object?>['bookings.cancel', 'bookings.read'],
      'permissionsByModule': <String, Object?>{
        'bookings': <Object?>['cancel', 'read'],
      },
    };

    test('parses GET /me/permissions', () {
      final mine = MyPermissions.fromJson(mineJson);
      expect(mine.userType, UserType.operatorStaff);
      expect(mine.roles.single.key, 'BOOKING_STAFF');
      expect(mine.permissionVersion, 4);
      expect(mine.dataScope.type, DataScopeType.ownOperator);
      expect(mine.dataScope.operatorIds, ['op-a']);
      expect(mine.permissions, {'bookings.cancel', 'bookings.read'});
    });

    test('all six data scopes map from their wire values', () {
      expect(
        [
          'ALL',
          'OWN_OPERATOR',
          'SELECTED_OPERATORS',
          'OWN_PARTNER',
          'OWN_RECORDS',
          'ASSIGNED_RECORDS',
        ].map(DataScopeType.fromWire),
        [
          DataScopeType.all,
          DataScopeType.ownOperator,
          DataScopeType.selectedOperators,
          DataScopeType.ownPartner,
          DataScopeType.ownRecords,
          DataScopeType.assignedRecords,
        ],
      );
      expect(DataScopeType.fromWire('EVERYTHING'), DataScopeType.unknown);
    });

    test('parses the catalogues', () {
      final permission = PermissionDefinition.fromJson(const <String, Object?>{
        'key': 'bookings.cancel',
        'module': 'bookings',
        'action': 'cancel',
        'name': 'Cancel bookings',
        'description': 'Cancel bookings or individual seats.',
        'sensitive': false,
        'grantableTo': <Object?>[
          'STAFF',
          'OPERATOR_STAFF',
          'PARTNER_USER',
          'CUSTOMER',
        ],
      });
      expect(permission.grantableTo, contains(UserType.customer));

      final role = Role.fromJson(const <String, Object?>{
        'key': 'SUPER_ADMIN',
        'name': 'Super administrator',
        'description': 'Full control.',
        'userType': 'STAFF',
        'dataScopeType': 'ALL',
        'isSystemRole': true,
        'permissionKeys': <Object?>['*'],
      });
      expect(role.permissionKeys, ['*']);
      expect(role.dataScopeType, DataScopeType.all);
    });

    test('parses another user\'s authorization with overrides', () {
      final authorization = UserAuthorization.fromJson(const <String, Object?>{
        'userId': 'u2',
        'userType': 'OPERATOR_STAFF',
        'operatorId': 'op-a',
        'partnerId': null,
        'permissionVersion': 3,
        'roles': <Object?>[
          <String, Object?>{'key': 'BOOKING_STAFF', 'name': 'Booking staff'},
        ],
        'dataScope': <String, Object?>{
          'type': 'OWN_OPERATOR',
          'operatorIds': <Object?>['op-a'],
        },
        'overrides': <Object?>[
          <String, Object?>{
            'permissionKey': 'reports.read',
            'effect': 'ALLOW',
            'reason': 'Needs reports',
            'grantedBy': 'admin-1',
            'updatedAt': '2026-10-01T06:00:00.000Z',
          },
          <String, Object?>{
            'permissionKey': 'bookings.cancel',
            'effect': 'DENY',
            'reason': 'Trainee',
            'grantedBy': 'admin-1',
            'updatedAt': null,
          },
        ],
        'effectivePermissions': <Object?>[
          <String, Object?>{'key': 'bookings.read', 'source': 'ROLE'},
          <String, Object?>{'key': 'reports.read', 'source': 'ALLOW_OVERRIDE'},
        ],
        'deniedPermissions': <Object?>['bookings.cancel'],
      });
      expect(authorization.overrides.map((o) => o.effect), [
        OverrideEffect.allow,
        OverrideEffect.deny,
      ]);
      expect(
        authorization.effectivePermissions.last.source,
        PermissionSource.allowOverride,
      );
      expect(authorization.deniedPermissions, ['bookings.cancel']);
    });

    test('a list with a wrong element type is rejected', () {
      expect(
        () => MyPermissions.fromJson(<String, Object?>{
          ...mineJson,
          'permissions': <Object?>['bookings.read', 7],
        }),
        throwsA(isA<ModelParseException>()),
      );
    });
  });
}
