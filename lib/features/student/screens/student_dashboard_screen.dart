// lib/features/student/screens/student_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/student_session.dart';
import '../../../services/student_service.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStudent();
    });
  }

  void _initializeStudent() {
    // Extract parameters from URL
    final state = GoRouterState.of(context);
    final studentId = state.uri.queryParameters['userId'];
    final tenantId = state.uri.queryParameters['tenantId'];
    
    if (studentId != null && tenantId != null) {
      // Set student data in session
      StudentSession.setSession(studentId: studentId, tenantId: tenantId);
      _loadStudentData();
    } else {
      // Check if we already have a session
      if (StudentSession.hasValidSession) {
        _loadStudentData();
      } else {
        setState(() {
          _error = 'Student ID or Tenant ID not provided';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStudentData() async {
    if (!StudentSession.hasValidSession) {
      setState(() {
        _error = 'Invalid student session';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('Loading student data for ID: ${StudentSession.studentId}'); // Debug

      // Load only student data from the single API endpoint
      final studentData = await StudentService.getStudentById(StudentSession.studentId!);

      print('Received student data: $studentData'); // Debug

      if (mounted) {
        setState(() {
          _studentData = studentData;
          _isLoading = false;
        });
        
        // Update session with student data
        StudentSession.setSession(
          studentId: StudentSession.studentId!,
          tenantId: StudentSession.tenantId!,
          userData: _studentData,
        );
      }
    } catch (e) {
      print('Error loading student data: $e'); // Debug
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
    if (_studentData == null) return _buildEmptyState();

    // Use Column instead of ListView to avoid nested scrollable widgets
    return RefreshIndicator(
      onRefresh: _loadStudentData,
      color: AppTheme.greenPrimary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeCard(),
            
            const SizedBox(height: 8),
            
            // Student Info Cards
            _buildStudentInfoGrid(),
            
            const SizedBox(height: 8),
            
            // Academic Summary
            _buildAcademicSummary(),
            
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
                onPressed: _loadStudentData,
                style: AppTheme.smallButtonStyle,
                child: Text('Retry', style: AppTheme.bodyMicro.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  StudentSession.clearSession();
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
            'No student data available',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.neutral600),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              StudentSession.clearSession();
              context.go(AppConstants.homeRoute);
            },
            child: Text('Back to Home', style: AppTheme.bodyMicro),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final firstName = _getStringValue(_studentData!['first_name']) ?? '';
    final lastName = _getStringValue(_studentData!['last_name']) ?? '';
    final studentName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : 'Student';
    final gradeLevel = _getStringValue(_studentData!['grade_level']) ?? '';
    final section = _getStringValue(_studentData!['section']) ?? '';
    final rollNumber = _getStringValue(_studentData!['roll_number']) ?? '';

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
                child: Icon(Icons.person, color: AppTheme.greenPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back, $studentName!',
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (gradeLevel.isNotEmpty || section.isNotEmpty || rollNumber.isNotEmpty)
                      Text(
                        _buildStudentInfo(gradeLevel, section, rollNumber),
                        style: AppTheme.bodyMicro.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to your student portal dashboard.',
            style: AppTheme.bodyMicro.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _buildStudentInfo(String gradeLevel, String section, String rollNumber) {
    List<String> info = [];
    if (gradeLevel.isNotEmpty) info.add('Grade $gradeLevel');
    if (section.isNotEmpty) info.add('Section $section');
    if (rollNumber.isNotEmpty) info.add('Roll: $rollNumber');
    return info.join(' • ');
  }

  Widget _buildStudentInfoGrid() {
    final email = _getStringValue(_studentData!['email']) ?? 'Not provided';
    final phone = _getStringValue(_studentData!['phone']) ?? 'Not provided';
    final address = _getStringValue(_studentData!['address']) ?? 'Not provided';
    final dateOfBirth = _getStringValue(_studentData!['date_of_birth']) ?? 'Not provided';

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
          'Address',
          address,
          Icons.location_on,
          AppTheme.warning,
        ),
        _buildInfoCard(
          'Birth Date',
          _formatDateOfBirth(dateOfBirth),
          Icons.cake,
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

  Widget _buildAcademicSummary() {
    final gradeLevel = _getStringValue(_studentData!['grade_level']) ?? '';
    final section = _getStringValue(_studentData!['section']) ?? '';
    final rollNumber = _getStringValue(_studentData!['roll_number']) ?? '';
    final admissionNumber = _getStringValue(_studentData!['admission_number']) ?? '';
    final academicYear = _getStringValue(_studentData!['academic_year']) ?? '';
    final status = _getStringValue(_studentData!['status']) ?? 'active';

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
                'Academic Information',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAcademicInfoRow('Grade Level', gradeLevel.isNotEmpty ? gradeLevel : 'Not assigned'),
          _buildAcademicInfoRow('Section', section.isNotEmpty ? section : 'Not assigned'),
          _buildAcademicInfoRow('Roll Number', rollNumber.isNotEmpty ? rollNumber : 'Not assigned'),
          _buildAcademicInfoRow('Admission No.', admissionNumber.isNotEmpty ? admissionNumber : 'Not assigned'),
          _buildAcademicInfoRow('Academic Year', academicYear.isNotEmpty ? academicYear : 'Not assigned'),
          _buildAcademicInfoRow('Status', status, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildAcademicInfoRow(String label, String value, {bool isStatus = false}) {
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
                'Assignments',
                Icons.assignment,
                AppTheme.warning,
                () => _navigateToAssignments(),
              ),
              _buildQuickActionButton(
                'Grades',
                Icons.grade,
                AppTheme.success,
                () => _navigateToGrades(),
              ),
              _buildQuickActionButton(
                'Attendance',
                Icons.calendar_today,
                AppTheme.info,
                () => _navigateToAttendance(),
              ),
              _buildQuickActionButton(
                'Timetable',
                Icons.schedule,
                AppTheme.greenPrimary,
                () => _navigateToTimetable(),
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

  void _navigateToAssignments() {
    context.go('${AppConstants.studentAssignmentsRoute}?userId=${StudentSession.studentId}&tenantId=${StudentSession.tenantId}');
  }

  void _navigateToGrades() {
    context.go('${AppConstants.studentGradesRoute}?userId=${StudentSession.studentId}&tenantId=${StudentSession.tenantId}');
  }

  void _navigateToAttendance() {
    context.go('${AppConstants.studentAttendanceRoute}?userId=${StudentSession.studentId}&tenantId=${StudentSession.tenantId}');
  }

  void _navigateToTimetable() {
    context.go('${AppConstants.studentTimetableRoute}?userId=${StudentSession.studentId}&tenantId=${StudentSession.tenantId}');
  }

  // Helper method to safely get string values from API response
  String? _getStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    return value.toString();
  }

  String _formatDateOfBirth(String? dateString) {
    if (dateString == null || dateString.isEmpty || dateString == 'Not provided') {
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
