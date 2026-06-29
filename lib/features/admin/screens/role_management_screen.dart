// lib/features/admin/screens/role_management_screen.dart
//
// Dynamic Roles & Access (admin). The admin defines roles freely — "Teacher",
// "Faculty", "Principal", "Parent", "HOD", anything — names each, picks its pages
// from the WHOLE catalog (any section), and chooses which other roles it may
// create users into (delegation). Nothing is hardcoded; every role is dynamic.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/roles_service.dart';
import '../../../shared/widgets/page_group_toggle.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _catalog = [];

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
        RolesService.listRoles(userType: 'staff'),
        RolesService.getGrantablePages(), // catalog + `locked` (org doesn't have it)
      ]);
      if (!mounted) return;
      setState(() {
        _roles = results[0];
        _catalog = results[1];
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

  Future<void> _delete(Map<String, dynamic> role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text(
            '"${role['role_name']}" will be removed. Users with this role lose its access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RolesService.deleteRole(role['id'].toString());
      _snack('Role deleted', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Roles & Access',
          subtitle: 'Define roles and the pages they can reach',
          icon: Icons.admin_panel_settings_outlined,
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'New role',
            onPressed: _catalog.isEmpty ? null : () => _openEditor(),
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading roles…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.green50, borderRadius: BorderRadius.circular(Sa.radius)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: Sa.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Create any role your school needs and pick exactly which pages it can '
                'see — across every section. Grant a role the right to add users into '
                'other roles to delegate user management.',
                style: Sa.body.copyWith(color: AppTheme.neutral700),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Sa.gapLg),
        if (_roles.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: SaStateView(
              icon: Icons.shield_outlined,
              title: 'No roles yet',
              subtitle: 'Tap “New role” to define your first one.',
            ),
          )
        else
          ..._roles.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: Sa.gap),
                child: _roleCard(r),
              )),
      ],
    );
  }

  Widget _roleCard(Map<String, dynamic> role) {
    final desc = (role['description'] ?? '').toString();
    return SaCard(
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Sa.accent.withValues(alpha: 0.12), borderRadius: AppTheme.borderRadius12),
          child: const Icon(Icons.badge_outlined, color: Sa.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role['role_name']?.toString() ?? 'Role',
                style: Sa.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Sa.label),
            ],
          ]),
        ),
        IconButton(
            tooltip: 'Edit',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => _openEditor(existing: role),
            icon: const Icon(Icons.edit_outlined, color: Sa.accent, size: 20)),
        IconButton(
            tooltip: 'Delete',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => _delete(role),
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20)),
      ]),
    );
  }

  // ---------------- editor ----------------
  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtl = TextEditingController(text: existing?['role_name']?.toString() ?? '');
    final descCtl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final selectedModules = <String>{};
    final selectedCreatable = <String>{};

    if (isEdit) {
      try {
        final detail = await RolesService.getRoleDetail(existing['id'].toString());
        selectedModules.addAll((detail['modules'] as List? ?? const []).map((e) => e.toString()));
        selectedCreatable
            .addAll((detail['creatable_role_ids'] as List? ?? const []).map((e) => e.toString()));
      } catch (e) {
        _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
      }
    }

    // The detail fetch above is async — bail if the screen went away meanwhile,
    // so we never open a dialog against a defunct BuildContext.
    if (!mounted) return;

    // Required pages (e.g. Profile) are always granted and cannot be removed.
    selectedModules.addAll(_catalog
        .where((m) => m['required'] == true)
        .map((m) => m['module_key'].toString()));

    // other roles available for delegation (exclude self when editing)
    final otherRoles = _roles.where((r) => r['id'].toString() != existing?['id']?.toString()).toList();

    bool saving = false;
    var groupMode = PageGroupMode.function;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final media = MediaQuery.of(ctx).size;
        final maxW = media.width - 24;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Sa.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxW > 520 ? 520 : maxW,
              maxHeight: media.height - 80,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(children: [
                  Icon(isEdit ? Icons.edit : Icons.add_moderator, color: Sa.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(isEdit ? 'Edit role' : 'New role',
                        style: Sa.cardTitle.copyWith(fontSize: 17)),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: nameCtl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Role name *', hintText: 'e.g. Faculty, Principal, Parent',
                          border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtl,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _sectionLabel('Pages this role can access')),
                      const SizedBox(width: Sa.gapXs),
                      PageGroupToggle(
                        mode: groupMode,
                        onChanged: (m) => setLocal(() => groupMode = m),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ...groupCatalog(_catalog, groupMode).entries.map((e) => _moduleSection(
                          e.key, e.value, selectedModules, setLocal)),
                    const SizedBox(height: 18),
                    _sectionLabel('Can add users into these roles'),
                    const Text('Holders of this role may create users assigned to the roles you tick.',
                        style: Sa.label),
                    const SizedBox(height: 8),
                    if (otherRoles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('No other roles yet — create more, then come back to delegate.',
                            style: Sa.label),
                      )
                    else
                      ...otherRoles.map((r) {
                        final id = r['id'].toString();
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Sa.accent,
                          value: selectedCreatable.contains(id),
                          title: Text(r['role_name']?.toString() ?? 'Role', style: Sa.value),
                          onChanged: (v) => setLocal(() =>
                              v == true ? selectedCreatable.add(id) : selectedCreatable.remove(id)),
                        );
                      }),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: Sa.gapXs),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Sa.accent, foregroundColor: Colors.white),
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtl.text.trim();
                            if (name.isEmpty) {
                              _snack('Role name is required', AppTheme.error);
                              return;
                            }
                            setLocal(() => saving = true);
                            try {
                              if (isEdit) {
                                await RolesService.updateRole(
                                  roleId: existing['id'].toString(),
                                  roleName: name,
                                  description: descCtl.text.trim(),
                                  modules: selectedModules.toList(),
                                  creatableRoleIds: selectedCreatable.toList(),
                                );
                              } else {
                                await RolesService.createRole(
                                  roleName: name,
                                  description: descCtl.text.trim(),
                                  modules: selectedModules.toList(),
                                  creatableRoleIds: selectedCreatable.toList(),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              _snack(isEdit ? 'Role updated' : 'Role created',
                                  AppTheme.greenPrimary);
                              _load();
                            } catch (e) {
                              setLocal(() => saving = false);
                              _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
                            }
                          },
                    child: Text(saving ? 'Saving…' : (isEdit ? 'Save' : 'Create')),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  void _showUpgradeDialog(String pageName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.workspace_premium, color: AppTheme.neutral600),
          SizedBox(width: 10),
          Expanded(child: Text('Premium feature')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('“$pageName” is not included in your organisation’s current plan.',
              style: Sa.value.copyWith(color: AppTheme.neutral800)),
          const SizedBox(height: 10),
          const Text('Ask your platform administrator to enable it for your organisation to start assigning it to your staff and students.',
              style: Sa.body),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: Sa.cardTitle.copyWith(color: AppTheme.neutral800));

  Widget _moduleSection(String section, List<Map<String, dynamic>> mods,
      Set<String> selected, void Function(void Function()) setLocal) {
    // Required + locked (premium) pages can't be toggled; select-all only affects the rest.
    final toggleable = mods
        .where((m) => m['required'] != true && m['locked'] != true)
        .map((m) => m['module_key'].toString()).toList();
    final allOn = toggleable.isNotEmpty && toggleable.every(selected.contains);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.borderRadius12,
          border: Border.all(color: Sa.stroke)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: const BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Expanded(
                child: Text(section,
                    style: Sa.value.copyWith(fontWeight: FontWeight.w700))),
            if (toggleable.isNotEmpty)
              TextButton(
                onPressed: () => setLocal(() =>
                    allOn ? selected.removeAll(toggleable) : selected.addAll(toggleable)),
                child: Text(allOn ? 'Clear' : 'Select all',
                    style: Sa.label.copyWith(color: Sa.accent, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        ...mods.map((m) {
          final key = m['module_key'].toString();
          final required = m['required'] == true;
          final locked = m['locked'] == true; // org didn't grant this page → premium
          final name = m['module_name']?.toString() ?? key;
          if (locked) {
            // Not in the organisation's plan — show a premium/upgrade row, not assignable.
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.lock_outline, size: 20, color: AppTheme.neutral400),
              title: Text(name,
                  style: Sa.value.copyWith(color: AppTheme.neutral500)),
              subtitle: Text("Not in your plan",
                  style: Sa.label.copyWith(color: AppTheme.neutral600)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                    color: AppTheme.neutral200, borderRadius: AppTheme.borderRadius8),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium, size: 13, color: AppTheme.neutral600),
                  SizedBox(width: 3),
                  Text('Premium',
                      style: TextStyle(
                          fontFamily: AppTheme.interFontFamily,
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              onTap: () => _showUpgradeDialog(name),
            );
          }
          return CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Sa.accent,
            value: required ? true : selected.contains(key),
            title: Text(name, style: Sa.value),
            subtitle: Text(required ? 'Always on — every user keeps this'
                : (m['path']?.toString() ?? ''),
                style: Sa.label.copyWith(
                    color: required ? Sa.accent : AppTheme.neutral400)),
            // Required pages (Profile) can't be switched off.
            onChanged: required
                ? null
                : (v) => setLocal(() => v == true ? selected.add(key) : selected.remove(key)),
          );
        }),
      ]),
    );
  }
}
