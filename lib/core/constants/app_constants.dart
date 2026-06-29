// lib/core/constants/app_constants.dart
class AppConstants {
  // API Configuration.
  // On a physical device "localhost" is the PHONE, not your Mac — so point at the
  // Mac's LAN IP. Override per-network without editing code via:
  //   flutter run --dart-define=API_BASE_URL=http://<your-mac-ip>:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // The Mac's mDNS/Bonjour name — resolves to the Mac's CURRENT IP automatically, so it
    // survives DHCP/network changes (the mobile equivalent of a web app's `localhost`).
    // The phone + Mac must be on the same Wi-Fi, and iOS must have local-network permission.
    // If mDNS is blocked on your network, override with the raw IP:
    //   flutter run --dart-define=API_BASE_URL=http://<mac-ip>:8000   (ipconfig getifaddr en0)
    defaultValue: 'http://Anirbans-MacBook-Air.local:8000',
  );
  // static const String apiVersion = '/api/v1';

  // Public Routes
  static const String homeRoute = '/';
  static const String schoolSelectionRoute = '/school-selection';
  static const String addSchoolRoute = '/add-school';
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String createSchoolRoute = '/create-school';
  static const String tenantManagementRoute = '/tenant-management';
  static const String schoolManagementRoute = '/school-management';

  // Global/System Admin Routes
  static const String globalAnalyticsRoute = '/global/analytics';
  static const String systemSettingsRoute = '/global/settings';

  // Student routes removed — students are dynamic `members`; their pages are served
  // through the RBAC sidebar, not hardcoded /student/* routes.

  // Teacher routes: only the surviving grantable-page screens (quizzes / notifications).
  // The other /teacher/* routes were removed with the legacy teacher portal teardown.
  static const String teacherQuizzesRoute = '/teacher/quizzes';
  static const String teacherQuizBuilderRoute = '/teacher/quizzes/new';
  static const String teacherQuizResultsRoute = '/teacher/quizzes/results';
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
