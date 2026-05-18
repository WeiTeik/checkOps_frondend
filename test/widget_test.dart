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
}
