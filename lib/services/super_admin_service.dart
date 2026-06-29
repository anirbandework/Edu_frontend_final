// lib/services/super_admin_service.dart
//
// Super-admin: create/list ADMINS (organisation authorities, organisation-less) and grant
// their module/page access. Admins: list/switch/create their own organisations.
// Backed by /api/auth/* (admins, my-organisations, switch-organisation), /api/access/catalog
// (module list) and /api/v1/organisations/ (organisation create).
import 'dart:convert';
import '../core/network/app_http.dart' as http; // routes authed calls through the 401-refresh/hard-logout wrapper

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
  /// Create an admin (organisation-less). Password-less: the admin sets their own
  /// password at first login (phone + OTP). email is optional. modules = granted page keys.
  /// POST /api/auth/admins
  static Future<Map<String, dynamic>> createAdmin({
    required String firstName,
    required String lastName,
    required String phone,
    required String groupId, // the institution group this admin belongs to
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
              'group_id': groupId,
              if (email != null && email.isNotEmpty) 'email': email,
              'modules': modules,
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create admin');
  }

  // ---- Institution Groups (super-admin) ----
  /// POST /api/auth/groups {name} -> {id, name, code, is_active, admin_count, org_count}
  static Future<Map<String, dynamic>> createGroup({required String name}) async {
    final r = await http
        .post(Uri.parse('$_base/api/auth/groups'),
            headers: AuthSession.instance.headers(),
            body: json.encode({'name': name}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create group');
  }

  /// GET /api/auth/groups -> [{id, name, code, is_active, admin_count, org_count}]
  static Future<List<Map<String, dynamic>>> getGroups() async {
    final r = await http
        .get(Uri.parse('$_base/api/auth/groups'), headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load groups');
  }

  /// GET /api/auth/groups/{id}/organisations -> the organisations in a group.
  static Future<List<Map<String, dynamic>>> getGroupOrganisations(String groupId) async {
    final r = await http
        .get(Uri.parse('$_base/api/auth/groups/$groupId/organisations'),
            headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load group organisations');
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

  /// Activate / deactivate a whole institution GROUP. When deactivated, nobody in the
  /// group (its admins or any staff in its organisations) can log in.
  /// PATCH /api/auth/groups/{id}/status
  static Future<void> setGroupStatus({
    required String groupId,
    required bool isActive,
  }) async {
    final uri = Uri.parse('$_base/api/auth/groups/$groupId/status');
    final r = await http
        .patch(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'is_active': isActive}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update group status');
  }

  /// Activate / deactivate a single ORGANISATION. When deactivated, that org's
  /// staff/users cannot log in. PATCH /api/auth/organisations/{id}/status
  static Future<void> setOrganisationStatus({
    required String organisationId,
    required bool isActive,
  }) async {
    final uri = Uri.parse('$_base/api/auth/organisations/$organisationId/status');
    final r = await http
        .patch(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'is_active': isActive}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update organisation status');
  }

  /// GET /api/auth/admins -> [{id, first_name, last_name, email, phone, status,
  ///                           modules:[...], org_count}]
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

  /// Platform-wide analytics (super-admin): organisation/admin/student/teacher totals,
  /// active-inactive, capacity, organisation-type distribution.
  /// GET /api/v1/organisations/analytics/comprehensive
  static Future<Map<String, dynamic>> getComprehensiveStats() async {
    final uri = Uri.parse('$_base/api/v1/organisations/analytics/comprehensive');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load analytics');
  }

  // ---- Per-organisation page grant (the org "ceiling" / what they paid for) ----
  // ---- Module access ceilings, PER INSTITUTION GROUP (super-admin) ----
  // (a) the page POOL the group may grant to roles; (b) the admin pages the
  //     group's admins see. Both apply to every organisation in the group.

  /// GET /api/access/group/{groupId}/pages -> ceiling (a): the role page-pool.
  static Future<List<Map<String, dynamic>>> getGroupPages(String groupId) async {
    final uri = Uri.parse('$_base/api/access/group/$groupId/pages');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['modules'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load group pages');
  }

  /// PUT /api/access/group/{groupId}/page/{moduleKey} {enabled}
  static Future<void> setGroupPage({
    required String groupId,
    required String moduleKey,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_base/api/access/group/$groupId/page/$moduleKey');
    final r = await http
        .put(uri, headers: AuthSession.instance.headers(), body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update page');
  }

  /// POST /api/access/group/{groupId}/pages/bulk {enabled} — enable/revoke all.
  static Future<void> setAllGroupPages({required String groupId, required bool enabled}) async {
    final uri = Uri.parse('$_base/api/access/group/$groupId/pages/bulk');
    final r = await http
        .post(uri, headers: AuthSession.instance.headers(), body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update pages');
  }

  /// GET /api/access/group/{groupId}/admin-pages -> ceiling (b): the admin pages.
  static Future<List<Map<String, dynamic>>> getAdminPages(String groupId) async {
    final uri = Uri.parse('$_base/api/access/group/$groupId/admin-pages');
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

  /// PUT /api/access/group/{groupId}/admin-page/{moduleKey} {enabled}
  static Future<void> setAdminPage({
    required String groupId,
    required String moduleKey,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_base/api/access/group/$groupId/admin-page/$moduleKey');
    final r = await http
        .put(uri, headers: AuthSession.instance.headers(), body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update admin page');
  }

  /// POST /api/access/group/{groupId}/admin-pages/bulk {enabled} — show/hide all.
  static Future<void> setAllAdminPages({required String groupId, required bool enabled}) async {
    final uri = Uri.parse('$_base/api/access/group/$groupId/admin-pages/bulk');
    final r = await http
        .post(uri, headers: AuthSession.instance.headers(), body: json.encode({'enabled': enabled}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update admin pages');
  }

  // ---- Admin: own organisations + switcher ----
  /// GET /api/auth/my-organisations -> [{id, name, code, is_active}]
  static Future<List<Map<String, dynamic>>> getMyOrganisations() async {
    final uri = Uri.parse('$_base/api/auth/my-organisations');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load your organisations');
  }

  /// Re-scope the session to one of the admin's organisations (new JWT).
  /// POST /api/auth/switch-organisation/{organisationId} -> TokenResponse (applied to session).
  static Future<void> switchOrganisation({required String organisationId}) async {
    final uri = Uri.parse('$_base/api/auth/switch-organisation/$organisationId');
    final r = await http
        .post(uri, headers: AuthSession.instance.headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      AuthSession.instance.setFromLogin(json.decode(r.body) as Map<String, dynamic>);
      // The admin/role page ceilings (admin_enabled + role grants) are PER-ORGANISATION,
      // so re-fetch permissions for the new active org — otherwise the sidebar
      // shows the previous organisation's pages until the next login.
      PermissionStore.instance.clear();
      await PermissionStore.instance.load();
      return;
    }
    throw _err(r, 'Failed to switch organisation');
  }
}
