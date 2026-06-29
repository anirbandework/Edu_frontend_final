// lib/services/enrollment_service.dart
//
// Enrolment management (require_authority for writes). Enrol members into a
// class, list a class's enrolments, and withdraw. Real backend under
// /api/v1/school_authority/enrollments and .../classes. AppTheme-agnostic.
//
// MEMBER MODEL: an enrolled "student" is a MEMBER (members table) with an
// Enrollment row. The roster/available endpoints return `id` = members.id UUID
// and `member_hrid` = the human school code (member.staff_id). Enrolment writes
// take the member UUID (member_id / member_ids).
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class EnrollmentService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// Members eligible to enrol in a class (same grade / ungraded, not already in).
  /// GET /api/v1/school_authority/classes/students/available-for-class/{classId}
  static Future<Map<String, dynamic>> getAvailableForClass({required String classId}) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/classes/students/available-for-class/$classId',
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load available members');
  }

  /// Raw enrolment rows for a class (gives enrollment_id needed to withdraw).
  /// GET /api/v1/school_authority/enrollments/class/{classId}
  /// -> [{id (enrollment id), member_id (UUID), academic_year, status,
  ///      member_name, member_hrid}]
  static Future<List<Map<String, dynamic>>> getClassEnrollments({required String classId}) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/enrollments/class/$classId');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load enrolments');
  }

  /// Bulk-enrol many members into ONE class.
  /// POST /api/v1/school_authority/enrollments/bulk
  static Future<Map<String, dynamic>> bulkEnroll({
    required String classId,
    required List<String> memberIds,
    required String academicYear,
  }) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/enrollments/bulk');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'class_id': classId,
              'member_ids': memberIds,
              'academic_year': academicYear,
            }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to enrol members');
  }

  /// Soft-delete (withdraw) one enrolment.
  /// DELETE /api/v1/school_authority/enrollments/{enrollmentId}
  static Future<void> removeEnrollment({required String enrollmentId}) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/enrollments/$enrollmentId');
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to remove enrolment');
  }

  /// Transfer members from one class to another.
  /// POST /api/v1/school_authority/enrollments/bulk/transfer
  static Future<Map<String, dynamic>> transferStudents({
    required List<String> memberIds,
    required String fromClassId,
    required String toClassId,
    required String academicYear,
  }) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/enrollments/bulk/transfer');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'member_ids': memberIds,
              'from_class_id': fromClassId,
              'to_class_id': toClassId,
              'academic_year': academicYear,
            }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to transfer members');
  }
}
