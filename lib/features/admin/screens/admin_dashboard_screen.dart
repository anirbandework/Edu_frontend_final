// lib/features/admin/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/school_authority_session.dart';
import '../../../services/school_authority_service.dart';

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

      print('Loading authority data for ID: ${AuthoritySession.authorityId}'); // Debug

      // Load only authority data from the single API endpoint
      final authorityData = await AuthorityService.getAuthorityById(AuthoritySession.authorityId!);

      print('Received authority data: $authorityData'); // Debug

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
      print('Error loading authority data: $e'); // Debug
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
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_authorityData == null) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadAuthorityData,
      color: AppTheme.greenPrimary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeCard(),
            
            const SizedBox(height: 8),
            
            // Authority Info Cards
            _buildAuthorityInfoGrid(),
            
            const SizedBox(height: 8),
            
            // Administrative Summary
            _buildAdministrativeSummary(),
            
            const SizedBox(height: 8),
            
            // School Overview
            _buildSchoolOverview(),
            
            const SizedBox(height: 8),
            
            // Quick Actions
            _buildQuickActions(),
            
            // Add some bottom padding
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: AppTheme.greenPrimary, strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading dashboard...',
            style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getMicroDecoration(
        color: AppTheme.error.withOpacity(0.1),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 32, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(
            'Failed to load dashboard',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.error),
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't load your dashboard. Check your connection and try again.",
            style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral700),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: AppTheme.bodyMicro.copyWith(
                color: AppTheme.neutral500,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loadAuthorityData,
                style: AppTheme.smallButtonStyle,
                child: Text('Retry', style: AppTheme.bodyMicro.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  AuthoritySession.clearSession();
                  context.go(AppConstants.homeRoute);
                },
                child: Text('Back to Home', style: AppTheme.bodyMicro),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: AppTheme.borderRadius12,
            ),
            child: Icon(Icons.admin_panel_settings, size: 40, color: AppTheme.neutral400),
          ),
          const SizedBox(height: 12),
          Text(
            'No authority data available',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.neutral600),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              AuthoritySession.clearSession();
              context.go(AppConstants.homeRoute);
            },
            child: Text('Back to Home', style: AppTheme.bodyMicro),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final firstName = _getStringValue(_authorityData!['first_name']) ?? '';
    final lastName = _getStringValue(_authorityData!['last_name']) ?? '';
    final authorityName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : 'Admin';
    final role = _getStringValue(_authorityData!['role']) ?? 'school_authority';
    final position = _getStringValue(_authorityData!['position']) ?? '';
    final authorityDetails = _authorityData!['authority_details'] as Map<String, dynamic>? ?? {};
    final department = _getStringValue(authorityDetails['department']) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Icon(Icons.admin_panel_settings, color: AppTheme.greenPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome, $authorityName!',
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (position.isNotEmpty || department.isNotEmpty)
                      Text(
                        _buildAuthorityInfo(position, department),
                        style: AppTheme.bodyMicro.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'School administration and management portal.',
            style: AppTheme.bodyMicro.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _buildAuthorityInfo(String position, String department) {
    List<String> info = [];
    if (position.isNotEmpty) info.add(position);
    if (department.isNotEmpty) info.add(department);
    return info.join(' • ');
  }

  Widget _buildAuthorityInfoGrid() {
    final email = _getStringValue(_authorityData!['email']) ?? 'Not provided';
    final phone = _getStringValue(_authorityData!['phone']) ?? 'Not provided';
    final authorityId = _getStringValue(_authorityData!['authority_id']) ?? 'Not provided';
    final experienceYears = _getStringValue(_authorityData!['experience_years']) ?? 'Not provided';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 1.4,
      children: [
        _buildInfoCard(
          'Email',
          email,
          Icons.email,
          AppTheme.info,
        ),
        _buildInfoCard(
          'Phone',
          phone,
          Icons.phone,
          AppTheme.success,
        ),
        _buildInfoCard(
          'Authority ID',
          authorityId,
          Icons.badge,
          AppTheme.warning,
        ),
        _buildInfoCard(
          'Experience',
          experienceYears != 'Not provided' ? '$experienceYears years' : 'Not provided',
          Icons.work_history,
          AppTheme.greenPrimary,
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: AppTheme.getMicroDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.bodyMicro.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.bodyMicro.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdministrativeSummary() {
    final role = _getStringValue(_authorityData!['role']) ?? '';
    final position = _getStringValue(_authorityData!['position']) ?? '';
    final qualification = _getStringValue(_authorityData!['qualification']) ?? '';
    final joiningDate = _getStringValue(_authorityData!['joining_date']) ?? '';
    final status = _getStringValue(_authorityData!['status']) ?? 'active';
    final permissions = _authorityData!['permissions'] as Map<String, dynamic>? ?? {};
    final authorityDetails = _authorityData!['authority_details'] as Map<String, dynamic>? ?? {};
    final department = _getStringValue(authorityDetails['department']) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: AppTheme.getMicroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 16, color: AppTheme.greenPrimary),
              const SizedBox(width: 4),
              Text(
                'Administrative Information',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAdministrativeInfoRow('Role', role.isNotEmpty ? role.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ') : 'Not assigned'),
          _buildAdministrativeInfoRow('Position', position.isNotEmpty ? position : 'Not assigned'),
          _buildAdministrativeInfoRow('Department', department.isNotEmpty ? department : 'Not assigned'),
          _buildAdministrativeInfoRow('Qualification', qualification.isNotEmpty ? qualification : 'Not provided'),
          _buildAdministrativeInfoRow('Joining Date', _formatDate(joiningDate)),
          _buildAdministrativeInfoRow('Permissions', _getPermissionsCount(permissions)),
          _buildAdministrativeInfoRow('Status', status, isStatus: true),
        ],
      ),
    );
  }

  String _getPermissionsCount(Map<String, dynamic> permissions) {
    if (permissions.isEmpty) return 'None assigned';
    final grantedPermissions = permissions.values.where((value) => value == true).length;
    final totalPermissions = permissions.length;
    return '$grantedPermissions of $totalPermissions granted';
  }

  Widget _buildSchoolOverview() {
    final schoolOverview = _authorityData!['school_overview'] as Map<String, dynamic>? ?? {};
    final totalStudents = schoolOverview['total_students_managed'] ?? 0;
    final gradeLevels = schoolOverview['grade_levels_supervised'] as List<dynamic>? ?? [];
    final directReports = schoolOverview['direct_reports'] ?? 0;
    final contactInfo = _authorityData!['contact_info'] as Map<String, dynamic>? ?? {};
    final officeExtension = _getStringValue(contactInfo['office_extension']) ?? '';
    final officeHours = _getStringValue(contactInfo['office_hours']) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: AppTheme.getMicroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.school, size: 16, color: AppTheme.greenPrimary),
              const SizedBox(width: 4),
              Text(
                'School Overview',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAdministrativeInfoRow('Students Managed', totalStudents > 0 ? totalStudents.toString() : 'None'),
          _buildAdministrativeInfoRow('Grade Levels', gradeLevels.isNotEmpty ? 'Grades ${gradeLevels.join(', ')}' : 'None assigned'),
          _buildAdministrativeInfoRow('Direct Reports', directReports > 0 ? directReports.toString() : 'None'),
          _buildAdministrativeInfoRow('Office Extension', officeExtension.isNotEmpty ? officeExtension : 'Not provided'),
          _buildAdministrativeInfoRow('Office Hours', officeHours.isNotEmpty ? officeHours : 'Not provided'),
        ],
      ),
    );
  }

  Widget _buildAdministrativeInfoRow(String label, String value, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.bodyMicro.copyWith(
                color: AppTheme.neutral600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: value.toLowerCase() == 'active' 
                          ? AppTheme.success.withOpacity(0.1)
                          : AppTheme.error.withOpacity(0.1),
                      borderRadius: AppTheme.borderRadius8,
                      border: Border.all(
                        color: value.toLowerCase() == 'active' 
                            ? AppTheme.success.withOpacity(0.3)
                            : AppTheme.error.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      value.toUpperCase(),
                      style: AppTheme.bodyMicro.copyWith(
                        fontWeight: FontWeight.bold,
                        color: value.toLowerCase() == 'active'
                            ? AppTheme.success
                            : AppTheme.error,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: AppTheme.bodyMicro.copyWith(
                      color: AppTheme.neutral800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: AppTheme.getMicroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, size: 16, color: AppTheme.greenPrimary),
              const SizedBox(width: 4),
              Text(
                'Quick Actions',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.8,
            children: [
              _buildQuickActionButton(
                'Students',
                Icons.people,
                AppTheme.success,
                () => _navigateToStudents(),
              ),
              _buildQuickActionButton(
                'Classes',
                Icons.class_,
                AppTheme.info,
                () => _navigateToClasses(),
              ),
              _buildQuickActionButton(
                'Exams',
                Icons.assignment,
                AppTheme.warning,
                () => _navigateToExams(),
              ),
              _buildQuickActionButton(
                'Enrolment',
                Icons.group_add,
                AppTheme.greenPrimary,
                () => _navigateToEnrolment(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: AppTheme.getMicroDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTheme.bodyMicro.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

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
