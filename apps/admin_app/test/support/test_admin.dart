import 'dart:io';

import 'package:admin_app/app/admin_app.dart';
import 'package:admin_app/app/providers.dart';
import 'package:admin_app/bootstrap/app_dependencies.dart';
import 'package:admin_app/routing/admin_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';

/// The real English resources (app + shared).
final MemoryTranslationSource englishTranslations = MemoryTranslationSource({
  'en': <String, String>{
    ...parseArb(
      File(
        '../../packages/shared_localization/l10n/app_en.arb',
      ).readAsStringSync(),
    ),
    ...parseArb(File('l10n/admin_en.arb').readAsStringSync()),
  },
});

const operatorAId = '66f0c0ffee000000000000a1';
const operatorBId = '66f0c0ffee000000000000b2';

/// Who is signed in, with the permissions the backend's system roles give.
class Persona {
  const Persona({
    required this.name,
    required this.userType,
    required this.roleKey,
    required this.permissions,
    this.operatorId,
  });

  final String name;
  final String userType;
  final String roleKey;
  final Set<String> permissions;
  final String? operatorId;

  static const superAdmin = Persona(
    name: 'Asha Admin',
    userType: 'STAFF',
    roleKey: 'SUPER_ADMIN',
    permissions: PermissionKeys.all,
  );

  /// Everything except what the backend withholds from ADMIN.
  static final admin = Persona(
    name: 'Anil Admin',
    userType: 'STAFF',
    roleKey: 'ADMIN',
    permissions: PermissionKeys.all.difference(const {
      'users.delete',
      'settings.update',
    }),
  );

  static const operatorAdmin = Persona(
    name: 'Omar Operator',
    userType: 'OPERATOR_STAFF',
    roleKey: 'OPERATOR_ADMIN',
    operatorId: operatorAId,
    permissions: {
      'buses.read',
      'buses.create',
      'buses.update',
      'routes.read',
      'routes.create',
      'routes.update',
      'trips.read',
      'trips.create',
      'trips.update',
      'trips.publish',
      'trips.cancel',
      'operators.read',
      'operators.update',
      'audit.read',
    },
  );

  static const operatorManager = Persona(
    name: 'Mira Manager',
    userType: 'OPERATOR_STAFF',
    roleKey: 'OPERATOR_MANAGER',
    operatorId: operatorAId,
    permissions: {
      'buses.read',
      'buses.create',
      'buses.update',
      'routes.read',
      'routes.create',
      'routes.update',
      'trips.read',
      'trips.create',
      'trips.update',
      'trips.publish',
      'trips.cancel',
    },
  );

  /// Read-only platform staff.
  static const support = Persona(
    name: 'Sam Support',
    userType: 'STAFF',
    roleKey: 'SUPPORT',
    permissions: {'buses.read', 'trips.read', 'operators.read'},
  );

  static const customer = Persona(
    name: 'Chitra Customer',
    userType: 'CUSTOMER',
    roleKey: 'CUSTOMER',
    permissions: {'trips.read', 'bookings.read'},
  );

  static const driver = Persona(
    name: 'Dev Driver',
    userType: 'DRIVER',
    roleKey: 'DRIVER',
    permissions: {'trips.read'},
  );

  JsonMap get userJson => <String, Object?>{
    'id': 'user-$roleKey',
    'name': name,
    'email': '${roleKey.toLowerCase()}@example.com',
    'phone': null,
    'emailVerified': true,
    'phoneVerified': false,
    'userType': userType,
    'status': 'ACTIVE',
    'operatorId': operatorId,
    'partnerId': null,
    'preferredLanguage': 'en',
    'hasPassword': true,
    'mfaEnabled': false,
    'lastLoginAt': null,
    'createdAt': null,
  };

  JsonMap sessionJson({bool mfaEnrollmentRequired = false}) =>
      <String, Object?>{
        'tokenType': 'Bearer',
        'accessToken': 'access-$roleKey',
        'accessTokenExpiresInSeconds': 900,
        'refreshToken': 'session-1.refresh-$roleKey',
        'refreshTokenExpiresAt': '2026-11-01T00:00:00.000Z',
        'sessionId': 'session-1',
        'mfaEnrollmentRequired': mfaEnrollmentRequired,
        'user': userJson,
      };

