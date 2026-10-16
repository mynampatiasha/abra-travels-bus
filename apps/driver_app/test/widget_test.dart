import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/app/driver_app.dart';

void main() {
  testWidgets('DriverApp basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DriverApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DriverApp), findsOneWidget);
  });
}
