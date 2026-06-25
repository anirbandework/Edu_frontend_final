// lib/features/admin/screens/staff_management_screen.dart
//
// Staff & Users — the unified directory of dynamic-role users for a school.
// Add users into any role you're allowed to assign (admins: all roles; delegated
// staff: only the roles their own role may create). Manage status / password.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/staff_service.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _roles = []; // assignable roles
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
      final results = await Future.wait([
        StaffService.listStaff(),
        StaffService.getAssignableRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _staff = results[0];
        _roles = results[1];
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

  void _snack(String m, [Color? c]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _staff;
    final q = _query.toLowerCase();
    return _staff.where((s) {
      return [s['name'], s['phone'], s['role_name'], s['position'], s['email']]
          .whereType<Object>()
          .any((v) => v.toString().toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Staff & Users'),
        backgroundColor: AppTheme.greenPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.greenPrimary,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
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
    final list = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search staff by name, phone or role',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: OutlineInputBorder(borderRadius: AppTheme.borderRadius12),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          color: AppTheme.greenPrimary,
          onRefresh: _load,
          child: list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Icon(Icons.badge_outlined, size: 44, color: AppTheme.neutral400),
                  const SizedBox(height: 12),
                  Center(
                      child: Text(_staff.isEmpty ? 'No staff yet' : 'No matches',
                          style: AppTheme.labelLarge.copyWith(color: AppTheme.neutral600))),
                  const SizedBox(height: 4),
                  Center(
                      child: Text(_staff.isEmpty ? 'Tap “Add user” to create one.' : 'Try a different search.',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500))),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _staffCard(list[i]),
                ),
        ),
      ),
    ]);
  }

  Widget _staffCard(Map<String, dynamic> s) {
    final active = (s['status'] ?? 'active') == 'active';
    final name = (s['name'] ?? '').toString().trim();
    final role = (s['role_name'] ?? '—').toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.green50,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTheme.labelLarge.copyWith(color: AppTheme.greenPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(name.isEmpty ? 'Unnamed' : name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              _statusBadge(active),
            ]),
            const SizedBox(height: 3),
            Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _chip(Icons.badge_outlined, role),
              if ((s['position'] ?? '').toString().isNotEmpty) _chip(Icons.work_outline, s['position'].toString()),
              if ((s['phone'] ?? '').toString().isNotEmpty) _chip(Icons.phone_outlined, s['phone'].toString()),
            ]),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.neutral600),
          onSelected: (v) => _onAction(v, s),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
            PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                    leading: Icon(active ? Icons.block : Icons.check_circle_outline),
                    title: Text(active ? 'Deactivate' : 'Activate'))),
            const PopupMenuItem(
                value: 'password',
                child: ListTile(leading: Icon(Icons.key_outlined), title: Text('Reset password'))),
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppTheme.error),
                    title: Text('Delete', style: TextStyle(color: AppTheme.error)))),
          ],
        ),
      ]),
    );
  }

  Widget _chip(IconData ic, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 13, color: AppTheme.neutral400),
        const SizedBox(width: 3),
        Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600)),
      ]);

  Widget _statusBadge(bool active) {
    final c = active ? AppTheme.success : AppTheme.neutral500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
      child: Text(active ? 'Active' : 'Inactive',
          style: AppTheme.bodyMicro.copyWith(color: c, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _onAction(String action, Map<String, dynamic> s) async {
    final id = s['id'].toString();
    switch (action) {
      case 'edit':
        _openEditor(existing: s);
        break;
      case 'toggle':
        try {
          await StaffService.setStatus(id: id, isActive: !((s['status'] ?? 'active') == 'active'));
          _snack('Updated', AppTheme.success);
          _load();
        } catch (e) {
          _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
        }
        break;
      case 'password':
        _resetPassword(s);
        break;
      case 'delete':
        _delete(s);
        break;
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> s) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password — ${s['name']}'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.greenPrimary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true || ctl.text.trim().isEmpty) return;
    try {
      await StaffService.resetPassword(id: s['id'].toString(), password: ctl.text.trim());
      _snack('Password reset', AppTheme.success);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('${s['name']} will lose access immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await StaffService.deleteStaff(s['id'].toString());
      _snack('Deleted', AppTheme.success);
      _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  // ---------------- add / edit ----------------
  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    if (_roles.isEmpty && !isEdit) {
      _snack('No roles you can assign. Create a role in “Roles & Access” first.', AppTheme.warning);
      return;
    }
    final firstCtl = TextEditingController(text: existing?['first_name']?.toString() ?? '');
    final lastCtl = TextEditingController(text: existing?['last_name']?.toString() ?? '');
    final phoneCtl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final posCtl = TextEditingController(text: existing?['position']?.toString() ?? '');
    final passCtl = TextEditingController();
    // role list for the dropdown: assignable roles, plus the current one when editing
    final roleItems = [..._roles];
    if (isEdit &&
        existing['rbac_role_id'] != null &&
        !roleItems.any((r) => r['id'].toString() == existing['rbac_role_id'].toString())) {
      roleItems.add({'id': existing['rbac_role_id'], 'role_name': existing['role_name'] ?? 'Current role'});
    }
    String? roleId = existing?['rbac_role_id']?.toString() ??
        (roleItems.isNotEmpty ? roleItems.first['id'].toString() : null);
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Row(children: [
            Icon(isEdit ? Icons.edit : Icons.person_add_alt_1, color: AppTheme.greenPrimary),
            const SizedBox(width: 10),
            Text(isEdit ? 'Edit user' : 'Add user'),
          ]),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _tf(firstCtl, 'First name *')),
                  const SizedBox(width: 10),
                  Expanded(child: _tf(lastCtl, 'Last name *')),
                ]),
                const SizedBox(height: 10),
                _tf(phoneCtl, 'Phone * (login id)', keyboard: TextInputType.phone),
                const SizedBox(height: 10),
                if (!isEdit) ...[
                  _tf(passCtl, 'Password *', obscure: true),
                  const SizedBox(height: 10),
                ],
                _tf(emailCtl, 'Email (optional)', keyboard: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _tf(posCtl, 'Designation (optional)', hint: 'e.g. Faculty, Principal'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: roleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Role *', border: OutlineInputBorder(), isDense: true),
                  items: roleItems
                      .map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                          value: r['id'].toString(),
                          child: Text(r['role_name']?.toString() ?? 'Role',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setLocal(() => roleId = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.greenPrimary),
              onPressed: saving
                  ? null
                  : () async {
                      if (firstCtl.text.trim().isEmpty ||
                          lastCtl.text.trim().isEmpty ||
                          phoneCtl.text.trim().isEmpty) {
                        _snack('First name, last name and phone are required', AppTheme.error);
                        return;
                      }
                      if (!isEdit && passCtl.text.trim().isEmpty) {
                        _snack('Password is required', AppTheme.error);
                        return;
                      }
                      if (roleId == null) {
                        _snack('Pick a role', AppTheme.error);
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        if (isEdit) {
                          await StaffService.updateStaff(
                            id: existing['id'].toString(),
                            firstName: firstCtl.text.trim(),
                            lastName: lastCtl.text.trim(),
                            phone: phoneCtl.text.trim(),
                            email: emailCtl.text.trim(),
                            position: posCtl.text.trim(),
                            roleId: roleId,
                          );
                        } else {
                          await StaffService.createStaff(
                            firstName: firstCtl.text.trim(),
                            lastName: lastCtl.text.trim(),
                            phone: phoneCtl.text.trim(),
                            password: passCtl.text.trim(),
                            roleId: roleId!,
                            email: emailCtl.text.trim(),
                            position: posCtl.text.trim(),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack(isEdit ? 'User updated' : 'User created', AppTheme.success);
                        _load();
                      } catch (e) {
                        setLocal(() => saving = false);
                        _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
                      }
                    },
              child: Text(saving ? 'Saving…' : (isEdit ? 'Save' : 'Create')),
            ),
          ],
        );
      }),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {bool obscure = false, String? hint, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
          labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
    );
  }
}
