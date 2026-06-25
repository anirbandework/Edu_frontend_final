// lib/services/student_portal_service.dart
//
// Student-facing reads/writes wired to the REAL backend. The student's own id
// (AuthSession.userId == students.id UUID) is passed as the `student_id` path
// param. Identity-checked endpoints (profile, quiz start/submit) are preferred.
//
// PREFIX NOTE: most data is under /api/v1/school_authority/... and /assessment/...
// but EXAMS live under a bare /exam-management/... (no /api/v1). The exam-results
// read is provided by GradesService.getStudentExamHistory.
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class StudentPortalService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  // ---- Profile (identity-checked: a student may fetch only their own) ----
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

  // ---- Enrolled class(es) ----
  /// GET /api/v1/school_authority/students/{studentId}/classes?academic_year=...
  /// -> {student_info, classes:[{id, class_name, grade_level, section, classroom,
  ///     enrollment_status, ...}], total_classes}
  static Future<Map<String, dynamic>> getMyClasses({
    required String studentId,
    String? academicYear,
  }) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/students/$studentId/classes')
        .replace(queryParameters: {
      if (academicYear != null && academicYear.isNotEmpty) 'academic_year': academicYear,
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load your class');
  }

  // ---- Class weekly timetable ----
  /// GET /api/v1/school_authority/timetable/class/{classId}/timetable?academic_year=...
  /// -> {class_id, academic_year, schedule:{monday:[{period_number,start_time,
  ///     end_time,subject_name,teacher_name,room_number}], ... saturday:[...]}}
  /// Day keys are lowercase monday..saturday; times are 'HH:MM' strings.
  static Future<Map<String, dynamic>> getClassTimetable({
    required String classId,
    required String academicYear,
  }) async {
    final uri = Uri.parse('$_base/api/v1/school_authority/timetable/class/$classId/timetable')
        .replace(queryParameters: {'academic_year': academicYear});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load timetable');
  }

  // ---- Attendance history (compute summary client-side; status is UPPERCASE) ----
  /// GET /api/v1/school_authority/attendance/students/{tenantId}/{studentId}/history
  ///   ?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD  (both optional; default last 30d)
  static Future<Map<String, dynamic>> getMyAttendanceHistory({
    required String tenantId,
    required String studentId,
    String? startDate,
    String? endDate,
  }) async {
    final uri = Uri.parse(
      '$_base/api/v1/school_authority/attendance/students/$tenantId/$studentId/history',
    ).replace(queryParameters: {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load attendance');
  }

  // ---- Quizzes ----
  /// GET /assessment/quiz/students/{studentId}/available-quizzes?tenant_id=...
  static Future<List<Map<String, dynamic>>> getAvailableQuizzes({
    required String studentId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/students/$studentId/available-quizzes')
        .replace(queryParameters: {
      if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load quizzes');
  }

  /// GET /assessment/quiz/quizzes/{quizId}/student  (questions WITHOUT answers)
  static Future<Map<String, dynamic>> getQuizForStudent({
    required String quizId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/quizzes/$quizId/student').replace(
      queryParameters: {
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load quiz');
  }

  /// POST /assessment/quiz/attempts/start  body {quiz_id}
  static Future<Map<String, dynamic>> startQuizAttempt({
    required String quizId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/attempts/start').replace(
      queryParameters: {
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'quiz_id': quizId}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to start quiz');
  }

  /// POST /assessment/quiz/attempts/submit  body {attempt_id, answers:[{question_id, student_answer}]}
  /// Identity-checked: 403 if the attempt is not the caller's.
  static Future<Map<String, dynamic>> submitQuizAttempt({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/attempts/submit').replace(
      queryParameters: {
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'attempt_id': attemptId, 'answers': answers}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to submit quiz');
  }

  /// GET /assessment/quiz/students/{studentId}/results  (only published shown)
  static Future<List<Map<String, dynamic>>> getMyQuizResults({
    required String studentId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/students/$studentId/results').replace(
      queryParameters: {
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load quiz results');
  }
}
