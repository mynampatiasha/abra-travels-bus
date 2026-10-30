import 'package:customer_app/features/profile/profile_repository.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_app.dart';

Map<String, Object?> all(bool value) => <String, Object?>{
  'whatsapp': value,
  'email': value,
  'push': value,
};

FakeResponse settings({bool bookingsWhatsApp = true}) => FakeResponse.ok(<String, Object?>{
  'bookings': <String, Object?>{'whatsapp': bookingsWhatsApp, 'email': true, 'push': true},
  'trips': all(true),
  'offers': all(false),
});

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

Future<TestApp> openAt(
  WidgetTester tester,
  String location,
  Future<FakeResponse> Function(RecordedRequest request) handler, {
  bool signedIn = true,
}) async {
  final app = TestApp(
    stored: signedIn ? storedSession : const <String, String>{},
    handler: handler,
  );
  await app.pump(tester, size: const Size(400, 1800));
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).go(location);
  await settle(tester);
  return app;
}

SwitchListTile switchOf(WidgetTester tester, String topicTitle, String label) {
  final card = find.ancestor(of: find.text(topicTitle), matching: find.byType(AbraCard)).first;
  final tile = find.descendant(of: card, matching: find.widgetWithText(SwitchListTile, label));
  return tester.widget<SwitchListTile>(tile.first);
}

void main() {
  test('the settings are read as a choice for each channel', () {
    final choices = ChannelChoices.fromJson(<String, Object?>{
      'whatsapp': false,
      'email': true,
      'push': true,
    });
    expect(choices.whatsapp, isFalse);
    expect(choices.copyWith(whatsapp: true).whatsapp, isTrue);
    expect(choices.toJson(), <String, Object?>{'whatsapp': false, 'email': true, 'push': true});
  });

  group('Notification settings', () {
    testWidgets('show what the server holds, offers off, and say safety is always on', (tester) async {
      await openAt(tester, '/profile/notifications', (request) async {
        if (request.path == 'customer/notification-settings') return settings(bookingsWhatsApp: false);
        return currentUserResponse;
      });

      expect(find.text('Bookings and refunds'), findsOneWidget);
      expect(find.text('Trip updates'), findsOneWidget);
      expect(find.text('Offers and promotions'), findsOneWidget);
      expect(switchOf(tester, 'Bookings and refunds', 'WhatsApp').value, isFalse);
      expect(switchOf(tester, 'Bookings and refunds', 'Email').value, isTrue);
      expect(switchOf(tester, 'Offers and promotions', 'Email').value, isFalse);
      expect(find.textContaining('Safety alerts are always on'), findsOneWidget);
    });

    testWidgets('a switch is saved at once with the whole set', (tester) async {
      late RecordedRequest saved;
      await openAt(tester, '/profile/notifications', (request) async {
        if (request.path == 'customer/notification-settings' && request.method == 'PUT') {
          saved = request;
          return settings(bookingsWhatsApp: false);
        }
        if (request.path == 'customer/notification-settings') return settings();
        return currentUserResponse;
      });

      await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('Bookings and refunds'), matching: find.byType(AbraCard)).first,
        matching: find.widgetWithText(SwitchListTile, 'WhatsApp'),
      ).first);
      await settle(tester);

      final body = saved.body! as Map;
      expect((body['bookings'] as Map)['whatsapp'], isFalse);
      expect((body['bookings'] as Map)['email'], isTrue);
      expect(body.keys, containsAll(<String>['bookings', 'trips', 'offers']));
      expect(switchOf(tester, 'Bookings and refunds', 'WhatsApp').value, isFalse);
    });

    testWidgets('when the server cannot be reached the switch goes back and says so', (tester) async {
      await openAt(tester, '/profile/notifications', (request) async {
        if (request.path == 'customer/notification-settings' && request.method == 'PUT') {
          return FakeResponse.error(422, 'VALIDATION_FAILED', message: 'Could not save.');
        }
        if (request.path == 'customer/notification-settings') return settings();
        return currentUserResponse;
      });

      await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('Offers and promotions'), matching: find.byType(AbraCard)).first,
        matching: find.widgetWithText(SwitchListTile, 'Email'),
      ).first);
      await settle(tester);

      expect(switchOf(tester, 'Offers and promotions', 'Email').value, isFalse);
      expect(find.text('Could not save.'), findsOneWidget);
    });
  });

  group('Language', () {
    testWidgets('a signed-in customer’s choice is also saved on the account', (tester) async {
      late RecordedRequest saved;
      await openAt(tester, '/language', (request) async {
        if (request.path == 'customer/profile' && request.method == 'PATCH') {
          saved = request;
          return FakeResponse.ok(<String, Object?>{'name': 'Asha', 'phone': '+91', 'language': 'hi'});
        }
        return currentUserResponse;
      });

      await tester.tap(find.text('हिन्दी'));
      await settle(tester);

      expect(saved.body, <String, Object?>{'language': 'hi'});
    });

    testWidgets('a guest’s choice stays on the phone and nothing is sent', (tester) async {
      final app = await openAt(
        tester,
        '/language',
        (_) async => currentUserResponse,
        signedIn: false,
      );

      await tester.tap(find.text('हिन्दी'));
      await settle(tester);

      expect(app.adapter.requests.where((r) => r.path == 'customer/profile'), isEmpty);
    });
  });
}
