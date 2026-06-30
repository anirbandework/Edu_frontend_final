// lib/features/rbac/screens/role_management_screen.dart
//
// Dynamic Roles & Access (admin). The admin defines roles freely — "Teacher",
// "Faculty", "Head", "Parent", "HOD", anything — names each, picks its pages
// from the WHOLE catalog (any section), and chooses which other roles it may
// create users into (delegation). Nothing is hardcoded; every role is dynamic.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../services/roles_service.dart';
import '../../../shared/widgets/page_group_toggle.dart';
import '../../../shared/widgets/sa_widgets.dart';
import '../../../shared/widgets/custom_fields.dart';
import '../widgets/role_templates.dart';

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
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
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
    final roleId = role['id'].toString();
    final roleName = (role['role_name'] ?? 'this role').toString();

    // How many users hold this role? Drives the impact prompt.
    int count;
    try {
      count = await RolesService.getRoleUsage(roleId);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
      return;
    }
    if (!mounted) return;

    final otherRoles = _roles.where((r) => r['id'].toString() != roleId).toList();
    bool reassign = count > 0 && otherRoles.isNotEmpty; // default to reassign when possible
    String? targetId = otherRoles.isNotEmpty ? otherRoles.first['id'].toString() : null;
    bool deleting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text('Delete "$roleName"?'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (count == 0)
                  const Text('This role has no users assigned. It will be permanently removed.',
                      style: Sa.body)
                else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: AppTheme.borderRadius8,
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$count ${count == 1 ? "user has" : "users have"} this role. '
                          'They keep their accounts — choose what happens to their access:',
                          style: Sa.body.copyWith(color: AppTheme.neutral800),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<bool>(
                    groupValue: reassign,
                    onChanged: (v) => setLocal(() => reassign = v ?? false),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (otherRoles.isNotEmpty)
                        const RadioListTile<bool>(
                          value: true,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Sa.accent,
                          title: Text('Move them to another role'),
                        ),
                      if (otherRoles.isNotEmpty && reassign)
                        Padding(
                          padding: const EdgeInsets.only(left: 32, bottom: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: targetId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                isDense: true, border: OutlineInputBorder()),
                            items: otherRoles
                                .map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                                    value: r['id'].toString(),
                                    child: Text(r['role_name']?.toString() ?? 'Role',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setLocal(() => targetId = v),
                          ),
                        ),
                      RadioListTile<bool>(
                        value: false,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Sa.accent,
                        title: const Text('Leave them unassigned'),
                        subtitle: Text(
                          'They will be deactivated and cannot sign in until you give them a new role.',
                          style: Sa.label.copyWith(color: AppTheme.error),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: deleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error, foregroundColor: Colors.white),
              onPressed: deleting
                  ? null
                  : () async {
                      setLocal(() => deleting = true);
                      try {
                        await RolesService.deleteRole(roleId,
                            reassignToRoleId: (count > 0 && reassign) ? targetId : null);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack('Role deleted', AppTheme.greenPrimary);
                        _load();
                      } catch (e) {
                        setLocal(() => deleting = false);
                        _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
                      }
                    },
              child: Text(deleting ? 'Deleting…' : 'Delete role'),
            ),
          ],
        );
      }),
    );
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
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            SaHeaderAction(
              icon: Icons.add,
              tooltip: 'New role',
              onPressed: _catalog.isEmpty ? null : () => _openEditor(),
            ),
            const SizedBox(width: Sa.gapXs),
            SaHeaderAction(
              icon: Icons.auto_awesome_outlined,
              tooltip: 'Role templates',
              onPressed: _openTemplates,
            ),
            const SizedBox(width: Sa.gapXs),
            SaHeaderAction(
              icon: Icons.lock_open_outlined,
              tooltip: 'Page access',
              onPressed: (_catalog.isEmpty || _roles.isEmpty) ? null : _openPageAccessManager,
            ),
          ]),
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
                'Create the roles your organisation needs — Student, Teacher, Parent and more. '
                'Each role collects its own details and can be granted the pages it needs. '
                'Tap ✨ Templates for ready-made roles.',
                style: Sa.body.copyWith(color: AppTheme.neutral700),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Sa.gapLg),
        if (_roles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(children: [
              const SaStateView(
                icon: Icons.shield_outlined,
                title: 'No roles yet',
                subtitle: 'Start from a ready-made template, or create one from scratch.',
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _openTemplates,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Browse role templates'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Sa.accent, foregroundColor: Colors.white),
              ),
            ]),
          )
        else ...[
          _searchBar(),
          const SizedBox(height: Sa.gap),
          ..._filteredRoles().map((r) => Padding(
                padding: const EdgeInsets.only(bottom: Sa.gap),
                child: _roleCard(r),
              )),
          if (_filteredRoles().isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: SaStateView(
                icon: Icons.search_off,
                title: 'No roles match',
                subtitle: 'Try a different search.',
              ),
            ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _filteredRoles() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _roles;
    return _roles.where((r) {
      final name = (r['role_name'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search roles',
        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.neutral500),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.neutral500),
                tooltip: 'Clear',
                onPressed: () {
                  _searchCtl.clear();
                  setState(() => _query = '');
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
    );
  }

  Widget _roleCard(Map<String, dynamic> role) {
    final desc = (role['description'] ?? '').toString();
    return SaCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Sa.radius),
          onTap: () => _openRoleDetails(role),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                  Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: Sa.label),
                ],
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppTheme.neutral400),
          ]),
          ),
        ),
      ),
    );
  }

  /// Read-only details view for a role: its pages + the information it collects,
  /// with Edit / Delete / Manage-pages actions.
  Future<void> _openRoleDetails(Map<String, dynamic> role) async {
    Map<String, dynamic> detail;
    try {
      detail = await RolesService.getRoleDetail(role['id'].toString());
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
      return;
    }
    if (!mounted) return;

    final modules =
        (detail['modules'] as List? ?? const []).map((e) => e.toString()).toSet();
    final pageNames = _catalog
        .where((m) => modules.contains(m['module_key'].toString()))
        .map((m) => (m['module_name'] ?? m['module_key']).toString())
        .toList();
    final fields = (detail['custom_fields'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final name = (detail['role_name'] ?? role['role_name'] ?? 'Role').toString();
    final desc = (detail['description'] ?? '').toString();
    final roleId = role['id'].toString();

    await showDialog(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx).size;
        final maxW = media.width - 24;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Sa.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxW > 520 ? 520 : maxW, maxHeight: media.height - 80),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Sa.accent.withValues(alpha: 0.12),
                        borderRadius: AppTheme.borderRadius8),
                    child: const Icon(Icons.badge_outlined, color: Sa.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: Sa.cardTitle.copyWith(fontSize: 17)),
                      if (desc.isNotEmpty)
                        Text(desc, style: Sa.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: AppTheme.neutral500)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: _sectionLabel('Page access')),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openPageAccessManager(initialRoleId: roleId);
                        },
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(foregroundColor: Sa.accent),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    if (pageNames.isEmpty)
                      const Text('No pages granted yet.', style: Sa.label)
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: pageNames
                            .map((n) => Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: const BoxDecoration(
                                      color: AppTheme.green50,
                                      borderRadius: AppTheme.borderRadius8),
                                  child: Text(n,
                                      style: Sa.label.copyWith(
                                          color: Sa.accent, fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    _sectionLabel('Information collected'),
                    const SizedBox(height: 4),
                    if (fields.isEmpty)
                      const Text('No custom fields. Tap Edit to add some.', style: Sa.label)
                    else
                      ...fields.map(_detailFieldRow),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(role);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openEditor(existing: role);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit role'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Sa.accent, foregroundColor: Colors.white),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _detailFieldRow(Map<String, dynamic> f) {
    final label = (f['label'] ?? '').toString();
    final type = customFieldTypeLabel((f['type'] ?? 'text').toString());
    final required = f['required'] == true;
    final options = (f['options'] as List?)?.map((e) => e.toString()).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 5, right: 8),
          child: Icon(Icons.circle, size: 6, color: Sa.accent),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(label,
                    style: Sa.value.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              if (required) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: AppTheme.borderRadius8),
                  child: Text('Required',
                      style: Sa.label.copyWith(
                          color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 10)),
                ),
              ],
            ]),
            Text(
              options != null && options.isNotEmpty ? '$type · $options' : type,
              style: Sa.label.copyWith(color: AppTheme.neutral500),
            ),
          ]),
        ),
      ]),
    );
  }

  // ---------------- templates ----------------
  /// Browse ready-made educational roles and add one in a tap (or customise first).
  Future<void> _openTemplates() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx).size;
        final maxW = media.width - 24;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Sa.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxW > 560 ? 560 : maxW, maxHeight: media.height - 80),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_outlined, color: Sa.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Role templates', style: Sa.cardTitle.copyWith(fontSize: 17)),
                      const Text('Ready-made roles with the right fields — add or customise.',
                          style: Sa.label),
                    ]),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final cat in kRoleTemplateCategories) ...[
                      _categoryHeader(cat),
                      ...kRoleTemplates
                          .where((t) => t.category == cat)
                          .map((t) => _templateCard(ctx, t)),
                      const SizedBox(height: 6),
                    ],
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _categoryHeader(String c) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        child: Text(c.toUpperCase(),
            style: Sa.label.copyWith(
                color: Sa.accent, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );

  Widget _templateCard(BuildContext dialogCtx, RoleTemplate t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadius12,
        border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: Sa.accent.withValues(alpha: 0.12), borderRadius: AppTheme.borderRadius8),
            child: Icon(t.icon, color: Sa.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: Sa.cardTitle),
              Text(t.description,
                  style: Sa.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: t.fields.map((f) {
            final req = f['required'] == true;
            final label = (f['label'] ?? '').toString();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                  color: AppTheme.neutral100, borderRadius: AppTheme.borderRadius8),
              child: Text(req ? '$label *' : label,
                  style: Sa.label.copyWith(color: AppTheme.neutral700)),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _openEditor(template: t);
              },
              style: OutlinedButton.styleFrom(
                  foregroundColor: Sa.accent,
                  side: BorderSide(color: Sa.accent.withValues(alpha: 0.5))),
              child: const Text('Customise'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _addTemplate(dialogCtx, t),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add role'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Sa.accent, foregroundColor: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _addTemplate(BuildContext dialogCtx, RoleTemplate t) async {
    try {
      await RolesService.createRole(
        roleName: t.name,
        description: t.description,
        customFields: t.fields.map((f) => Map<String, dynamic>.from(f)).toList(),
      );
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      _snack('“${t.name}” role added', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  // ---------------- editor ----------------
  Future<void> _openEditor({Map<String, dynamic>? existing, RoleTemplate? template}) async {
    final isEdit = existing != null;
    final nameCtl = TextEditingController(
        text: (existing?['role_name'] ?? template?.name ?? '').toString());
    final descCtl = TextEditingController(
        text: (existing?['description'] ?? template?.description ?? '').toString());
    // Page access is NOT edited here — it's managed from the "Page access" header
    // button. This form is only name + description + custom fields.
    // Admin-defined custom fields for this role (grade, parent name, ...). The
    // CustomFieldsBuilder owns the live editing; we keep the latest list here for save.
    var customFields = <Map<String, dynamic>>[];

    if (isEdit) {
      try {
        final detail = await RolesService.getRoleDetail(existing['id'].toString());
        customFields = (detail['custom_fields'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } catch (e) {
        _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
      }
    } else if (template != null) {
      // Prefill a fresh role from the chosen template (deep-copied so edits don't
      // mutate the const template data).
      customFields = template.fields
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
    }

    // The detail fetch above is async — bail if the screen went away meanwhile,
    // so we never open a dialog against a defunct BuildContext.
    if (!mounted) return;

    bool saving = false;

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
                          labelText: 'Role name *', hintText: 'e.g. Faculty, Head, Parent',
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
                    _sectionLabel('Information to collect for this role'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: Sa.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Every role needs different details. Add the fields you want filled in '
                              'whenever someone is added to this role — they appear automatically on '
                              'the Add User form.',
                              style: Sa.body.copyWith(color: AppTheme.neutral800),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text('For example:',
                            style: Sa.label.copyWith(
                                color: AppTheme.neutral700, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        _exampleLine('Student', 'the grade/class they study in, parent name & phone'),
                        _exampleLine('Teacher / Professor', 'years of experience, qualification, subject'),
                        const SizedBox(height: 6),
                        Text('Turn on “Required” for anything that must not be left blank.',
                            style: Sa.label.copyWith(color: AppTheme.neutral700)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    CustomFieldsBuilder(
                      initial: customFields,
                      onChanged: (v) => customFields = v,
                    ),
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
                                  customFields: customFields,
                                );
                              } else {
                                await RolesService.createRole(
                                  roleName: name,
                                  description: descCtl.text.trim(),
                                  customFields: customFields,
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

  /// "•  Role — examples" line for the custom-fields explainer.
  Widget _exampleLine(String role, String examples) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: RichText(
          text: TextSpan(
            style: Sa.label.copyWith(color: AppTheme.neutral700),
            children: [
              const TextSpan(text: '•  '),
              TextSpan(
                  text: '$role — ',
                  style: Sa.label.copyWith(
                      color: AppTheme.neutral800, fontWeight: FontWeight.w700)),
              TextSpan(text: examples),
            ],
          ),
        ),
      );

  /// Header "Page access" flow: pick a role, then tick the pages it can reach.
  /// Saved independently of role create/edit (which only handles name + fields).
  Future<void> _openPageAccessManager({String? initialRoleId}) async {
    if (_roles.isEmpty) {
      _snack('Create a role first.', AppTheme.error);
      return;
    }
    var roleId = (initialRoleId != null &&
            _roles.any((r) => r['id'].toString() == initialRoleId))
        ? initialRoleId
        : _roles.first['id'].toString();
    final selected = <String>{};
    var groupMode = PageGroupMode.function;
    var busy = true; // loading the selected role's pages
    var saving = false;

    // Load a role's currently-granted pages into `selected` (+ always-on required).
    Future<void> fetchInto(String rid) async {
      selected.clear();
      try {
        final detail = await RolesService.getRoleDetail(rid);
        selected.addAll((detail['modules'] as List? ?? const []).map((e) => e.toString()));
      } catch (e) {
        _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
      }
      selected.addAll(_catalog
          .where((m) => m['required'] == true)
          .map((m) => m['module_key'].toString()));
    }

    await fetchInto(roleId);
    busy = false;
    if (!mounted) return;

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
                maxWidth: maxW > 520 ? 520 : maxW, maxHeight: media.height - 80),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
                child: Row(children: [
                  const Icon(Icons.lock_open_outlined, color: Sa.accent),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Page access', style: Sa.cardTitle.copyWith(fontSize: 17))),
                  PageGroupToggle(mode: groupMode, onChanged: (m) => setLocal(() => groupMode = m)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: DropdownButtonFormField<String>(
                  initialValue: roleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Role', isDense: true, border: OutlineInputBorder()),
                  items: _roles
                      .map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                          value: r['id'].toString(),
                          child: Text(r['role_name']?.toString() ?? 'Role',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) async {
                          if (v == null || v == roleId) return;
                          roleId = v;
                          setLocal(() => busy = true);
                          await fetchInto(v);
                          setLocal(() => busy = false);
                        },
                ),
              ),
              Flexible(
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Sa.accent))),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ...groupCatalog(_catalog, groupMode).entries.map(
                              (e) => _moduleSection(e.key, e.value, selected, setLocal)),
                          if (selected.contains('staff')) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                  color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Icon(Icons.info_outline, size: 18, color: Sa.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'With “Staff & Users” granted, holders of this role can add '
                                    'users into any role in this organisation and see all roles.',
                                    style: Sa.label.copyWith(color: AppTheme.neutral800),
                                  ),
                                ),
                              ]),
                            ),
                          ],
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
                    onPressed: (saving || busy)
                        ? null
                        : () async {
                            setLocal(() => saving = true);
                            try {
                              await RolesService.updateRole(
                                  roleId: roleId, modules: selected.toList());
                              if (ctx.mounted) Navigator.pop(ctx);
                              _snack('Page access updated', AppTheme.greenPrimary);
                            } catch (e) {
                              setLocal(() => saving = false);
                              _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
                            }
                          },
                    child: Text(saving ? 'Saving…' : 'Save'),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

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
