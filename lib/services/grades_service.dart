// lib/services/grades_service.dart
//
// Exam marks / grades, wired to the REAL backend. IMPORTANT: the exam-management
// router is mounted BARE in app/main.py — there is NO /api/v1 prefix. Paths are
// literally /exam-management/... . The server derives the acting staff member
// (created_by / marked_by) from the JWT, so client-supplied ids are nominal.
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class GradesService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// List exams for the tenant (auto-scoped from JWT for non-super-admin).
  /// GET /exam-management/exams  -> plain array of ExamResponse
  static Future<List<Map<String, dynamic>>> getExams({int limit = 200}) async {
    final uri = Uri.parse('$_base/exam-management/exams')
        .replace(queryParameters: {'skip': '0', 'limit': '$limit'});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load exams');
  }

  /// Create an exam. class_ids is REQUIRED (min 1). created_by is from the JWT.
  /// POST /exam-management/exams
  static Future<Map<String, dynamic>> createExam({
    required String examName,
    required String examCode,
    required String examType,
    required String academicYear,
    required List<String> classIds,
    String? subject,
    String? term,
    String? description,
    String? examDate, // ISO-8601
    int? durationMinutes,
    List<int>? gradeLevels,
  }) async {
    final uri = Uri.parse('$_base/exam-management/exams');
    final body = <String, dynamic>{
      'exam_name': examName,
      'exam_code': examCode,
      'exam_type': examType,
      'academic_year': academicYear,
      'class_ids': classIds,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      if (term != null && term.isNotEmpty) 'term': term,
      if (description != null && description.isNotEmpty) 'description': description,
      if (examDate != null && examDate.isNotEmpty) 'exam_date': examDate,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (gradeLevels != null && gradeLevels.isNotEmpty) 'grade_levels': gradeLevels,
    };
    final r = await http
        .post(uri, headers: AuthSession.instance.headers(), body: json.encode(body))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create exam');
  }

  /// Soft-delete an exam.
  /// DELETE /exam-management/exams/{examId}
  static Future<void> deleteExam({required String examId}) async {
    final uri = Uri.parse('$_base/exam-management/exams/$examId');
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to delete exam');
  }

  /// Exam-level analytics (averages, pass %, grade distribution).
  /// GET /exam-management/exams/{examId}/analytics
  static Future<Map<String, dynamic>> getExamAnalytics({required String examId}) async {
    final uri = Uri.parse('$_base/exam-management/exams/$examId/analytics');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load analytics');
  }

  /// Existing marks for an exam, optionally a single class. Returns ONLY students
  /// who already have a mark row (names/roll joined in). Merge with the class
  /// roster to seed an entry grid for unmarked students.
  /// GET /exam-management/exams/{examId}/marks?class_id=...
  static Future<List<Map<String, dynamic>>> getExamMarks({
    required String examId,
    String? classId,
  }) async {
    final uri = Uri.parse('$_base/exam-management/exams/$examId/marks').replace(
      queryParameters: {
        'skip': '0',
        'limit': '1000',
        if (classId != null && classId.isNotEmpty) 'class_id': classId,
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
    throw _err(r, 'Failed to load marks');
  }

  /// Bulk upsert marks for an exam. The backend auto-resolves each student's
  /// class from their active enrollment, so NO class_id is sent. Each entry is a
  /// full mark object: {student_id, marks_data, total_marks, obtained_marks,
  /// percentage, grade, remarks, attendance_status}. `student_id` must be the
  /// students-table UUID (the roster's `id` field).
  /// POST /exam-management/exams/{examId}/bulk-marks
  static Future<Map<String, dynamic>> saveBulkMarks({
    required String examId,
    required List<Map<String, dynamic>> marks,
    String? batchName,
  }) async {
    final uri = Uri.parse('$_base/exam-management/exams/$examId/bulk-marks');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'exam_id': examId,
              'marks_data': marks,
              if (batchName != null) 'batch_name': batchName,
            }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to save marks');
  }

  /// Publish an exam's results to students.
  /// POST /exam-management/exams/{examId}/publish
  static Future<void> publishExam({required String examId}) async {
    final uri = Uri.parse('$_base/exam-management/exams/$examId/publish');
    final r = await http
        .post(uri, headers: AuthSession.instance.headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to publish results');
  }

  /// A student's report card aggregated from their exam marks (by subject).
  /// GET /exam-management/students/{studentId}/report-card
  static Future<Map<String, dynamic>> getStudentReportCard({
    required String studentId,
    String? academicYear,
  }) async {
    final uri = Uri.parse('$_base/exam-management/students/$studentId/report-card')
        .replace(queryParameters: {
      if (academicYear != null && academicYear.isNotEmpty) 'academic_year': academicYear,
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load report card');
  }

  /// A single student's results across all exams (student/results view).
  /// GET /exam-management/students/{studentId}/exam-history
  static Future<Map<String, dynamic>> getStudentExamHistory({
    required String studentId,
  }) async {
    final uri = Uri.parse('$_base/exam-management/students/$studentId/exam-history');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load results');
  }
}
