// lib/features/super_admin/screens/admins_screen.dart
//
// Super-admin → Admin management, shown as a HIERARCHY: each institution group is a
// collapsible section that expands to list its admins (the group → admins tree).
// Create admins (login is phone+password; email optional, created into a group),
// run the lifecycle per admin: edit, activate/deactivate, reset password. Admins are
// never deleted — only deactivated (a deactivated admin can't log in; data preserved).
// Search filters admins and auto-expands the groups that match. Real backend, Sa/AppTheme.
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
  List<Map<String, dynamic>> _groups = [];
  final Set<String> _expanded = {}; // group ids currently expanded
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
      // Load groups + admins together so we can render the group → admins tree.
      final results = await Future.wait([
        SuperAdminService.getGroups(),
        SuperAdminService.getAdmins(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0];
        _admins = results[1];
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

  bool _matches(Map<String, dynamic> a) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.toLowerCase();
    final phone = (a['phone'] ?? '').toString().toLowerCase();
    final email = (a['email'] ?? '').toString().toLowerCase();
    return name.contains(q) || phone.contains(q) || email.contains(q);
  }

  /// The admins belonging to a group (id), honouring the current search.
  List<Map<String, dynamic>> _adminsOf(String groupId) => _admins
      .where((a) => a['group_id']?.toString() == groupId && _matches(a))
      .toList();

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Future<void> _create({String? presetGroupId}) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminFormDialog(presetGroupId: presetGroupId),
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
    // Only a deactivated admin re-activates; active AND pending both deactivate.
    final deactivated = (a['status'] ?? '') == 'inactive';
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final ok = await _confirm(
      title: deactivated ? 'Activate $name?' : 'Deactivate $name?',
      message: deactivated
          ? 'They will be able to log in again.'
          : 'They will not be able to log in until reactivated.',
      confirmLabel: deactivated ? 'Activate' : 'Deactivate',
      danger: !deactivated,
    );
    if (ok != true) return;
    try {
      await SuperAdminService.setAdminStatus(adminId: a['id'].toString(), isActive: deactivated);
      _toast(deactivated ? 'Admin activated' : 'Admin deactivated', AppTheme.greenPrimary);
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
          subtitle: 'Admins grouped by institution group',
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
    if (_groups.isEmpty) {
      return const SaStateView(
        icon: Icons.workspaces_outline,
        title: 'No institution groups yet',
        subtitle: 'Create an institution group first (Institution Groups page), '
            'then add admins into it.',
      );
    }
    final searching = _query.trim().isNotEmpty;
    // While searching, show only the groups that have a matching admin (and expand
    // them so the matches are visible).
    final groups = searching
        ? _groups.where((g) => _adminsOf(g['id'].toString()).isNotEmpty).toList()
        : _groups;
    if (groups.isEmpty) {
      return const SaStateView(
        icon: Icons.search_off,
        title: 'No matches',
        subtitle: 'No admins match your search.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _groupSection(groups[i], forceExpanded: searching),
    );
  }

  // ---- Group section: a collapsible card whose body lists the group's admins ----
  Widget _groupSection(Map<String, dynamic> group, {bool forceExpanded = false}) {
    final gid = group['id'].toString();
    final name = (group['name'] ?? 'Group').toString();
    final groupActive = group['is_active'] != false;
    final orgs = group['org_count'] ?? 0;
    final admins = _adminsOf(gid);
    final expanded = forceExpanded || _expanded.contains(gid);
    return SaCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Sa.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tappable group header (toggles expand) — disabled while searching.
            InkWell(
              onTap: forceExpanded
                  ? null
                  : () => setState(() {
                        if (!_expanded.remove(gid)) _expanded.add(gid);
                      }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Sa.accent.withValues(alpha: 0.10),
                      borderRadius: AppTheme.borderRadius8,
                    ),
                    child: const Icon(Icons.workspaces_outline, color: Sa.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Sa.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${admins.length} admin${admins.length == 1 ? '' : 's'}'
                          ' · $orgs organisation${orgs == 1 ? '' : 's'}',
                          style: Sa.label,
                        ),
                      ],
                    ),
                  ),
                  if (!groupActive) ...[
                    const SaStatusPill(text: 'Inactive', color: AppTheme.neutral400),
                    const SizedBox(width: 6),
                  ],
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more, color: AppTheme.neutral500),
                  ),
                ]),
              ),
            ),
            if (expanded) ...[
              const Divider(height: 1, color: Sa.stroke),
              if (admins.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text('No admins in this group yet.', style: Sa.label),
                )
              else
                ..._adminRows(admins),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: TextButton.icon(
                    onPressed: () => _create(presetGroupId: gid),
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Add admin to this group'),
                    style: TextButton.styleFrom(
                        foregroundColor: Sa.accent, visualDensity: VisualDensity.compact),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _adminRows(List<Map<String, dynamic>> admins) {
    final out = <Widget>[];
    for (int i = 0; i < admins.length; i++) {
      out.add(_adminTile(admins[i]));
      if (i < admins.length - 1) {
        out.add(const Divider(height: 1, indent: 14, endIndent: 14, color: Sa.stroke));
      }
    }
    return out;
  }

  Widget _adminTile(Map<String, dynamic> a) {
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final phone = (a['phone'] ?? '').toString();
    final email = (a['email'] ?? '').toString();
    final status = (a['status'] ?? '').toString();
    final active = status == 'active';
    final pending = status == 'invited'; // created, awaiting first-login — NOT deactivated
    final contact = [if (phone.isNotEmpty) phone, if (email.isNotEmpty) email].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: active ? AppTheme.green50 : AppTheme.neutral100,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTheme.labelLarge.copyWith(
                  color: active ? AppTheme.greenPrimary : AppTheme.neutral500)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Flexible(
                  child: Text(name.isEmpty ? 'Admin' : name,
                      style: Sa.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                SaStatusPill(
                  text: active
                      ? 'Active'
                      : pending
                          ? 'Pending'
                          : 'Inactive',
                  color: active
                      ? AppTheme.greenPrimary
                      : pending
                          ? AppTheme.neutral500
                          : AppTheme.neutral400,
                ),
              ]),
              if (contact.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(contact, style: Sa.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        // Pass not-deactivated so a pending admin still offers "Deactivate".
        _actionsMenu(a, status != 'inactive'),
      ]),
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
      ],
    );
  }

}

