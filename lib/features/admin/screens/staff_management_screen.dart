// lib/features/admin/screens/staff_management_screen.dart
//
// Staff & Users — the unified directory of dynamic-role users for a organisation.
// Add users into any role you're allowed to assign (admins: all roles; delegated
// staff: only the roles their own role may create). Manage status / password.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
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
  bool _loadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _roles = []; // available roles (admin: all org roles)
  String _query = '';
  String? _roleFilterId; // tapped role chip → server-side filter by that role
  int _total = 0;
  int _offset = 0;
  static const int _pageSize = 50;
  Timer? _debounce;
  final TextEditingController _searchCtl = TextEditingController();

  bool get _hasMore => _staff.length < _total;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  /// Server-side page load. `reset` starts a fresh search/list; otherwise it appends
  /// the next page ("load more"). Assignable roles are fetched once.
  Future<void> _load({bool reset = true}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _offset = 0;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await StaffService.listStaffPage(
        q: _query, roleId: _roleFilterId, limit: _pageSize, offset: reset ? 0 : _offset);
      if (reset && _roles.isEmpty) {
        _roles = await StaffService.getAssignableRoles();
      }
      if (!mounted) return;
      setState(() {
        if (reset) {
          _staff = page.items;
        } else {
          _staff = [..._staff, ...page.items];
        }
        _offset = _staff.length;
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v); // live, so the clear (✕) button + empty-state text update
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load(reset: true);
    });
  }

  void _onRoleTap(String? roleId) {
    if (_roleFilterId == roleId) return;
    setState(() => _roleFilterId = roleId);
    _load(reset: true);
  }

  void _snack(String m, [Color? c]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
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
    // Search bar + roles strip stay MOUNTED across reloads (so typing never loses the
    // field/focus); only the content area below swaps loader / error / list.
    return Column(children: [
      _searchBar(),
      _rolesStrip(),
      Expanded(child: _content()),
    ]);
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: TextField(
        controller: _searchCtl, // keeps text across rebuilds
        onChanged: _onSearchChanged, // debounced server-side search
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name, phone or role',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.neutral500),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.neutral500),
                  tooltip: 'Clear',
                  onPressed: () {
                    _searchCtl.clear();
                    _onSearchChanged('');
                  },
                ),
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
    );
  }

  /// Horizontal strip of every role the admin created (doubles as a filter).
  Widget _rolesStrip() {
    if (_roles.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Text('Roles · ${_roles.length}',
            style: Sa.label.copyWith(color: AppTheme.neutral500, fontWeight: FontWeight.w600)),
      ),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            _roleChip('All', null),
            ..._roles.map((r) => _roleChip(
                  (r['role_name'] ?? 'Role').toString(),
                  r['id'].toString(),
                )),
          ],
        ),
      ),
    ]);
  }

  Widget _roleChip(String label, String? id) {
    final selected = _roleFilterId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: AppTheme.greenPrimary,
        backgroundColor: AppTheme.neutral100,
        side: BorderSide(color: selected ? AppTheme.greenPrimary : Sa.stroke.withValues(alpha: 0.7)),
        labelStyle: Sa.label.copyWith(
          color: selected ? Colors.white : AppTheme.neutral700,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => _onRoleTap(id),
      ),
    );
  }

  Widget _content() {
    if (_loading && _staff.isEmpty) return const SaLoading(message: 'Loading…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    final filtered = _query.trim().isNotEmpty || _roleFilterId != null;
    return Column(children: [
      // Thin bar while a search/filter reloads — the existing list stays visible beneath.
      if (_loading)
        LinearProgressIndicator(
            minHeight: 2, color: Sa.accent, backgroundColor: Sa.stroke.withValues(alpha: 0.3)),
      Expanded(
        child: _staff.isEmpty
            ? SaStateView(
                icon: Icons.badge_outlined,
                title: filtered ? 'No matches' : 'No staff yet',
                subtitle: filtered
                    ? 'Try a different search or role.'
                    : 'Tap "Add user" to create one.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                itemCount: _staff.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
                itemBuilder: (_, i) {
                  if (i >= _staff.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: _loadingMore
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Sa.accent))
                            : OutlinedButton.icon(
                                onPressed: () => _load(reset: false),
                                icon: const Icon(Icons.expand_more, size: 18),
                                label: Text('Load more  ·  ${_staff.length} of $_total'),
                                style: OutlinedButton.styleFrom(foregroundColor: Sa.accent),
                              ),
                      ),
                    );
                  }
                  return _staffCard(_staff[i]);
                },
              ),
      ),
    ]);
  }

  Widget _staffCard(Map<String, dynamic> s) {
    // Three distinct states: active, pending (created, awaiting first-login — NOT
    // deactivated), and inactive (deactivated by an admin).
    final status = (s['status'] ?? 'active').toString();
    final isActive = status == 'active';
    final isPending = status == 'invited';
    final isDeactivated = status == 'inactive';
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
                text: isActive
                    ? 'Active'
                    : isPending
                        ? 'Pending'
                        : 'Inactive',
                color: isActive
                    ? AppTheme.greenPrimary
                    : isPending
                        ? AppTheme.neutral500
                        : AppTheme.neutral400,
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
                  Icon(isDeactivated ? Icons.check_circle_outline : Icons.block,
                      size: 18, color: isDeactivated ? AppTheme.greenPrimary : AppTheme.neutral600),
                  const SizedBox(width: 10),
                  Text(isDeactivated ? 'Activate' : 'Deactivate'),
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
          // Only a deactivated row re-activates; active AND pending both deactivate.
          await StaffService.setStatus(id: id, isActive: (s['status'] ?? '') == 'inactive');
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
      // Admins can create roles; a staff user (e.g. "Management") cannot reach Roles & Access,
      // so point them at their admin instead of telling them to create roles.
      final isAdmin = AuthSession.instance.role == 'authority' ||
          AuthSession.instance.role == 'super_admin';
      _snack(
        isAdmin
            ? 'No roles yet. Create a role in "Roles & Access" first.'
            : 'No roles are available to assign yet. Ask your admin to add roles in "Roles & Access".',
        AppTheme.error,
      );
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
                    _tf(posCtl, 'Designation (optional)', hint: 'e.g. Faculty, Head'),
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
