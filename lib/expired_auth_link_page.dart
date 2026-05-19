import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_flow.dart';

class ExpiredAuthLinkPage extends StatefulWidget {
  const ExpiredAuthLinkPage({
    super.key,
    required this.email,
    required this.flow,
    required this.errorMessage,
  });

  final String email;
  final OtpFlow flow;
  final String errorMessage;

  @override
  State<ExpiredAuthLinkPage> createState() => _ExpiredAuthLinkPageState();
}

class _ExpiredAuthLinkPageState extends State<ExpiredAuthLinkPage> {
  final _authApi = AuthApi();
  bool _isSending = false;

  bool get _isActivation => widget.flow == OtpFlow.activation;

  String get _title {
    return _isActivation ? 'Activation link expired' : 'Reset link expired';
  }

  String get _subtitle {
    return _isActivation
        ? 'Your activation link is no longer valid. Send a fresh activation email to continue setting up your account.'
        : 'Your password reset link is no longer valid. Send a fresh reset email to continue.';
  }

  Future<void> _resend() async {
    setState(() => _isSending = true);
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
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF474747),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Link Expired'),
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
                    Icons.mark_email_unread_outlined,
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
                  const SizedBox(height: 24),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _isSending ? null : _resend,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_isSending ? 'Sending...' : 'Resend email'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF1796D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8EDCFF),
                    ),
                    child: const Text('Back to sign in'),
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
