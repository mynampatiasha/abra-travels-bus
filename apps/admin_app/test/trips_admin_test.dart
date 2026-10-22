import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_app_test.dart';
import 'support/test_admin.dart';

void main() {
  testWidgets('AdminTripsPage renders header, filters, and trip table', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
    await app.pump(tester);
    await open(tester, AdminRoutes.trips);

    // Verify header and subtitle
    expect(find.text('Trips'), findsWidgets);
    expect(
      find.text(
        'Every trip. Operators publish their own; here you can step in when something goes wrong.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add trip for operator'), findsOneWidget);

    // Verify filter bar
    expect(find.text('Operator'), findsOneWidget);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Export'), findsOneWidget);

    // Verify table headers
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Route'), findsWidgets);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Departs'), findsOneWidget);
    expect(find.text('Seats'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);

    // Verify seeded trips are visible
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Scheduled'), findsWidgets);
  });
}
