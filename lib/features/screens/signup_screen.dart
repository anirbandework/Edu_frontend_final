// lib/features/screens/signup_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/auth_session.dart';
import '../../services/auth_api_service.dart';

/// Signup from an invitation link: validate invite -> phone -> OTP -> set password.
class SignupScreen extends StatefulWidget {
  final String token;
  const SignupScreen({super.key, required this.token});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loadingInvite = true;
  bool _busy = false;
  bool _otpSent = false;
  String? _error;
  String? _devCode;
  Map<String, dynamic>? _invite;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _loadInvite() async {
    final r = await AuthApiService.getInvite(widget.token);
    if (!mounted) return;
    setState(() {
      _loadingInvite = false;
      if (r.ok) {
        _invite = r.data;
        final p = r.data?['phone'];
        if (p != null && p.toString().isNotEmpty) _phone.text = p.toString();
      } else {
        _error = r.error;
      }
    });
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
    final r = await AuthApiService.signupRequestOtp(widget.token, _phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _otpSent = true;
        _devCode = r.data?['dev_code']?.toString();
      } else {
        _error = r.error;
      }
    });
    if (r.ok && wasAlreadySent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code was sent')),
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
      token: widget.token,
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
    // auto-logged in
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Welcome!')),
    );
    final s = AuthSession.instance;
    context.go(_routeForRole(s.role ?? 'student', s.tenantId, s.userId));
  }

  String _routeForRole(String role, String? tenantId, String? userId) {
    final qs = (tenantId != null) ? '?tenantId=$tenantId&userId=${userId ?? ''}' : '';
    switch (role) {
      case 'super_admin':
        return '${AppConstants.tenantManagementRoute}?role=tenant_manager';
      case 'school_authority':
        return '${AppConstants.adminDashboardRoute}$qs';
      case 'teacher':
        return '${AppConstants.teacherDashboardRoute}$qs';
      default:
        return '${AppConstants.studentDashboardRoute}$qs';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loadingInvite) {
      body = const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    } else if (_invite == null) {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.link_off, size: 48, color: AppTheme.error),
        const SizedBox(height: 12),
        Text(_error ?? 'This invitation is not valid.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(onPressed: () => context.go(AppConstants.loginRoute), child: const Text('Go to login')),
      ]);
    } else {
      final role = (_invite!['role'] ?? '').toString().replaceAll('_', ' ');
      final name = [_invite!['first_name'], _invite!['last_name']]
          .where((e) => e != null && e.toString().isNotEmpty)
          .join(' ');
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.how_to_reg, size: 44, color: AppTheme.greenPrimary),
        const SizedBox(height: 8),
        Text('Join as ${role.isEmpty ? 'user' : role}',
            textAlign: TextAlign.center, style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.greenPrimary)),
        if (name.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(name, textAlign: TextAlign.center, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500))),
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
          TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          _btn('Create account', _busy ? null : _createAccount),
          TextButton(
            onPressed: (_busy || _resendSeconds > 0) ? null : _sendOtp,
            child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend code'),
          ),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: AppTheme.error))),
      ]);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(padding: const EdgeInsets.all(28), child: body),
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
              : Text(label, style: AppTheme.labelMedium.copyWith(color: Colors.white)),
        ),
      );
}
