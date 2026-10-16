import 'package:admin_app/features/operations/admin_trips_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdminTripsPage renders header, filters, and trip table', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdminTripsPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

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

    // Verify trip ID from mock store is visible
    expect(find.text('TRP-3001'), findsOneWidget);
    expect(find.text('Hyderabad to Bengaluru'), findsOneWidget);
  });
}
