// lib/shared/widgets/org_switcher.dart
//
// Header control for ADMINS (authority): shows the active organisation and lets
// them switch between the organisations they own or create a new one. Renders nothing
// for other roles. Switching re-scopes the session (new JWT) via the backend.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../services/super_admin_service.dart';
import '../../features/organisation_management/widgets/organisation_create_dialog.dart';

class OrgSwitcher extends StatefulWidget {
  const OrgSwitcher({super.key});

  @override
  State<OrgSwitcher> createState() => _OrgSwitcherState();
}

class _OrgSwitcherState extends State<OrgSwitcher> {
  List<Map<String, dynamic>> _orgs = [];
  bool _loading = false;
  bool _busy = false;

  bool get _isAdmin => AuthSession.instance.role == 'authority';

  @override
  void initState() {
    super.initState();
    if (_isAdmin) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final organisations = await SuperAdminService.getMyOrganisations();
      if (!mounted) return;
      setState(() {
        _orgs = organisations;
        _loading = false;
      });
      // If the admin has organisations but no active one, adopt the first.
      final tid = AuthSession.instance.organisationId;
      if ((tid == null || tid.isEmpty) && organisations.isNotEmpty) {
        _switch(organisations.first['id'].toString(), silent: true);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _currentName {
    final tid = AuthSession.instance.organisationId;
    final match = _orgs.firstWhere(
      (s) => s['id']?.toString() == tid,
      orElse: () => const <String, dynamic>{},
    );
    final name = (match['name'] ?? '').toString();
    if (name.isNotEmpty) return name;
    return _orgs.isEmpty ? 'No organisation yet' : 'Select organisation';
  }

  Future<void> _switch(String organisationId, {bool silent = false}) async {
    if (_busy) return;
    if (!silent) setState(() => _busy = true);
    try {
      await SuperAdminService.switchOrganisation(organisationId: organisationId);
      if (!mounted) return;
      setState(() => _busy = false);
      // Re-enter the admin's home (Staff & Users) scoped to the new organisation.
      final uid = AuthSession.instance.userId ?? '';
      context.go('${AppConstants.adminStaffRoute}?userId=$uid&organisationId=$organisationId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _createOrg() {
    showDialog(
      context: context,
      builder: (_) => OrganisationCreateDialog(
        onOrganisationCreated: () async {
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Switch organisation',
      offset: const Offset(0, 44),
      onSelected: (v) {
        if (v == '__create__') {
          _createOrg();
        } else {
          _switch(v);
        }
      },
      itemBuilder: (context) => [
        ..._orgs.map((s) {
          final id = s['id'].toString();
          final name = (s['name'] ?? 'Organisation').toString();
          final active = id == AuthSession.instance.organisationId;
          return PopupMenuItem<String>(
            value: id,
            child: Row(children: [
              Icon(active ? Icons.check_circle : Icons.business,
                  size: 18, color: active ? AppTheme.greenPrimary : AppTheme.neutral400),
              const SizedBox(width: 10),
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
            ]),
          );
        }),
        if (_orgs.isNotEmpty) const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__create__',
          child: Row(children: [
            Icon(Icons.add_business, size: 18, color: AppTheme.greenPrimary),
            SizedBox(width: 10),
            Text('Create organisation'),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: AppTheme.borderRadius8,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.business, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              _loading ? 'Loading…' : _currentName,
              style: AppTheme.labelSmall.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          _busy
              ? const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}
