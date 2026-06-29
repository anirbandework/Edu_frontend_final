// lib/features/admin/screens/staff_management_screen.dart
//
// Staff & Users — the unified directory of dynamic-role users for a school.
// Add users into any role you're allowed to assign (admins: all roles; delegated
// staff: only the roles their own role may create). Manage status / password.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/staff_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

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
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Staff & Users',
          subtitle: 'Unified directory of roles and access',
          icon: Icons.badge_outlined,
          trailing: SaHeaderAction(
            icon: Icons.person_add_alt_1,
            tooltip: 'Add user',
            onPressed: () => _openEditor(),
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);

    final list = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search staff by name, phone or role',
            prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.neutral500),
            isDense: true,
            filled: true,
            fillColor: Sa.surface,
            border: OutlineInputBorder(
              borderRadius: AppTheme.borderRadius12,
              borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppTheme.borderRadius12,
              borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppTheme.borderRadius12,
              borderSide: BorderSide(color: Sa.accent, width: 1.5),
            ),
          ),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? SaStateView(
                icon: Icons.badge_outlined,
                title: _staff.isEmpty ? 'No staff yet' : 'No matches',
                subtitle: _staff.isEmpty
                    ? 'Tap "Add user" to create one.'
                    : 'Try a different search.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
                itemBuilder: (_, i) => _staffCard(list[i]),
              ),
      ),
    ]);
  }

  Widget _staffCard(Map<String, dynamic> s) {
    final active = (s['status'] ?? 'active') == 'active';
    final name = (s['name'] ?? '').toString().trim();
    final role = (s['role_name'] ?? '—').toString();
    return SaCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.green50,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: Sa.cardTitle.copyWith(color: Sa.accent, fontSize: 16),
          ),
        ),
        const SizedBox(width: Sa.gap),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(name.isEmpty ? 'Unnamed' : name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Sa.cardTitle),
              ),
              const SizedBox(width: 8),
              SaStatusPill(
                text: active ? 'Active' : 'Inactive',
                color: active ? AppTheme.greenPrimary : AppTheme.neutral500,
              ),
            ]),
            const SizedBox(height: 5),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: AppTheme.neutral600),
                  SizedBox(width: 10),
                  Text('Edit'),
                ])),
            PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(active ? Icons.block : Icons.check_circle_outline,
                      size: 18, color: active ? AppTheme.neutral600 : AppTheme.greenPrimary),
                  const SizedBox(width: 10),
                  Text(active ? 'Deactivate' : 'Activate'),
                ])),
            const PopupMenuItem(
                value: 'password',
                child: Row(children: [
                  Icon(Icons.key_outlined, size: 18, color: AppTheme.neutral600),
                  SizedBox(width: 10),
                  Text('Reset password'),
                ])),
            // No "Delete" — deactivate instead (keeps the user + their history).
          ],
        ),
      ]),
    );
  }

  Widget _chip(IconData ic, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 13, color: AppTheme.neutral400),
        const SizedBox(width: 3),
        Text(text, style: Sa.label),
      ]);

  Future<void> _onAction(String action, Map<String, dynamic> s) async {
    final id = s['id'].toString();
    switch (action) {
      case 'edit':
        _openEditor(existing: s);
        break;
      case 'toggle':
        try {
          await StaffService.setStatus(id: id, isActive: !((s['status'] ?? 'active') == 'active'));
          _snack('Updated', AppTheme.greenPrimary);
          _load();
        } catch (e) {
          _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
        }
        break;
      case 'password':
        _resetPassword(s);
        break;
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> s) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final maxW = MediaQuery.of(ctx).size.width - 24;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Sa.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW > 420 ? 420 : maxW),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset password', style: Sa.cardTitle.copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text((s['name'] ?? '').toString(), style: Sa.label),
                  const SizedBox(height: Sa.gapLg),
                  _tf(ctl, 'New password', obscure: true),
                  const SizedBox(height: Sa.gapLg),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.neutral600))),
                    const SizedBox(width: 8),
                    SaPrimaryButton(
                      label: 'Reset',
                      icon: Icons.key_outlined,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true || ctl.text.trim().isEmpty) return;
    try {
      await StaffService.resetPassword(id: s['id'].toString(), password: ctl.text.trim());
      _snack('Password reset', AppTheme.greenPrimary);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  // ---------------- add / edit ----------------
  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    if (_roles.isEmpty && !isEdit) {
      _snack('No roles you can assign. Create a role in "Roles & Access" first.', AppTheme.error);
      return;
    }
    final firstCtl = TextEditingController(text: existing?['first_name']?.toString() ?? '');
    final lastCtl = TextEditingController(text: existing?['last_name']?.toString() ?? '');
    final phoneCtl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final posCtl = TextEditingController(text: existing?['position']?.toString() ?? '');
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
        final size = MediaQuery.of(ctx).size;
        final maxW = size.width - 24;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Sa.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxW > 520 ? 520 : maxW,
              maxHeight: size.height - 80,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Sa.accent.withValues(alpha: 0.12), borderRadius: AppTheme.borderRadius8),
                    child: Icon(isEdit ? Icons.edit : Icons.person_add_alt_1,
                        color: Sa.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(isEdit ? 'Edit user' : 'Add user',
                          style: Sa.cardTitle.copyWith(fontSize: 16))),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LayoutBuilder(builder: (context, c) {
                      final oneCol = c.maxWidth < 600;
                      final f1 = _tf(firstCtl, 'First name *');
                      final f2 = _tf(lastCtl, 'Last name *');
                      return oneCol
                          ? Column(children: [f1, const SizedBox(height: Sa.gap), f2])
                          : Row(children: [
                              Expanded(child: f1),
                              const SizedBox(width: Sa.gap),
                              Expanded(child: f2),
                            ]);
                    }),
                    const SizedBox(height: Sa.gap),
                    _tf(phoneCtl, 'Phone * (login id)', keyboard: TextInputType.phone),
                    const SizedBox(height: Sa.gap),
                    if (!isEdit) ...[
                      Text(
                        'No password needed — the user sets their own at first login (phone + OTP).',
                        style: TextStyle(fontSize: 12, color: AppTheme.neutral600),
                      ),
                      const SizedBox(height: Sa.gap),
                    ],
                    _tf(emailCtl, 'Email (optional)', keyboard: TextInputType.emailAddress),
                    const SizedBox(height: Sa.gap),
                    _tf(posCtl, 'Designation (optional)', hint: 'e.g. Faculty, Principal'),
                    const SizedBox(height: Sa.gap),
                    DropdownButtonFormField<String>(
                      initialValue: roleId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Role *',
                        isDense: true,
                        border: const OutlineInputBorder(borderRadius: AppTheme.borderRadius12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppTheme.borderRadius12,
                          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: AppTheme.borderRadius12,
                          borderSide: BorderSide(color: Sa.accent, width: 1.5),
                        ),
                      ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.neutral600))),
                  const SizedBox(width: 8),
                  SaPrimaryButton(
                    label: saving ? 'Saving…' : (isEdit ? 'Save' : 'Create'),
                    icon: isEdit ? Icons.check_rounded : Icons.person_add_alt_1,
                    busy: saving,
                    onPressed: saving
                        ? null
                        : () async {
                            if (firstCtl.text.trim().isEmpty ||
                                lastCtl.text.trim().isEmpty ||
                                phoneCtl.text.trim().isEmpty) {
                              _snack('First name, last name and phone are required', AppTheme.error);
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
                                  roleId: roleId!,
                                  email: emailCtl.text.trim(),
                                  position: posCtl.text.trim(),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              _snack(isEdit ? 'User updated' : 'User created', AppTheme.greenPrimary);
                              _load();
                            } catch (e) {
                              setLocal(() => saving = false);
                              _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
                            }
                          },
                  ),
                ]),
              ),
            ]),
          ),
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
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(borderRadius: AppTheme.borderRadius12),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.accent, width: 1.5),
        ),
      ),
    );
  }
}
