// lib/features/screens/forgot_password_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../services/auth_api_service.dart';
import '../super_admin/widgets/sa_widgets.dart';

/// Forgot password: phone -> OTP -> new password -> back to login.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _otpSent = false;
  String? _error;
  String? _info;
  String? _devCode;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_phone.text.trim().length < 6) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await AuthApiService.forgotRequestOtp(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _otpSent = true; // always advance (uniform response, no account enumeration)
      _devCode = r.data?['dev_code']?.toString();
      _info = 'If that number has an account, a code was sent.';
    });
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    if (_otp.text.trim().isEmpty) {
      setState(() => _error = 'Enter the OTP');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() => _busy = true);
    final r = await AuthApiService.resetPassword(_phone.text, _otp.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Please log in.'),
          backgroundColor: AppTheme.greenPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(AppConstants.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.greenPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.loginRoute),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SaGradientHeader(
                    title: 'Reset password',
                    subtitle: 'Verify your phone, then set a new password.',
                    icon: Icons.lock_reset_outlined,
                  ),
                  const SizedBox(height: Sa.gapLg),
                  SaCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _phone,
                          enabled: !_otpSent,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                          ],
                          decoration: _decoration(
                            label: 'Phone number',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        if (!_otpSent) ...[
                          const SizedBox(height: Sa.gapLg),
                          SaPrimaryButton(
                            label: 'Send OTP',
                            icon: Icons.sms_outlined,
                            busy: _busy,
                            expand: true,
                            onPressed: _busy ? null : _sendOtp,
                          ),
                        ] else ...[
                          const SizedBox(height: Sa.gap),
                          TextField(
                            controller: _otp,
                            keyboardType: TextInputType.number,
                            decoration: _decoration(
                              label: 'OTP',
                              icon: Icons.sms_outlined,
                              helperText: (kDebugMode && _devCode != null)
                                  ? 'Dev code: $_devCode'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: Sa.gap),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            decoration: _decoration(
                              label: 'New password',
                              icon: Icons.lock_outline,
                            ),
                          ),
                          const SizedBox(height: Sa.gapLg),
                          SaPrimaryButton(
                            label: 'Reset password',
                            icon: Icons.check_rounded,
                            busy: _busy,
                            expand: true,
                            onPressed: _busy ? null : _reset,
                          ),
                          const SizedBox(height: Sa.gapXs),
                          TextButton(
                            onPressed: _busy ? null : _sendOtp,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.greenPrimary,
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text('Resend code'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _otpSent = false;
                                      _otp.clear();
                                      _error = null;
                                      _info = null;
                                      _devCode = null;
                                    }),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.neutral600,
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text('Change number'),
                          ),
                        ],
                        if (_info != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Sa.gap),
                            child: Text(_info!, style: Sa.label),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Sa.gapXs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 16, color: AppTheme.error),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: Sa.body.copyWith(color: AppTheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon, color: AppTheme.neutral500),
      filled: true,
      fillColor: AppTheme.neutral50,
      labelStyle: Sa.label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
        borderSide: const BorderSide(color: Sa.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
        borderSide: const BorderSide(color: Sa.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
        borderSide: const BorderSide(color: AppTheme.greenPrimary, width: 1.5),
      ),
    );
  }
}
