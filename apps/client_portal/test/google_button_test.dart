import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';

void main() {
  Future<void> showButton(
    WidgetTester tester,
    GoogleSignInButton button,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: button)));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'successful Google popup passes only its ID token to the session exchange',
    (tester) async {
      String? exchanged;
      await showButton(
        tester,
        GoogleSignInButton(
          obtainIdToken: () async => 'verified-by-backend-token',
          exchange: (token, _) async => exchanged = token,
        ),
      );
      expect(exchanged, 'verified-by-backend-token');
    },
  );
  testWidgets('cancelled Google popup never exchanges a token', (tester) async {
    var exchanges = 0;
    await showButton(
      tester,
      GoogleSignInButton(
        obtainIdToken: () async => null,
        exchange: (_, _) async {
          exchanges++;
        },
      ),
    );
    expect(exchanges, 0);
    expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
  });
  testWidgets('blocked popup gives a useful error and can be retried', (
    tester,
  ) async {
    await showButton(
      tester,
      GoogleSignInButton(
        obtainIdToken: () async =>
            throw FirebaseAuthException(code: 'popup-blocked'),
        exchange: (_, _) async {},
      ),
    );
    expect(
      find.text('Allow pop-ups for this site and try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byWidgetPredicate((widget) => widget is OutlinedButton),
          )
          .onPressed,
      isNotNull,
    );
  });
}
