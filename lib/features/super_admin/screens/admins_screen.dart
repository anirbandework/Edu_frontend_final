// lib/features/super_admin/screens/admins_screen.dart
//
// Super-admin → Admin management. Create admins (login is phone+password; email
// optional), grant their page access, and run the full lifecycle: edit,
// activate/deactivate, reset password, delete. Consistent gradient header +
// search + status badges. Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../widgets/sa_widgets.dart';

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _admins = [];
  String _query = '';

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
      final admins = await SuperAdminService.getAdmins();
      if (!mounted) return;
      setState(() {
        _admins = admins;
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

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _admins;
    final q = _query.toLowerCase();
    return _admins.where((a) {
      final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.toLowerCase();
      final phone = (a['phone'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }).toList();
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdminFormDialog(),
    );
    if (created == true) {
      _load();
      _toast('Admin created', AppTheme.greenPrimary);
    }
  }

  Future<void> _edit(Map<String, dynamic> a) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminFormDialog(existing: a),
    );
    if (saved == true) {
      _load();
      _toast('Admin updated', AppTheme.greenPrimary);
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> a) async {
    final active = (a['status'] ?? '') == 'active';
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final ok = await _confirm(
      title: active ? 'Deactivate $name?' : 'Activate $name?',
      message: active
          ? 'They will not be able to log in until reactivated.'
          : 'They will be able to log in again.',
      confirmLabel: active ? 'Deactivate' : 'Activate',
      danger: active,
    );
    if (ok != true) return;
    try {
      await SuperAdminService.setAdminStatus(adminId: a['id'].toString(), isActive: !active);
      _toast(active ? 'Admin deactivated' : 'Admin activated', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> a) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        adminId: a['id'].toString(),
        adminName: '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim(),
      ),
    );
    if (done == true) _toast('Password reset', AppTheme.greenPrimary);
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final schools = a['school_count'] ?? 0;
    final ok = await _confirm(
      title: 'Delete $name?',
      message: schools == 0
          ? 'This admin will be removed.'
          : 'This admin and access to their $schools school(s) will be removed. The schools are deactivated, not erased.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok != true) return;
    try {
      await SuperAdminService.deleteAdmin(adminId: a['id'].toString());
      _toast('Admin deleted', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: danger ? ElevatedButton.styleFrom(backgroundColor: AppTheme.error) : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Admin Management',
          subtitle: 'Create admins and grant their page access',
          icon: Icons.admin_panel_settings,
          trailing: SaHeaderAction(
            icon: Icons.person_add_alt_1,
            tooltip: 'Create admin',
            onPressed: _create,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchBar(),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search by name, phone or email',
        prefixIcon: Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: AppTheme.neutral50,
        border: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12, borderSide: BorderSide.none),
      ),
      onChanged: (v) => setState(() => _query = v),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SaLoading(message: 'Loading admins…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    final list = _filtered;
    if (list.isEmpty) {
      return _admins.isEmpty
          ? SaStateView(
              icon: Icons.group_outlined,
              title: 'No admins yet',
              subtitle: 'Create your first admin to get started.',
              action: SaPrimaryButton(
                  label: 'Create admin',
                  icon: Icons.person_add_alt_1,
                  onPressed: _create),
            )
          : const SaStateView(
              icon: Icons.search_off,
              title: 'No matches',
              subtitle: 'No admins match your search.',
            );
    }
    // Single-column list of cards: intrinsic height avoids overflow at large text.
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _adminCard(list[i]),
    );
  }

  Widget _adminCard(Map<String, dynamic> a) {
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final phone = (a['phone'] ?? '').toString();
    final email = (a['email'] ?? '').toString();
    final active = (a['status'] ?? '') == 'active';
    final schools = a['school_count'] ?? 0;
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.green50,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTheme.labelLarge.copyWith(color: AppTheme.greenPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Admin' : name,
                      style: Sa.cardTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(phone,
                        style: Sa.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (email.isNotEmpty)
                    Text(email,
                        style: Sa.label.copyWith(fontSize: 11.5, color: AppTheme.neutral400),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SaStatusPill(
              text: active ? 'Active' : 'Inactive',
              color: active ? AppTheme.greenPrimary : AppTheme.neutral400,
              icon: active ? Icons.check_circle : Icons.remove_circle_outline,
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _stat(Icons.business, '$schools', schools == 1 ? 'school' : 'schools'),
            ],
          ),
          const Divider(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: _actionsMenu(a, active),
          ),
        ],
      ),
    );
  }

  Widget _actionsMenu(Map<String, dynamic> a, bool active) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, color: AppTheme.neutral500),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _edit(a);
            break;
          case 'status':
            _toggleStatus(a);
            break;
          case 'reset':
            _resetPassword(a);
            break;
          case 'delete':
            _delete(a);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [
          Icon(Icons.edit, size: 18, color: AppTheme.neutral600), SizedBox(width: 10), Text('Edit')])),
        PopupMenuItem(value: 'status', child: Row(children: [
          Icon(active ? Icons.block : Icons.check_circle, size: 18,
              color: active ? AppTheme.neutral600 : AppTheme.greenPrimary),
          const SizedBox(width: 10),
          Text(active ? 'Deactivate' : 'Activate')])),
        const PopupMenuItem(value: 'reset', child: Row(children: [
          Icon(Icons.password, size: 18, color: AppTheme.neutral600), SizedBox(width: 10), Text('Reset password')])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Row(children: [
          Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
          SizedBox(width: 10), Text('Delete', style: TextStyle(color: AppTheme.error))])),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
      const SizedBox(width: 6),
      Text(value, style: Sa.value.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      Text(label, style: Sa.label),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Create / edit admin. In create mode shows phone + password (required) + email
// (optional) + a page-access picker. In edit mode shows name/phone/email only.
class _AdminFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _AdminFormDialog({this.existing});

  @override
  State<_AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<_AdminFormDialog> {
  late final TextEditingController _first =
      TextEditingController(text: widget.existing?['first_name']?.toString() ?? '');
  late final TextEditingController _last =
      TextEditingController(text: widget.existing?['last_name']?.toString() ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?['phone']?.toString() ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?['email']?.toString() ?? '');
  bool _saving = false;
  String? _err;

  // module picker (create only)

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _err = 'First and last name are required');
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _err = 'Phone is required (used to log in)');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      if (_isEdit) {
        await SuperAdminService.updateAdmin(
          adminId: widget.existing!['id'].toString(),
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
        );
      } else {
        await SuperAdminService.createAdmin(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = screenW - 48 < 460 ? screenW - 48 : 460.0;
    final firstField = TextField(controller: _first,
        decoration: const InputDecoration(labelText: 'First name *', isDense: true));
    final lastField = TextField(controller: _last,
        decoration: const InputDecoration(labelText: 'Last name *', isDense: true));
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_isEdit ? 'Edit Admin' : 'Create Admin'),
      content: SizedBox(
        width: dialogW,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 360) {
                  return Column(children: [
                    firstField,
                    const SizedBox(height: 12),
                    lastField,
                  ]);
                }
                return Row(children: [
                  Expanded(child: firstField),
                  const SizedBox(width: 12),
                  Expanded(child: lastField),
                ]);
              }),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone * (login)', prefixIcon: Icon(Icons.phone), isDense: true),
              ),
              const SizedBox(height: 12),
              if (!_isEdit) ...[
                Text(
                  'No password needed — the admin sets their own at first login (phone + OTP).',
                  style: TextStyle(fontSize: 12, color: AppTheme.neutral600),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email (optional)', prefixIcon: Icon(Icons.email), isDense: true),
              ),
              if (_err != null) ...[
                const SizedBox(height: 12),
                Text(_err!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: AppTheme.iconSmall),
          label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save' : 'Create')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class _ResetPasswordDialog extends StatefulWidget {
  final String adminId;
  final String adminName;
  const _ResetPasswordDialog({required this.adminId, required this.adminName});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 6) {
      setState(() => _err = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await SuperAdminService.resetAdminPassword(
          adminId: widget.adminId, password: _password.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = screenW - 48 < 360 ? screenW - 48 : 360.0;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Reset password · ${widget.adminName}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: dialogW,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: AppTheme.iconSmall),
          label: Text(_saving ? 'Saving…' : 'Reset'),
        ),
      ],
    );
  }
}
