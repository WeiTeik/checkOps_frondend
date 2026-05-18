import 'package:flutter_test/flutter_test.dart';

import 'package:checkops_frondend/main.dart';

void main() {
  testWidgets('Login page shows required controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forget password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Forget password button opens reset screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Forget password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forget Password'), findsOneWidget);
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);
  });
}
