// lib/services/rbac_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

/// Client for the module/tab RBAC API (/api/access/*).
class RbacApiService {
  static String get _base => AppConstants.apiBaseUrl;
  static Map<String, String> get _h => AuthSession.instance.headers();
  static Map<String, String> get _hg => AuthSession.instance.headers(json: false);

  static Future<List<dynamic>> listRoles({String? userType}) async {
    final q = userType != null ? '?user_type=$userType' : '';
    final r = await http.get(Uri.parse('$_base/api/access/roles$q'), headers: _hg);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception(_err(r));
  }

  static Future<Map<String, dynamic>> createRole({
    required String userType,
    required String roleName,
    String? description,
    bool isDefault = false,
  }) async {
    final r = await http.post(Uri.parse('$_base/api/access/roles'),
        headers: _h,
        body: jsonEncode({
          'user_type': userType,
          'role_name': roleName,
          if (description != null) 'description': description,
          'is_default': isDefault,
        }));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_err(r));
  }

  static Future<void> deleteRole(String roleId) async {
    final r = await http.delete(Uri.parse('$_base/api/access/roles/$roleId'), headers: _hg);
    if (r.statusCode != 200) throw Exception(_err(r));
  }

  /// Returns the role's module list (with enabled + tab_permissions).
  static Future<Map<String, dynamic>> rolePermissions(String roleId) async {
    final r = await http.get(Uri.parse('$_base/api/access/roles/$roleId/permissions'), headers: _hg);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_err(r));
  }

  static Future<void> toggleRoleModule(String roleId, String moduleKey, bool enabled) async {
    final r = await http.put(Uri.parse('$_base/api/access/roles/$roleId/module/$moduleKey'),
        headers: _h, body: jsonEncode({'enabled': enabled}));
    if (r.statusCode != 200) throw Exception(_err(r));
  }

  static Future<void> toggleRoleTab(String roleId, String moduleKey, String tabKey, bool enabled) async {
    final r = await http.put(Uri.parse('$_base/api/access/roles/$roleId/module/$moduleKey/tab/$tabKey'),
        headers: _h, body: jsonEncode({'enabled': enabled}));
    if (r.statusCode != 200) throw Exception(_err(r));
  }

  static Future<List<dynamic>> listUsers(String userType) async {
    final r = await http.get(Uri.parse('$_base/api/access/users?user_type=$userType'), headers: _hg);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception(_err(r));
  }

  static Future<void> assignRole({required String userType, required String userId, String? roleId}) async {
    final r = await http.post(Uri.parse('$_base/api/access/assign'),
        headers: _h, body: jsonEncode({'user_type': userType, 'user_id': userId, 'role_id': roleId}));
    if (r.statusCode != 200) throw Exception(_err(r));
  }

  // --- super-admin tenant ceiling ---
  static Future<Map<String, dynamic>> tenantPermissions(String tenantId) async {
    final r = await http.get(Uri.parse('$_base/api/access/tenant/$tenantId/permissions'), headers: _hg);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_err(r));
  }

  static Future<void> toggleTenantModule(String tenantId, String moduleKey,
      {bool? authority, bool? teacher, bool? student}) async {
    final r = await http.put(Uri.parse('$_base/api/access/tenant/$tenantId/module/$moduleKey'),
        headers: _h,
        body: jsonEncode({
          if (authority != null) 'authority_enabled': authority,
          if (teacher != null) 'teacher_enabled': teacher,
          if (student != null) 'student_enabled': student,
        }));
    if (r.statusCode != 200) throw Exception(_err(r));
  }

  static Future<void> toggleTenantTab(String tenantId, String moduleKey, String tabKey, bool enabled) async {
    final r = await http.put(Uri.parse('$_base/api/access/tenant/$tenantId/module/$moduleKey/tab/$tabKey'),
        headers: _h, body: jsonEncode({'enabled': enabled}));
    if (r.statusCode != 200) throw Exception(_err(r));
  }

  static String _err(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {}
    return 'Request failed (${r.statusCode})';
  }
}
