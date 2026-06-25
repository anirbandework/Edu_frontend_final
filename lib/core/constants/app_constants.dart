// lib/core/constants/app_constants.dart
class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'http://localhost:8000';
  // static const String apiVersion = '/api/v1';

  // Public Routes
  static const String homeRoute = '/';
  static const String schoolSelectionRoute = '/school-selection';
  static const String addSchoolRoute = '/add-school';
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String inviteRoute = '/invite';
  static const String createSchoolRoute = '/create-school';
  static const String tenantManagementRoute = '/tenant-management';
  static const String schoolManagementRoute = '/school-management';

  // Global/System Admin Routes
  static const String globalAnalyticsRoute = '/global/analytics';
  static const String systemSettingsRoute = '/global/settings';

  // Student Routes
  static const String studentDashboardRoute = '/student/dashboard';
  static const String studentAssignmentsRoute = '/student/assignments';
  static const String studentGradesRoute = '/student/grades';
  static const String studentAttendanceRoute = '/student/attendance';
  static const String studentTimetableRoute = '/student/timetable';
  static const String studentProfileRoute = '/student/profile';
  static const String studentNotificationsRoute = '/student/notifications';
  static const String studentQuizRoute = '/student/quiz';
  static const String studentChatRoute = '/student/chat';
  static const String studentReportCardRoute = '/student/report-card';

  // Teacher Routes
  static const String teacherDashboardRoute = '/teacher/dashboard';
  static const String teacherClassesRoute = '/teacher/classes';
  static const String teacherScheduleRoute = '/teacher/schedule';
  static const String teacherStudentsRoute = '/teacher/students';
  static const String teacherAssignmentsRoute = '/teacher/assignments';
  static const String teacherAttendanceRoute = '/teacher/attendance';
  static const String teacherGradesRoute = '/teacher/grades';
  static const String teacherExamsRoute = '/teacher/exams';
  static const String teacherQuizzesRoute = '/teacher/quizzes';
  static const String teacherQuizBuilderRoute = '/teacher/quizzes/new';
  static const String teacherQuizResultsRoute = '/teacher/quizzes/results';
  static const String teacherChatRoute = '/teacher/chat';
  static const String teacherReportsRoute = '/teacher/reports';
  static const String teacherProfileRoute = '/teacher/profile';
  static const String teacherNotificationsRoute = '/teacher/notifications';
  static const String teacherSendNotificationRoute = '/teacher/send-notification';
  
  // Admin Routes (School-level)
  static const String adminDashboardRoute = '/admin/dashboard';
  static const String adminOnboardingRoute = '/admin/onboarding';
  static const String adminSchoolsRoute = '/admin/schools';
  static const String adminTeachersRoute = '/admin/teachers';
  static const String adminStudentsRoute = '/admin/students';
  static const String adminAnalyticsRoute = '/admin/analytics';
  static const String adminReportsRoute = '/admin/reports';
  static const String adminSettingsRoute = '/admin/settings';
  static const String adminProfileRoute = '/admin/profile';
  static const String adminNotificationsRoute = '/admin/notifications';
  static const String adminSendNotificationRoute = '/admin/send-notification';
  static const String adminNotificationAnalyticsRoute = '/admin/notification-analytics';
  static const String adminTenantManagementRoute = '/admin/tenant-management';
  static const String superAdminAdminsRoute = '/admin/admins';
  static const String superAdminModuleAccessRoute = '/admin/module-access';
  static const String superAdminAnalyticsRoute = '/admin/platform-analytics';
  static const String superAdminFeedbackRoute = '/admin/feedback';
  static const String adminAttendanceRoute = '/school_authority/attendance';
  static const String adminExamsRoute = '/school_authority/exams';
  static const String adminEnrollmentRoute = '/school_authority/enrollment';
  static const String adminRolesRoute = '/admin/roles';
  static const String adminStaffRoute = '/admin/staff';

  // Dynamic staff (unified role-based users) portal
  static const String staffDashboardRoute = '/staff/dashboard';
  static const String staffProfileRoute = '/staff/profile';

  // Universal profile (available to every role; never RBAC-gated)
  static const String superAdminProfileRoute = '/super-admin/profile';
}
