// lib/core/utils/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/screens/landing_screen.dart';
import '../../features/screens/organisation_selection_screen.dart';
import '../auth/auth_session.dart';
import '../../shared/widgets/main_layout.dart';

// Super-admin (6 pages)
import '../../features/super_admin/screens/institution_groups_screen.dart';
import '../../features/super_admin/screens/admins_screen.dart';
import '../../features/super_admin/screens/module_access_screen.dart';
import '../../features/super_admin/screens/analytics_screen.dart';
import '../../features/super_admin/screens/feedback_screen.dart';

// Admin + shared
import '../../features/admin/screens/admin_onboarding_screen.dart';
import '../../features/admin/screens/role_management_screen.dart';
import '../../features/admin/screens/staff_management_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

import '../constants/app_constants.dart';
import '../constants/app_theme.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.homeRoute,
  refreshListenable: AuthSession.instance,
  errorBuilder: (context, state) => _RouteNotFoundScreen(uri: state.uri.toString()),
  // Route guard: only the public pages are reachable without a token. Server-side
  // authorization is the real control; this is defense-in-depth + UX.
  redirect: (context, state) {
    final authed = AuthSession.instance.isAuthenticated;
    final loc = state.uri.path;
    const publicPaths = {
      AppConstants.homeRoute,
      AppConstants.organisationSelectionRoute,
    };
    // There is NO standalone /login page — login/signup/forgot are all inline in
    // the LoginCard, opened as a dialog from the landing ("Manage Organisations")
    // or the organisation-selection screen. Unauthenticated users go to the
    // landing (Get Started), never a /login page.
    if (!authed && !publicPaths.contains(loc)) return AppConstants.homeRoute;
    return null;
  },
  routes: [
    // ---- Public ---- (login/signup/forgot live INSIDE the LoginCard dialog —
    // no standalone routes for them.)
    GoRoute(
      path: AppConstants.homeRoute,
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: AppConstants.organisationSelectionRoute,
      builder: (context, state) => const OrganisationSelectionScreen(),
    ),

    // Admin onboarding (authed, standalone): a organisation-less admin creates their
    // first organisation here before entering the app.
    GoRoute(
      path: AppConstants.adminOnboardingRoute,
      builder: (context, state) => const AdminOnboardingScreen(),
    ),

    // ---- Super-admin: 6 pages ----
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: state.uri.queryParameters['role'] ?? 'super_admin',
        organisationId: null,
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.organisationManagementRoute,
          builder: (context, state) => const InstitutionGroupsScreen(),
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

    // ---- Staff (dynamic-role users): currently only Profile ----
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: 'staff',
        organisationId: state.uri.queryParameters['organisationId'],
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppConstants.staffProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // ---- Organisation Authority (Admin): Roles & Access, Staff & Users, Profile ----
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        userRole: 'authority',
        organisationId: state.uri.queryParameters['organisationId'],
        userId: state.uri.queryParameters['userId'],
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/admin/roles',
          builder: (context, state) => const RoleManagementScreen(),
        ),
        GoRoute(
          path: AppConstants.adminStaffRoute,
          builder: (context, state) => const StaffManagementScreen(),
        ),
        GoRoute(
          path: AppConstants.adminProfileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

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
              const Text('This page isn’t available',
                  style: AppTheme.headingMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'It may not be set up for your account yet. Try going back to your home page.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final dest = AuthSession.instance.isAuthenticated
                      ? AuthSession.instance.landingRoute()
                      : AppConstants.homeRoute;
                  context.go(dest);
                },
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to home'),
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