  JsonMap get permissionsJson => <String, Object?>{
    'userId': 'user-$roleKey',
    'userType': userType,
    'roles': <Object?>[
      <String, Object?>{'key': roleKey, 'name': roleKey},
    ],
    'permissionVersion': 1,
    'dataScope': <String, Object?>{
      'type': operatorId == null
          ? (userType == 'STAFF' ? 'ALL' : 'OWN_RECORDS')
          : 'OWN_OPERATOR',
      'operatorIds': <String>[?operatorId],
    },
    'operatorId': operatorId,
    'partnerId': null,
    'permissions': permissions.toList(),
    'permissionsByModule': <String, Object?>{},
  };
}

/// A stand-in for the backend: authentication, permissions and an
/// in-memory catalogue that behaves like the real API for the calls the
/// app makes (lists with paging and filters, create, edit, actions). Like
/// the backend, it returns to operator staff only their operator's records.
class FakeBackend {
  FakeBackend(this.persona);

  Persona persona;
  bool isOnline = true;
  bool requireMfa = false;
  bool mfaEnrollmentRequired = false;
  String validPassword = 'correct-horse-battery';
  final Map<String, List<JsonMap>> records = <String, List<JsonMap>>{};

  /// Replaces the answer to one request (`METHOD path`), for error cases.
  final Map<String, FakeResponse Function(RecordedRequest request)> overrides =
      <String, FakeResponse Function(RecordedRequest)>{};
  int _nextId = 1;

  List<JsonMap> of(String resource) =>
      records.putIfAbsent(resource, () => <JsonMap>[]);

  JsonMap add(String resource, JsonMap record) {
    final stored = <String, Object?>{
      'id': '66f0c0ffee0000000000${(_nextId++).toString().padLeft(4, '0')}',
      ...record,
    };
    of(resource).add(stored);
    return stored;
  }

  Future<FakeResponse> call(RecordedRequest request) async {
    if (!isOnline) {
      throw DioException(
        requestOptions: request.options,
        type: DioExceptionType.connectionError,
      );
    }
    final method = request.options.method;
    final path = request.path;
    final override = overrides['$method $path'];
    if (override != null) return override(request);

    switch (path) {
      case 'auth/login':
        final body = request.body! as Map;
        if (body['password'] != validPassword) {
          return FakeResponse.error(401, 'INVALID_CREDENTIALS');
        }
        return requireMfa
            ? FakeResponse.ok(<String, Object?>{
                'mfaRequired': true,
                'mfaToken': 'mfa-token',
                'mfaTokenExpiresInSeconds': 300,
              })
            : FakeResponse.ok(
                persona.sessionJson(
                  mfaEnrollmentRequired: mfaEnrollmentRequired,
                ),
              );
      case 'auth/mfa/verify':
        final body = request.body! as Map;
        return body['code'] == '123456' || body['recoveryCode'] == 'RECOVERY-1'
            ? FakeResponse.ok(persona.sessionJson())
            : FakeResponse.error(401, 'MFA_INVALID');
      case 'auth/logout':
        return FakeResponse.ok(null);
      case 'me':
        return FakeResponse.ok(<String, Object?>{
          'user': persona.userJson,
          'session': <String, Object?>{
            'id': 'session-1',
            'mfaEnrollmentRequired': mfaEnrollmentRequired,
          },
        });
      case 'me/permissions':
        return FakeResponse.ok(persona.permissionsJson);
    }
    if (path.startsWith('catalogue/')) return _catalogue(request);
    return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
  }

  /// Records the signed-in persona may see: operator staff get their own
  /// operator's records, plus shared locations.
  Iterable<JsonMap> _visible(String resource) {
    final operatorId = persona.operatorId;
    if (operatorId == null) return of(resource);
    return of(resource).where(
      (record) => resource == 'operators'
          ? record['id'] == operatorId
          : !record.containsKey('operatorId') ||
                record['operatorId'] == operatorId ||
                (resource == 'locations' && record['operatorId'] == null),
    );
  }

