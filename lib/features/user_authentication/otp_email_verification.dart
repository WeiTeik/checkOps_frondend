import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_api.dart';
import 'auth_flow.dart';
import 'reset_password.dart';

class OtpEmailVerificationPage extends StatefulWidget {
  const OtpEmailVerificationPage({
    super.key,
    required this.email,
    required this.token,
    required this.flow,
    this.initialOtp,
  });

  final String email;
  final String token;
  final OtpFlow flow;
  final String? initialOtp;

  @override
  State<OtpEmailVerificationPage> createState() =>
      _OtpEmailVerificationPageState();
}

class _OtpEmailVerificationPageState extends State<OtpEmailVerificationPage> {
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _authApi = AuthApi();

  bool _isResending = false;

  bool get _isActivation => widget.flow == OtpFlow.activation;

  String get _otp =>
      _otpControllers.map((controller) => controller.text).join();

  String get _title =>
      _isActivation ? 'Activate your account' : 'Verify your email';

  String get _subtitle {
    return _isActivation
        ? 'Enter the 6 digit code from your activation email.'
        : 'Enter the 6 digit code sent to your email.';
  }

  @override
  void initState() {
    super.initState();
    final otp = widget.initialOtp ?? '';
    if (otp.length == 6) {
      for (var index = 0; index < 6; index++) {
        _otpControllers[index].text = otp[index];
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      final message = _isActivation
          ? await _authApi.resendActivation(widget.email)
          : await _authApi.resendPasswordReset(widget.email);
      if (!mounted) {
        return;
      }
      _showMessage('$message Open the newest email link to continue.');
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _verifyOtp() {
    if (_otp.length != 6) {
      _showMessage('Enter the 6 digit OTP.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResetPasswordPage(
          email: widget.email,
          otp: _otp,
          token: widget.token,
          mode: _isActivation
              ? PasswordScreenMode.set
              : PasswordScreenMode.reset,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF474747),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('OTP Email Verification'),
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
                    Icons.mark_email_read_outlined,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (index) => _OtpInputBox(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        onChanged: (value) {
                          if (value.length == 6) {
                            for (var otpIndex = 0; otpIndex < 6; otpIndex++) {
                              _otpControllers[otpIndex].text = value[otpIndex];
                            }
                            _otpFocusNodes[5].requestFocus();
                            return;
                          }
                          if (value.isNotEmpty && index < 5) {
                            _otpFocusNodes[index + 1].requestFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            _otpFocusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive? ",
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: _isResending ? null : _resendCode,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8EDCFF),
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend code',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _verifyOtp,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF1796D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Verify',
                      style: TextStyle(
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

class _OtpInputBox extends StatelessWidget {
  const _OtpInputBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        maxLength: 6,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: Colors.white,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white70),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
