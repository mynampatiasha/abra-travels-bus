import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:test/test.dart';

JsonMap mineJson({
  List<String> permissions = const [
    'bookings.read',
    'bookings.create',
    'customers.read',
  ],
  List<String> roles = const ['BOOKING_STAFF'],
  int version = 1,
}) => <String, Object?>{
  'userId': 'u1',
  'userType': 'OPERATOR_STAFF',
  'roles': [
    for (final role in roles) <String, Object?>{'key': role, 'name': role},
  ],
  'permissionVersion': version,
  'dataScope': <String, Object?>{
    'type': 'OWN_OPERATOR',
    'operatorIds': ['op-a'],
  },
  'operatorId': 'op-a',
  'partnerId': null,
  'permissions': permissions,
  'permissionsByModule': <String, Object?>{},
};

PermissionSet setOf(
  List<String> permissions, {
  List<String> roles = const ['BOOKING_STAFF'],
}) => PermissionSet.fromMyPermissions(
  MyPermissions.fromJson(mineJson(permissions: permissions, roles: roles)),
);

class _Tokens implements AuthTokenSource {
  @override
  Future<String?> accessToken() async => 'access';

  @override
  Future<bool> refreshAccessToken() async => false;

  @override
  Future<void> onSessionRejected() async {}
}

({PermissionsController controller, FakeHttpAdapter adapter}) controllerWith(
  Future<FakeResponse> Function(RecordedRequest request) handler,
) {
  final adapter = FakeHttpAdapter(handler);
  final client = ApiClient(
    config: AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.admin,
      apiBaseUrl: Uri.parse('http://localhost:4000'),
    ),
    dio: Dio()..httpClientAdapter = adapter,
  )..attachTokenSource(_Tokens());
  return (
    controller: PermissionsController(PermissionsRepository(client)),
    adapter: adapter,
  );
}

