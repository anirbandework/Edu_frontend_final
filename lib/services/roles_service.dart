// lib/services/roles_service.dart
//
// Dynamic RBAC roles for a organisation (admin-defined). A role is { name, pages
// (cross-section module keys), creatable_role_ids (delegated user creation) }.
// Backed by /api/access/* (catalog, roles, role detail).
import 'dart:convert';
import '../core/network/app_http.dart' as http; // routes authed calls through the 401-refresh/hard-logout wrapper

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class RolesService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// GET /api/access/grantable-pages -> catalog + `locked` flag (the org doesn't
  /// have the page → show "Premium/upgrade", not assignable). Use this in the
  /// admin's role page-picker instead of the raw catalog.
  static Future<List<Map<String, dynamic>>> getGrantablePages() async {
    final uri = Uri.parse('$_base/api/access/grantable-pages');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['modules'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load pages');
  }

  /// GET /api/access/roles?user_type=staff -> dynamic roles for this organisation.
  static Future<List<Map<String, dynamic>>> listRoles({String userType = 'staff'}) async {
    final uri = Uri.parse('$_base/api/access/roles')
        .replace(queryParameters: {'user_type': userType});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load roles');
  }

  /// GET /api/access/roles/{id}/detail -> { role_name, description, modules:[keys],
  /// creatable_role_ids:[ids] } — to prefill the editor.
  static Future<Map<String, dynamic>> getRoleDetail(String roleId) async {
    final uri = Uri.parse('$_base/api/access/roles/$roleId/detail');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load role');
  }

  /// POST /api/access/roles — creates a dynamic (staff) role with its pages +
  /// delegated creatable roles in one call.
  static Future<Map<String, dynamic>> createRole({
    required String roleName,
    String? description,
    List<String> modules = const [],
    List<String> creatableRoleIds = const [],
  }) async {
    final uri = Uri.parse('$_base/api/access/roles');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'role_name': roleName,
              'user_type': 'staff',
              if (description != null && description.isNotEmpty) 'description': description,
              'modules': modules,
              'creatable_role_ids': creatableRoleIds,
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create role');
  }

  /// PUT /api/access/roles/{id} — update name/pages/delegation.
  static Future<void> updateRole({
    required String roleId,
    String? roleName,
    String? description,
    List<String>? modules,
    List<String>? creatableRoleIds,
  }) async {
    final uri = Uri.parse('$_base/api/access/roles/$roleId');
    final r = await http
        .put(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              if (roleName != null) 'role_name': roleName,
              if (description != null) 'description': description,
              if (modules != null) 'modules': modules,
              if (creatableRoleIds != null) 'creatable_role_ids': creatableRoleIds,
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update role');
  }

  /// DELETE /api/access/roles/{id}
  static Future<void> deleteRole(String roleId) async {
    final uri = Uri.parse('$_base/api/access/roles/$roleId');
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to delete role');
  }
}
