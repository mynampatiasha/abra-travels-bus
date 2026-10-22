import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_app.dart';

GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
).read(customerRouterProvider);

void main() {
  testWidgets('Messages archive renders empty state when no messages', (
    tester,
  ) async {
    final app = TestApp(
      stored: storedSession,
      handler: (req) async {
        if (req.path == 'me') return currentUserResponse;
        if (req.path.contains('customer/messages')) {
          return FakeResponse.ok(<String, Object?>{
            'items': <Object?>[],
            'page': 1,
            'pageSize': 50,
            'total': 0,
          });
        }
        return const FakeResponse(404, <String, Object?>{'message': 'Not found'});
      },
    );
    await app.pump(tester);
    routerOf(tester).go('/profile/messages');
    await tester.pumpAndSettle();

    expect(find.text('Messages sent to me'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('Messages archive renders message items from API', (
    tester,
  ) async {
    final app = TestApp(
      stored: storedSession,
      handler: (req) async {
        if (req.path == 'me') return currentUserResponse;
        if (req.path.contains('customer/messages')) {
          return FakeResponse.ok(<String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'at': '2026-10-21T10:00:00.000Z',
                'channel': 'WHATSAPP',
                'kind': 'BOOKING_CONFIRMED',
                'subject': 'Your booking is confirmed',
                'body': 'Bus departs at 21:00 from Hyderabad.',
                'address': '+919876543210',
                'bookingId': 'bk-123',
              },
            ],
            'page': 1,
            'pageSize': 50,
            'total': 1,
          });
        }
        return const FakeResponse(404, <String, Object?>{'message': 'Not found'});
      },
    );
    await app.pump(tester);
    routerOf(tester).go('/profile/messages');
    await tester.pumpAndSettle();

    expect(find.text('Your booking is confirmed'), findsOneWidget);
    expect(find.text('Bus departs at 21:00 from Hyderabad.'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });
}

