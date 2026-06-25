// lib/services/staff_service.dart
//
// Staff & Users directory (unified staff_users table). Add/list/manage users
// assigned to dynamic roles. Creation is delegation-gated server-side.
// Backed by /api/staff/* and /api/access/assignable-roles.
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class StaffService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  static List<Map<String, dynamic>> _asList(dynamic d) {
    final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// GET /api/access/assignable-roles -> roles the caller may assign when
  /// creating a user (admin = all; staff = only delegated roles).
  static Future<List<Map<String, dynamic>>> getAssignableRoles() async {
    final uri = Uri.parse('$_base/api/access/assignable-roles');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return _asList(json.decode(r.body));
    throw _err(r, 'Failed to load roles');
  }

  /// GET /api/staff -> [{id, name, phone, email, position, status, role_name,
  /// rbac_role_id, has_login}]
  static Future<List<Map<String, dynamic>>> listStaff() async {
    final uri = Uri.parse('$_base/api/staff');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return _asList(json.decode(r.body));
    throw _err(r, 'Failed to load staff');
  }

  /// POST /api/staff
  static Future<Map<String, dynamic>> createStaff({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String roleId,
    String? email,
    String? position,
  }) async {
    final uri = Uri.parse('$_base/api/staff');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'first_name': firstName,
              'last_name': lastName,
              'phone': phone,
              'password': password,
              'rbac_role_id': roleId,
              if (email != null && email.isNotEmpty) 'email': email,
              if (position != null && position.isNotEmpty) 'position': position,
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create staff member');
  }

  /// PUT /api/staff/{id}
  static Future<void> updateStaff({
    required String id,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? position,
    String? roleId,
  }) async {
    final uri = Uri.parse('$_base/api/staff/$id');
    final r = await http
        .put(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              if (firstName != null) 'first_name': firstName,
              if (lastName != null) 'last_name': lastName,
              if (phone != null) 'phone': phone,
              if (email != null) 'email': email,
              if (position != null) 'position': position,
              if (roleId != null) 'rbac_role_id': roleId,
            }))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update staff member');
  }

  /// PATCH /api/staff/{id}/status
  static Future<void> setStatus({required String id, required bool isActive}) async {
    final uri = Uri.parse('$_base/api/staff/$id/status');
    final r = await http
        .patch(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'is_active': isActive}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update status');
  }

  /// POST /api/staff/{id}/reset-password
  static Future<void> resetPassword({required String id, required String password}) async {
    final uri = Uri.parse('$_base/api/staff/$id/reset-password');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'password': password}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to reset password');
  }

  /// DELETE /api/staff/{id}
  static Future<void> deleteStaff(String id) async {
    final uri = Uri.parse('$_base/api/staff/$id');
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to delete staff member');
  }
}
