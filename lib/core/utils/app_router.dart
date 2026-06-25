// lib/core/utils/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/screens/landing_screen.dart';
import '../../features/screens/login_screen.dart';
import '../../features/screens/school_selection_screen.dart';
import '../../features/screens/signup_screen.dart';
import '../../features/screens/forgot_password_screen.dart';
import '../../features/screens/invite_screen.dart';
import '../auth/auth_session.dart';
import '../../shared/widgets/main_layout.dart';

import '../../features/tenant_management/screens/tenant_management_screen.dart';
import '../../features/tenant_management/screens/tenant_access_screen.dart';
import '../../features/super_admin/screens/admins_screen.dart';
import '../../features/super_admin/screens/module_access_screen.dart';
import '../../features/super_admin/screens/analytics_screen.dart';
import '../../features/super_admin/screens/feedback_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';

import '../../features/student/screens/student_dashboard_screen.dart';
import '../../features/student/screens/student_assignments_screen.dart';
import '../../features/student/screens/student_timetable_screen.dart';
import '../../features/student/screens/student_attendance_screen.dart';
import '../../features/student/screens/student_results_screen.dart';
import '../../features/student/screens/student_quiz_screen.dart';
import '../../features/student/screens/student_report_card_screen.dart';

import '../../features/teacher/screens/teacher_dashboard_screen.dart';
import '../../features/teacher/screens/teacher_classes_screen.dart';
import '../../features/teacher/screens/teacher_schedule_screen.dart';
import '../../features/teacher/screens/teacher_attendance_screen.dart';
import '../../features/teacher/screens/teacher_students_screen.dart';
import '../../features/teacher/screens/teacher_grades_screen.dart';
import '../../features/exams/screens/exam_management_screen.dart';
import '../../features/enrollment/screens/enrollment_screen.dart';
import '../../features/quizzes/screens/quiz_list_screen.dart';
import '../../features/quizzes/screens/quiz_builder_screen.dart';
import '../../features/quizzes/screens/quiz_results_screen.dart';
import '../../features/assignments/screens/assignment_management_screen.dart';
import '../../features/chat/screens/chat_screen.dart';

import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_onboarding_screen.dart';
import '../../features/admin/screens/send_notification_screen.dart';
import '../../features/admin/screens/class_screen.dart';
import '../../features/admin/screens/student_management_screen.dart';
import '../../features/admin/screens/role_management_screen.dart';
import '../../features/admin/screens/staff_management_screen.dart';
import '../../features/staff/screens/staff_dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/admin/screens/timetable_screen.dart';
import '../../features/admin/screens/attendance_screen.dart';
import '../../services/attendance_service.dart';

