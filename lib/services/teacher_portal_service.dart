// lib/services/teacher_portal_service.dart
//
// Teacher-facing reads/writes wired to the REAL backend endpoints (the older
// teacher_service.dart pointed at several routes that don't exist). Everything
// here uses AuthSession headers; the server derives the acting teacher from the
// JWT, so we never trust a client-supplied teacher id for authorization.
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class TeacherPortalService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// The teacher's weekly timetable.
  /// GET /api/v1/school_authority/timetable/teacher/{teacherId}/schedule
  static Future<Map<String, dynamic>> getMySchedule({
    required String teacherId,
    String academicYear = '2025-26',
  }) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/timetable/teacher/$teacherId/schedule',
    ).replace(queryParameters: {
      'academic_year': academicYear,
      'requester_type': 'teacher',
      'requester_id': teacherId,
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load schedule');
  }

  /// Tenant class list (for class pickers). Read endpoint available to staff.
  /// GET /api/v1/school_authority/classes/?tenant_id=...
  static Future<List<Map<String, dynamic>>> getClasses({required String tenantId}) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/classes/').replace(
      queryParameters: {'tenant_id': tenantId, 'page': '1', 'size': '100'},
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final items = (d is Map ? d['items'] : d) as List? ?? const [];
      return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load classes');
  }

  /// Class roster: members actively enrolled in a class (with names/roll).
  /// GET /api/v1/school_authority/classes/{classId}/students
  /// Member model — each roster item:
  ///   `member_id`   = members table UUID (the canonical member PK / marks user_id)
  ///   `member_hrid` = the human-readable school code (member.staff_id, e.g. STU001)
  ///   `member_name` = first + last name
  static Future<Map<String, dynamic>> getClassRoster({required String classId}) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/classes/$classId/students',
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load class roster');
  }

  /// Students of a class with their attendance for a date.
  /// GET /attendance/class/{classId}/students-with-attendance/{date}
  static Future<Map<String, dynamic>> getClassAttendance({
    required String classId,
    required String date,
  }) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/attendance/class/$classId/students-with-attendance/$date',
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load class attendance');
  }

  /// Bulk-mark attendance for a class on a date. The server derives the marker
  /// (marked_by / marked_by_type) from the JWT, so the body values are nominal.
  /// POST /attendance/class/{classId}/bulk-update-attendance
  static Future<Map<String, dynamic>> markClassAttendance({
    required String classId,
    required String date,
    required List<Map<String, dynamic>> updates,
    required String teacherId,
  }) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/attendance/class/$classId/bulk-update-attendance',
    );
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'attendance_updates': updates,
              'attendance_date': date,
              'marked_by': teacherId,
              'marked_by_type': 'staff',
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to save attendance');
  }

  /// The teacher's own identity profile.
  /// GET /api/auth/user-profile/{userId}?tenant_id=...
  static Future<Map<String, dynamic>> getMyProfile({
    required String userId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/api/auth/user-profile/$userId').replace(
      queryParameters: {
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load profile');
  }
}
