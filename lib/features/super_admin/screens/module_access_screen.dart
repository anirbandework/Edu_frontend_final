// lib/features/super_admin/screens/module_access_screen.dart
//
// Super-admin: grant each ORGANISATION the set of pages it may use ("what they
// paid for"). Lists organisations; tap one to toggle its pages. The admin then
// distributes those pages to their users; pages left off show as Premium/locked.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../widgets/group_pages_dialog.dart';
import '../widgets/sa_widgets.dart';

class ModuleAccessScreen extends StatefulWidget {
  const ModuleAccessScreen({super.key});

  @override
  State<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends State<ModuleAccessScreen> {
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
      final orgs = await SuperAdminService.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = orgs;
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

  Future<void> _edit(Map<String, dynamic> group) async {
    await showGroupPagesDialog(
      context,
      groupId: group['id'].toString(),
      groupName: (group['name'] ?? 'Group').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Module Access',
          subtitle: 'Set the page ceilings for each institution group',
          icon: Icons.tune,
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SaLoading(message: 'Loading groups…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    if (_groups.isEmpty) {
      return const SaStateView(
        icon: Icons.tune,
        title: 'No institution groups yet',
        subtitle: 'Create a group first, then set its page ceilings here.',
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
    final admins = (group['admin_count'] ?? 0).toString();
    final orgs = (group['org_count'] ?? 0).toString();
    return SaCard(
      onTap: () => _edit(group),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Sa.accent.withValues(alpha: 0.10),
            borderRadius: AppTheme.borderRadius12,
          ),
          child: const Icon(Icons.workspaces_outline, color: Sa.accent, size: 22),
        ),
        const SizedBox(width: Sa.gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: Sa.cardTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$admins admin(s) · $orgs organisation(s)',
                  style: Sa.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: Sa.gapXs),
        const SaStatusPill(
          text: 'Manage pages',
          color: Sa.accent,
          icon: Icons.tune,
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppTheme.neutral400),
      ]),
    );
  }
}
