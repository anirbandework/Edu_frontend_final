// lib/features/screens/signup_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/auth_session.dart';
import '../../services/auth_api_service.dart';
import '../super_admin/widgets/sa_widgets.dart';

/// First-time "Set your password" screen. There is NO invite/link: an admin creates the
/// user (password-less), and the user activates here — enter phone → OTP → set password.
/// Returning users use the Login screen instead.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _otpSent = false;
  String? _error;
  String? _devCode;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_phone.text.trim().length < 6) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    final wasAlreadySent = _otpSent;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await AuthApiService.signupRequestOtp(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _otpSent = true;
        _devCode = r.data?['dev_code']?.toString();
        // Dev mode has no SMS gateway — prefill the code so signup is testable.
        if (_devCode != null && _devCode!.isNotEmpty) _otp.text = _devCode!;
      } else {
        _error = r.error;
      }
    });
    if (r.ok && wasAlreadySent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code was sent'),
          backgroundColor: AppTheme.greenPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startResendCountdown();
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _createAccount() async {
    setState(() => _error = null);
    if (_otp.text.trim().isEmpty) {
      setState(() => _error = 'Enter the OTP');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() => _busy = true);
    final r = await AuthApiService.signupVerify(
      phone: _phone.text,
      otp: _otp.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    // auto-logged in — land where this role belongs (permission-driven, like login).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account ready. Welcome!'),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go(AuthSession.instance.landingRoute());
  }

  // ---- Green/white themed input decoration (Sa palette) -------------------
  InputDecoration _dec(String label, IconData icon, {String? helperText}) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: Sa.label,
      helperText: helperText,
      helperStyle: Sa.label.copyWith(color: AppTheme.greenPrimary),
      prefixIcon: Icon(icon, color: AppTheme.neutral500, size: 20),
      filled: true,
      fillColor: AppTheme.neutral50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(Sa.stroke, 1),
      focusedBorder: border(AppTheme.greenPrimary, 1.5),
      disabledBorder: border(Sa.stroke.withValues(alpha: 0.6), 1),
      errorBorder: border(AppTheme.error, 1),
      focusedErrorBorder: border(AppTheme.error, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.greenPrimary.withValues(alpha: 0.12),
              borderRadius: AppTheme.borderRadius16,
            ),
            child: const Icon(Icons.how_to_reg_rounded,
                size: 30, color: AppTheme.greenPrimary),
          ),
        ),
        const SizedBox(height: Sa.gap),
        Text(
          'Set your password',
          textAlign: TextAlign.center,
          style: Sa.cardTitle.copyWith(fontSize: 18, color: AppTheme.greenPrimary),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'First time? Use the phone number your admin registered.',
            textAlign: TextAlign.center,
            style: Sa.body,
          ),
        ),
        const SizedBox(height: Sa.gapLg + 4),
        TextField(
          controller: _phone,
          enabled: !_otpSent,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          style: Sa.value,
          decoration: _dec('Phone number', Icons.phone_outlined),
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
          const SizedBox(height: Sa.gapLg),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            style: Sa.value,
            decoration: _dec(
              'OTP',
              Icons.sms_outlined,
              helperText: _devCode != null
                  ? 'Test OTP (no SMS gateway yet): $_devCode'
                  : 'Enter the 6-digit code sent to your phone',
            ),
          ),
          const SizedBox(height: Sa.gapLg),
          TextField(
            controller: _password,
            obscureText: true,
            style: Sa.value,
            decoration: _dec('New password', Icons.lock_outline_rounded),
          ),
          const SizedBox(height: Sa.gapLg),
          TextField(
            controller: _confirm,
            obscureText: true,
            style: Sa.value,
            decoration: _dec('Confirm password', Icons.lock_outline_rounded),
          ),
          const SizedBox(height: Sa.gapLg),
          SaPrimaryButton(
            label: 'Create account',
            icon: Icons.check_rounded,
            busy: _busy,
            expand: true,
            onPressed: _busy ? null : _createAccount,
          ),
          const SizedBox(height: Sa.gapXs),
          TextButton(
            onPressed: (_busy || _resendSeconds > 0) ? null : _sendOtp,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.greenPrimary,
              disabledForegroundColor: AppTheme.neutral400,
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend code',
              style: Sa.value.copyWith(
                color: _resendSeconds > 0 ? AppTheme.neutral400 : AppTheme.greenPrimary,
              ),
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Sa.gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: Sa.body.copyWith(color: AppTheme.error)),
                ),
              ],
            ),
          ),
        const SizedBox(height: Sa.gap),
        const Divider(height: 1),
        const SizedBox(height: Sa.gapXs),
        // Returning users log in. (The entry offers both: log in OR first-time setup.)
        TextButton(
          onPressed: () => context.go(AppConstants.loginRoute),
          style: TextButton.styleFrom(
              foregroundColor: AppTheme.greenPrimary, minimumSize: const Size(0, 44)),
          child: Text('Already have an account? Log in',
              style: Sa.value
                  .copyWith(color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sa.gapLg + 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SaGradientHeader(
                    title: 'Create your account',
                    subtitle: 'Set up access with EduAssist',
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                  const SizedBox(height: Sa.gapLg),
                  SaCard(padding: const EdgeInsets.all(20), child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
