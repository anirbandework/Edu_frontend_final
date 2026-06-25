// lib/features/admin/services/attendance_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models/attendance_models.dart';
import '../core/auth/auth_session.dart';

class AttendanceService {
  final String baseUrl;
  final http.Client _client;
  AttendanceService(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  Uri _u(String p, [Map<String, dynamic>? q]) =>
      Uri.parse('$baseUrl$p').replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  Future<Map<String, dynamic>> mark({
    required String markedBy,
    required UserType markedByType,
    required AttendanceRecord payload,
  }) async {
    final res = await _client.post(
      _u('/api/v1/school_authority/attendance/mark', {
        'marked_by': markedBy,
        'marked_by_type': userTypeTo(markedByType),
      }),
      headers: AuthSession.instance.headers(),
      body: jsonEncode(payload.toMarkBody()),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // The backend has a SINGLE mark endpoint (/attendance/mark) that takes the
  // user_type in the body; there are no /mark/student|teacher|authority routes.
  // These helpers post to /mark and inject the right user_type. marked_by /
  // marked_by_type are derived from the JWT server-side (query params nominal).
  Future<Map<String, dynamic>> markStudent({
    required String markedBy,
    required UserType markedByType,
    required Map<String, dynamic> body,
  }) =>
      _markOne(markedBy, markedByType, body, 'student');

  Future<Map<String, dynamic>> markTeacher({
    required String markedBy,
    required UserType markedByType,
    required Map<String, dynamic> body,
  }) =>
      _markOne(markedBy, markedByType, body, 'teacher');

  Future<Map<String, dynamic>> _markOne(
    String markedBy,
    UserType markedByType,
    Map<String, dynamic> body,
    String userType,
  ) async {
    final b = Map<String, dynamic>.from(body);
    b['user_type'] ??= userType;
    final res = await _client.post(
      _u('/api/v1/school_authority/attendance/mark', {
        'marked_by': markedBy,
        'marked_by_type': userTypeTo(markedByType),
      }),
      headers: AuthSession.instance.headers(),
      body: jsonEncode(b),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> markAuthority({
    required String markedBy,
    required Map<String, dynamic> body,
  }) =>
      _markOne(markedBy, UserType.school_authority, body, 'school_authority');

  Future<Map<String, dynamic>> bulkMark({
    required String tenantId,
    required List<Map<String, dynamic>> records,
  }) async {
    final res = await _client.post(
      _u('/api/v1/school_authority/attendance/bulk/mark'),
      headers: AuthSession.instance.headers(),
      body: jsonEncode({'tenant_id': tenantId, 'attendance_records': records}),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> bulkUpdateStatus({
    required List<String> attendanceIds,
    required String newStatus,
    required String updatedBy,
  }) async {
    final res = await _client.post(
      _u('/api/v1/school_authority/attendance/bulk/update-status'),
      headers: AuthSession.instance.headers(),
      body: jsonEncode({
        'attendance_ids': attendanceIds,
        'new_status': newStatus,
        'updated_by': updatedBy,
      }),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> bulkApproveAbsences({
    required List<String> attendanceIds,
    required String approvedBy,
    String? approvalRemarks,
  }) async {
    final res = await _client.post(
      _u('/api/v1/school_authority/attendance/bulk/approve-absences'),
      headers: AuthSession.instance.headers(),
      body: jsonEncode({
        'attendance_ids': attendanceIds,
        'approved_by': approvedBy,
        'approval_remarks': approvalRemarks,
      }..removeWhere((k, v) => v == null)),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  Future<List<AttendanceRecord>> getUserAttendance({
    required String userId,
    required UserType userType,
    required String requesterId,
    required UserType requesterType,
    DateTime? startDate,
    DateTime? endDate,
    AttendanceType? attendanceType,
  }) async {
    final q = {
      'user_type': userTypeTo(userType),
      'requester_id': requesterId,
      'requester_type': userTypeTo(requesterType),
      if (startDate != null) 'start_date': _d(startDate),
      if (endDate != null) 'end_date': _d(endDate),
      if (attendanceType != null) 'attendance_type': typeTo(attendanceType),
    };
    final res = await _client.get(_u('/api/v1/school_authority/attendance/user/$userId', q), headers: AuthSession.instance.headers(json: false));
    _check(res);
    final data = jsonDecode(res.body) as List;
    return data.map((e) => AttendanceRecord.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getDashboard({
    required String tenantId,
    UserType? userType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final q = {
      if (userType != null) 'user_type': userTypeTo(userType),
      if (startDate != null) 'start_date': _d(startDate),
      if (endDate != null) 'end_date': _d(endDate),
    };
    final res = await _client.get(_u('/api/v1/school_authority/attendance/dashboard/$tenantId', q), headers: AuthSession.instance.headers(json: false));
    _check(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getLowAttendance({
    required String tenantId,
    int thresholdPercentage = 75,
    UserType? userType,
  }) async {
    final q = {
      'threshold_percentage': '$thresholdPercentage',
      if (userType != null) 'user_type': userTypeTo(userType),
    };
    final res = await _client.get(_u('/api/v1/school_authority/attendance/low-attendance/$tenantId', q), headers: AuthSession.instance.headers(json: false));
    _check(res);
    return jsonDecode(res.body);
  }

  Future<List<AttendanceRecord>> getClassByDate({
    required String classId,
    required DateTime attendanceDate,
    int? periodNumber,
  }) async {
    final q = { if (periodNumber != null) 'period_number': '$periodNumber' };
    final res = await _client.get(_u('/api/v1/school_authority/attendance/class/$classId/date/${_d(attendanceDate)}', q), headers: AuthSession.instance.headers(json: false));
    _check(res);
    final data = jsonDecode(res.body) as List;
    return data.map((e) => AttendanceRecord.fromJson(e)).toList();
  }

  Future<AttendanceRecord> getById(String attendanceId) async {
    final res = await _client.get(_u('/api/v1/school_authority/attendance/$attendanceId'), headers: AuthSession.instance.headers(json: false));
    _check(res);
    return AttendanceRecord.fromJson(jsonDecode(res.body));
  }

  void _check(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
  }

  String _d(DateTime d) => d.toIso8601String().split('T').first;
}
