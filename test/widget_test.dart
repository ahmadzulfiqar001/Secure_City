import 'package:flutter_test/flutter_test.dart';

import 'package:securecity/main.dart';

void main() {
  testWidgets('SecureCity app boots to the splash screen then onboarding',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SecureCityApp());

    expect(find.text('SECURE'), findsOneWidget);
    expect(find.text('CITY'), findsOneWidget);

    // Let the splash sequence finish and navigate away so no timers/animations
    // are left pending when the test ends.
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pumpAndSettle();

    expect(find.text('AI Surveillance'), findsOneWidget);
  });
}
