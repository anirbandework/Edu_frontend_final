// lib/services/assignment_service.dart
//
// Assignments: teacher create/list, student list+submit (PDF), teacher grade.
// CRUD lives under /assessment/assignments; submit/grade under /assessment/grading.
// The server derives the acting teacher/student from the JWT.
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class AssignmentService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  static String get _tenant => AuthSession.instance.tenantId ?? '';

  /// Create an assignment (teacher). subject is a name; teacher_id is from JWT.
  /// POST /assessment/assignments
  static Future<Map<String, dynamic>> createAssignment({
    required String classId,
    required String title,
    required String subject,
    required String academicYear,
    String type = 'assignment',
    String? description,
    String? dueDate, // ISO-8601
    num maxMarks = 100,
    bool allowLate = false,
  }) async {
    final uri = Uri.parse('$_base/assessment/assignments');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'class_id': classId,
              'assessment_title': title,
              'subject': subject,
              'assessment_type': type,
              'academic_year': academicYear,
              'max_marks': maxMarks,
              'allow_late_submission': allowLate,
              if (description != null && description.isNotEmpty) 'description': description,
              if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
            }))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create assignment');
  }

  /// GET /assessment/assignments/class/{classId}
  static Future<List<Map<String, dynamic>>> getClassAssignments({required String classId}) =>
      _list('$_base/assessment/assignments/class/$classId');

  /// GET /assessment/assignments/student/{studentId} (each with submission status)
  static Future<List<Map<String, dynamic>>> getStudentAssignments({required String studentId}) =>
      _list('$_base/assessment/assignments/student/$studentId');

  static Future<List<Map<String, dynamic>>> _list(String url) async {
    final r = await http
        .get(Uri.parse(url), headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load assignments');
  }

  /// Student uploads a PDF submission (multipart).
  /// POST /assessment/grading/submit-assignment/{assessmentId}?student_id=&tenant_id=
  static Future<Map<String, dynamic>> submitAssignment({
    required String assessmentId,
    required Uint8List fileBytes,
    required String filename,
    String? studentId,
  }) async {
    final uri = Uri.parse('$_base/assessment/grading/submit-assignment/$assessmentId')
        .replace(queryParameters: {
      'student_id': studentId ?? (AuthSession.instance.userId ?? ''),
      'tenant_id': _tenant,
    });
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(AuthSession.instance.headers(json: false))
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to submit assignment');
  }

  /// Teacher lists submissions for an assignment.
  /// GET /assessment/grading/submissions/{assessmentId}?tenant_id=
  static Future<Map<String, dynamic>> getSubmissions({required String assessmentId}) async {
    final uri = Uri.parse('$_base/assessment/grading/submissions/$assessmentId')
        .replace(queryParameters: {'tenant_id': _tenant});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load submissions');
  }

  /// Teacher grades a submission. marks/grade/feedback are QUERY params.
  /// POST /assessment/grading/grade-submission/{submissionId}
  static Future<void> gradeSubmission({
    required String submissionId,
    required double marks,
    required String grade,
    String feedback = '',
  }) async {
    final uri = Uri.parse('$_base/assessment/grading/grade-submission/$submissionId')
        .replace(queryParameters: {
      'marks': marks.toString(),
      'grade': grade,
      'feedback': feedback,
    });
    final r = await http
        .post(uri, headers: AuthSession.instance.headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to grade submission');
  }
}
