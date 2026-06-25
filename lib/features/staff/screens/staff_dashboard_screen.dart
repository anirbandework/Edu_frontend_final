// lib/features/staff/screens/staff_dashboard_screen.dart
//
// Home hub for a unified dynamic-role user (staff). Their pages are defined
// entirely by the role the admin assigned — this screen renders exactly those
// granted pages as quick-launch cards (cross-section), driven by my-permissions.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/permission_store.dart';

/// Map a module key to a representative icon (the permissions API ships a string
/// icon name; we keep a small local map so the hub looks intentional).
const Map<String, IconData> _moduleIcons = {
  'dashboard': Icons.dashboard_outlined,
  'profile': Icons.person_outline,
  'notifications': Icons.notifications_outlined,
  'students': Icons.people_outline,
  'teachers': Icons.person_2_outlined,
  'classes': Icons.class_outlined,
  'timetable': Icons.schedule_outlined,
  'attendance': Icons.how_to_reg_outlined,
  'send_notification': Icons.send_outlined,
  'assessments': Icons.assessment_outlined,
  'exams': Icons.fact_check_outlined,
  'analytics': Icons.insights_outlined,
  'settings': Icons.settings_outlined,
  'invite': Icons.person_add_outlined,
  'rbac_management': Icons.admin_panel_settings_outlined,
  'staff': Icons.badge_outlined,
  'my_classes': Icons.class_outlined,
  'assignments': Icons.assignment_outlined,
  'grades': Icons.grade_outlined,
};

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ensurePermissions();
  }

  Future<void> _ensurePermissions() async {
    if (!PermissionStore.instance.loaded) {
      await PermissionStore.instance.load();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _open(ModulePerm m) {
    final auth = AuthSession.instance;
    final qs = <String, String>{
      if (auth.userId != null && auth.userId!.isNotEmpty) 'userId': auth.userId!,
      if (auth.tenantId != null && auth.tenantId!.isNotEmpty) 'tenantId': auth.tenantId!,
    };
    final uri = Uri(path: m.path, queryParameters: qs.isEmpty ? null : qs);
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    // Exclude the dashboard tile itself; show every other enabled page.
    final pages = PermissionStore.instance.modules
        .where((m) => m.enabled && m.key != 'dashboard' && m.path.isNotEmpty)
        .toList();

    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: () async {
        await PermissionStore.instance.load();
        if (mounted) setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppTheme.borderRadius16,
            ),
            child: Row(children: [
              const Icon(Icons.badge, color: Colors.white, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Welcome',
                      style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text('Your workspace',
                      style: AppTheme.labelLarge.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${pages.length} page${pages.length == 1 ? '' : 's'} available to you',
                      style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          if (pages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(children: [
                Icon(Icons.lock_outline, size: 44, color: AppTheme.neutral400),
                const SizedBox(height: 12),
                Text('No pages assigned yet',
                    style: AppTheme.labelLarge.copyWith(color: AppTheme.neutral600)),
                const SizedBox(height: 4),
                Text('Ask your administrator to grant your role access.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
              ]),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final cross = c.maxWidth > 720 ? 3 : (c.maxWidth > 460 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: pages.map(_pageCard).toList(),
              );
            }),
        ],
      ),
    );
  }

  Widget _pageCard(ModulePerm m) {
    return InkWell(
      borderRadius: AppTheme.borderRadius12,
      onTap: () => _open(m),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCardDecoration,
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.green50, borderRadius: AppTheme.borderRadius12),
            child: Icon(_moduleIcons[m.key] ?? Icons.widgets_outlined, color: AppTheme.greenPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(m.name.isEmpty ? m.key : m.name,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.neutral400),
        ]),
      ),
    );
  }
}
