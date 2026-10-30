import 'package:dio/dio.dart';
import 'package:driver_app/app/providers.dart';
import 'package:driver_app/features/bus_documents/driver_bus_documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';

Map<String, Object?> _doc({String status = 'EXPIRING', int daysLeft = 9}) => <String, Object?>{
  'id': 'd-1',
  'docName': 'Fitness certificate',
  'validTill': '2026-11-12',
  'daysLeft': daysLeft,
  'status': status,
  'remindDaysBefore': <Object?>[],
  'files': <Object?>[
    <String, Object?>{'id': 'f-1', 'originalName': 'fitness.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 4096},
  ],
};

/// A signed-in driver: the client sends this token with every request.
class _SignedIn implements AuthTokenSource {
  @override
  Future<String?> accessToken() async => 'access-token';

  @override
  Future<bool> refreshAccessToken() async => false;

  @override
  Future<void> onSessionRejected() async {}
}

/// The request path without its leading slash.
String _pathOf(RecordedRequest request) => request.path.replaceFirst(RegExp(r'^/'), '');

Future<(FakeHttpAdapter, Widget)> _screen(
  Future<FakeResponse> Function(RecordedRequest request) handler,
  Widget home,
) async {
  final adapter = FakeHttpAdapter(handler);
  final client = ApiClient(
    config: AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.driver,
      apiBaseUrl: Uri.parse('http://localhost:4000'),
      clientType: ClientType.mobile,
    ),
    dio: Dio()..httpClientAdapter = adapter,
    logger: DeveloperLogger(),
  )..attachTokenSource(_SignedIn());
  return (
    adapter,
    ProviderScope(
      overrides: [driverApiClientProvider.overrideWithValue(client)],
      child: MaterialApp(home: home),
    ),
  );
}

void main() {
  group('driver bus documents', () {
    testWidgets('lists the buses the driver runs, with what needs attention', (tester) async {
      final (adapter, app) = await _screen((request) async {
        if (_pathOf(request) == 'driver/buses') {
          return FakeResponse.ok(<Object?>[
            <String, Object?>{
              'id': 'b-1',
              'registrationNumber': 'KA01AB1234',
              'name': 'Vikram Travels',
              'documentsExpiring': 2,
              'documentsExpired': 0,
            },
            <String, Object?>{
              'id': 'b-2',
              'registrationNumber': 'KA05CD5678',
              'name': 'Night Rider',
              'documentsExpiring': 0,
              'documentsExpired': 1,
            },
          ]);
        }
        return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
      }, const DriverBusesScreen());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('My buses'), findsOneWidget);
      expect(find.text('KA01AB1234'), findsOneWidget);
      expect(find.textContaining('2 documents expiring soon'), findsOneWidget);
      expect(find.textContaining('1 document expired'), findsOneWidget);
      expect(adapter.requests.map(_pathOf), contains('driver/buses'));
    });

    testWidgets('says plainly when the driver has no bus yet', (tester) async {
      final (_, app) = await _screen((request) async => FakeResponse.ok(<Object?>[]), const DriverBusesScreen());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('No bus yet'), findsOneWidget);
    });

    testWidgets('shows a retry when the buses cannot be loaded', (tester) async {
      final (_, app) = await _screen(
        (request) async => FakeResponse.error(500, 'INTERNAL_ERROR'),
        const DriverBusesScreen(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Unable to load your buses'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('opens the documents of a bus, with their dates and files to view or download', (tester) async {
      final (adapter, app) = await _screen((request) async {
        if (_pathOf(request) == 'driver/buses') {
          return FakeResponse.ok(<Object?>[
            <String, Object?>{
              'id': 'b-1',
              'registrationNumber': 'KA01AB1234',
              'name': 'Vikram Travels',
              'documentsExpiring': 1,
              'documentsExpired': 0,
            },
          ]);
        }
        if (_pathOf(request) == 'driver/buses/b-1/documents') {
          return FakeResponse.ok(<Object?>[_doc(), _doc(status: 'EXPIRED', daysLeft: -2)..['id'] = 'd-2']);
        }
        return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
      }, const DriverBusesScreen());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('KA01AB1234'));
      await tester.pumpAndSettle();

      expect(find.text('Fitness certificate'), findsNWidgets(2));
      expect(find.text('Expires in 9 days (2026-11-12)'), findsOneWidget);
      expect(find.text('Expired on 2026-11-12'), findsOneWidget);
      expect(find.text('fitness.pdf (4 KB)'), findsNWidgets(2));
      expect(find.byTooltip('View'), findsNWidgets(2));
      expect(find.byTooltip('Download'), findsNWidgets(2));
      // The driver only reads: nothing to rename, upload or delete
      expect(find.text('Delete document'), findsNothing);
      expect(find.text('Upload'), findsNothing);
      expect(adapter.requests.map((r) => r.method).toSet(), {'GET'});
    });
  });
}
