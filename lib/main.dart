import 'package:flutter/material.dart';

import 'app_config.dart';
import 'authentication/auth_api.dart';
import 'authentication/auth_flow.dart';
import 'authentication/auth_session.dart';
import 'authentication/deep_link_service.dart';
import 'authentication/expired_auth_link_page.dart';
import 'authentication/login_page.dart';
import 'authentication/otp_email_verification.dart';
import 'general/home_page.dart';
import 'general/notifications/local_notification_service.dart';
import 'general/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  try {
    await LocalNotificationService.instance.initialize();
    await PushNotificationService.instance.initialize();
  } on Object {
    // Notification setup must not prevent the app from starting.
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _authApi = AuthApi();
  late final AuthSessionManager _sessionManager = AuthSessionManager(
    authApi: _authApi,
  );

  @override
  void initState() {
    super.initState();
    _listenForDeepLinks();
  }

  void _listenForDeepLinks() {
    DeepLinkService.initialAuthLink().then((link) {
      if (link != null) {
        _openAuthLink(link);
      }
    });

    DeepLinkService.authLinks().listen(_openAuthLink);
  }

  Future<void> _openAuthLink(AuthDeepLink link) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(navigator.context);

    try {
      await _authApi.validateLink(
        email: link.email,
        token: link.token,
        type: link.flow,
      );
      navigator.push(
        MaterialPageRoute(
          builder: (context) => OtpEmailVerificationPage(
            email: link.email,
            token: link.token,
            initialOtp: link.otp,
            flow: link.isActivation
                ? OtpFlow.activation
                : OtpFlow.passwordReset,
          ),
        ),
      );
    } on AuthApiException catch (error) {
      if (_isExpiredLinkError(error.message)) {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ExpiredAuthLinkPage(
              email: link.email,
              flow: link.isActivation
                  ? OtpFlow.activation
                  : OtpFlow.passwordReset,
              errorMessage: error.message,
            ),
          ),
        );
        return;
      }

      messenger?.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  bool _isExpiredLinkError(String message) {
    return message.toLowerCase().contains('expired');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CheckOps',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1998D4)),
        scaffoldBackgroundColor: const Color(0xFF474747),
        useMaterial3: true,
      ),
      home: _AuthGate(sessionManager: _sessionManager),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.sessionManager});

  final AuthSessionManager sessionManager;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<AuthSession?> _restoreSession = widget.sessionManager
      .restore();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: _restoreSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF8EDCFF)),
            ),
          );
        }

        final session = snapshot.data;
        if (session != null) {
          return HomePage(
            role: session.role,
            displayName: session.displayName,
            email: session.email,
            employeeId: session.employeeId,
            userId: session.userId,
            accessToken: session.accessToken,
            profilePic: session.profilePic,
            onLogout: widget.sessionManager.logout,
            loginBuilder: (context) =>
                LoginPage(sessionManager: widget.sessionManager),
            onProfileUpdated: widget.sessionManager.updateCachedProfile,
          );
        }

        return LoginPage(sessionManager: widget.sessionManager);
      },
    );
  }
}