// ---------------------------------------------------------------------------
// Create / edit admin. In create mode shows phone + password (required) + email
// (optional) + a page-access picker. In edit mode shows name/phone/email only.
class _AdminFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String? presetGroupId; // pre-select this group (from a group's "Add admin")
  const _AdminFormDialog({this.existing, this.presetGroupId});

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

  // institution group (create only) — the admin is created INTO a group.
  List<Map<String, dynamic>> _groups = [];
  String? _groupId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      _groupId = widget.presetGroupId; // pre-selected when adding from a group
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    try {
      final g = await SuperAdminService.getGroups();
      if (mounted) setState(() => _groups = g);
    } catch (_) {
      // non-fatal; the dropdown just stays empty and save will prompt to pick one
    }
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
    if (!_isEdit && (_groupId == null || _groupId!.isEmpty)) {
      setState(() => _err = 'Select an institution group for this admin');
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
          groupId: _groupId!,
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
                DropdownButtonFormField<String>(
                  initialValue: _groupId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Institution group *',
                    prefixIcon: Icon(Icons.workspaces_outline),
                    isDense: true,
                  ),
                  hint: Text(_groups.isEmpty ? 'No groups — create one first' : 'Select a group'),
                  items: _groups
                      .map((g) => DropdownMenuItem(
                            value: g['id'].toString(),
                            child: Text((g['name'] ?? 'Group').toString(),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _groupId = v),
                ),
                const SizedBox(height: 12),
                const Text(
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
