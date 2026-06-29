// lib/features/super_admin/screens/institution_groups_screen.dart
//
// Super-admin: manage INSTITUTION GROUPS — the top-level grouping above
// organisations. The super-admin creates a group here, then creates admins into it
// (Admins page) and sets its page ceilings (Module Access page). The admins create
// the actual organisations (schools/colleges) that belong to the group.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../widgets/sa_widgets.dart';

class InstitutionGroupsScreen extends StatefulWidget {
  const InstitutionGroupsScreen({super.key});

  @override
  State<InstitutionGroupsScreen> createState() => _InstitutionGroupsScreenState();
}

class _InstitutionGroupsScreenState extends State<InstitutionGroupsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _groups = [];

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
      final g = await SuperAdminService.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = g;
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

  void _toast(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New institution group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Group name *',
            hintText: 'e.g. Acme Education Group',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    try {
      await SuperAdminService.createGroup(name: name);
      _toast('Group "$name" created', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _viewOrganisations(Map<String, dynamic> group) async {
    final gid = group['id'].toString();
    final name = (group['name'] ?? 'Group').toString();
    // A centered dialog (not a bottom sheet): it sits in the middle of the screen
    // and reads correctly on wide desktop/web as well as on narrow phones. A
    // bottom sheet anchors to the bottom edge and looks broken on desktop.
    showDialog<void>(
      context: context,
      builder: (ctx) => _GroupOrgsDialog(groupId: gid, groupName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Institution Groups',
          subtitle: 'Top-level groups — each holds admins + organisations',
          icon: Icons.workspaces_outline,
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'Create group',
            onPressed: _create,
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading groups…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    if (_groups.isEmpty) {
      return SaStateView(
        icon: Icons.workspaces_outline,
        title: 'No institution groups yet',
        subtitle: 'Create a group, then add admins to it and set its page access.',
        action: SaPrimaryButton(label: 'Create group', icon: Icons.add, onPressed: _create),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _groupRow(_groups[i]),
    );
  }

  Widget _groupRow(Map<String, dynamic> group) {
    final name = (group['name'] ?? 'Group').toString();
    final code = (group['code'] ?? '').toString();
    final admins = (group['admin_count'] ?? 0).toString();
    final orgs = (group['org_count'] ?? 0).toString();
    final active = group['is_active'] != false; // default true
    return SaCard(
      onTap: () => _viewOrganisations(group),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(
            icon: Icons.workspaces_outline,
            title: name,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              SaStatusPill(
                text: active ? 'Active' : 'Inactive',
                color: active ? AppTheme.greenPrimary : AppTheme.neutral400,
                icon: active ? Icons.check_circle : Icons.block,
              ),
              _groupMenu(group, active),
            ]),
          ),
          const SizedBox(height: Sa.gap),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SaStatusPill(text: code, color: AppTheme.neutral400),
            SaStatusPill(text: '$admins admin(s)', icon: Icons.badge_outlined),
            SaStatusPill(text: '$orgs organisation(s)', icon: Icons.apartment_outlined),
          ]),
        ],
      ),
    );
  }

  Widget _groupMenu(Map<String, dynamic> group, bool active) {
    return PopupMenuButton<String>(
      tooltip: 'Group actions',
      icon: const Icon(Icons.more_vert, color: AppTheme.neutral500),
      onSelected: (v) {
        if (v == 'view') _viewOrganisations(group);
        if (v == 'status') _toggleGroupStatus(group, active);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'view', child: Row(children: [
          Icon(Icons.apartment_outlined, size: 18, color: AppTheme.neutral600),
          SizedBox(width: 10), Text('View organisations')])),
        PopupMenuItem(value: 'status', child: Row(children: [
          Icon(active ? Icons.block : Icons.check_circle, size: 18,
              color: active ? AppTheme.neutral600 : AppTheme.greenPrimary),
          const SizedBox(width: 10),
          Text(active ? 'Deactivate group' : 'Activate group')])),
      ],
    );
  }

  Future<void> _toggleGroupStatus(Map<String, dynamic> group, bool active) async {
    final name = (group['name'] ?? 'this group').toString();
    final ok = await _confirm(
      title: active ? 'Deactivate "$name"?' : 'Activate "$name"?',
      message: active
          ? 'Nobody in this group — its admins, or any staff in any of its '
              'organisations — will be able to log in until it is reactivated.'
          : 'The group and its organisations can be used again.',
      confirmLabel: active ? 'Deactivate' : 'Activate',
      danger: active,
    );
    if (ok != true) return;
    try {
      await SuperAdminService.setGroupStatus(
          groupId: group['id'].toString(), isActive: !active);
      _toast(active ? 'Group deactivated' : 'Group activated', AppTheme.greenPrimary);
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
}

/// A centered dialog listing the organisations that belong to a group (read-only —
/// the group's admins create/manage them).
class _GroupOrgsDialog extends StatefulWidget {
  final String groupId;
  final String groupName;
  const _GroupOrgsDialog({required this.groupId, required this.groupName});

  @override
  State<_GroupOrgsDialog> createState() => _GroupOrgsDialogState();
}

class _GroupOrgsDialogState extends State<_GroupOrgsDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orgs = [];

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
      final o = await SuperAdminService.getGroupOrganisations(widget.groupId);
      if (!mounted) return;
      setState(() {
        _orgs = o;
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = media.size.width - 24;
    final maxH = media.size.height - 80;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW > 520 ? 520 : maxW,
          maxHeight: maxH,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleBar(context),
            const Divider(height: 1),
            Flexible(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Sa.accent.withValues(alpha: 0.10),
            borderRadius: AppTheme.borderRadius8,
          ),
          child: const Icon(Icons.workspaces_outline, color: Sa.accent, size: 20),
        ),
        const SizedBox(width: Sa.gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.groupName,
                  style: Sa.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              const Text('Organisations in this group', style: Sa.label),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.neutral500),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: SaLoading());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: SaStateView.error(message: _error!, onRetry: _load),
      );
    }
    if (_orgs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Text("No organisations yet — the group's admins create them.",
            style: Sa.body, textAlign: TextAlign.center),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: _orgs.map(_orgTile).toList(),
    );
  }

  Widget _orgTile(Map<String, dynamic> o) {
    final active = o['is_active'] != false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(Icons.apartment,
          color: active ? Sa.accent : AppTheme.neutral400, size: 20),
      title: Text((o['name'] ?? '').toString(),
          style: Sa.value, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${o['org_type'] ?? ''} · ${o['code'] ?? ''}', style: Sa.label),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        SaStatusPill(
          text: active ? 'Active' : 'Inactive',
          color: active ? AppTheme.greenPrimary : AppTheme.neutral400,
        ),
        PopupMenuButton<String>(
          tooltip: 'Organisation actions',
          icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.neutral500),
          padding: EdgeInsets.zero,
          onSelected: (v) {
            if (v == 'status') _toggleOrg(o, active);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'status', child: Row(children: [
              Icon(active ? Icons.block : Icons.check_circle, size: 18,
                  color: active ? AppTheme.neutral600 : AppTheme.greenPrimary),
              const SizedBox(width: 10),
              Text(active ? 'Deactivate' : 'Activate')])),
          ],
        ),
      ]),
    );
  }

  Future<void> _toggleOrg(Map<String, dynamic> o, bool active) async {
    try {
      await SuperAdminService.setOrganisationStatus(
          organisationId: o['id'].toString(), isActive: !active);
      _toast(active ? 'Organisation deactivated' : 'Organisation activated',
          AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  void _toast(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }
}
