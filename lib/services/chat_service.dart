// lib/services/chat_service.dart
//
// 1:1 teacher<->student chat over REST. The backend also offers a websocket at
// /ws/chat?token= for realtime; this client uses REST + light polling (no extra
// dependency) — messages persist server-side so both parties converge.
// Endpoints under /api/v1/chat. The server derives the real sender from the JWT.
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class ChatService {
  static const String _base = AppConstants.apiBaseUrl;

  static Exception _err(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return Exception(d['detail'].toString());
    } catch (_) {}
    return Exception('$fallback (${r.statusCode})');
  }

  static String get _tenant => AuthSession.instance.tenantId ?? '';

  /// Conversations for a teacher: [{chat_room_id, student:{id,name,...,is_online},
  /// unread_count, last_message:{message,sender_type,created_at}|null}]
  static Future<List<Map<String, dynamic>>> getTeacherChats({required String teacherId}) async {
    return _chats('teacher', teacherId, 'chats');
  }

  /// Conversations for a student (counterpart is `teacher`).
  static Future<List<Map<String, dynamic>>> getStudentChats({required String studentId}) async {
    return _chats('student', studentId, 'chats');
  }

  static Future<List<Map<String, dynamic>>> _chats(String role, String id, String key) async {
    final uri = Uri.parse('$_base/api/v1/chat/$role/$id/chats')
        .replace(queryParameters: {'tenant_id': _tenant});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is Map ? d[key] : d) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load conversations');
  }

  /// People a teacher can start a new chat with.
  static Future<List<Map<String, dynamic>>> availableStudents({required String teacherId}) async {
    return _available('teacher', teacherId, 'available-students', 'available_students');
  }

  /// People a student can start a new chat with.
  static Future<List<Map<String, dynamic>>> availableTeachers({required String studentId}) async {
    return _available('student', studentId, 'available-teachers', 'available_teachers');
  }

  static Future<List<Map<String, dynamic>>> _available(
      String role, String id, String path, String key) async {
    final uri = Uri.parse('$_base/api/v1/chat/$role/$id/$path')
        .replace(queryParameters: {'tenant_id': _tenant});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is Map ? d[key] : d) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load contacts');
  }

  /// Resolve (or create) the room between a teacher and a student.
  /// GET /api/v1/chat/room/{teacherId}/{studentId}
  static Future<Map<String, dynamic>> getOrCreateRoom({
    required String teacherId,
    required String studentId,
  }) async {
    final uri = Uri.parse('$_base/api/v1/chat/room/$teacherId/$studentId')
        .replace(queryParameters: {'tenant_id': _tenant});
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to open conversation');
  }

  /// Message history for a room (newest pagination via offset/limit).
  /// GET /api/v1/chat/history/{chatRoomId}
  static Future<List<Map<String, dynamic>>> getHistory({
    required String chatRoomId,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_base/api/v1/chat/history/$chatRoomId').replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final r = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final list = (d is Map ? d['messages'] : d) as List? ?? const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw _err(r, 'Failed to load messages');
  }

  /// Send a message (REST). Auto-creates the room if absent.
  /// POST /api/v1/chat/send-message
  static Future<Map<String, dynamic>> sendMessage({
    required String teacherId,
    required String studentId,
    required String message,
    required String senderType, // 'teacher' | 'student'
  }) async {
    final uri = Uri.parse('$_base/api/v1/chat/send-message');
    final r = await http
        .post(uri,
            headers: AuthSession.instance.headers(),
            body: json.encode({
              'teacher_id': teacherId,
              'student_id': studentId,
              'tenant_id': _tenant,
              'message': message,
              'sender_type': senderType,
            }))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw _err(r, 'Failed to send message');
  }

  /// Mark the other party's messages in a room as read.
  /// POST /api/v1/chat/mark-read/{chatRoomId}
  static Future<void> markRead({required String chatRoomId}) async {
    final uri = Uri.parse('$_base/api/v1/chat/mark-read/$chatRoomId');
    final r = await http
        .post(uri, headers: AuthSession.instance.headers())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return;
    throw _err(r, 'Failed to mark read');
  }
}
