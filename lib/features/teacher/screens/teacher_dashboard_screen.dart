// lib/features/teacher/screens/teacher_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/teacher_session.dart';
import '../../../services/teacher_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Map<String, dynamic>? _teacherData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTeacher();
    });
  }

  void _initializeTeacher() {
    // Extract parameters from URL
    final state = GoRouterState.of(context);
    final teacherId = state.uri.queryParameters['userId'];
    final tenantId = state.uri.queryParameters['tenantId'];
    
    if (teacherId != null && tenantId != null) {
      // Set teacher data in session
      TeacherSession.setSession(teacherId: teacherId, tenantId: tenantId);
      _loadTeacherData();
    } else {
      // Check if we already have a session
      if (TeacherSession.hasValidSession) {
        _loadTeacherData();
      } else {
        setState(() {
          _error = 'Teacher ID or Tenant ID not provided';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTeacherData() async {
    if (!TeacherSession.hasValidSession) {
      setState(() {
        _error = 'Invalid teacher session';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('Loading teacher data for ID: ${TeacherSession.teacherId}'); // Debug

      // Load only teacher data from the single API endpoint
      final teacherData = await TeacherService.getTeacherById(TeacherSession.teacherId!);

      print('Received teacher data: $teacherData'); // Debug

      if (mounted) {
        setState(() {
          _teacherData = _normalizeTeacher(teacherData);
          _isLoading = false;
        });
        
        // Update session with teacher data
        TeacherSession.setSession(
          teacherId: TeacherSession.teacherId!,
          tenantId: TeacherSession.tenantId!,
          userData: _teacherData,
        );
      }
    } catch (e) {
      print('Error loading teacher data: $e'); // Debug
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
    if (_teacherData == null) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadTeacherData,
      color: AppTheme.greenPrimary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeCard(),
            
            const SizedBox(height: 8),
            
            // Teacher Info Cards
            _buildTeacherInfoGrid(),
            
            const SizedBox(height: 8),
            
            // Professional Summary
            _buildProfessionalSummary(),
            
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
            'We couldn\'t load your dashboard right now. Please check your connection and try again.',
            style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loadTeacherData,
                style: AppTheme.smallButtonStyle,
                child: Text('Retry', style: AppTheme.bodyMicro.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  TeacherSession.clearSession();
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
            child: Icon(Icons.school_outlined, size: 40, color: AppTheme.neutral400),
          ),
          const SizedBox(height: 12),
          Text(
            'No teacher data available',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.neutral600),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              TeacherSession.clearSession();
              context.go(AppConstants.homeRoute);
            },
            child: Text('Back to Home', style: AppTheme.bodyMicro),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final firstName = _getStringValue(_teacherData!['first_name']) ?? '';
    final lastName = _getStringValue(_teacherData!['last_name']) ?? '';
    final teacherName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : 'Teacher';
    final subjects = _teacherData!['subjects_taught'] as List<dynamic>? ?? [];
    final department = _getStringValue(_teacherData!['department']) ?? '';

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
                child: Icon(Icons.person_2, color: AppTheme.greenPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome, $teacherName!',
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (department.isNotEmpty || subjects.isNotEmpty)
                      Text(
                        _buildTeacherInfo(department, subjects),
                        style: AppTheme.bodyMicro.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your classes and track student progress.',
            style: AppTheme.bodyMicro.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _buildTeacherInfo(String department, List<dynamic> subjects) {
    List<String> info = [];
    if (department.isNotEmpty) info.add(department);
    if (subjects.isNotEmpty) {
      final subjectNames = subjects.take(2).map((s) => s.toString()).toList();
      if (subjects.length > 2) {
        subjectNames.add('+${subjects.length - 2} more');
      }
      info.add(subjectNames.join(', '));
    }
    return info.join(' • ');
  }

  Widget _buildTeacherInfoGrid() {
    final email = _getStringValue(_teacherData!['email']) ?? 'Not provided';
    final phone = _getStringValue(_teacherData!['phone']) ?? 'Not provided';
    final employeeId = _getStringValue(_teacherData!['employee_id']) ?? 'Not provided';
    final experience = _teacherData!['years_of_experience'] ?? 'Not provided';

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
          'Employee ID',
          employeeId,
          Icons.badge,
          AppTheme.warning,
        ),
        _buildInfoCard(
          'Experience',
          experience != 'Not provided' ? '$experience years' : 'Not provided',
          Icons.work,
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

  Widget _buildProfessionalSummary() {
    final department = _getStringValue(_teacherData!['department']) ?? '';
    final position = _getStringValue(_teacherData!['position']) ?? '';
    final qualification = _getStringValue(_teacherData!['qualification']) ?? '';
    final joiningDate = _getStringValue(_teacherData!['joining_date']) ?? '';
    final status = _getStringValue(_teacherData!['status']) ?? 'active';
    final subjects = _teacherData!['subjects_taught'] as List<dynamic>? ?? [];

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
              Icon(Icons.work, size: 16, color: AppTheme.greenPrimary),
              const SizedBox(width: 4),
              Text(
                'Professional Information',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProfessionalInfoRow('Department', department.isNotEmpty ? department : 'Not assigned'),
          _buildProfessionalInfoRow('Position', position.isNotEmpty ? position : 'Not assigned'),
          _buildProfessionalInfoRow('Qualification', qualification.isNotEmpty ? qualification : 'Not provided'),
          _buildProfessionalInfoRow('Joining Date', _formatDate(joiningDate)),
          _buildProfessionalInfoRow('Subjects', subjects.isNotEmpty ? subjects.take(3).join(', ') + (subjects.length > 3 ? '...' : '') : 'Not assigned'),
          _buildProfessionalInfoRow('Status', status, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfoRow(String label, String value, {bool isStatus = false}) {
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
                'Classes',
                Icons.class_,
                AppTheme.info,
                () => _navigateToClasses(),
              ),
              _buildQuickActionButton(
                'Students',
                Icons.people,
                AppTheme.success,
                () => _navigateToStudents(),
              ),
              _buildQuickActionButton(
                'Assignments',
                Icons.assignment,
                AppTheme.warning,
                () => _navigateToAssignments(),
              ),
              _buildQuickActionButton(
                'Attendance',
                Icons.how_to_reg,
                AppTheme.greenPrimary,
                () => _navigateToAttendance(),
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

  void _navigateToClasses() {
    context.go('${AppConstants.teacherClassesRoute}?userId=${TeacherSession.teacherId}&tenantId=${TeacherSession.tenantId}');
  }

  void _navigateToStudents() {
    context.go('${AppConstants.teacherStudentsRoute}?userId=${TeacherSession.teacherId}&tenantId=${TeacherSession.tenantId}');
  }

  void _navigateToAssignments() {
    context.go('${AppConstants.teacherAssignmentsRoute}?userId=${TeacherSession.teacherId}&tenantId=${TeacherSession.tenantId}');
  }

  void _navigateToAttendance() {
    context.go('${AppConstants.teacherAttendanceRoute}?userId=${TeacherSession.teacherId}&tenantId=${TeacherSession.tenantId}');
  }

  /// GET /teachers/{id} nests contact details under
  /// personal_info.contact_info and identity under teacher_id, but this
  /// dashboard reads flat keys. Hoist the known nested values to the top level
  /// so email/phone/employee-id render instead of showing 'Not provided'.
  Map<String, dynamic> _normalizeTeacher(Map<String, dynamic>? data) {
    if (data == null) return {};
    final m = Map<String, dynamic>.from(data);
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
    final personal = asMap(m['personal_info']);
    final pContact = asMap(personal['contact_info']);
    final contact = pContact.isNotEmpty ? pContact : asMap(m['contact_info']);
    final employment = asMap(m['employment']);

    m['email'] ??= contact['primary_email'] ?? contact['email'];
    m['phone'] ??= contact['primary_phone'] ?? contact['phone'];
    m['employee_id'] ??= m['teacher_id'] ?? employment['employee_id'];
    m['position'] ??= employment['designation'] ?? employment['position'];
    m['department'] ??= employment['department'];
    m['joining_date'] ??=
        employment['joining_date'] ?? employment['date_of_joining'];
    return m;
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
