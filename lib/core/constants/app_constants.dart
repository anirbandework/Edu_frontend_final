// lib/core/constants/app_constants.dart
import 'package:flutter/foundation.dart' show kReleaseMode;

class AppConstants {
  // API Configuration.
  // On a physical device "localhost" is the PHONE, not your Mac — so point at the
  // Mac's LAN IP. Override per-network without editing code via:
  //   flutter run --dart-define=API_BASE_URL=http://<your-mac-ip>:8000
  // For RELEASE, set the real backend at build time:
  //   flutter build <apk|ipa|web> --dart-define=API_BASE_URL=https://api.yourdomain.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // The Mac's mDNS/Bonjour name — resolves to the Mac's CURRENT IP automatically, so it
    // survives DHCP/network changes (the mobile equivalent of a web app's `localhost`).
    // The phone + Mac must be on the same Wi-Fi, and iOS must have local-network permission.
    // If mDNS is blocked on your network, override with the raw IP:
    //   flutter run --dart-define=API_BASE_URL=http://<mac-ip>:8000   (ipconfig getifaddr en0)
    defaultValue: 'http://Anirbans-MacBook-Air.local:8000',
  );

  /// Fail fast if a RELEASE build was produced without a real backend URL — otherwise
  /// it silently ships pointing at a developer machine and EVERY API call fails. The
  /// value still comes from your build/CI via `--dart-define=API_BASE_URL=...`; this
  /// only refuses to launch a release that's still aimed at a dev host. (Called from
  /// main() before runApp; a no-op in debug/profile.)
  static void assertApiBaseUrlConfigured() {
    if (!kReleaseMode) return;
    final u = apiBaseUrl.toLowerCase();
    final isDevHost = u.isEmpty ||
        u.contains('localhost') ||
        u.contains('127.0.0.1') ||
        u.contains('10.0.2.2') ||
        u.contains('.local');
    if (isDevHost) {
      throw StateError(
        'API_BASE_URL is not configured for release (currently "$apiBaseUrl"). '
        'Build with --dart-define=API_BASE_URL=https://api.yourdomain.com');
    }
  }
  // static const String apiVersion = '/api/v1';

  // ── Routes ────────────────────────────────────────────────────────────────
  // Only the pages that survive the strip-down: auth (login/signup/forgot),
  // the super-admin's 6 pages, the admin's flow pages (Roles & Access, Staff &
  // Users) + Profile, and the universal Profile for every role. Feature routes
  // (exams/attendance/classes/timetable/enrolment/notifications/…) were removed
  // and will be re-added when those modules are rebuilt.

  // Public. Login/signup/forgot are NOT routes — they're inline modes of the
  // LoginCard dialog (opened from the landing or the organisation-selection
  // screen), so there is no standalone /login, /signup or /forgot-password page.
  static const String homeRoute = '/';
  static const String organisationSelectionRoute = '/organisation-selection';

  // Super-admin (6 pages)
  static const String organisationManagementRoute = '/organisation-management';
  static const String superAdminAdminsRoute = '/admin/admins';
  static const String superAdminModuleAccessRoute = '/admin/module-access';
  static const String superAdminAnalyticsRoute = '/admin/platform-analytics';
  static const String superAdminFeedbackRoute = '/admin/feedback';
  static const String superAdminProfileRoute = '/super-admin/profile';

  // Admin (organisation authority): flow pages + profile. Roles & Access uses the
  // literal '/admin/roles' route directly.
  static const String adminOnboardingRoute = '/admin/onboarding';
  static const String adminStaffRoute = '/admin/staff';
  static const String adminProfileRoute = '/admin/profile';

  // Dynamic staff (unified role-based users): currently only Profile.
  static const String staffProfileRoute = '/staff/profile';
}
