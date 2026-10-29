import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  JsonMap kycConfiguration = <String, Object?>{
    'schemaVersion': 1,
    'version': 0,
    'questions': <JsonMap>[],
    'rules': <JsonMap>[],
  };

  /// The settings the backend holds, by integration (`whatsapp`, `email`, etc.).
  /// Secrets are never in them: only whether one is set.
  final Map<String, JsonMap> settings = <String, JsonMap>{
    'whatsapp': <String, Object?>{
      'provider': 'meta',
      'title': 'WhatsApp',
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
      'title': 'Email (SMTP)',
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
    'sms': <String, Object?>{
      'provider': 'MSG91',
      'title': 'SMS',
      'status': 'INCOMPLETE',
      'missing': <String>['apiKey'],
      'enabled': true,
      'apiKey': <String, Object?>{'configured': false},
      'senderId': null,
    },
    'razorpay': <String, Object?>{
      'title': 'Razorpay',
      'status': 'INCOMPLETE',
      'missing': <String>['keyId', 'keySecret'],
      'enabled': true,
      'keyId': null,
      'keySecret': <String, Object?>{'configured': false},
      'webhookSecret': <String, Object?>{'configured': false},
    },
    'maps': <String, Object?>{
      'provider': 'Google Maps',
      'title': 'Maps',
      'status': 'INCOMPLETE',
      'missing': <String>['apiKey'],
      'enabled': true,
      'apiKey': <String, Object?>{'configured': false},
    },
    'push': <String, Object?>{
      'title': 'Push (Firebase)',
      'status': 'INCOMPLETE',
      'missing': <String>['projectId'],
      'enabled': true,
      'projectId': null,
      'serviceAccountJson': <String, Object?>{'configured': false},
    },
  };

  final List<JsonMap> featureFlags = <JsonMap>[
    <String, Object?>{
      'key': 'live_tracking',
      'name': 'Live tracking',
      'description': 'Customers see the bus on a map',
      'on': true,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'whatsapp_chatbot',
      'name': 'WhatsApp chatbot',
      'description': 'Booking help on WhatsApp',
      'on': false,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'ai_support',
      'name': 'AI support assistant',
      'description': 'AI answers common questions',
      'on': false,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'women_safety',
      'name': 'Women safety',
      'description': 'SOS and trip sharing',
      'on': true,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'partner_api',
      'name': 'Partner API',
      'description': 'External agents',
      'on': false,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'dynamic_pricing',
      'name': 'Dynamic pricing',
      'description': 'Fares change with demand',
      'on': false,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'mobile_app',
      'name': 'Mobile app booking',
      'description': 'Booking in the customer app',
      'on': true,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'driver_app',
      'name': 'Driver app',
      'description': 'Driver check-in and GPS',
      'on': true,
      'updatedAt': null,
    },
    <String, Object?>{
      'key': 'advanced_analytics',
      'name': 'Advanced analytics',
      'description': 'Extra reports',
      'on': false,
      'updatedAt': null,
    },
  ];

  final JsonMap maintenance = <String, Object?>{
    'scopes': <String, Object?>{
      'global': false,
      'customer': false,
      'operator': false,
      'partner': false,
      'admin': false,
    },
    'message': 'We are improving Abra Travels. Back soon.',
    'from': null,
    'to': null,
    'activeNow': <String, Object?>{
      'customer': false,
      'operator': false,
      'partner': false,
      'admin': false,
    },
    'updatedAt': null,
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
    if (path.startsWith('audit-logs')) return _audit(request);
    if (path.startsWith('catalogue/')) return _catalogue(request);
    if (path.startsWith('admin/feature-flags')) return _featureFlags(request);
    if (path.startsWith('admin/maintenance')) return _maintenance(request);
    // The admin lists (`admin/banners`) behave like the catalogue ones.
    if (path.startsWith('admin/')) return _catalogue(request);
    if (path == 'settings/integrations' ||
        path.startsWith('settings/integrations/')) {
      return _settings(request);
    }
    if (path.startsWith('settings/kyc-configuration')) {
      return _kycConfiguration(request);
    }
    if (path.startsWith('notifications')) return _notifications(request);
    if (path.startsWith('onboarding/')) return _onboarding(request);
    return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
  }

  /// The audit log: entries are records with the words the page shows
  /// (`actorName`, `actionLabel`, `sensitive`...).
  FakeResponse _audit(RecordedRequest request) {
    if (!persona.permissions.contains('audit.read')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    final address = Uri.parse(request.path);
    final query = <String, Object?>{
      ...request.options.queryParameters,
      ...address.queryParameters,
    };
    final all = of('audit-logs');
    if (address.path == 'audit-logs/filters') {
      return FakeResponse.ok(<String, Object?>{
        'people': <JsonMap>[
          for (final name in {for (final e in all) '${e['actorName']}'})
            <String, Object?>{'id': 'person-$name', 'name': name},
        ],
        'actions': <JsonMap>[
          for (final e in {for (final e in all) '${e['action']}': e}.values)
            <String, Object?>{
              'key': e['action'],
              'label': e['actionLabel'],
              'sensitive': e['sensitive'] == true,
            },
        ],
      });
    }
    final term = '${query['search'] ?? ''}'.toLowerCase();
    var items =
        all.where((entry) {
          if (query['personId'] != null &&
              'person-${entry['actorName']}' != query['personId']) {
            return false;
          }
          if (query['type'] == 'sensitive' && entry['sensitive'] != true) {
            return false;
          }
          if (query['action'] != null && entry['action'] != query['action']) {
            return false;
          }
          return term.isEmpty ||
              '${entry['actorName']} ${entry['actionLabel']} ${entry['targetLabel']}'
                  .toLowerCase()
                  .contains(term);
        }).toList()..sort(
          (a, b) => query['sort'] == 'oldest'
              ? '${a['at']}'.compareTo('${b['at']}')
              : '${b['at']}'.compareTo('${a['at']}'),
        );
    final page = (query['page'] as int?) ?? 1;
    final size = (query['pageSize'] as int?) ?? 15;
    final total = items.length;
    items = items.skip((page - 1) * size).take(size).toList();
    return FakeResponse.ok(
      items,
      meta: <String, Object?>{'page': page, 'pageSize': size, 'total': total},
    );
  }

  FakeResponse _kycConfiguration(RecordedRequest request) {
    if (!persona.permissions.contains('documents.read')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    if (request.options.method == 'GET') {
      return FakeResponse.ok(<String, Object?>{
        ...kycConfiguration,
        'documents': of('document-types'),
      });
    }
    final body = asJsonMap(request.body! as Map<Object?, Object?>);
    if (request.path.endsWith('/preview')) {
      return FakeResponse.ok(<String, Object?>{
        'missingQuestions': <String>[],
        'documents': <JsonMap>[],
      });
    }
    if (!persona.permissions.contains('documents.manage')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    if (request.path.endsWith('/validate-import')) {
      return FakeResponse.ok(<String, Object?>{'valid': true});
    }
    if (body['expectedVersion'] != kycConfiguration['version']) {
      return FakeResponse.error(
        409,
        'INVALID_STATE_TRANSITION',
        message: 'Configuration changed. Refresh and try again.',
      );
    }
    kycConfiguration = asJsonMap(
      jsonDecode(
            jsonEncode(<String, Object?>{
              'schemaVersion': 1,
              'version': (kycConfiguration['version']! as int) + 1,
              'questions': body['questions'],
              'rules': body['rules'],
            }),
          )
          as Map<Object?, Object?>,
    );
    return FakeResponse.ok(<String, Object?>{
      ...kycConfiguration,
      'documents': of('document-types'),
    });
  }

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
        'inviteUrl': 'http://localhost:5001/accept-invite?token=TESTTOKEN',
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

  /// A logged message sent to a customer.
  JsonMap addMessage({
    String channel = 'WHATSAPP',
    String kind = 'BOOKING_CONFIRMED',
    String recipientName = 'Priya Sharma',
    String address = '+91 98765 43210',
    String subject = 'Booking confirmed: Hyderabad to Bengaluru',
    String body =
        'Hi Priya, your seat 12A on Hyderabad to Bengaluru is confirmed. PNR ABRK1234A.',
    String status = 'SENT',
    String? bookingId = 'BK-1001',
    String? at,
  }) => add('messages', <String, Object?>{
    'channel': channel,
    'kind': kind,
    'recipientName': recipientName,
    'toName': recipientName,
    'name': recipientName,
    'address': address,
    'subject': subject,
    'body': body,
    'status': status,
    'bookingId': bookingId,
    'at': at ?? DateTime.now().toUtc().toIso8601String(),
    'sentAt':
        status == 'SENT'
            ? (at ?? DateTime.now().toUtc().toIso8601String())
            : null,
    'attempts': 1,
    'detail': status == 'FAILED' ? 'Provider rejected the message.' : null,
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
    final method = request.options.method;
    if (parts.length == 2 && method == 'GET') {
      return FakeResponse.ok(<JsonMap>[
        for (final entry in settings.entries)
          <String, Object?>{
            'key': entry.key,
            'title': entry.value['title'] ?? entry.key,
            'status': entry.value['status'] ?? 'INCOMPLETE',
            'missing': entry.value['missing'] ?? <String>[],
          },
      ]);
    }
    final channel = parts[2];
    final current = settings[channel];
    if (current == null) return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
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
      if (!['whatsapp', 'email'].contains(channel)) {
        return FakeResponse.ok(<String, Object?>{
          'ok': true,
          'message': 'Connection works',
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
        case 'webhookVerifyToken':
          current['webhookVerifyToken'] = <String, Object?>{
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

  FakeResponse _featureFlags(RecordedRequest request) {
    if (!persona.permissions.contains('settings.read')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    final method = request.options.method;
    if (method == 'GET') {
      return FakeResponse.ok(featureFlags);
    }
    if (!persona.permissions.contains('settings.update')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    final parts = request.path.split('/');
    if (parts.length >= 3 && method == 'PUT') {
      final key = parts[2];
      final flag = featureFlags.where((f) => f['key'] == key).firstOrNull;
      if (flag == null) return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
      final body = asJsonMap(request.body! as Map);
      flag['on'] = body['on'] == true;
      flag['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      return FakeResponse.ok(flag);
    }
    return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
  }

  FakeResponse _maintenance(RecordedRequest request) {
    if (!persona.permissions.contains('settings.read')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    final method = request.options.method;
    if (method == 'GET') {
      return FakeResponse.ok(maintenance);
    }
    if (!persona.permissions.contains('settings.update')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }
    if (method == 'PUT') {
      final body = asJsonMap(request.body! as Map);
      final scopes = maintenance['scopes']! as Map<String, Object?>;
      if (body['scopes'] != null) {
        final newScopes = body['scopes']! as Map;
        for (final entry in newScopes.entries) {
          scopes['${entry.key}'] = entry.value == true;
        }
      }
      if (body.containsKey('message') && body['message'] != null) {
        maintenance['message'] = body['message'];
      }
      if (body.containsKey('from')) {
        maintenance['from'] = body['from'];
      }
      if (body.containsKey('to')) {
        maintenance['to'] = body['to'];
      }
      if (maintenance['from'] != null && maintenance['to'] != null) {
        final fromStr = '${maintenance['from']}';
        final toStr = '${maintenance['to']}';
        if (toStr.isNotEmpty && fromStr.isNotEmpty && toStr.compareTo(fromStr) <= 0) {
          return FakeResponse.error(400, 'VALIDATION_FAILED', message: 'End must be after start');
        }
      }
      maintenance['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      return FakeResponse.ok(maintenance);
    }
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
    // A query may be part of the path (`.../image?variant=desktop`).
    final address = Uri.parse(request.path);
    final parts = address.path.split('/').skip(1).toList();
    final resource = parts[0];
    final query = <String, Object?>{
      ...request.options.queryParameters,
      ...address.queryParameters,
    };
    final body = request.body == null
        ? <String, Object?>{}
        : asJsonMap(request.body! as Map);

    if (resource == 'messages' &&
        !persona.permissions.contains('messages.read')) {
      return FakeResponse.error(403, 'PERMISSION_DENIED');
    }

    if (resource == 'messages' && parts.length == 1 && method == 'GET') {
      final q = '${query['q'] ?? query['query'] ?? ''}'.trim().toLowerCase();
      final channel = query['channel'];
      final kind = query['kind'];
      final status = query['status'];
      var items =
          of('messages').where((record) {
            if (channel != null &&
                '${record['channel']}'.toUpperCase() !=
                    '$channel'.toUpperCase()) {
              return false;
            }
            if (kind != null && '${record['kind']}' != '$kind') {
              return false;
            }
            if (status != null &&
                '${record['status']}'.toUpperCase() !=
                    '$status'.toUpperCase()) {
              return false;
            }
            if (q.isNotEmpty) {
              final haystack =
                  '${record['toName'] ?? record['recipientName'] ?? record['name'] ?? ''} ${record['address'] ?? ''} ${record['subject'] ?? ''} ${record['kind'] ?? ''} ${record['bookingId'] ?? ''}'
                      .toLowerCase();
              if (!haystack.contains(q)) return false;
            }
            return true;
          }).toList();
      final page = (query['page'] as int?) ?? 1;
      final size = (query['pageSize'] as int?) ?? 15;
      final total = items.length;
      items = items.skip((page - 1) * size).take(size).toList();
      return FakeResponse.ok(
        items,
        meta: <String, Object?>{'page': page, 'pageSize': size, 'total': total},
      );
    }

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
    if (const {'place-requests', 'bus-type-requests'}.contains(resource) &&
        parts[1] == 'pending-count') {
      return FakeResponse.ok(<String, Object?>{
        'pending': of(
          resource,
        ).where((item) => item['status'] == 'PENDING').length,
      });
    }
    final record = _visible(
      resource,
    ).where((item) => item['id'] == parts[1]).firstOrNull;
    if (record == null) return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
    if (parts.length == 2 && method == 'GET') return FakeResponse.ok(record);
    if (parts.length == 2 && method == 'DELETE') {
      of(resource).remove(record);
      return FakeResponse.ok(null);
    }
    if (parts.length == 2 && method == 'PUT') {
      record.addAll(body);
      return FakeResponse.ok(record);
    }
    switch (parts[2]) {
      case 'image':
        // Banner images: `variant` is mobile or desktop.
        final key = query['variant'] == 'desktop'
            ? 'desktopImageUrl'
            : 'imageUrl';
        record[key] = method == 'DELETE'
            ? null
            : '$resource/${record['id']}/image?variant=${query['variant']}';
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
      case 'approve':
        record['status'] = 'APPROVED';
      case 'reject':
        record['status'] = 'REJECTED';
        record['reason'] = body['reason'];
      case 'resend':
        if (!persona.permissions.contains('messages.resend')) {
          return FakeResponse.error(403, 'PERMISSION_DENIED');
        }
        final resent = Map<String, Object?>.from(record);
        resent['id'] =
            '66f0c0ffee0000000000${(_nextId++).toString().padLeft(4, '0')}';
        resent['at'] = DateTime.now().toUtc().toIso8601String();
        resent['status'] = 'SENT';
        resent['attempts'] = ((record['attempts'] as int?) ?? 1) + 1;
        of('messages').insert(0, resent);
        return FakeResponse.ok(resent);
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
      dio: Dio()..httpClientAdapter = _UploadsAccepted(adapter),
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

Future<void> open(WidgetTester tester, String location, {bool settleDown = true}) async {
  containerOf(tester).read(adminRouterProvider).go(location);
  if (settleDown) {
    await settle(tester);
  } else {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }
}

/// Lets file uploads (`multipart/form-data`) through to the fake backend,
/// which reads only JSON bodies: the upload is recorded without its body.
class _UploadsAccepted implements HttpClientAdapter {
  _UploadsAccepted(this._inner);

  final FakeHttpAdapter _inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isUpload = options.contentType?.startsWith('multipart/') ?? false;
    if (isUpload && requestStream != null) {
      await requestStream.drain<void>();
      return _inner.fetch(options, null, cancelFuture);
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
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
