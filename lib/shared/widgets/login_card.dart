// lib/shared/widgets/login_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_theme.dart';
import '../../services/auth_api_service.dart';

/// Self-contained phone + password login card. Renders the same whether shown
/// as an in-place dialog (school picker) or on the standalone login page.
class LoginCard extends StatefulWidget {
  final String? schoolName;
  final String? roleLabel; // display only
  final String? tenantId;
  final VoidCallback onSuccess; // AuthSession is populated when this fires
  final VoidCallback? onForgot;
  final VoidCallback? onClose; // shown as an X when provided (dialog mode)

  const LoginCard({
    super.key,
    this.schoolName,
    this.roleLabel,
    this.tenantId,
    required this.onSuccess,
    this.onForgot,
    this.onClose,
  });

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AuthApiService.login(
      _phone.text,
      _password.text,
      tenantId: widget.tenantId,
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

  @override
  Widget build(BuildContext context) {
    final hasSchool = widget.schoolName != null && widget.schoolName!.isNotEmpty;
    final hasRole = widget.roleLabel != null && widget.roleLabel!.isNotEmpty;
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
                  child: const Icon(Icons.school, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  hasSchool ? widget.schoolName! : 'EduAssist',
                  textAlign: TextAlign.center,
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.greenPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasRole ? 'Login as ${widget.roleLabel}' : 'Sign in with your phone number',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600),
                ),
                const SizedBox(height: 22),
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
                if (widget.onForgot != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : widget.onForgot,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
                      child: Text('Forgot password?',
                          style: AppTheme.labelSmall.copyWith(color: AppTheme.greenPrimary)),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
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
                        : Text('Sign In', style: AppTheme.labelLarge.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
