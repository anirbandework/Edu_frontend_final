// lib/features/members/services/staff_service.dart
//
// Staff & Users directory (unified staff_users table). Add/list/manage users
// assigned to dynamic roles. Creation is delegation-gated server-side.
// Backed by /api/staff/* and /api/access/assignable-roles.
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/network/app_http.dart' as http; // routes authed calls through the 401-refresh/hard-logout wrapper
import 'package:http/http.dart' as mhttp; // raw client, for the multipart bulk-import upload

import '../../../core/constants/app_constants.dart';
import '../../../core/auth/auth_session.dart';

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

  /// GET /api/staff?q=&limit=&offset= -> paginated + server-side searched.
  /// Returns the page items plus the total count so callers can "load more".
  static Future<({List<Map<String, dynamic>> items, int total})> listStaffPage({
    String q = '',
    String? roleId,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_base/api/staff').replace(queryParameters: {
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (roleId != null && roleId.isNotEmpty) 'role_id': roleId,
      'limit': '$limit',
      'offset': '$offset',
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final total = (d is Map && d['total'] is num) ? (d['total'] as num).toInt() : 0;
      return (items: _asList(d), total: total);
    }
    throw _err(r, 'Failed to load staff');
  }

  /// GET /api/staff/{id} -> one member's full record INCLUDING custom-field values
  /// (those are intentionally NOT in the list payload). Used by the details view.
  static Future<Map<String, dynamic>> getStaff(String id) async {
    final uri = Uri.parse('$_base/api/staff/$id');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load user');
  }

  /// GET /api/staff/import/template?role_id= -> the .xlsx template bytes for a role.
  static Future<Uint8List> downloadImportTemplate(String roleId) async {
    final uri = Uri.parse('$_base/api/staff/import/template')
        .replace(queryParameters: {'role_id': roleId});
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return r.bodyBytes;
    throw _err(r, 'Failed to download template');
  }

  /// POST /api/staff/import (multipart) -> bulk-create members of [roleId] from an
  /// uploaded .xlsx/.csv. Returns {created, skipped:[{row,reason}], failed:[{row,reason}], total}.
  static Future<Map<String, dynamic>> bulkImport({
    required String roleId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse('$_base/api/staff/import');
    // Through the app_http wrapper so a token expiring mid-upload is refreshed + retried
    // (or hard-logged-out), like every other authed call. Builder, not request, so the
    // retry rebuilds it; the wrapper attaches fresh auth — don't set it here.
    final r = await http.multipart(() => mhttp.MultipartRequest('POST', uri)
      ..fields['role_id'] = roleId
      ..files.add(mhttp.MultipartFile.fromBytes('file', bytes, filename: fileName)));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Bulk import failed');
  }

  /// POST /api/staff
  static Future<Map<String, dynamic>> createStaff({
    required String firstName,
    required String lastName,
    required String phone,
    required String roleId,
    String? email,
    String? position,
    Map<String, dynamic>? customFields,
  }) async {
    // No password: the user sets their own at first login (phone + OTP).
    final uri = Uri.parse('$_base/api/staff');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'first_name': firstName,
              'last_name': lastName,
              'phone': phone,
              'rbac_role_id': roleId,
              if (email != null && email.isNotEmpty) 'email': email,
              if (position != null && position.isNotEmpty) 'position': position,
              if (customFields != null) 'custom_fields': customFields,
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
    Map<String, dynamic>? customFields,
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
              if (customFields != null) 'custom_fields': customFields,
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
}
