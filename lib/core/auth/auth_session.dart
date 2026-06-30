// lib/core/auth/auth_session.dart
//
// Holds the authenticated session: the JWT access/refresh tokens and the
// server-derived identity (userId, role, organisationId). This is the single source
// of truth for "who am I" — screens must NOT trust role/organisation from the URL for
// anything security-sensitive (the server enforces from the token regardless).
//
// NOTE: tokens are kept in memory. For production, persist the refresh token in
// flutter_secure_storage and rehydrate on launch (follow-up).
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'auth_storage.dart';

class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  String? accessToken;
  String? refreshToken;
  String? userId;
  String? role;
  String? organisationId;
  // The institution group (set for an admin). Their organisations all belong to it.
  String? groupId;

  bool get isAuthenticated =>
      accessToken != null && accessToken!.isNotEmpty;

  /// The dashboard route for the logged-in user, derived from the server role.
  /// Single source of truth for post-login navigation.
  String dashboardRoute() {
    final t = organisationId;
    final u = userId ?? '';
    final qs = (t != null && t.isNotEmpty) ? '?organisationId=$t&userId=$u' : '?userId=$u';
    switch (role) {
      case 'super_admin':
        return '${AppConstants.organisationManagementRoute}?role=super_admin&userId=$u';
      case 'authority':
        // An organisation-less admin (no active organisation yet) goes to onboarding to create
        // their first organisation; otherwise to Staff & Users (their home page).
        if (t == null || t.isEmpty) {
          return '${AppConstants.adminOnboardingRoute}?userId=$u';
        }
        return '${AppConstants.adminStaffRoute}$qs';
      case 'staff':
      default:
        // Dynamic-role users currently have only Profile.
        return '${AppConstants.staffProfileRoute}$qs';
    }
  }

  /// Where to land right after login. Super-admin → their menu; admin → Staff &
  /// Users (or onboarding if organisation-less); staff → Profile. (dashboardRoute()
  /// already encodes this; the old "dashboard page" fallback is gone with it.)
  String landingRoute() => dashboardRoute();

  /// The Profile route for the current role (always available, never RBAC-gated).
  String profileRoute() {
    final u = userId ?? '';
    final t = organisationId ?? '';
    final qs = (t.isNotEmpty) ? '?organisationId=$t&userId=$u' : '?userId=$u';
    switch (role) {
      case 'super_admin':
        return '${AppConstants.superAdminProfileRoute}?userId=$u';
      case 'authority':
        return '${AppConstants.adminProfileRoute}$qs';
      case 'staff':
      default:
        return '${AppConstants.staffProfileRoute}$qs';
    }
  }

  void setFromLogin(Map<String, dynamic> r) {
    accessToken = r['access_token'] as String?;
    refreshToken = r['refresh_token'] as String?;
    userId = r['user_id'] as String?;
    role = r['role'] as String?;
    organisationId = r['organisation_id'] as String?;
    groupId = r['group_id'] as String?;
    notifyListeners();
    _persist(); // survive a web refresh / app relaunch
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
    userId = null;
    role = null;
    organisationId = null;
    groupId = null;
    notifyListeners();
    AuthStorage.clear(); // fire-and-forget
  }

  /// Rehydrate the session from storage on app launch (call before runApp).
  /// Without this, a web page refresh restarts the Dart app with an empty
  /// session and the router guard bounces the user to /login.
  Future<void> restore() async {
    try {
      final s = await AuthStorage.read();
      accessToken = s['accessToken'];
      refreshToken = s['refreshToken'];
      userId = s['userId'];
      role = s['role'];
      organisationId = s['organisationId'];
      groupId = s['groupId'];
      notifyListeners();
    } catch (_) {
      // Storage unavailable — start logged out rather than crash on launch.
    }
  }

  /// True when there's an access token whose JWT `exp` is in the past. Used on
  /// launch to decide whether to refresh before entering the app. Unknown/
  /// undecodable tokens return false (let the server be the judge).
  bool get accessTokenExpired {
    final t = accessToken;
    if (t == null || t.isEmpty) return false;
    try {
      final parts = t.split('.');
      if (parts.length != 3) return false;
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      p += '=' * ((4 - p.length % 4) % 4);
      final payload = json.decode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return false;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp <= nowSec + 10; // 10s leeway
    } catch (_) {
      return false;
    }
  }

  void _persist() {
    AuthStorage.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      role: role,
      organisationId: organisationId,
      groupId: groupId,
    );
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
