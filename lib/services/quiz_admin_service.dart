// lib/services/quiz_admin_service.dart
//
// Teacher quiz authoring (require_staff). Create-with-questions is the preferred
// one-shot create path. Status PATCH makes a quiz available to students. Real
// backend under /assessment/quiz (NO /api/v1 prefix).
//
// CONTRACT: options is a Dict{key:text}; correct_answer must be the KEY for
// multiple_choice (server compares student_answer.upper()==correct_answer.upper())
// and "True"/"False" for true_false (compared case-insensitively).
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class QuizAdminService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// Create a quiz with inline questions.
  /// POST /assessment/quiz/quizzes/create-with-questions
  /// Each question: {question_text, question_type, difficulty_level, options?,
  ///                 correct_answer, explanation?, points}
  static Future<Map<String, dynamic>> createWithQuestions({
    required String title,
    required String subject,
    int? gradeLevel,
    String? description,
    String? instructions,
    List<String>? classIds,
    int? timeLimit,
    bool allowRetakes = false,
    bool showResultsImmediately = true,
    required List<Map<String, dynamic>> questions,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/quizzes/create-with-questions');
    final body = <String, dynamic>{
      'title': title,
      'subject': subject,
      'questions': questions,
      'allow_retakes': allowRetakes,
      'show_results_immediately': showResultsImmediately,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (description != null && description.isNotEmpty) 'description': description,
      if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
      if (classIds != null && classIds.isNotEmpty) 'class_ids': classIds,
      if (timeLimit != null) 'time_limit': timeLimit,
    };
    final r = await http
        .post(uri, headers: AuthSession.instance.headers(), body: json.encode(body))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to create quiz');
  }

  /// List quizzes created by a teacher (teacher_id forced to caller for teachers).
  /// GET /assessment/quiz/teachers/{teacherId}/quizzes
  static Future<List<Map<String, dynamic>>> getTeacherQuizzes({
    required String teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/teachers/$teacherId/quizzes').replace(
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
    throw _err(r, 'Failed to load quizzes');
  }

  /// Activate / deactivate (publish) a quiz so students can see it.
  /// PATCH /assessment/quiz/quizzes/{quizId}/status  body {is_active}
  static Future<void> setStatus({
    required String quizId,
    required bool isActive,
    String? teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/quizzes/$quizId/status').replace(
      queryParameters: {
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .patch(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'is_active': isActive}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update quiz status');
  }

  /// All student results for a quiz (teacher cohort view).
  /// GET /assessment/quiz/quizzes/{quizId}/results
  static Future<List<Map<String, dynamic>>> getQuizResults({
    required String quizId,
    String? teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/quizzes/$quizId/results').replace(
      queryParameters: {
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? (d['results'] ?? d['items']) : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load quiz results');
  }

  /// Short-answer answers awaiting manual grading (tenant-wide for the teacher).
  /// GET /assessment/quiz/grading/pending?tenant_id=(required)
  static Future<List<Map<String, dynamic>>> getPendingGrading({
    required String tenantId,
    String? teacherId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/grading/pending').replace(
      queryParameters: {
        'tenant_id': tenantId,
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
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
    throw _err(r, 'Failed to load pending grading');
  }

  /// Grade one short-answer answer.
  /// POST /assessment/quiz/grading/{answerId}  body {points_awarded}
  static Future<void> gradeAnswer({
    required String answerId,
    required int pointsAwarded,
    String? teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/grading/$answerId').replace(
      queryParameters: {
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'points_awarded': pointsAwarded}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to grade answer');
  }

  /// Attempts fully graded and ready to publish.
  /// GET /assessment/quiz/grading/ready-to-publish
  static Future<List<Map<String, dynamic>>> getReadyToPublish({
    String? teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/grading/ready-to-publish').replace(
      queryParameters: {
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
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
    throw _err(r, 'Failed to load ready-to-publish');
  }

  /// Publish results for the given attempt ids.
  /// POST /assessment/quiz/results/publish  body {attempt_ids}
  static Future<void> publishResults({
    required List<String> attemptIds,
    String? teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/results/publish').replace(
      queryParameters: {
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'attempt_ids': attemptIds}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to publish results');
  }

  /// Soft-delete a quiz.
  /// DELETE /assessment/quiz/quizzes/{quizId}
  static Future<void> deleteQuiz({
    required String quizId,
    String? teacherId,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$_base/assessment/quiz/quizzes/$quizId').replace(
      queryParameters: {
        if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      },
    );
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to delete quiz');
  }
}
