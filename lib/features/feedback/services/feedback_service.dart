// lib/features/feedback/services/feedback_service.dart
//
// Feedback: any authenticated user can submit; the super-admin lists/triages.
// /api/v1/feedback (submit = any user; list/status/stats/delete = super-admin).
import 'dart:convert';
import '../../../core/network/app_http.dart' as http; // routes authed calls through the 401-refresh/hard-logout wrapper

import '../../../core/constants/app_constants.dart';
import '../../../core/auth/auth_session.dart';

class FeedbackService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  /// Submit feedback (any logged-in user).
  static Future<void> submit({
    required String title,
    required String message,
    String feedbackType = 'suggestion',
    int? rating,
    String? userName,
    String? userPhone,
  }) async {
    final uri = Uri.parse('$_base/api/v1/feedback');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'title': title,
              'message': message,
              'feedback_type': feedbackType,
              if (rating != null) 'rating': rating,
              if (userName != null && userName.isNotEmpty) 'user_name': userName,
              if (userPhone != null && userPhone.isNotEmpty) 'user_phone': userPhone,
            }))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to submit feedback');
  }

  /// All feedback (super-admin), newest first, optionally filtered.
  static Future<List<Map<String, dynamic>>> getAll({String? status, String? type}) async {
    final uri = Uri.parse('$_base/api/v1/feedback').replace(queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'feedback_type': type,
    });
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is List ? d : (d is Map ? d['items'] : null)) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load feedback');
  }

  /// Status counts (super-admin).
  static Future<Map<String, dynamic>> getStats() async {
    final uri = Uri.parse('$_base/api/v1/feedback/stats');
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to load feedback stats');
  }

  /// Move feedback through pending -> reviewed -> resolved (super-admin).
  static Future<void> setStatus({required String id, required String status}) async {
    final uri = Uri.parse('$_base/api/v1/feedback/$id/status');
    final r = await http
        .patch(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({'status': status}))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to update status');
  }

  /// Soft-delete feedback (super-admin).
  static Future<void> delete({required String id}) async {
    final uri = Uri.parse('$_base/api/v1/feedback/$id');
    final r = await http
        .delete(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to delete feedback');
  }
}
