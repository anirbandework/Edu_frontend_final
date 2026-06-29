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
import '../../super_admin/widgets/sa_widgets.dart';

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
    // Exclude the dashboard tile itself; show every other enabled page.
    final pages = PermissionStore.instance.modules
        .where((m) => m.enabled && m.key != 'dashboard' && m.path.isNotEmpty)
        .toList();

    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Your workspace',
          subtitle:
              '${pages.length} page${pages.length == 1 ? '' : 's'} available to you',
          icon: Icons.badge_outlined,
        ),
      ),
      child: _body(pages),
    );
  }

  Widget _body(List<ModulePerm> pages) {
    if (_loading) return const SaLoading(message: 'Loading…');
    if (pages.isEmpty) {
      return const SaStateView(
        icon: Icons.lock_outline,
        title: 'No pages assigned yet',
        subtitle: 'Ask your administrator to grant your role access.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      children: [
        LayoutBuilder(builder: (context, c) {
          final cross = c.maxWidth > 720 ? 3 : (c.maxWidth > 460 ? 2 : 1);
          return GridView.count(
            crossAxisCount: cross,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Sa.gap,
            crossAxisSpacing: Sa.gap,
            childAspectRatio: 2.6,
            children: pages.map(_pageCard).toList(),
          );
        }),
      ],
    );
  }

  Widget _pageCard(ModulePerm m) {
    return SaCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _open(m),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Sa.accent.withValues(alpha: 0.12),
            borderRadius: AppTheme.borderRadius12,
          ),
          child: Icon(_moduleIcons[m.key] ?? Icons.widgets_outlined,
              color: Sa.accent),
        ),
        const SizedBox(width: Sa.gap),
        Expanded(
          child: Text(
            m.name.isEmpty ? m.key : m.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Sa.cardTitle,
          ),
        ),
        const Icon(Icons.chevron_right, color: AppTheme.neutral400),
      ]),
    );
  }
}
