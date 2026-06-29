// lib/features/profile/screens/profile_screen.dart
//
// Universal profile page — available to EVERY role (super-admin → student),
// never gated by RBAC. Shows identity info + a change-password form. It is also
// the default landing page when a user has no granted pages.
//
// Phone-first: no Scaffold/AppBar of its own (the MainLayout shell already
// supplies the top bar, SafeArea and background), a gradient hero header, and
// shared super-admin design-system widgets. No manual refresh / pull-to-refresh
// — the page loads fresh on open; a failed load offers a "Try again".
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../features/super_admin/widgets/sa_widgets.dart';
import '../../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ProfileService.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  String get _fullName {
    final f = (_profile['first_name'] ?? '').toString().trim();
    final l = (_profile['last_name'] ?? '').toString().trim();
    final n = '$f $l'.trim();
    return n.isEmpty ? 'My Profile' : n;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'school_authority':
      case 'admin':
        return 'Admin';
      case 'staff':
        return _profile['position']?.toString().isNotEmpty == true
            ? _profile['position'].toString()
            : 'Staff';
      default:
        return role.isEmpty ? '' : role[0].toUpperCase() + role.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold/AppBar — the MainLayout shell provides the top bar + SafeArea.
    if (_loading) return const SaLoading(message: 'Loading your profile…');
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: _hero(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, Sa.gap, 8, 28),
        children: [
          _infoCard(),
          const SizedBox(height: Sa.gap),
          _ChangePasswordCard(
            onChanged: (msg) => _snack(msg, AppTheme.greenPrimary),
            onError: (msg) => _snack(msg, AppTheme.error),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final role = _roleLabel((_profile['role'] ?? '').toString());
    final initial = _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(Sa.radius),
        boxShadow: const [AppTheme.greenShadow],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: const TextStyle(
                fontFamily: AppTheme.bauhausFontFamily,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.greenPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fullName,
                  style: Sa.headerTitle.copyWith(fontSize: 20),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppTheme.borderRadius8,
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        fontFamily: AppTheme.interFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final rows = <MapEntry<String, String?>>[
      MapEntry('Phone', _profile['phone']?.toString()),
      MapEntry('Email', _profile['email']?.toString()),
      MapEntry('Designation', _profile['position']?.toString()),
      MapEntry('Gender', _profile['gender']?.toString()),
      MapEntry('Status', _profile['status']?.toString()),
      MapEntry('Grade', _profile['grade_level']?.toString()),
      MapEntry('Section', _profile['section']?.toString()),
    ].where((e) => (e.value ?? '').trim().isNotEmpty).toList();

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.badge_outlined, title: 'Account details'),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('No additional details on file.', style: Sa.body),
            )
          else ...[
            const Divider(height: 20, color: Sa.stroke),
            for (var i = 0; i < rows.length; i++) ...[
              SaInfoRow(label: rows[i].key, value: rows[i].value!.trim()),
              if (i != rows.length - 1)
                const Divider(height: 1, color: Sa.stroke),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  final void Function(String) onChanged;
  final void Function(String) onError;
  const _ChangePasswordCard({required this.onChanged, required this.onError});

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.isEmpty) {
      widget.onError('Fill in your current and new password');
      return;
    }
    if (_next.text.length < 6) {
      widget.onError('New password must be at least 6 characters');
      return;
    }
    if (_next.text != _confirm.text) {
      widget.onError('New passwords do not match');
      return;
    }
    setState(() => _saving = true);
    try {
      await ProfileService.changePassword(
          currentPassword: _current.text, newPassword: _next.text);
      _current.clear();
      _next.clear();
      _confirm.clear();
      widget.onChanged('Password changed successfully');
    } catch (e) {
      widget.onError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(
            icon: Icons.lock_outline,
            title: 'Change password',
            trailing: IconButton(
              tooltip: _obscure ? 'Show' : 'Hide',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppTheme.neutral500,
              ),
            ),
          ),
          const SizedBox(height: Sa.gap),
          _field(_current, 'Current password'),
          const SizedBox(height: Sa.gap),
          _field(_next, 'New password'),
          const SizedBox(height: Sa.gap),
          _field(_confirm, 'Confirm new password'),
          const SizedBox(height: Sa.gapLg),
          SaPrimaryButton(
            label: _saving ? 'Saving…' : 'Update password',
            icon: Icons.check_rounded,
            busy: _saving,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      obscureText: _obscure,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
