// lib/core/auth/auth_session.dart
//
// Holds the authenticated session: the JWT access/refresh tokens and the
// server-derived identity (userId, role, tenantId). This is the single source
// of truth for "who am I" — screens must NOT trust role/tenant from the URL for
// anything security-sensitive (the server enforces from the token regardless).
//
// NOTE: tokens are kept in memory. For production, persist the refresh token in
// flutter_secure_storage and rehydrate on launch (follow-up).
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'permission_store.dart';

class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  String? accessToken;
  String? refreshToken;
  String? userId;
  String? role;
  String? tenantId;

  bool get isAuthenticated =>
      accessToken != null && accessToken!.isNotEmpty;

  /// The dashboard route for the logged-in user, derived from the server role.
  /// Single source of truth for post-login navigation.
  String dashboardRoute() {
    final t = tenantId;
    final u = userId ?? '';
    final qs = (t != null && t.isNotEmpty) ? '?tenantId=$t&userId=$u' : '?userId=$u';
    switch (role) {
      case 'super_admin':
        return '${AppConstants.tenantManagementRoute}?role=tenant_manager&userId=$u';
      case 'school_authority':
        // A school-less admin (no active school yet) goes to onboarding to create
        // their first school; otherwise straight to their dashboard.
        if (t == null || t.isEmpty) {
          return '${AppConstants.adminOnboardingRoute}?userId=$u';
        }
        return '${AppConstants.adminDashboardRoute}$qs';
      case 'teacher':
        return '${AppConstants.teacherDashboardRoute}$qs';
      case 'staff':
        // Unified dynamic-role user — lands on a hub built from their granted pages.
        return '${AppConstants.staffDashboardRoute}$qs';
      case 'student':
      default:
        return '${AppConstants.studentDashboardRoute}$qs';
    }
  }

  /// Where to land right after login. Normally the dashboard, BUT if the user
  /// has no granted pages at all, fall back to their (always-available) Profile.
  /// Super-admins keep their full menu; a school-less admin keeps onboarding.
  String landingRoute() {
    if (role == 'super_admin') return dashboardRoute();
    if (role == 'school_authority' && (tenantId == null || tenantId!.isEmpty)) {
      return dashboardRoute(); // -> create-your-first-school onboarding
    }
    final ps = PermissionStore.instance;
    if (ps.loaded) {
      final hasAnyPage = ps.modules.any(
          (m) => m.enabled && m.key != 'profile' && m.key != 'dashboard');
      if (!hasAnyPage) return profileRoute();
    }
    return dashboardRoute();
  }

  /// The Profile route for the current role (always available, never RBAC-gated).
  String profileRoute() {
    final u = userId ?? '';
    final t = tenantId ?? '';
    final qs = (t.isNotEmpty) ? '?tenantId=$t&userId=$u' : '?userId=$u';
    switch (role) {
      case 'super_admin':
        return '${AppConstants.superAdminProfileRoute}?userId=$u';
      case 'school_authority':
        return '${AppConstants.adminProfileRoute}$qs';
      case 'teacher':
        return '${AppConstants.teacherProfileRoute}$qs';
      case 'staff':
        return '${AppConstants.staffProfileRoute}$qs';
      case 'student':
      default:
        return '${AppConstants.studentProfileRoute}$qs';
    }
  }

  void setFromLogin(Map<String, dynamic> r) {
    accessToken = r['access_token'] as String?;
    refreshToken = r['refresh_token'] as String?;
    userId = r['user_id'] as String?;
    role = r['role'] as String?;
    tenantId = r['tenant_id'] as String?;
    notifyListeners();
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
    userId = null;
    role = null;
    tenantId = null;
    notifyListeners();
  }

  /// Standard headers for authenticated API calls. Use everywhere instead of
  /// hand-built header maps so the bearer token is always attached.
  Map<String, String> headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final t = accessToken;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }
}
