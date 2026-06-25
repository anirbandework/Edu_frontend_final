import 'dart:convert';
import 'dart:io' show File, HttpException;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import '../core/auth/auth_session.dart';

class ClassApi {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  const ClassApi({
    required this.baseUrl,
    this.defaultHeaders = const {'Content-Type': 'application/json'},
  });

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$baseUrl$path').replace(
        queryParameters: q?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );

  Map<String, String> _jsonHeaders() {
    final h = <String, String>{};
    h.addAll(defaultHeaders);
    h['Content-Type'] = 'application/json';
    h['Accept'] = h['Accept'] ?? 'application/json';
    h.addAll(AuthSession.instance.headers());
    return h;
  }

  Future<Map<String, dynamic>> getPaginated({
    int page = 1,
    int pageSize = 20,
    String? tenantId,
    int? gradeLevel,
    String? section,
    String? academicYear,
    bool? isActive,
  }) async {
    final query = {
      'page': page,
      'page_size': pageSize,
      if (tenantId != null) 'tenant_id': tenantId,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (section != null && section.isNotEmpty) 'section': section,
      if (academicYear != null && academicYear.isNotEmpty)
        'academic_year': academicYear,
      if (isActive != null) 'is_active': isActive,
    };
    final headers = Map<String, String>.from(defaultHeaders)..remove('Content-Type');
    headers.addAll(AuthSession.instance.headers(json: false));
    final res = await http.get(_u('/api/v1/school_authority/classes/', query), headers: headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw HttpException('Failed to load classes: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final res = await http.get(
      _u('/api/v1/school_authority/classes/$id'),
      headers: _jsonHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw HttpException('Failed to load class');
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final cur = payload['current_students'] as int? ?? 0;
    final max = payload['maximum_students'] as int? ?? 0;
    if (cur > max) {
      throw HttpException('Create failed: current_students cannot exceed maximum_students');
    }

    final res = await http.post(
      _u('/api/v1/school_authority/classes/'),
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Create class failed ${res.statusCode}: ${res.body}');
    debugPrint('Payload sent: $payload');
    throw HttpException('Create failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> payload) async {
    final res = await http.put(
      _u('/api/v1/school_authority/classes/$id'),
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Update class failed ${res.statusCode}: ${res.body}');
    throw HttpException('Update failed');
  }

  Future<void> delete(String id) async {
    final res = await http.delete(
      _u('/api/v1/school_authority/classes/$id'),
      headers: _jsonHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('Delete class failed ${res.statusCode}: ${res.body}');
      throw HttpException('Delete failed');
    }
  }

  Future<Map<String, dynamic>> stats(String tenantId) async {
    final res = await http.get(
      _u('/api/v1/school_authority/classes/statistics/$tenantId'),
      headers: _jsonHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw HttpException('Stats failed');
  }

  Future<Map<String, dynamic>> updateStudentCount(String id, int newCount) async {
    final res = await http.patch(
      _u('/api/v1/school_authority/classes/$id/student-count'),
      headers: _jsonHeaders(),
      body: jsonEncode({'new_count': newCount}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Update student count failed ${res.statusCode}: ${res.body}');
    throw HttpException('Student count failed');
  }

  // Native path version for servers that accept multipart/form-data
  Future<Map<String, dynamic>> bulkImportCsv({
    required String tenantId,
    required File csvFile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/school_authority/classes/bulk/import');
    final req = http.MultipartRequest('POST', uri);
    req.fields['tenant_id'] = tenantId;
    req.files.add(await http.MultipartFile.fromPath('file', csvFile.path, contentType: MediaType('text', 'csv')));
    defaultHeaders.forEach((k, v) {
      if (k.toLowerCase() != 'content-type') req.headers[k] = v;
    });
    req.headers.addAll(AuthSession.instance.headers(json: false));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    debugPrint('Bulk import (path) failed ${res.statusCode}: $body');
    throw HttpException('Bulk import failed: ${res.statusCode} $body');
  }

  // Helper: parse CSV text into array of class objects for JSON bulk import
  List<Map<String, dynamic>> _parseCsvToClasses(String csvText) {
    final lines = csvText.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final header = lines.first.split(',').map((s) => s.trim()).toList();
    final index = {for (var i = 0; i < header.length; i++) header[i]: i};

    int idxOf(String key) => index[key] ?? -1;
    String get(List<String> cols, String key) {
      final i = idxOf(key);
      if (i < 0 || i >= cols.length) return '';
      return cols[i].trim();
    }

    final result = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final raw = lines[i];
      if (raw.trim().isEmpty) continue;
      final cols = raw.split(',').map((s) => s.trim()).toList();
      if (cols.length < header.length) continue;

      final className = get(cols, 'class_name');
      if (className.isEmpty) continue;

      final gradeLevel = int.tryParse(get(cols, 'grade_level')) ?? 0;
      final section = get(cols, 'section');
      final academicYear = get(cols, 'academic_year');
      final maxStudents = int.tryParse(get(cols, 'maximum_students')) ?? 0;
      final curStudents = int.tryParse(get(cols, 'current_students')) ?? 0;
      final classroomStr = get(cols, 'classroom');
      final isActiveStr = get(cols, 'is_active').toLowerCase();
      final isActive = isActiveStr == 'true' || isActiveStr == '1' || isActiveStr == 'yes';

      result.add({
        'class_name': className,
        'grade_level': gradeLevel,
        'section': section,
        'academic_year': academicYear,
        'maximum_students': maxStudents,
        'current_students': curStudents,
        'classroom': classroomStr.isEmpty ? null : classroomStr,
        'is_active': isActive,
      });
    }
    return result;
  }

  // JSON bulk import for servers that expect {"tenant_id": "...", "classes": [...]}
  Future<Map<String, dynamic>> bulkImportWithPickerResult({
    required String tenantId,
    required FilePickerResult pick,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/school_authority/classes/bulk/import');
    final file = pick.files.single;

    // Read CSV text (web: bytes are present; native: read from path)
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final csvText = utf8.decode(bytes);

    // Build classes array
    final classes = _parseCsvToClasses(csvText);

    final payload = {
      'tenant_id': tenantId,
      'classes': classes, // server requires this field
    };

    final res = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Bulk import (json classes) failed ${res.statusCode}: ${res.body}');
    throw HttpException('Bulk import failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> bulkUpdateCapacity({
    required String tenantId,
    required List<Map<String, dynamic>> updates,
  }) async {
    final res = await http.post(
      _u('/api/v1/school_authority/classes/bulk/update-capacity'),
      headers: _jsonHeaders(),
      body: jsonEncode({'tenant_id': tenantId, 'updates': updates}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Bulk update capacity failed ${res.statusCode}: ${res.body}');
    throw HttpException('Bulk capacity failed');
  }

  Future<Map<String, dynamic>> bulkUpdateStatus({
    required String tenantId,
    required List<String> classIds,
    required bool isActive,
  }) async {
    final res = await http.post(
      _u('/api/v1/school_authority/classes/bulk/update-status'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'tenant_id': tenantId,
        'class_ids': classIds,
        'is_active': isActive,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Bulk update status failed ${res.statusCode}: ${res.body}');
    throw HttpException('Bulk status failed');
  }

  Future<Map<String, dynamic>> assignClassrooms({
    required String tenantId,
    required Map<String, String?> classroomMap,
  }) async {
    final res = await http.post(
      _u('/api/v1/school_authority/classes/bulk/assign-classrooms'),
      headers: _jsonHeaders(),
      body: jsonEncode({'tenant_id': tenantId, 'classrooms': classroomMap}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Assign classrooms failed ${res.statusCode}: ${res.body}');
    throw HttpException('Assign classrooms failed');
  }

  Future<Map<String, dynamic>> rollover({
    required String tenantId,
    required String fromYear,
    required String toYear,
    List<String>? classIds,
  }) async {
    final res = await http.post(
      _u('/api/v1/school_authority/classes/bulk/academic-year-rollover'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'tenant_id': tenantId,
        'from_academic_year': fromYear,
        'to_academic_year': toYear,
        if (classIds != null) 'class_ids': classIds,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Rollover failed ${res.statusCode}: ${res.body}');
    throw HttpException('Rollover failed');
  }

  Future<Map<String, dynamic>> bulkDelete({
    required String tenantId,
    required List<String> classIds,
  }) async {
    final res = await http.post(
      _u('/api/v1/school_authority/classes/bulk/delete'),
      headers: _jsonHeaders(),
      body: jsonEncode({'tenant_id': tenantId, 'class_ids': classIds}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('Bulk delete failed ${res.statusCode}: ${res.body}');
    throw HttpException('Bulk delete failed');
  }
}
