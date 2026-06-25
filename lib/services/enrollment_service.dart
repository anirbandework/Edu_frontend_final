// lib/services/enrollment_service.dart
//
// Enrolment management (require_authority for writes). Enrol students into a
// class, list a class's enrolments, and withdraw. Real backend under
// /api/v1/school_authority/enrollments and .../classes. AppTheme-agnostic.
//
// ID NOTE: the roster/available endpoints return `id` = students.id UUID and
// `student_id` = the human school code. Enrolment writes take the UUID.
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

  /// Students eligible to enrol in a class (same grade / ungraded, not already in).
  /// GET /api/v1/school_authority/classes/students/available-for-class/{classId}
  static Future<Map<String, dynamic>> getAvailableForClass({required String classId}) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/classes/students/available-for-class/$classId',
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load available students');
  }

  /// Raw enrolment rows for a class (gives enrollment_id needed to withdraw).
  /// GET /api/v1/school_authority/enrollments/class/{classId}
  /// -> [{id (enrollment id), student_id (UUID), academic_year, status}]
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

  /// Bulk-enrol many students into ONE class.
  /// POST /api/v1/school_authority/enrollments/bulk
  static Future<Map<String, dynamic>> bulkEnroll({
    required String classId,
    required List<String> studentIds,
    required String academicYear,
  }) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/enrollments/bulk');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'class_id': classId,
              'student_ids': studentIds,
              'academic_year': academicYear,
            }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to enrol students');
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

  /// Transfer students from one class to another.
  /// POST /api/v1/school_authority/enrollments/bulk/transfer
  static Future<Map<String, dynamic>> transferStudents({
    required List<String> studentIds,
    required String fromClassId,
    required String toClassId,
    required String academicYear,
  }) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/enrollments/bulk/transfer');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'student_ids': studentIds,
              'from_class_id': fromClassId,
              'to_class_id': toClassId,
              'academic_year': academicYear,
            }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to transfer students');
  }
}
