// lib/features/profile/services/profile_service.dart
//
// The signed-in user's own profile + change-password. Works for every role
// (super-admin / admin / staff / teacher / student). Backed by
// GET /api/auth/profile and POST /api/auth/change-password.
import 'dart:convert';
import '../../../core/network/app_http.dart' as http; // routes authed calls through the 401-refresh/hard-logout wrapper

import '../../../core/constants/app_constants.dart';
import '../../../core/auth/auth_session.dart';

class ProfileService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// GET /api/auth/profile -> the caller's identity profile.
  static Future<Map<String, dynamic>> getMyProfile() async {
    final uri = Uri.parse('$_base/api/auth/profile');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load profile');
  }

  /// POST /api/auth/change-password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_base/api/auth/change-password');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to change password');
  }
}
