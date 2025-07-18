import 'package:flutter_test/flutter_test.dart';
import 'package:studywithcharles/main.dart';

void main() {
  testWidgets('App starts and shows WelcomeScreen title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StudyWithCharlesApp());

    // Verify that our welcome text appears.
    expect(find.text('Study With Charles'), findsOneWidget);

    // Verify both buttons are present.
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
