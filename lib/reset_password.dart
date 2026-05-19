import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_flow.dart';
import 'expired_auth_link_page.dart';

enum PasswordScreenMode { reset, set }

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.otp,
    required this.token,
    this.mode = PasswordScreenMode.reset,
  });

  final String email;
  final String otp;
  final String token;
  final PasswordScreenMode mode;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const _badPasswords = {
    '123456',
    '12345678',
    '123456789',
    '111111',
    '000000',
    'password',
    'password1',
    'password1!',
    'qwerty',
    'qwerty123',
    'abc123',
    'admin',
    'admin123',
    'letmein',
    'welcome',
    'iloveyou',
    'checkops',
    'checkops123',
  };

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authApi = AuthApi();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String get _title {
    return widget.mode == PasswordScreenMode.set
        ? 'Set Password'
        : 'Reset Password';
  }

  String get _subtitle {
    return widget.mode == PasswordScreenMode.set
        ? 'Create a secure password for your first login.'
        : 'Create a new secure password for your account.';
  }

  String get _password => _passwordController.text;

  bool get _hasUppercase => RegExp('[A-Z]').hasMatch(_password);

  bool get _hasNumber => RegExp('[0-9]').hasMatch(_password);

  bool get _hasPunctuation {
    return RegExp(
      r'''[!@#$%^&*(),.?":{}|<>_\-+=;'/\\[\]`~]''',
    ).hasMatch(_password);
  }

  bool get _hasEightCharacters => _password.length >= 8;

  bool get _isNotCommonPassword {
    return _password.isNotEmpty &&
        !_badPasswords.contains(_password.toLowerCase());
  }

  bool get _passwordsMatch {
    return _confirmPasswordController.text.isNotEmpty &&
        _password == _confirmPasswordController.text;
  }

  bool get _canSubmit {
    return _hasUppercase &&
        _hasNumber &&
        _hasPunctuation &&
        _hasEightCharacters &&
        _isNotCommonPassword &&
        _passwordsMatch;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please meet all password requirements')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final message = widget.mode == PasswordScreenMode.set
          ? await _authApi.setPasswordFromActivation(
              email: widget.email,
              otp: widget.otp,
              token: widget.token,
              password: _password,
            )
          : await _authApi.resetPassword(
              email: widget.email,
              otp: widget.otp,
              token: widget.token,
              password: _password,
            );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (_isExpiredLinkError(error.message)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ExpiredAuthLinkPage(
              email: widget.email,
              flow: widget.mode == PasswordScreenMode.set
                  ? OtpFlow.activation
                  : OtpFlow.passwordReset,
              errorMessage: error.message,
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isExpiredLinkError(String message) {
    return message.toLowerCase().contains('expired');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF474747),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_title),
      ),
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
                  const Icon(
                    Icons.password_outlined,
                    color: Color(0xFF8EDCFF),
                    size: 72,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                      ),
                      suffixIcon: IconButton(
                        color: Colors.white,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: Colors.white),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                      ),
                      suffixIcon: IconButton(
                        color: Colors.white,
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PasswordRequirement(
                    text: 'Capital/uppercase letter',
                    isMet: _hasUppercase,
                  ),
                  _PasswordRequirement(
                    text: 'Punctuation mark',
                    isMet: _hasPunctuation,
                  ),
                  _PasswordRequirement(text: 'Number', isMet: _hasNumber),
                  _PasswordRequirement(
                    text: 'At least 8 characters',
                    isMet: _hasEightCharacters,
                  ),
                  _PasswordRequirement(
                    text: 'Not a common/simple password',
                    isMet: _isNotCommonPassword,
                  ),
                  _PasswordRequirement(
                    text: 'Passwords match',
                    isMet: _passwordsMatch,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submitPassword,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF1796D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'Saving...' : _title,
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

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.text, required this.isMet});

  final String text;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? const Color(0xFF8EECA8) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
