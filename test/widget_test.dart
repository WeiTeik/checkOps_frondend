import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checkops_frondend/authentication/auth_flow.dart';
import 'package:checkops_frondend/authentication/login_page.dart';
import 'package:checkops_frondend/authentication/otp_email_verification.dart';
import 'package:checkops_frondend/authentication/reset_password.dart';

void main() {
  Future<void> pumpLoginPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
  }

  Future<void> pumpOtpPage(WidgetTester tester, {String? initialOtp}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OtpEmailVerificationPage(
          email: 'test@example.com',
          token: 'token',
          flow: OtpFlow.passwordReset,
          initialOtp: initialOtp,
        ),
      ),
    );
  }

  testWidgets('Login page shows required controls', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forget password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Forget password button opens reset screen', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.text('Forget password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forget Password'), findsOneWidget);
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);
  });

  testWidgets('Reset password opens OTP email verification screen', (
    WidgetTester tester,
  ) async {
    await pumpOtpPage(tester);

    expect(find.text('OTP Email Verification'), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.byType(EditableText), findsNWidgets(6));
    expect(find.text("Didn't receive? "), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('Resend code button is clickable', (WidgetTester tester) async {
    await pumpOtpPage(tester);
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('OTP verify opens reset password screen', (
    WidgetTester tester,
  ) async {
    await pumpOtpPage(tester, initialOtp: '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsNWidgets(3));
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Capital/uppercase letter'), findsOneWidget);
    expect(find.text('Punctuation mark'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('Not a common/simple password'), findsOneWidget);
    expect(find.text('Passwords match'), findsOneWidget);
  });

  testWidgets('Set password mode uses first login title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordPage(
          email: 'test@example.com',
          otp: '123456',
          token: 'token',
          mode: PasswordScreenMode.set,
        ),
      ),
    );

    expect(find.text('Set Password'), findsNWidgets(3));
    expect(
      find.text('Create a secure password for your first login.'),
      findsOneWidget,
    );
  });

  testWidgets('Simple password is blocked by requirements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordPage(
          email: 'test@example.com',
          otp: '123456',
          token: 'token',
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText).at(0), 'Password1!');
    await tester.enterText(find.byType(EditableText).at(1), 'Password1!');
    await tester.pump();

    expect(find.text('Not a common/simple password'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'password');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    final resetButton = find.widgetWithText(FilledButton, 'Reset Password');
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pump();

    expect(find.text('Please meet all password requirements'), findsOneWidget);
  });
}
