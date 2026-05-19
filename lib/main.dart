import 'package:flutter/material.dart';

import 'app_config.dart';
import 'authentication/auth_api.dart';
import 'authentication/auth_flow.dart';
import 'authentication/deep_link_service.dart';
import 'authentication/expired_auth_link_page.dart';
import 'authentication/login_page.dart';
import 'authentication/otp_email_verification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
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
      home: const LoginPage(),
    );
  }
}
