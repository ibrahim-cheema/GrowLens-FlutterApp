// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:growlens/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GrowLensApp());

    // Verify that the app starts and shows the Login title or button
    expect(find.text('Sign In'), findsOneWidget);
  });
}
