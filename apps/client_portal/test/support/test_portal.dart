import 'dart:async';
import 'dart:io';

import 'package:client_portal/app/portal_app.dart';
import 'package:client_portal/app/providers.dart';
import 'package:client_portal/bootstrap/app_dependencies.dart';
import 'package:client_portal/routing/portal_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_permissions/shared_permissions.dart';

/// The real English resources (app + shared).
final MemoryTranslationSource englishTranslations = MemoryTranslationSource({
  'en': <String, String>{
    ...parseArb(
      File(
        '../../packages/shared_localization/l10n/app_en.arb',
      ).readAsStringSync(),
    ),
    ...parseArb(File('l10n/portal_en.arb').readAsStringSync()),
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

  /// The bus owner who signs in to the portal.
  static const owner = operatorAdmin;

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
  JsonMap clientKyc = <String, Object?>{
    'approved': true,
    'companyName': 'Alpha Lines',
    'companyStatus': 'ACTIVE',
    'status': 'APPROVED',
    'submissionId': 'company-file',
    'kyc': null,
  };

  /// The company profile page (`client/company`), as the backend holds it.
  JsonMap company = <String, Object?>{
    'id': operatorAId,
    'companyName': 'Alpha Lines',
    'ownerName': 'Omar Operator',
    'email': 'omar@alpha.test',
    'supportPhone': '',
    'city': '',
    'gstin': '',
    'payoutMode': 'MANUAL',
    'bank': null,
  };
  bool requireMfa = false;
  bool mfaEnrollmentRequired = false;
  String validPassword = 'correct-horse-battery';
  final Map<String, List<JsonMap>> records = <String, List<JsonMap>>{};

  /// The settings the backend holds, by integration (`whatsapp`, `email`).
  /// Secrets are never in them: only whether one is set.
  final Map<String, JsonMap> settings = <String, JsonMap>{
    'whatsapp': <String, Object?>{
      'provider': 'meta',
      'status': 'INCOMPLETE',
      'missing': <String>['accessToken', 'phoneNumberId'],
      'enabled': true,
      'businessAccountId': null,
      'phoneNumberId': null,
      'accessToken': <String, Object?>{
        'configured': false,
        'source': 'NONE',
        'lastFour': null,
      },
      'otpTemplateName': null,
      'otpTemplateLanguage': null,
      'otpFallbackToSms': true,
    },
    'email': <String, Object?>{
      'provider': 'smtp',
      'status': 'INCOMPLETE',
      'missing': <String>['host', 'port'],
      'enabled': true,
      'host': null,
      'port': null,
      'security': 'STARTTLS',
      'username': null,
      'password': <String, Object?>{'configured': false},
      'fromName': null,
      'fromAddress': 'no-reply@abratravels.local',
      'replyTo': null,
    },
  };

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

  /// The owner's company documents file as the API returns it.
  JsonMap addCompanyFile({
    String status = 'DRAFT',
    List<JsonMap> documents = const <JsonMap>[],
    String? decisionNote,
    bool canSubmit = false,
    List<String> problems = const <String>[],
  }) => add('submissions', <String, Object?>{
    'operatorId': operatorAId,
    'companyName': 'Alpha Lines',
    'subjectType': 'OPERATOR',
    'busId': null,
    'busRegistrationNumber': null,
    'busName': null,
    'status': status,
    'submitCount': 0,
    'submittedAt': null,
    'decidedAt': null,
    'updatedAt': '2026-10-06T10:00:00.000Z',
    'decisionNote': decisionNote,
    'problems': problems,
    'canSubmit': canSubmit,
    'checklist': <Object?>[
      <String, Object?>{
        'documentTypeId': 'gst-type',
        'name': 'GST certificate',
        'isRequired': true,
        'state': 'MISSING',
      },
    ],
    'documents': documents,
    'history': <Object?>[],
  });

  static JsonMap document(
    String name,
    String typeId,
    String status, {
    String? reason,
  }) => <String, Object?>{
    'documentTypeId': typeId,
    'key': typeId,
    'name': name,
    'status': status,
    'rejectionReason': reason,
    'expiryDate': null,
    'reviewedAt': null,
    'files': <Object?>[
      <String, Object?>{
        'id': 'file-$typeId',
        'originalName': 'scan.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 20480,
      },
    ],
  };

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
    final portal = _portal(request);
    if (portal != null) return portal;
    if (path.startsWith('catalogue/')) return _catalogue(request);
    if (path.startsWith('settings/integrations/')) return _settings(request);
    if (path.startsWith('notifications')) return _notifications(request);
    if (path.startsWith('onboarding/')) return _onboarding(request);
    return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
  }

  /// The calls only the owner's portal makes: the invitation link, uploads, saving a
  /// document, sending for review and adding a bus.
  FakeResponse? _portal(RecordedRequest request) {
    final method = request.options.method;
    final path = request.path;
    final body = request.body is Map
        ? asJsonMap(request.body! as Map)
        : <String, Object?>{};
    switch (path) {
      case 'client/company':
        if (method == 'PUT') company = <String, Object?>{...company, ...body};
        return FakeResponse.ok(company);
      case 'client/company/bank':
        final number = '${body['accountNumber']}';
        company = <String, Object?>{
          ...company,
          'payoutMode': 'MANUAL',
          'bank': <String, Object?>{
            'holderName': body['holderName'],
            'accountLast4': number.substring(number.length - 4),
            'ifsc': body['ifsc'],
            'status': 'PENDING',
            'note': null,
          },
        };
        return FakeResponse.ok(company);
      case 'client/kyc':
        if (method == 'PUT') {
          clientKyc['companyName'] = body['companyName'];
          final kyc = clientKyc['kyc'];
          if (kyc is Map) {
            kyc['answers'] = body['answers'];
            kyc['introductionAcceptedAt'] = '2026-10-09T00:00:00Z';
          }
        }
        return FakeResponse.ok(clientKyc);
      case 'onboarding/invitations/inspect':
        return body['token'] == 'good-token'
            ? FakeResponse.ok(<String, Object?>{
                'companyName': 'Alpha Lines',
                'ownerName': 'Anita Rao',
                'email': 'anita@alpha.test',
              })
            : FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
      case 'onboarding/invitations/accept':
        return body['token'] == 'good-token'
            ? FakeResponse.ok(<String, Object?>{'email': 'anita@alpha.test'})
            : FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
      case 'catalogue/buses':
        if (method == 'POST') {
          return FakeResponse(201, <String, Object?>{
            'success': true,
            'data': add('buses', <String, Object?>{
              ...body,
              'status': 'PENDING_APPROVAL',
            }),
            'meta': <String, Object?>{'requestId': 'test-request'},
          });
        }
        return _all('buses');
      case 'catalogue/bus-types':
        return _all('bus-types');
      case 'files':
        return const FakeResponse(201, <String, Object?>{
          'success': true,
          'data': <String, Object?>{'id': 'uploaded-file'},
          'meta': <String, Object?>{'requestId': 'test-request'},
        });
    }
    final parts = path.split('/');
    if (parts.length >= 4 &&
        parts[0] == 'onboarding' &&
        parts[1] == 'submissions') {
      final file = of(
        'submissions',
      ).where((item) => item['id'] == parts[2]).firstOrNull;
      if (file == null) return null;
      if (method == 'POST' && parts[3] == 'submit') {
        file['status'] = 'PENDING';
        // The company KYC view reads the same submission, as on the server.
        if (clientKyc['submissionId'] == file['id']) clientKyc['status'] = 'PENDING';
        return FakeResponse.ok(file);
      }
      if (method == 'PUT' && parts[3] == 'documents') {
        return FakeResponse.ok(file);
      }
    }
    return null;
  }

  FakeResponse _all(String resource) => FakeResponse(200, <String, Object?>{
    'success': true,
    'data': of(resource),
    'meta': <String, Object?>{
      'requestId': 'test-request',
      'page': 1,
      'pageSize': 100,
      'total': of(resource).length,
    },
  });

  /// `onboarding/invitations` and `onboarding/submissions`: lists with a status filter, the
  /// invite, resend and withdraw calls, and the review calls of one file.
  FakeResponse _onboarding(RecordedRequest request) {
    final method = request.options.method;
    final parts = request.path.split('/');
    final resource = parts[1];
    final records = of(resource);
    final body = request.body == null
        ? <String, Object?>{}
        : asJsonMap(request.body! as Map);

    if (parts.length == 2 && method == 'GET') {
      final status = request.options.queryParameters['status'];
      final items = records
          .where((record) => status == null || record['status'] == status)
          .toList();
      return FakeResponse(200, <String, Object?>{
        'success': true,
        'data': items,
        'meta': <String, Object?>{
          'requestId': 'test-request',
          'page': 1,
          'pageSize': request.options.queryParameters['pageSize'] ?? 20,
          'total': items.length,
        },
      });
    }
    if (resource == 'invitations' && parts.length == 2 && method == 'POST') {
      final created = add('invitations', <String, Object?>{
        'operatorId': 'op-${records.length}',
        'companyName': body['companyName'],
        'ownerName': body['ownerName'],
        'email': body['email'],
        'phone': body['phone'],
        'status': 'PENDING',
        'expired': false,
        'emailStatus': 'SENT',
        'emailProblem': null,
        'inviteUrl': 'http://localhost:5000/accept-invite?token=TESTTOKEN',
        'expiresAt': '2026-10-14T10:00:00.000Z',
        'createdAt': '2026-10-07T10:00:00.000Z',
      });
      return FakeResponse(201, <String, Object?>{
        'success': true,
        'data': created,
        'meta': <String, Object?>{'requestId': 'test-request'},
      });
    }
    final record = records.where((item) => item['id'] == parts[2]).firstOrNull;
    if (record == null) return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
    if (parts.length == 3) return FakeResponse.ok(record);
    final action = parts[3];
    if (resource == 'invitations') {
      if (action == 'revoke') record['status'] = 'REVOKED';
      return FakeResponse.ok(record);
    }
    // submissions
    final documents = (record['documents']! as List).cast<JsonMap>();
    switch (action) {
      case 'documents': // .../documents/<typeId>/review
        final document = documents.firstWhere(
          (item) => item['documentTypeId'] == parts[4],
        );
        document['status'] = body['decision'];
        document['rejectionReason'] = body['reason'];
      case 'approve':
        record['status'] = 'APPROVED';
      case 'reject':
        record['status'] = 'REJECTED';
        record['decisionNote'] = body['note'];
    }
    return FakeResponse.ok(record);
  }

  /// A file waiting for review, as the API returns it.
  JsonMap addSubmission({String status = 'PENDING'}) =>
      add('submissions', <String, Object?>{
        'operatorId': 'op-1',
        'companyName': 'Alpha Lines',
        'subjectType': 'OPERATOR',
        'busId': null,
        'busRegistrationNumber': null,
        'busName': null,
        'status': status,
        'submitCount': 1,
        'submittedAt': '2026-10-06T10:00:00.000Z',
        'decidedAt': null,
        'updatedAt': '2026-10-06T10:00:00.000Z',
        'decisionNote': null,
        'problems': <String>[],
        'canSubmit': false,
        'checklist': <Object?>[
          <String, Object?>{
            'documentTypeId': 'pan-type',
            'name': 'PAN card',
            'isRequired': true,
            'state': 'MISSING',
          },
        ],
        'documents': <Object?>[
          <String, Object?>{
            'documentTypeId': 'gst-type',
            'key': 'GST',
            'name': 'GST certificate',
            'status': 'PENDING',
            'rejectionReason': null,
            'expiryDate': null,
            'reviewedAt': null,
            'files': <Object?>[
              <String, Object?>{
                'id': 'file-1',
                'originalName': 'gst.pdf',
                'mimeType': 'application/pdf',
                'sizeBytes': 20480,
              },
            ],
          },
        ],
        'history': <Object?>[
          <String, Object?>{
            'at': '2026-10-06T10:00:00.000Z',
            'action': 'SUBMITTED',
            'byUserId': 'u1',
            'documentTypeKey': null,
            'note': null,
          },
        ],
      });

  /// The notification list: nobody has any in these tests.
  FakeResponse _notifications(RecordedRequest request) =>
      request.path == 'notifications/unread-count'
      ? FakeResponse.ok(<String, Object?>{'count': 0})
      : const FakeResponse(200, <String, Object?>{
          'success': true,
          'data': <Object?>[],
          'meta': <String, Object?>{
            'requestId': 'test-request',
            'page': 1,
            'pageSize': 20,
            'total': 0,
          },
        });

  /// `settings/integrations/<channel>[/test-connection|/test-email]`. Like
  /// the backend: anyone with `settings.read` may read, only
  /// `settings.update` may change or test, and a secret is never returned.
  FakeResponse _settings(RecordedRequest request) {
    final parts = request.path.split('/');
    final channel = parts[2];
    final current = settings[channel];
    if (current == null) return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
    final method = request.options.method;
    if (method == 'GET') return FakeResponse.ok(current);
    if (!persona.permissions.contains('settings.update')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    final body = request.body == null
        ? <String, Object?>{}
        : asJsonMap(request.body! as Map);

    if (parts.length == 4) {
      final isWhatsApp = channel == 'whatsapp';
      if (parts[3] == 'test-email') {
        return FakeResponse.ok(<String, Object?>{
          'ok': true,
          'message': 'A test email was sent to ${body['to']}.',
        });
      }
      final ready = isWhatsApp
          ? (current['accessToken']! as Map)['configured'] == true
          : current['host'] != null;
      return FakeResponse.ok(<String, Object?>{
        'ok': ready,
        'message': ready
            ? (isWhatsApp
                  ? 'Connected to WhatsApp: number +91 98765 43210.'
                  : 'Connected to ${current['host']}:${current['port']} and signed in.')
            : (isWhatsApp
                  ? 'Save the access token first.'
                  : 'Enter the host and the port and save, then test again.'),
      });
    }

    for (final entry in body.entries) {
      switch (entry.key) {
        case 'reason':
          break;
        case 'accessToken':
          final token = entry.value as String?;
          current['accessToken'] = <String, Object?>{
            'configured': token != null,
            'source': token == null ? 'NONE' : 'ADMIN',
            'lastFour': token?.substring(token.length - 4),
          };
        case 'password':
          current['password'] = <String, Object?>{
            'configured': entry.value != null,
          };
        default:
          current[entry.key] = entry.value;
      }
    }
    final ready = channel == 'whatsapp'
        ? (current['accessToken']! as Map)['configured'] == true &&
              current['phoneNumberId'] != null
        : current['host'] != null && current['port'] != null;
    current['status'] = current['enabled'] == false
        ? 'DISABLED'
        : (ready ? 'READY' : 'INCOMPLETE');
    current['missing'] = ready ? <String>[] : <String>['setup'];
    return FakeResponse.ok(current);
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
class TestPortal {
  TestPortal(this.backend, {Map<String, String> stored = const {}})
    : secureStore = InMemorySecureStore(stored) {
    adapter = FakeHttpAdapter(backend.call);
    final config = AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.operator,
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
      notifications: NotificationCenter(
        repository: NotificationsRepository(client),
        live: const _SilentLive(),
      ),
    );
  }

  /// A device that already holds a session for the backend's persona.
  factory TestPortal.signedIn(FakeBackend backend) => TestPortal(
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
        child: const PortalApp(),
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
).read(portalRouterProvider).routerDelegate.currentConfiguration.uri.path;

Future<void> open(WidgetTester tester, String location) async {
  containerOf(tester).read(portalRouterProvider).go(location);
  await settle(tester);
}

/// No live channel in tests: a stream that never has anything to say.
class _SilentLive implements LiveNotificationSource {
  const _SilentLive();

  @override
  Stream<NotificationItem> connect(Future<String?> Function() accessToken) =>
      StreamController<NotificationItem>.broadcast().stream;

  @override
  Future<void> disconnect() async {}
}
