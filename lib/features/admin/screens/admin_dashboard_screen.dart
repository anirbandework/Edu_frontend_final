// lib/features/admin/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/school_authority_session.dart';
import '../../../services/school_authority_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _authorityData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuthority();
    });
  }

  void _initializeAuthority() {
    // Extract parameters from URL
    final state = GoRouterState.of(context);
    final authorityId = state.uri.queryParameters['userId'];
    final tenantId = state.uri.queryParameters['tenantId'];

    if (authorityId != null && tenantId != null) {
      // Set authority data in session
      AuthoritySession.setSession(authorityId: authorityId, tenantId: tenantId);
      _loadAuthorityData();
    } else {
      // Check if we already have a session
      if (AuthoritySession.hasValidSession) {
        _loadAuthorityData();
      } else {
        setState(() {
          _error = 'Authority ID or Tenant ID not provided';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAuthorityData() async {
    if (!AuthoritySession.hasValidSession) {
      setState(() {
        _error = 'Invalid authority session';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load only authority data from the single API endpoint
      final authorityData = await AuthorityService.getAuthorityById(AuthoritySession.authorityId!);

      if (mounted) {
        setState(() {
          _authorityData = authorityData;
          _isLoading = false;
        });

        // Update session with authority data
        AuthoritySession.setSession(
          authorityId: AuthoritySession.authorityId!,
          tenantId: AuthoritySession.tenantId!,
          userData: _authorityData,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: _headerTitle(),
          subtitle: _headerSubtitle(),
          icon: Icons.admin_panel_settings,
        ),
      ),
      child: _body(),
    );
  }

  String _headerTitle() {
    if (_authorityData == null) return 'Admin Dashboard';
    final firstName = _getStringValue(_authorityData!['first_name']) ?? '';
    final lastName = _getStringValue(_authorityData!['last_name']) ?? '';
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? 'Welcome, $name' : 'Welcome, Admin';
  }

  String _headerSubtitle() {
    if (_authorityData == null) return 'School administration & management';
    final position = _getStringValue(_authorityData!['position']) ?? '';
    final authorityDetails =
        _authorityData!['authority_details'] as Map<String, dynamic>? ?? {};
    final department = _getStringValue(authorityDetails['department']) ?? '';
    final info = _buildAuthorityInfo(position, department);
    return info.isNotEmpty ? info : 'School administration & management';
  }

  Widget _body() {
    if (_isLoading) return const SaLoading(message: 'Loading dashboard…');
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _loadAuthorityData);
    }
    if (_authorityData == null) {
      return SaStateView(
        icon: Icons.admin_panel_settings,
        title: 'No authority data available',
        subtitle: 'We could not find your administrative profile.',
        action: OutlinedButton.icon(
          onPressed: () {
            AuthoritySession.clearSession();
            context.go(AppConstants.homeRoute);
          },
          icon: const Icon(Icons.home_outlined, size: 18),
          label: const Text('Back to Home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Sa.accent,
            minimumSize: const Size(0, 46),
            side: const BorderSide(color: Sa.accent, width: 1.5),
            shape: const RoundedRectangleBorder(
                borderRadius: AppTheme.borderRadius12),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      children: [
        _buildQuickStatsGrid(),
        const SizedBox(height: Sa.gap),
        _buildShortcutsCard(),
        const SizedBox(height: Sa.gap),
        _buildAdministrativeSummary(),
        const SizedBox(height: Sa.gap),
        _buildSchoolOverview(),
        const SizedBox(height: Sa.gap),
        _buildContactCard(),
      ],
    );
  }

  String _buildAuthorityInfo(String position, String department) {
    List<String> info = [];
    if (position.isNotEmpty) info.add(position);
    if (department.isNotEmpty) info.add(department);
    return info.join(' • ');
  }

  // ---- Quick stats ---------------------------------------------------------

  Widget _buildQuickStatsGrid() {
    final schoolOverview =
        _authorityData!['school_overview'] as Map<String, dynamic>? ?? {};
    final totalStudents = schoolOverview['total_students_managed'] ?? 0;
    final gradeLevels =
        schoolOverview['grade_levels_supervised'] as List<dynamic>? ?? [];
    final directReports = schoolOverview['direct_reports'] ?? 0;
    final permissions =
        _authorityData!['permissions'] as Map<String, dynamic>? ?? {};
    final grantedPermissions =
        permissions.values.where((value) => value == true).length;

    final stats = <_Stat>[
      _Stat('Students', '${totalStudents is num ? totalStudents : 0}',
          Icons.people_alt_outlined),
      _Stat('Grade Levels', '${gradeLevels.length}', Icons.layers_outlined),
      _Stat('Direct Reports', '${directReports is num ? directReports : 0}',
          Icons.supervisor_account_outlined),
      _Stat('Permissions', '$grantedPermissions', Icons.verified_user_outlined),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth < 360 ? 2 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          crossAxisSpacing: Sa.gap,
          mainAxisSpacing: Sa.gap,
          childAspectRatio: 1.7,
          children: stats.map(_statCard).toList(),
        );
      },
    );
  }

  Widget _statCard(_Stat stat) {
    return SaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Sa.accent.withValues(alpha: 0.12),
                  borderRadius: AppTheme.borderRadius12,
                ),
                child: Icon(stat.icon, color: Sa.accent, size: 19),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  stat.value,
                  style: Sa.cardTitle.copyWith(fontSize: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            stat.label,
            style: Sa.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---- Shortcuts -----------------------------------------------------------

  Widget _buildShortcutsCard() {
    final shortcuts = <_Shortcut>[
      _Shortcut('Students', Icons.people_alt_outlined, _navigateToStudents),
      _Shortcut('Classes', Icons.class_outlined, _navigateToClasses),
      _Shortcut('Exams', Icons.assignment_outlined, _navigateToExams),
      _Shortcut('Enrolment', Icons.group_add_outlined, _navigateToEnrolment),
    ];

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.dashboard_outlined,
            title: 'Quick Actions',
          ),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth < 360 ? 2 : (c.maxWidth < 600 ? 2 : 4);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: Sa.gapXs,
                mainAxisSpacing: Sa.gapXs,
                childAspectRatio: 1.0,
                children: shortcuts.map(_shortcutTile).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shortcutTile(_Shortcut shortcut) {
    return Material(
      color: Sa.accent.withValues(alpha: 0.06),
      borderRadius: AppTheme.borderRadius12,
      child: InkWell(
        onTap: shortcut.onTap,
        borderRadius: AppTheme.borderRadius12,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadius12,
            border: Border.all(color: Sa.accent.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(shortcut.icon, size: 24, color: Sa.accent),
              const SizedBox(height: 6),
              Text(
                shortcut.label,
                style: Sa.label.copyWith(
                  color: AppTheme.neutral800,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Administrative information -----------------------------------------

  Widget _buildAdministrativeSummary() {
    final role = _getStringValue(_authorityData!['role']) ?? '';
    final position = _getStringValue(_authorityData!['position']) ?? '';
    final qualification = _getStringValue(_authorityData!['qualification']) ?? '';
    final joiningDate = _getStringValue(_authorityData!['joining_date']) ?? '';
    final status = _getStringValue(_authorityData!['status']) ?? 'active';
    final permissions =
        _authorityData!['permissions'] as Map<String, dynamic>? ?? {};
    final authorityDetails =
        _authorityData!['authority_details'] as Map<String, dynamic>? ?? {};
    final department = _getStringValue(authorityDetails['department']) ?? '';
    final isActive = status.toLowerCase() == 'active';

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(
            icon: Icons.admin_panel_settings,
            title: 'Administrative Information',
            trailing: SaStatusPill(
              text: status.toUpperCase(),
              color: isActive ? AppTheme.greenPrimary : AppTheme.error,
              icon: isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
            ),
          ),
          const SizedBox(height: Sa.gapXs),
          SaInfoRow(
            label: 'Role',
            value: role.isNotEmpty
                ? role
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((word) => word[0].toUpperCase() + word.substring(1))
                    .join(' ')
                : 'Not assigned',
          ),
          SaInfoRow(
              label: 'Position',
              value: position.isNotEmpty ? position : 'Not assigned'),
          SaInfoRow(
              label: 'Department',
              value: department.isNotEmpty ? department : 'Not assigned'),
          SaInfoRow(
              label: 'Qualification',
              value: qualification.isNotEmpty ? qualification : 'Not provided'),
          SaInfoRow(label: 'Joining Date', value: _formatDate(joiningDate)),
          SaInfoRow(
              label: 'Permissions',
              value: _getPermissionsCount(permissions)),
        ],
      ),
    );
  }

  String _getPermissionsCount(Map<String, dynamic> permissions) {
    if (permissions.isEmpty) return 'None assigned';
    final grantedPermissions =
        permissions.values.where((value) => value == true).length;
    final totalPermissions = permissions.length;
    return '$grantedPermissions of $totalPermissions granted';
  }

  Widget _buildSchoolOverview() {
    final schoolOverview =
        _authorityData!['school_overview'] as Map<String, dynamic>? ?? {};
    final totalStudents = schoolOverview['total_students_managed'] ?? 0;
    final gradeLevels =
        schoolOverview['grade_levels_supervised'] as List<dynamic>? ?? [];
    final directReports = schoolOverview['direct_reports'] ?? 0;

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.school,
            title: 'School Overview',
          ),
          const SizedBox(height: Sa.gapXs),
          SaInfoRow(
              label: 'Students Managed',
              value: totalStudents is num && totalStudents > 0
                  ? totalStudents.toString()
                  : 'None'),
          SaInfoRow(
              label: 'Grade Levels',
              value: gradeLevels.isNotEmpty
                  ? 'Grades ${gradeLevels.join(', ')}'
                  : 'None assigned'),
          SaInfoRow(
              label: 'Direct Reports',
              value: directReports is num && directReports > 0
                  ? directReports.toString()
                  : 'None'),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    final email = _getStringValue(_authorityData!['email']) ?? 'Not provided';
    final phone = _getStringValue(_authorityData!['phone']) ?? 'Not provided';
    final authorityId =
        _getStringValue(_authorityData!['authority_id']) ?? 'Not provided';
    final experienceYears =
        _getStringValue(_authorityData!['experience_years']) ?? 'Not provided';
    final contactInfo =
        _authorityData!['contact_info'] as Map<String, dynamic>? ?? {};
    final officeExtension =
        _getStringValue(contactInfo['office_extension']) ?? '';
    final officeHours = _getStringValue(contactInfo['office_hours']) ?? '';

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.contact_mail_outlined,
            title: 'Contact & Profile',
          ),
          const SizedBox(height: Sa.gapXs),
          SaInfoRow(label: 'Email', value: email),
          SaInfoRow(label: 'Phone', value: phone),
          SaInfoRow(label: 'Authority ID', value: authorityId),
          SaInfoRow(
              label: 'Experience',
              value: experienceYears != 'Not provided'
                  ? '$experienceYears years'
                  : 'Not provided'),
          SaInfoRow(
              label: 'Office Extension',
              value: officeExtension.isNotEmpty
                  ? officeExtension
                  : 'Not provided'),
          SaInfoRow(
              label: 'Office Hours',
              value: officeHours.isNotEmpty ? officeHours : 'Not provided'),
        ],
      ),
    );
  }

  // ---- Navigation ----------------------------------------------------------

  String get _idParams =>
      'userId=${AuthoritySession.authorityId}&tenantId=${AuthoritySession.tenantId}';

  void _navigateToStudents() {
    context.go('/school_authority/students?$_idParams');
  }

  void _navigateToClasses() {
    context.go('/school_authority/classes?$_idParams');
  }

  void _navigateToExams() {
    context.go('${AppConstants.adminExamsRoute}?$_idParams');
  }

  void _navigateToEnrolment() {
    context.go('${AppConstants.adminEnrollmentRoute}?$_idParams');
  }

  // ---- Helpers -------------------------------------------------------------

  // Helper method to safely get string values from API response
  String? _getStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    return value.toString();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Not provided';
    }

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
}

class _Shortcut {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Shortcut(this.label, this.icon, this.onTap);
}
