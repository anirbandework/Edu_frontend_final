// lib/features/screens/forgot_password_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../services/auth_api_service.dart';

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
        const SnackBar(content: Text('Password updated. Please log in.')),
      );
      context.go(AppConstants.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = AppTheme.greenPrimary;
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: green,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(AppConstants.loginRoute)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 44, color: green),
                    const SizedBox(height: 8),
                    Text('Reset password',
                        textAlign: TextAlign.center, style: AppTheme.headingSmall.copyWith(color: green)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _phone,
                      enabled: !_otpSent,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                      decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                    ),
                    if (!_otpSent) ...[
                      const SizedBox(height: 16),
                      _btn('Send OTP', _busy ? null : _sendOtp),
                    ] else ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'OTP',
                          prefixIcon: const Icon(Icons.sms_outlined),
                          helperText: (kDebugMode && _devCode != null) ? 'Dev code: $_devCode' : null,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _btn('Reset password', _busy ? null : _reset),
                      TextButton(onPressed: _busy ? null : _sendOtp, child: const Text('Resend code')),
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
                        child: const Text('Change number'),
                      ),
                    ],
                    if (_info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_info!, style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600))),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: AppTheme.error))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback? onTap) => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.greenPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: AppTheme.bodyMedium.copyWith(color: Colors.white)),
        ),
      );
}
