// lib/features/screens/invite_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/auth_session.dart';
import '../../services/auth_api_service.dart';

/// Invite users. Super-admin invites School Authorities (into a chosen school);
/// School authorities invite Teachers / Students into their own school.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _grade = TextEditingController();
  final _section = TextEditingController();

  String _inviteRole = 'student'; // for authority: teacher|student
  String? _tenantId; // for super-admin
  List<Map<String, dynamic>> _tenants = [];
  bool _busy = false;
  bool _tenantsLoading = false;
  bool _tenantsError = false;
  String? _error;
  String? _inviteUrl;

  bool get _isSuperAdmin => AuthSession.instance.role == 'super_admin';

  @override
  void initState() {
    super.initState();
    if (_isSuperAdmin) {
      _inviteRole = 'school_authority';
      _loadTenants();
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _grade, _section]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _tenantsLoading = true;
      _tenantsError = false;
    });
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/?page=1&size=100'),
        headers: AuthSession.instance.headers(json: false),
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final items = (body is Map ? body['items'] : body) as List? ?? [];
        if (!mounted) return;
        setState(() {
          _tenants = items.cast<Map<String, dynamic>>();
          _tenantsLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _tenantsLoading = false;
          _tenantsError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tenantsLoading = false;
        _tenantsError = true;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _inviteUrl = null;
    });
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = 'First and last name are required');
      return;
    }
    if (_isSuperAdmin && (_tenantId == null || _tenantId!.isEmpty)) {
      setState(() => _error = 'Pick a school');
      return;
    }
    if (_isSuperAdmin && _email.text.trim().isEmpty) {
      setState(() => _error = 'Email is required for a school authority');
      return;
    }
    final emailText = _email.text.trim();
    if (emailText.isNotEmpty && !_isValidEmail(emailText)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() => _busy = true);
    AuthResult r;
    if (_isSuperAdmin) {
      r = await AuthApiService.inviteAuthority(
        tenantId: _tenantId!, email: _email.text, firstName: _first.text, lastName: _last.text, phone: _phone.text);
    } else if (_inviteRole == 'teacher') {
      r = await AuthApiService.inviteTeacher(
        firstName: _first.text, lastName: _last.text, email: _email.text, phone: _phone.text);
    } else {
      r = await AuthApiService.inviteStudent(
        firstName: _first.text, lastName: _last.text, email: _email.text, phone: _phone.text,
        gradeLevel: int.tryParse(_grade.text), section: _section.text);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _inviteUrl = r.data?['invite_url']?.toString();
      } else {
        _error = r.error;
      }
    });
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link generated')),
      );
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    const green = AppTheme.greenPrimary;
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(title: const Text('Invite user'), backgroundColor: green, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  if (_isSuperAdmin) ...[
                    DropdownButtonFormField<String>(
                      value: _tenantId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'School (tenant)', border: OutlineInputBorder()),
                      items: _tenants
                          .map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['school_name']?.toString() ?? t['id'].toString())))
                          .toList(),
                      onChanged: (v) => setState(() => _tenantId = v),
                    ),
                    if (_tenantsLoading) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text('Loading schools…', style: AppTheme.bodyMedium),
                      ]),
                    ] else if (_tenantsError) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text("Couldn't load schools", style: AppTheme.bodyMedium.copyWith(color: AppTheme.error))),
                        TextButton(onPressed: _loadTenants, child: const Text('Retry')),
                      ]),
                    ] else if (_tenants.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text('No schools available', style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
                    ],
                    const SizedBox(height: 8),
                    Text('Inviting: School Authority', style: AppTheme.labelMedium.copyWith(color: green)),
                  ] else ...[
                    Row(children: [
                      const Text('Invite as: '),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _inviteRole,
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                        ],
                        onChanged: (v) => setState(() => _inviteRole = v ?? 'student'),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: _first, decoration: const InputDecoration(labelText: 'First name', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _last, decoration: const InputDecoration(labelText: 'Last name', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: _isSuperAdmin ? 'Email (required)' : 'Email (optional)', border: const OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _phone, keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                      decoration: const InputDecoration(labelText: 'Phone (optional — set at signup if blank)', border: OutlineInputBorder())),
                  if (!_isSuperAdmin && _inviteRole == 'student') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: _grade, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _section, decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()))),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Generate invite link'),
                    ),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: AppTheme.error))),
                  if (_inviteUrl != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.green50, borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Invite link (share with the user):', style: AppTheme.labelMedium),
                        const SizedBox(height: 6),
                        SelectableText(_inviteUrl!, style: AppTheme.bodyMicro),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _inviteUrl!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                            },
                          ),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
