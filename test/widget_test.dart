// Widget tests for SensioScanner.
// Phase 0: Smoke test verifying the app widget tree builds without errors.

import 'package:flutter_test/flutter_test.dart';

import 'package:sensioscanner/main.dart';

void main() {
  testWidgets('SensioScannerApp smoke test — app builds without throwing',
      (WidgetTester tester) async {
    // We pump with a short duration; GoRouter + GetIt need to be initialised
    // before the widget renders. Full integration tests will be added in later phases.
    await tester.pumpWidget(const SensioScannerApp());
    // If no exception is thrown the scaffold is wired correctly.
    expect(tester.takeException(), isNull);
  });
}