  FakeResponse _catalogue(RecordedRequest request) {
    final method = request.options.method;
    final parts = request.path.split('/').skip(1).toList();
    final resource = parts[0];
    final query = request.options.queryParameters;
    final body = request.body == null
        ? <String, Object?>{}
        : asJsonMap(request.body! as Map);

    if (parts.length == 1 && method == 'GET') {
      var items = _visible(resource).where((record) {
        for (final entry in query.entries) {
          if (entry.key == 'page' || entry.key == 'pageSize') continue;
          if (entry.key == 'query') {
            if (!(record['name']! as String).toLowerCase().startsWith(
              (entry.value as String).toLowerCase(),
            )) {
              return false;
            }
          } else if (entry.key == 'active') {
            if ('${record['isActive']}' != entry.value) return false;
          } else if ('${record[entry.key]}' != entry.value) {
            return false;
          }
        }
        return true;
      }).toList();
      final page = query['page']! as int;
      final size = query['pageSize']! as int;
      final total = items.length;
      items = items.skip((page - 1) * size).take(size).toList();
      return FakeResponse.ok(
        items,
        meta: <String, Object?>{'page': page, 'pageSize': size, 'total': total},
      );
    }
    if (parts.length == 1 && method == 'POST') {
      return FakeResponse.ok(
        add(resource, <String, Object?>{
          ...body,
          if (persona.operatorId != null &&
              const {'buses', 'routes', 'trips'}.contains(resource))
            'operatorId': persona.operatorId,
          if (const {'cities', 'bus-types', 'locations'}.contains(resource))
            'isActive': true,
          if (const {'buses', 'routes'}.contains(resource)) 'status': 'ACTIVE',
          if (resource == 'operators') 'status': 'PENDING_APPROVAL',
          if (resource == 'trips') ...<String, Object?>{
            'status': 'DRAFT',
            'seatCounts': <String, Object?>{'total': 0, 'available': 0},
            'bus': <String, Object?>{
              'name': 'Express',
              'registrationNumber': 'KA01AB1234',
              'busTypeName': 'AC Sleeper',
            },
            'departureAt': '2099-01-01T16:00:00.000Z',
          },
        }),
      );
    }
    final record = _visible(
      resource,
    ).where((item) => item['id'] == parts[1]).firstOrNull;
    if (record == null) return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
    if (parts.length == 2 && method == 'GET') return FakeResponse.ok(record);
    if (parts.length == 2 && method == 'PUT') {
      record.addAll(body);
      return FakeResponse.ok(record);
    }
    switch (parts[2]) {
      case 'active':
        record['isActive'] = body['active'];
      case 'status':
        record['status'] = body['status'];
      case 'publish':
        record['status'] = 'SCHEDULED';
        record['seatCounts'] = <String, Object?>{'total': 36, 'available': 36};
      case 'cancel':
        record['status'] = 'CANCELLED';
        record['cancellationReason'] = body['reason'];
    }
    return FakeResponse.ok(record);
  }
}

/// The management app wired as in production, with in-memory storage and
/// HTTP answered by [backend].
class TestAdmin {
  TestAdmin(this.backend, {Map<String, String> stored = const {}})
    : secureStore = InMemorySecureStore(stored) {
    adapter = FakeHttpAdapter(backend.call);
    final config = AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.admin,
      apiBaseUrl: Uri.parse('http://localhost:4000'),
    );
    final localeController = LocaleController(
      config: AbraLocaleConfig(),
      preferences: preferences,
      deviceLocales: const <Locale>[Locale('en')],
    );
    final client = ApiClient(
      config: config,
      dio: Dio()..httpClientAdapter = adapter,
      logger: logger,
    );
    dependencies = AppDependencies(
      config: config,
      logger: logger,
      preferences: preferences,
      localeController: localeController,
      translations: englishTranslations,
      apiClient: client,
      sessionManager: AuthSessionManager(
        api: AuthApi(client, clientType: config.clientType),
        client: client,
        tokenStore: AuthTokenStore(secureStore),
        clientType: config.clientType,
        logger: logger,
      ),
      permissions: PermissionsController(PermissionsRepository(client)),
    );
  }

  /// A device that already holds a session for the backend's persona.
  factory TestAdmin.signedIn(FakeBackend backend) => TestAdmin(
    backend,
    stored: <String, String>{
      AuthTokenStore.accessTokenKey: 'access-${backend.persona.roleKey}',
      AuthTokenStore.refreshTokenKey:
          'session-1.refresh-${backend.persona.roleKey}',
      AuthTokenStore.sessionIdKey: 'session-1',
    },
  );

  final FakeBackend backend;
  final InMemorySecureStore secureStore;
  final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
  final MemoryLogger logger = MemoryLogger();
  late final FakeHttpAdapter adapter;
  late final AppDependencies dependencies;

  List<RecordedRequest> requestsTo(String path, [String? method]) => adapter
      .requests
      .where(
        (request) =>
            request.path == path &&
            (method == null || request.options.method == method),
      )
      .toList();

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    // A test may start the app more than once (as different users).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
        child: const AdminApp(),
      ),
    );
    await settle(tester);
  }
}

/// Lets requests in flight finish, then the UI settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

String locationOf(WidgetTester tester) => containerOf(
  tester,
).read(adminRouterProvider).routerDelegate.currentConfiguration.uri.path;

Future<void> open(WidgetTester tester, String location) async {
  containerOf(tester).read(adminRouterProvider).go(location);
  await settle(tester);
}