void main() {
  group('PermissionSet', () {
    final set = setOf(['bookings.read', 'bookings.create', 'customers.read']);

    test('hasPermission', () {
      expect(set.hasPermission(PermissionKeys.bookingsRead), isTrue);
      expect(set.hasPermission(PermissionKeys.bookingsCancel), isFalse);
      expect(set.hasPermission('made.up'), isFalse);
      expect(set.hasPermission(''), isFalse);
    });

    test('hasAnyPermission', () {
      expect(
        set.hasAnyPermission([
          PermissionKeys.settingsUpdate,
          PermissionKeys.customersRead,
        ]),
        isTrue,
      );
      expect(
        set.hasAnyPermission([
          PermissionKeys.settingsUpdate,
          PermissionKeys.auditRead,
        ]),
        isFalse,
      );
      expect(set.hasAnyPermission(const []), isFalse);
    });

    test('hasAllPermissions; an empty requirement is never satisfied', () {
      expect(
        set.hasAllPermissions([
          PermissionKeys.bookingsRead,
          PermissionKeys.bookingsCreate,
        ]),
        isTrue,
      );
      expect(
        set.hasAllPermissions([
          PermissionKeys.bookingsRead,
          PermissionKeys.bookingsCancel,
        ]),
        isFalse,
      );
      expect(set.hasAllPermissions(const []), isFalse);
    });

    test('hasRole / hasAnyRole', () {
      expect(set.hasRole(RoleKeys.bookingStaff), isTrue);
      expect(set.hasRole(RoleKeys.operatorAdmin), isFalse);
      expect(set.hasAnyRole([RoleKeys.admin, RoleKeys.bookingStaff]), isTrue);
      expect(set.hasAnyRole(const []), isFalse);
    });

    test('carries scope, operator and version from the server', () {
      expect(set.dataScope.type, DataScopeType.ownOperator);
      expect(set.dataScope.operatorIds, ['op-a']);
      expect(set.operatorId, 'op-a');
      expect(set.permissionVersion, 1);
    });

    test('none allows nothing', () {
      const none = PermissionSet.none;
      expect(none.isEmpty, isTrue);
      expect(none.hasPermission(PermissionKeys.bookingsRead), isFalse);
      expect(none.hasAnyPermission(PermissionKeys.all), isFalse);
      expect(none.hasRole(RoleKeys.superAdmin), isFalse);
    });

    test('the sets cannot be modified from outside', () {
      expect(
        () => set.permissions.add(PermissionKeys.settingsUpdate),
        throwsUnsupportedError,
      );
      expect(
        () => set.roleKeys.add(RoleKeys.superAdmin),
        throwsUnsupportedError,
      );
    });

    test(
      'a role name alone grants no permission (the server list is the only source)',
      () {
        final superAdminWithDeny = setOf(
          ['users.read'],
          roles: [RoleKeys.superAdmin],
        );
        expect(superAdminWithDeny.hasRole(RoleKeys.superAdmin), isTrue);
        expect(
          superAdminWithDeny.hasPermission(PermissionKeys.settingsUpdate),
          isFalse,
        );
      },
    );
  });

  group('PermissionsController', () {
    test(
      'starts with nothing, loads from GET /me/permissions and notifies',
      () async {
        final h = controllerWith((_) async => FakeResponse.ok(mineJson()));
        final changes = <PermissionSet>[];
        h.controller.changes.listen(changes.add);
        expect(h.controller.current.isEmpty, isTrue);

        final result = await h.controller.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(result.isSuccess, isTrue);
        expect(h.adapter.requests.single.path, 'me/permissions');
        expect(
          h.adapter.requests.single.header('Authorization'),
          'Bearer access',
        );
        expect(
          h.controller.current.hasPermission(PermissionKeys.bookingsRead),
          isTrue,
        );
        expect(changes, hasLength(1));
      },
    );

    test('picks up a changed permission set', () async {
      var version = 1;
      final h = controllerWith(
        (_) async => FakeResponse.ok(
          mineJson(
            version: version,
            permissions: version == 1
                ? ['bookings.read', 'bookings.cancel']
                : ['bookings.read'],
          ),
        ),
      );
      await h.controller.refresh();
      expect(
        h.controller.current.hasPermission(PermissionKeys.bookingsCancel),
        isTrue,
      );
      version = 2;
      await h.controller.refresh();
      expect(
        h.controller.current.hasPermission(PermissionKeys.bookingsCancel),
        isFalse,
      );
      expect(h.controller.current.permissionVersion, 2);
    });

    test(
      'a failed load never widens access: the failure is returned',
      () async {
        final h = controllerWith(
          (_) async =>
              FakeResponse.error(503, ApiErrorCodes.serviceUnavailable),
        );
        final result = await h.controller.refresh();
        expect(result.failureOrNull, isA<ApiFailure>());
        expect(h.controller.current.isEmpty, isTrue);
      },
    );

    test('a malformed response is a failure, not a partial set', () async {
      final h = controllerWith(
        (_) async => FakeResponse.ok(<String, Object?>{
          'permissions': ['users.read'],
        }),
      );
      final result = await h.controller.refresh();
      expect(result.failureOrNull, isA<ServerFailure>());
      expect(h.controller.current.isEmpty, isTrue);
    });

    test('clear forgets everything (sign-out)', () async {
      final h = controllerWith((_) async => FakeResponse.ok(mineJson()));
      await h.controller.refresh();
      h.controller.clear();
      expect(h.controller.current.isEmpty, isTrue);
    });
  });

  group('PermissionsRepository', () {
    test('reads catalogue, roles and another user\'s authorization', () async {
      final h = controllerWith((request) async {
        return switch (request.path) {
          'permissions' => FakeResponse.ok(<Object?>[
            <String, Object?>{
              'key': 'audit.read',
              'module': 'audit',
              'action': 'read',
              'name': 'View audit log',
              'description': 'View the audit trail.',
              'sensitive': false,
              'grantableTo': <Object?>['STAFF', 'OPERATOR_STAFF'],
            },
          ]),
          'roles' => FakeResponse.ok(<Object?>[]),
          _ => FakeResponse.error(404, ApiErrorCodes.resourceNotFound),
        };
      });
      final client = ApiClient(
        config: AppConfig(
          environment: AppEnvironment.test,
          appKind: AppKind.admin,
          apiBaseUrl: Uri.parse('http://localhost:4000'),
        ),
        dio: Dio()..httpClientAdapter = h.adapter,
      )..attachTokenSource(_Tokens());
      final repository = PermissionsRepository(client);

      expect(
        (await repository.fetchCatalogue()).single.key,
        PermissionKeys.auditRead,
      );
      expect(await repository.fetchRoles(), isEmpty);
      await expectLater(
        repository.fetchForUser('other-tenant-user'),
        throwsA(
          isA<AppException>().having(
            (e) => (e.failure as ApiFailure).isNotFound,
            'not found',
            isTrue,
          ),
        ),
      );
      expect(
        h.adapter.requests.last.path,
        'users/other-tenant-user/permissions',
      );
    });
  });

  group('parity with the backend (no second registry)', () {
    // Parses definePermissions('<module>', { <action>: { ... }, ... }) blocks.
    Set<String> backendPermissionKeys() {
      final catalog = File(
        '../../backend/src/modules/rbac/permissions/permission-catalog.ts',
      );
      // A module may define its permissions next to its model and the
      // catalogue spreads them in: read the files it imports too.
      final sources = StringBuffer(catalog.readAsStringSync());
      for (final link in RegExp(
        r"from '(\.{1,2}/[^']+)'",
      ).allMatches(sources.toString()).toList()) {
        final file = File.fromUri(
          catalog.absolute.uri.resolve('${link.group(1)}.ts'),
        );
        if (file.existsSync()) sources.write(file.readAsStringSync());
      }
      final source = sources.toString();
      final keys = <String>{};
      final group = RegExp(r"definePermissions\('([a-z.-]+)',\s*\{");
      for (final match in group.allMatches(source)) {
        final module = match.group(1)!;
        var depth = 1;
        var index = match.end;
        final body = StringBuffer();
        while (index < source.length && depth > 0) {
          final char = source[index++];
          if (char == '{') depth++;
          if (char == '}') depth--;
          if (depth > 0) body.write(char);
        }
        // Actions are the keys at the first nesting level of the block.
        var level = 0;
        for (final line in body.toString().split('\n')) {
          final action = RegExp(
            r'^\s*([a-z][a-zA-Z-]*):\s*\{',
          ).firstMatch(line);
          if (level == 0 && action != null) {
            keys.add('$module.${action.group(1)}');
          }
          level += '{'.allMatches(line).length - '}'.allMatches(line).length;
        }
      }
      return keys;
    }

    test('PermissionKeys is exactly the backend catalogue', () {
      final backend = backendPermissionKeys();
      expect(backend, hasLength(81), reason: 'backend catalogue size changed');
      expect(
        PermissionKeys.all.difference(backend),
        isEmpty,
        reason: 'keys unknown to the backend',
      );
      expect(
        backend.difference(PermissionKeys.all),
        isEmpty,
        reason: 'backend keys missing in Flutter',
      );
    });

    test('RoleKeys is exactly the backend role list', () {
      final source = File(
        '../../backend/src/modules/rbac/roles/system-roles.ts',
      ).readAsStringSync();
      final list = RegExp(
        r'SYSTEM_ROLE_KEYS = \[([^\]]+)\]',
      ).firstMatch(source)!.group(1)!;
      final backend = RegExp(
        r"'([A-Z_]+)'",
      ).allMatches(list).map((m) => m.group(1)!).toSet();
      expect(backend, hasLength(13));
      expect(RoleKeys.all, backend);
    });
  });
}