import '../constants/app_constants.dart';
import '../constants/app_theme.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.homeRoute,
  refreshListenable: AuthSession.instance,
  // Friendly fallback instead of go_router's raw red error screen — e.g. when a
  // role is granted a page whose route isn't built yet, or a deep link is stale.
  errorBuilder: (context, state) => _RouteNotFoundScreen(uri: state.uri.toString()),
  // Route guard: only the landing and login pages are reachable without a token.
  // Everything else requires an authenticated session. Server-side authorization
  // is the real control; this is defense-in-depth + UX.
  redirect: (context, state) {
    final authed = AuthSession.instance.isAuthenticated;
    final loc = state.uri.path;
    const publicPaths = {
      AppConstants.homeRoute,
      AppConstants.loginRoute,
      AppConstants.schoolSelectionRoute,
      AppConstants.signupRoute,
      AppConstants.forgotPasswordRoute,
    };
    if (!authed && !publicPaths.contains(loc)) return AppConstants.loginRoute;
    return null;
  },
  routes: [
    // Public routes
    GoRoute(
      path: AppConstants.homeRoute,
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: AppConstants.loginRoute,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppConstants.signupRoute,
      builder: (context, state) =>
          SignupScreen(token: state.uri.queryParameters['token'] ?? ''),
    ),
    GoRoute(
      path: AppConstants.forgotPasswordRoute,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppConstants.inviteRoute,
      builder: (context, state) => const InviteScreen(),
    ),
    GoRoute(
      // School picker -> pick role -> phone+password login (public entry).
      path: AppConstants.schoolSelectionRoute,
      builder: (context, state) => const SchoolSelectionScreen(),
    ),

    // Admin onboarding (authed, standalone): a school-less admin lands here to
    // create their first school before entering the dashboard.
    GoRoute(
      path: AppConstants.adminOnboardingRoute,
      builder: (context, state) => const AdminOnboardingScreen(),
    ),

    // Global admin/tenant management
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: state.uri.queryParameters['role'] ?? 'tenant_manager',
        tenantId: null,
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.tenantManagementRoute,
          builder: (context, state) => const TenantManagementScreen(),
        ),
        GoRoute(
          path: '/admin/tenant-access',
          builder: (context, state) => const TenantAccessScreen(),
        ),
        GoRoute(
          path: AppConstants.superAdminAdminsRoute,
          builder: (context, state) => const AdminsScreen(),
        ),
        GoRoute(
          path: AppConstants.superAdminModuleAccessRoute,
          builder: (context, state) => const ModuleAccessScreen(),
        ),
        GoRoute(
          path: AppConstants.superAdminAnalyticsRoute,
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: AppConstants.superAdminFeedbackRoute,
          builder: (context, state) => const FeedbackScreen(),
        ),
        GoRoute(
          path: AppConstants.superAdminProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // Student
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: 'student',
        tenantId: state.uri.queryParameters['tenantId'],
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.studentDashboardRoute,
          builder: (context, state) => const StudentDashboardScreen(),
        ),
        GoRoute(
          path: AppConstants.studentNotificationsRoute,
          builder: (context, state) => NotificationsScreen(
            userId: state.uri.queryParameters['userId'] ?? '',
            userType: 'student',
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
          ),
        ),
        GoRoute(
          path: AppConstants.studentAssignmentsRoute,
          builder: (context, state) => StudentAssignmentsScreen(
            studentId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.studentQuizRoute,
          builder: (context, state) => StudentQuizScreen(
            quizId: state.uri.queryParameters['quizId'] ?? '',
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.studentProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppConstants.studentTimetableRoute,
          builder: (context, state) => StudentTimetableScreen(
            studentId: state.uri.queryParameters['userId'],
            academicYear: state.uri.queryParameters['academicYear'],
          ),
        ),
        GoRoute(
          path: AppConstants.studentAttendanceRoute,
          builder: (context, state) => StudentAttendanceScreen(
            studentId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.studentGradesRoute,
          builder: (context, state) => StudentResultsScreen(
            studentId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.studentChatRoute,
          builder: (context, state) => ChatScreen(
            role: 'student',
            userId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.studentReportCardRoute,
          builder: (context, state) => StudentReportCardScreen(
            studentId: state.uri.queryParameters['userId'],
            academicYear: state.uri.queryParameters['academicYear'],
            studentName: state.uri.queryParameters['name'],
          ),
        ),
      ],
    ),

    // Teacher
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: 'teacher',
        tenantId: state.uri.queryParameters['tenantId'],
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.teacherDashboardRoute,
          builder: (context, state) => const TeacherDashboardScreen(),
        ),
        GoRoute(
          path: AppConstants.teacherNotificationsRoute,
          builder: (context, state) => NotificationsScreen(
            userId: state.uri.queryParameters['userId'] ?? '',
            userType: 'teacher',
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
          ),
        ),
        GoRoute(
          path: AppConstants.teacherSendNotificationRoute,
          builder: (context, state) => SendNotificationScreen(
            senderId: state.uri.queryParameters['userId'] ?? '',
            senderType: 'teacher',
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
          ),
        ),
        GoRoute(
          path: AppConstants.teacherClassesRoute,
          builder: (context, state) => TeacherClassesScreen(
            teacherId: state.uri.queryParameters['userId'],
            academicYear: state.uri.queryParameters['academicYear'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherScheduleRoute,
          builder: (context, state) => TeacherScheduleScreen(
            teacherId: state.uri.queryParameters['userId'],
            academicYear: state.uri.queryParameters['academicYear'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppConstants.teacherAttendanceRoute,
          builder: (context, state) => TeacherAttendanceScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherStudentsRoute,
          builder: (context, state) => TeacherStudentsScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherGradesRoute,
          builder: (context, state) => TeacherGradesScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherExamsRoute,
          builder: (context, state) => ExamManagementScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherQuizBuilderRoute,
          builder: (context, state) => QuizBuilderScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherQuizzesRoute,
          builder: (context, state) => QuizListScreen(
            teacherId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherQuizResultsRoute,
          builder: (context, state) => QuizResultsScreen(
            quizId: state.uri.queryParameters['quizId'] ?? '',
            quizTitle: state.uri.queryParameters['title'] ?? 'Quiz',
            teacherId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherAssignmentsRoute,
          builder: (context, state) => AssignmentManagementScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
        GoRoute(
          path: AppConstants.teacherChatRoute,
          builder: (context, state) => ChatScreen(
            role: 'teacher',
            userId: state.uri.queryParameters['userId'],
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),
      ],
    ),

    // Unified dynamic-role staff portal — pages come from their assigned role.
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: 'staff',
        tenantId: state.uri.queryParameters['tenantId'],
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.staffDashboardRoute,
          builder: (context, state) => const StaffDashboardScreen(),
        ),
        GoRoute(
          path: AppConstants.staffProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // School Authority (Admin)
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: 'school_authority',
        tenantId: state.uri.queryParameters['tenantId'],
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.adminDashboardRoute,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: AppConstants.adminNotificationsRoute,
          builder: (context, state) => NotificationsScreen(
            userId: state.uri.queryParameters['userId'] ?? '',
            userType: 'school_authority',
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
          ),
        ),
        GoRoute(
          path: AppConstants.adminSendNotificationRoute,
          builder: (context, state) => SendNotificationScreen(
            senderId: state.uri.queryParameters['userId'] ?? '',
            senderType: 'school_authority',
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
          ),
        ),

        GoRoute(
          path: AppConstants.adminAttendanceRoute,
          builder: (context, state) => AttendanceScreen(
            service: AttendanceService(AppConstants.apiBaseUrl),
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
            authorityUserId: state.uri.queryParameters['userId'] ?? '',
          ),
        ),

        // Student management
        GoRoute(
          path: '/school_authority/students',
          builder: (context, state) => const StudentManagementScreen(),
        ),

        // Exam management (create/publish/delete)
        GoRoute(
          path: AppConstants.adminExamsRoute,
          builder: (context, state) => ExamManagementScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),

        // Enrolment management
        GoRoute(
          path: AppConstants.adminEnrollmentRoute,
          builder: (context, state) => EnrollmentScreen(
            tenantId: state.uri.queryParameters['tenantId'],
          ),
        ),

        // Classes management (this is the ClassScreen you asked to wire)
        GoRoute(
          path: '/school_authority/classes',
          builder: (context, state) => ClassScreen(
            baseUrl: AppConstants.apiBaseUrl,
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
            headers: {
              // Example: inject auth header if present in app state
              // 'Authorization': 'Bearer ${someToken}',
            },
          ),
        ),
        GoRoute(
          path: '/school_authority/timetable',
          builder: (context, state) => TimetableScreen(
            baseUrl: AppConstants.apiBaseUrl,
            tenantId: state.uri.queryParameters['tenantId'] ?? '',
            currentUserId: state.uri.queryParameters['userId'] ?? '',
            academicYear:
                state.uri.queryParameters['academicYear'] ?? '2025-26',
          ),
        ),

        // RBAC: roles & access management (authority)
        GoRoute(
          path: '/admin/roles',
          builder: (context, state) => const RoleManagementScreen(),
        ),

        // Staff & Users — the unified dynamic-role directory (authority)
        GoRoute(
          path: AppConstants.adminStaffRoute,
          builder: (context, state) => const StaffManagementScreen(),
        ),

        // Universal profile (always available, never RBAC-gated)
        GoRoute(
          path: AppConstants.adminProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),

        // Placeholder example
        GoRoute(
          path: AppConstants.adminNotificationAnalyticsRoute,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Notification Analytics'),
        ),
      ],
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: AppTheme.warning),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.headingMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is under construction',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.homeRoute),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown by go_router's errorBuilder when a path has no route (e.g. a granted
/// page that isn't built yet, or a stale deep link) — avoids a raw error screen.
class _RouteNotFoundScreen extends StatelessWidget {
  final String uri;
  const _RouteNotFoundScreen({required this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 56, color: AppTheme.neutral400),
              const SizedBox(height: 16),
              Text('This page isn’t available',
                  style: AppTheme.headingMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'It may not be set up for your account yet. Try going back to your dashboard.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final dest = AuthSession.instance.isAuthenticated
                      ? AuthSession.instance.dashboardRoute()
                      : AppConstants.homeRoute;
                  context.go(dest);
                },
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.greenPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
