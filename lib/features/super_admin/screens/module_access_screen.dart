// lib/features/super_admin/screens/module_access_screen.dart
//
// Super-admin: grant each ORGANISATION the set of pages it may use ("what they
// paid for"). Lists organisations; tap one to toggle its pages. The admin then
// distributes those pages to their users; pages left off show as Premium/locked.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../widgets/org_pages_dialog.dart';
import '../widgets/super_admin_action_bar.dart';
import '../widgets/super_admin_header.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SuperAdminHeader(
          title: 'Module Access',
          subtitle: 'Choose which pages each organisation can use',
          icon: Icons.tune,
        ),
        const SizedBox(height: 12),
        SuperAdminActionBar(
          actions: [
            SaActionButton(
              icon: Icons.refresh,
              label: 'Refresh',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ],
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
          Text(_error!,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    if (_orgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No organisations yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 4),
          Text('Once an admin creates a school, grant its pages here.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400),
              textAlign: TextAlign.center),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _orgs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _orgRow(_orgs[i]),
      ),
    );
  }

  Widget _orgRow(Map<String, dynamic> org) {
    final name = (org['school_name'] ?? org['name'] ?? 'Organisation').toString();
    final code = (org['school_code'] ?? '').toString();
    return InkWell(
      borderRadius: AppTheme.borderRadius12,
      onTap: () => _edit(org),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCardDecoration,
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.green50,
            child: const Icon(Icons.school, color: AppTheme.greenPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (code.isNotEmpty)
                  Text(code,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
            child: Text('Manage pages',
                style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.greenPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppTheme.neutral400),
        ]),
      ),
    );
  }
}
