// lib/features/profile/screens/profile_screen.dart
//
// Universal profile page — available to EVERY role (super-admin → student),
// never gated by RBAC. Shows identity info + a change-password form. It is also
// the default landing page when a user has no granted pages.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.greenPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 40, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 16),
          _infoCard(),
          const SizedBox(height: 16),
          _passwordCard(),
        ],
      ),
    );
  }

  Widget _header() {
    final role = (_profile['role'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient, borderRadius: AppTheme.borderRadius16),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white,
          child: Text(
            _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.greenPrimary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fullName,
                style: AppTheme.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), borderRadius: AppTheme.borderRadius8),
              child: Text(_roleLabel(role),
                  style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.badge_outlined, color: AppTheme.greenPrimary, size: 20),
          const SizedBox(width: 8),
          Text('Account details',
              style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const Divider(height: 20),
        ...rows.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 110,
                  child: Text(e.key, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                ),
                Expanded(
                  child: Text(e.value!.trim(),
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.neutral800, fontWeight: FontWeight.w500)),
                ),
              ]),
            )),
      ]),
    );
  }

  Widget _passwordCard() {
    return _ChangePasswordCard(onChanged: (msg) => _snack(msg, AppTheme.success),
        onError: (msg) => _snack(msg, AppTheme.error));
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_outline, color: AppTheme.greenPrimary, size: 20),
          const SizedBox(width: 8),
          Text('Change password',
              style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            tooltip: _obscure ? 'Show' : 'Hide',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18, color: AppTheme.neutral500),
          ),
        ]),
        const Divider(height: 16),
        _field(_current, 'Current password'),
        const SizedBox(height: 10),
        _field(_next, 'New password'),
        const SizedBox(height: 10),
        _field(_confirm, 'Confirm new password'),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.greenPrimary, foregroundColor: Colors.white),
            icon: _saving
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: Text(_saving ? 'Saving…' : 'Update password'),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: AppTheme.borderRadius8),
      ),
    );
  }
}
