// lib/features/super_admin/screens/module_access_screen.dart
//
// Super-admin: grant each ORGANISATION the set of pages it may use ("what they
// paid for"). Lists organisations; tap one to toggle its pages. The admin then
// distributes those pages to their users; pages left off show as Premium/locked.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../widgets/org_pages_dialog.dart';
import '../widgets/sa_widgets.dart';

class ModuleAccessScreen extends StatefulWidget {
  const ModuleAccessScreen({super.key});

  @override
  State<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends State<ModuleAccessScreen> {
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
      final orgs = await SuperAdminService.getTenants();
      if (!mounted) return;
      setState(() {
        _orgs = orgs;
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

  Future<void> _edit(Map<String, dynamic> org) async {
    await showOrgPagesDialog(
      context,
      tenantId: org['id'].toString(),
      tenantName: (org['school_name'] ?? org['name'] ?? 'Organisation').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Module Access',
          subtitle: 'Choose which pages each organisation can use',
          icon: Icons.tune,
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SaLoading(message: 'Loading organisations…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    if (_orgs.isEmpty) {
      return const SaStateView(
        icon: Icons.tune,
        title: 'No organisations yet',
        subtitle: 'Once an admin creates a school, grant its pages here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _orgs.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _orgRow(_orgs[i]),
    );
  }

  Widget _orgRow(Map<String, dynamic> org) {
    final name = (org['school_name'] ?? org['name'] ?? 'Organisation').toString();
    final code = (org['school_code'] ?? '').toString();
    return SaCard(
      onTap: () => _edit(org),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Sa.accent.withValues(alpha: 0.10),
            borderRadius: AppTheme.borderRadius12,
          ),
          child: const Icon(Icons.school, color: Sa.accent, size: 22),
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
              if (code.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(code,
                    style: Sa.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
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
