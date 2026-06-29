// lib/shared/widgets/login_card.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_theme.dart';
import '../../services/auth_api_service.dart';

/// Self-contained phone + password login card. Renders the same whether shown
/// as an in-place dialog (organisation picker) or on the standalone login page.
///
/// "Forgot password?" runs INLINE, inside this same card (phone → OTP → new
/// password), so it never navigates to a separate page/URL. Pass [onForgot] only
/// if a caller needs to override that with its own navigation.
class LoginCard extends StatefulWidget {
  final String? name;
  final String? roleLabel; // display only
  final String? organisationId;
  final VoidCallback onSuccess; // AuthSession is populated when this fires
  final VoidCallback? onForgot; // optional override; default = inline reset flow
  final VoidCallback? onClose; // shown as an X when provided (dialog mode)

  const LoginCard({
    super.key,
    this.name,
    this.roleLabel,
    this.organisationId,
    required this.onSuccess,
    this.onForgot,
    this.onClose,
  });

  @override
  State<LoginCard> createState() => _LoginCardState();
}

enum _Mode { signIn, forgot, firstTime }

class _LoginCardState extends State<LoginCard> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  bool _obscureNew = true;
  String? _error;
  String? _success; // green banner shown back on the sign-in view

  // Inline "forgot password" flow state.
  _Mode _mode = _Mode.signIn;
  bool _otpSent = false;
  String? _info;
  String? _devCode;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final result = await AuthApiService.login(
      _phone.text,
      _password.text,
      organisationId: widget.organisationId,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) {
      setState(() => _error = _friendlyError(result.error));
      return;
    }
    widget.onSuccess();
  }

  /// Maps a raw/technical error into a user-friendly message. Connection-style
  /// errors are kept readable; auth/technical failures fall back to a generic
  /// "incorrect credentials" message.
  String _friendlyError(String? raw) {
    final msg = (raw ?? '').trim();
    if (msg.isEmpty) return 'Incorrect phone number or password.';
    final lower = msg.toLowerCase();

    // Keep connection / network errors readable.
    if (lower.contains('connect') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('internet') ||
        lower.contains('unreachable') ||
        lower.contains('socket') ||
        lower.contains('host')) {
      return msg;
    }

    // Detect raw/technical errors (status codes, stack-ish text, exceptions).
    final looksTechnical = RegExp(
          r'(exception|error:|null|\{|\}|\[|\]|http|status|code\s*\d|<|>|401|403|500|stacktrace)',
          caseSensitive: false,
        ).hasMatch(msg) ||
        msg.length > 80;

    if (looksTechnical) return 'Incorrect phone number or password.';
    return msg;
  }

  // ---- Inline forgot-password flow ---------------------------------------

  void _enterForgot() => _enterFlow(_Mode.forgot);
  void _enterFirstTime() => _enterFlow(_Mode.firstTime);

  void _enterFlow(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _success = null;
      _info = null;
      _devCode = null;
      _otpSent = false;
      _otp.clear();
      _newPassword.clear();
    });
  }

  void _backToSignIn({String? success}) {
    setState(() {
      _mode = _Mode.signIn;
      _error = null;
      _info = null;
      _devCode = null;
      _otpSent = false;
      _otp.clear();
      _newPassword.clear();
      _success = success;
    });
  }

  Future<void> _sendOtp() async {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final r = _mode == _Mode.firstTime
        ? await AuthApiService.signupRequestOtp(_phone.text)
        : await AuthApiService.forgotRequestOtp(_phone.text);
    if (!mounted) return;
    // First-time setup surfaces "no pending account for this phone"; forgot stays
    // uniform (no account enumeration).
    if (_mode == _Mode.firstTime && !r.ok) {
      setState(() {
        _loading = false;
        _error = r.error ?? 'No account awaiting setup for this phone.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _otpSent = true;
      _devCode = r.data?['dev_code']?.toString();
      if (_devCode != null && _devCode!.isNotEmpty) _otp.text = _devCode!;
      _info = _mode == _Mode.firstTime
          ? null
          : 'If that number has an account, a code was sent.';
    });
  }

  Future<void> _createAccount() async {
    setState(() => _error = null);
    if (_otp.text.trim().isEmpty) {
      setState(() => _error = 'Enter the OTP');
      return;
    }
    if (_newPassword.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() => _loading = true);
    final r = await AuthApiService.signupVerify(
        phone: _phone.text, otp: _otp.text, password: _newPassword.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _loading = false;
        _error = r.error ?? 'Could not set your password. Please try again.';
      });
      return;
    }
    setState(() => _loading = false);
    widget.onSuccess(); // signupVerify auto-logs in (AuthSession populated)
  }

  Future<void> _resetPassword() async {
    setState(() => _error = null);
    if (_otp.text.trim().isEmpty) {
      setState(() => _error = 'Enter the OTP');
      return;
    }
    if (_newPassword.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() => _loading = true);
    final r =
        await AuthApiService.resetPassword(_phone.text, _otp.text, _newPassword.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _loading = false;
        _error = r.error ?? 'Could not reset the password. Please try again.';
      });
      return;
    }
    setState(() => _loading = false);
    _backToSignIn(success: 'Password updated. Please sign in.');
  }

  @override
  Widget build(BuildContext context) {
    final hasOrg = widget.name != null && widget.name!.isNotEmpty;
    final hasRole = widget.roleLabel != null && widget.roleLabel!.isNotEmpty;
    final forgot = _mode == _Mode.forgot;
    final firstTime = _mode == _Mode.firstTime;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onClose != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppTheme.neutral500,
                      onPressed: _loading ? null : widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.borderRadius16,
                  ),
                  child: Icon(
                      forgot
                          ? Icons.lock_reset
                          : firstTime
                              ? Icons.how_to_reg
                              : Icons.apartment,
                      size: 28,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  forgot
                      ? 'Reset password'
                      : firstTime
                          ? 'Set your password'
                          : (hasOrg ? widget.name! : 'EduAssist'),
                  textAlign: TextAlign.center,
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.greenPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  forgot
                      ? 'Verify your phone, then set a new password.'
                      : firstTime
                          ? 'First time? Verify the phone your admin registered, then set a password.'
                          : (hasRole
                              ? 'Login as ${widget.roleLabel}'
                              : 'Sign in with your phone number'),
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600),
                ),
                const SizedBox(height: 22),
                if (forgot)
                  ..._forgotFields()
                else if (firstTime)
                  ..._firstTimeFields()
                else
                  ..._signInFields(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _signInFields() {
    return [
      if (_success != null) ...[
        _banner(_success!, AppTheme.greenPrimary, Icons.check_circle_outline),
        const SizedBox(height: 14),
      ],
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(
          labelText: 'Phone number',
          prefixIcon: Icon(Icons.phone_outlined),
          border: OutlineInputBorder(),
        ),
        validator: (v) {
          final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
          return digits.length < 8 ? 'Enter a valid phone number' : null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _password,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.password],
        onFieldSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          border: const OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading
              ? null
              : (widget.onForgot ?? _enterForgot),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
          child: Text('Forgot password?',
              style: AppTheme.labelSmall.copyWith(color: AppTheme.greenPrimary)),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        _banner(_error!, AppTheme.error, Icons.error_outline),
      ],
      const SizedBox(height: 14),
      _primaryButton('Sign In', _loading ? null : _submit),
      const SizedBox(height: 8),
      Center(
        child: TextButton.icon(
          // Runs IN PLACE (like "Forgot password?") — no new page.
          onPressed: _loading ? null : _enterFirstTime,
          icon: const Icon(Icons.password_rounded,
              size: 18, color: AppTheme.greenPrimary),
          label: Text('First time here? Set your password',
              style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  // Inline first-time "set your password" flow (phone → OTP → password → auto-login).
  List<Widget> _firstTimeFields() {
    return [
      TextField(
        controller: _phone,
        enabled: !_otpSent && !_loading,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
        decoration: const InputDecoration(
          labelText: 'Phone number',
          prefixIcon: Icon(Icons.phone_outlined),
          border: OutlineInputBorder(),
        ),
      ),
      if (!_otpSent) ...[
        const SizedBox(height: 14),
        _primaryButton('Send OTP', _loading ? null : _sendOtp),
      ] else ...[
        const SizedBox(height: 14),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'OTP',
            prefixIcon: const Icon(Icons.sms_outlined),
            helperText: _devCode != null
                ? 'Test OTP (no SMS gateway yet): $_devCode'
                : 'Enter the 6-digit code sent to your phone',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _newPassword,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Create account', _loading ? null : _createAccount),
        TextButton(
          onPressed: _loading ? null : _sendOtp,
          child: Text('Resend code',
              style: AppTheme.labelSmall.copyWith(color: AppTheme.greenPrimary)),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        _banner(_error!, AppTheme.error, Icons.error_outline),
      ],
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: _loading ? null : () => _backToSignIn(),
        icon: const Icon(Icons.arrow_back, size: 16),
        label: const Text('Back to sign in'),
        style: TextButton.styleFrom(foregroundColor: AppTheme.neutral600),
      ),
    ];
  }

  List<Widget> _forgotFields() {
    return [
      TextField(
        controller: _phone,
        enabled: !_otpSent && !_loading,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
        decoration: const InputDecoration(
          labelText: 'Phone number',
          prefixIcon: Icon(Icons.phone_outlined),
          border: OutlineInputBorder(),
        ),
      ),
      if (!_otpSent) ...[
        const SizedBox(height: 14),
        _primaryButton('Send OTP', _loading ? null : _sendOtp),
      ] else ...[
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        TextField(
          controller: _newPassword,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Reset password', _loading ? null : _resetPassword),
        TextButton(
          onPressed: _loading ? null : _sendOtp,
          child: Text('Resend code',
              style: AppTheme.labelSmall.copyWith(color: AppTheme.greenPrimary)),
        ),
      ],
      if (_info != null) ...[
        const SizedBox(height: 8),
        Text(_info!,
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        _banner(_error!, AppTheme.error, Icons.error_outline),
      ],
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: _loading ? null : () => _backToSignIn(),
        icon: const Icon(Icons.arrow_back, size: 16),
        label: const Text('Back to sign in'),
        style: TextButton.styleFrom(foregroundColor: AppTheme.neutral600),
      ),
    ];
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.greenPrimary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius12),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: AppTheme.labelLarge.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTheme.bodySmall.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
