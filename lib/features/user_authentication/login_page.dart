import 'package:flutter/material.dart';

import '../dashboard_reporting/home_page.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'forget_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, AuthSessionManager? sessionManager})
    : _sessionManager = sessionManager;

  final AuthSessionManager? _sessionManager;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authApi = AuthApi();
  late final AuthSessionManager _sessionManager =
      widget._sessionManager ?? AuthSessionManager(authApi: _authApi);
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authApi.login(email: email, password: password);
      final session = AuthSession.fromLoginResponse(response);
      if (session == null) {
        throw AuthApiException(
          'Login response did not include a valid session.',
        );
      }

      await _sessionManager.saveAfterLogin(
        session: session,
        rememberMe: _rememberMe,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomePage(
            role: session.role,
            displayName: session.displayName,
            email: session.email,
            employeeId: session.employeeId,
            userId: session.userId,
            accessToken: session.accessToken,
            profilePic: session.profilePic,
            onLogout: _sessionManager.logout,
            loginBuilder: (context) =>
                LoginPage(sessionManager: _sessionManager),
            onProfileUpdated: _sessionManager.updateCachedProfile,
          ),
        ),
      );
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CheckOpsLogo(),
                  const SizedBox(height: 0),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: Colors.white,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.white),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              checkColor: const Color(0xFF474747),
                              fillColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.transparent;
                              }),
                              side: const BorderSide(color: Colors.white),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Remember me',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ForgetPasswordPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8EDCFF),
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Forget password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF1796D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'Signing in...' : 'Sign in',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckOpsLogo extends StatelessWidget {
  const CheckOpsLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/checkops_logo.png',
      height: 245,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: Color(0xFF1796D2),
            ),
            children: [
              TextSpan(text: 'Check'),
              TextSpan(
                text: 'Ops',
                style: TextStyle(color: Color(0xFF42B81E)),
              ),
            ],
          ),
        );
      },
    );
  }
}
