// lib/services/super_admin_service.dart
//
// Super-admin: create/list ADMINS (school authorities, school-less) and grant
// their module/page access. Admins: list/switch/create their own schools.
// Backed by /api/auth/* (admins, my-schools, switch-school), /api/access/catalog
// (module list) and /api/v1/tenants/ (school create).
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/permission_store.dart';

class SuperAdminService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  // ---- Admins ----
  /// Create an admin (school-less). Password-less: the admin sets their own
  /// password at first login (phone + OTP). email is optional. modules = granted page keys.
  /// POST /api/auth/admins
  static Future<Map<String, dynamic>> createAdmin({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    List<String> modules = const [],
  }) async {
    final uri = Uri.parse('$_base/api/auth/admins');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'first_name': firstName,
              'last_name': lastName,
              'phone': phone,
              if (email != null && email.isNotEmpty) 'email': email,
              'modules': modules,
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create admin');
  }

  /// Edit an admin's name / phone / email. PUT /api/auth/admins/{id}
  static Future<void> updateAdmin({
    required String adminId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
  }) async {
    final uri = Uri.parse('$_base/api/auth/admins/$adminId');
    final r = await http
        .put(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              if (firstName != null) 'first_name': firstName,
              if (lastName != null) 'last_name': lastName,
              if (phone != null) 'phone': phone,
              if (email != null) 'email': email,
            }))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update admin');
  }

  /// Activate / deactivate an admin. PATCH /api/auth/admins/{id}/status
  static Future<void> setAdminStatus({
    required String adminId,
    required bool isActive,
  }) async {
    final uri = Uri.parse('$_base/api/auth/admins/$adminId/status');
    final r = await http
        .patch(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'is_active': isActive}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update status');
  }

  /// Set a new password for an admin. POST /api/auth/admins/{id}/reset-password
  static Future<void> resetAdminPassword({
    required String adminId,
    required String password,
  }) async {
    final uri = Uri.parse('$_base/api/auth/admins/$adminId/reset-password');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'password': password}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to reset password');
  }

  /// Soft-delete an admin (and deactivate their schools). DELETE /api/auth/admins/{id}
  static Future<Map<String, dynamic>> deleteAdmin({required String adminId}) async {
    final uri = Uri.parse('$_base/api/auth/admins/$adminId');
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to delete admin');
  }

  /// GET /api/auth/admins -> [{id, first_name, last_name, email, phone, status,
  ///                           modules:[...], school_count}]
  static Future<List<Map<String, dynamic>>> getAdmins() async {
    final uri = Uri.parse('$_base/api/auth/admins');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load admins');
  }

  /// Platform-wide analytics (super-admin): school/admin/student/teacher totals,
  /// active-inactive, capacity, school-type distribution.
  /// GET /api/v1/tenants/analytics/comprehensive
  static Future<Map<String, dynamic>> getComprehensiveStats() async {
    final uri = Uri.parse('$_base/api/v1/tenants/analytics/comprehensive');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load analytics');
  }

  // ---- Per-organisation page grant (the org "ceiling" / what they paid for) ----
  /// GET /api/access/org/{tenantId}/pages -> [{module_key, module_name, section,
  /// audience_group, enabled, required}]
  static Future<List<Map<String, dynamic>>> getOrgPages(String tenantId) async {
    final uri = Uri.parse('$_base/api/access/org/$tenantId/pages');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['modules'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load organisation pages');
  }

  /// PUT /api/access/org/{tenantId}/page/{moduleKey} {enabled}
  static Future<void> setOrgPage({
    required String tenantId,
    required String moduleKey,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_base/api/access/org/$tenantId/page/$moduleKey');
    final r = await http
        .put(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update page');
  }

  /// POST /api/access/org/{tenantId}/pages/bulk {enabled} — enable/revoke all.
  static Future<void> setAllOrgPages({required String tenantId, required bool enabled}) async {
    final uri = Uri.parse('$_base/api/access/org/$tenantId/pages/bulk');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update pages');
  }

  // ---- Per-organisation ADMIN page grant (which pages the ADMIN themselves see
  //      in their OWN sidebar — separate from the distributable org pages above) --
  /// GET /api/access/org/{tenantId}/admin-pages -> same shape as getOrgPages.
  static Future<List<Map<String, dynamic>>> getAdminPages(String tenantId) async {
    final uri = Uri.parse('$_base/api/access/org/$tenantId/admin-pages');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['modules'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load admin pages');
  }

  /// PUT /api/access/org/{tenantId}/admin-page/{moduleKey} {enabled}
  static Future<void> setAdminPage({
    required String tenantId,
    required String moduleKey,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_base/api/access/org/$tenantId/admin-page/$moduleKey');
    final r = await http
        .put(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update admin page');
  }

  /// POST /api/access/org/{tenantId}/admin-pages/bulk {enabled} — show/hide all.
  static Future<void> setAllAdminPages({required String tenantId, required bool enabled}) async {
    final uri = Uri.parse('$_base/api/access/org/$tenantId/admin-pages/bulk');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update admin pages');
  }

  // ---- Tenants (schools) ----
  /// GET /api/v1/tenants/ -> ALL schools (each carries owner_authority_id).
  /// The backend caps page `size` at 100, so we page through until every school
  /// is collected — no silent truncation even with many organisations.
  static Future<List<Map<String, dynamic>>> getTenants({int size = 100}) async {
    final pageSize = size.clamp(1, 100);
    final out = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final uri = Uri.parse('$_base/api/v1/tenants/')
          .replace(queryParameters: {'page': '$page', 'size': '$pageSize'});
      final r = await http
          .get(uri, headers: AuthSession.instance.headers(json: false))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw _err(r, 'Failed to load schools');
      final d = json.decode(r.body);
      final list = (d is Map ? (d['items'] ?? d['tenants']) : d) as List? ?? const [];
      out.addAll(list.whereType<Map>().map((e) => e.cast<String, dynamic>()));
      // Stop on a non-paginated (bare list) response, a short/last page, or once
      // we've gathered the reported total. The page guard is a runaway backstop.
      if (d is! Map) break;
      final total = (d['total'] is num) ? (d['total'] as num).toInt() : null;
      if (list.length < pageSize) break;
      if (total != null && out.length >= total) break;
      page++;
      if (page > 1000) break;
    }
    return out;
  }

  // ---- Admin: own schools + switcher ----
  /// GET /api/auth/my-schools -> [{id, school_name, school_code, is_active}]
  static Future<List<Map<String, dynamic>>> getMySchools() async {
    final uri = Uri.parse('$_base/api/auth/my-schools');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load your schools');
  }

  /// Re-scope the session to one of the admin's schools (new JWT).
  /// POST /api/auth/switch-school/{tenantId} -> TokenResponse (applied to session).
  static Future<void> switchSchool({required String tenantId}) async {
    final uri = Uri.parse('$_base/api/auth/switch-school/$tenantId');
    final r = await http
        .post(uri, headers: AuthSession.instance.headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      AuthSession.instance.setFromLogin(json.decode(r.body) as Map<String, dynamic>);
      // The admin/role page ceilings (admin_enabled + role grants) are PER-TENANT,
      // so re-fetch permissions for the new active org — otherwise the sidebar
      // shows the previous school's pages until the next login.
      PermissionStore.instance.clear();
      await PermissionStore.instance.load();
      return;
    }
    throw _err(r, 'Failed to switch school');
  }
}
