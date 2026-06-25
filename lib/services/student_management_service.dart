// lib/services/student_management_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/auth/auth_session.dart';
import '../core/constants/app_constants.dart';
import '../core/models/student.dart';
import '../core/utils/school_session.dart';

class StudentManagementService {
  static const String _baseUrl = '${AppConstants.apiBaseUrl}/api/v1/school_authority/students';

  // Get paginated students with filtering
  static Future<Map<String, dynamic>> getStudents({
    int page = 1,
    int size = 20,
    String? tenantId,
    int? gradeLevel,
    String? section,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'size': size.toString(),
    };

    if (tenantId != null) queryParams['tenant_id'] = tenantId;
    if (gradeLevel != null) queryParams['grade_level'] = gradeLevel.toString();
    if (section != null && section.isNotEmpty) queryParams['section'] = section;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    final response = await http
        .get(uri, headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch students: ${response.statusCode}');
    }
  }

  // Create new student
  static Future<Student> createStudent(Map<String, dynamic> studentData) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: AuthSession.instance.headers(),
      body: json.encode(studentData),
    );

    if (response.statusCode == 200) {
      return Student.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create student: ${response.statusCode}');
    }
  }

  // Get specific student by ID
  static Future<Student> getStudent(String studentId) async {
    final response = await http.get(Uri.parse('$_baseUrl/$studentId'),
        headers: AuthSession.instance.headers(json: false));

    if (response.statusCode == 200) {
      return Student.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch student: ${response.statusCode}');
    }
  }

  // Update student information
  static Future<Student> updateStudent(String studentId, Map<String, dynamic> updateData) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$studentId'),
      headers: AuthSession.instance.headers(),
      body: json.encode(updateData),
    );

    if (response.statusCode == 200) {
      return Student.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update student: ${response.statusCode}');
    }
  }

  // Delete student (soft delete)
  static Future<String> deleteStudent(String studentId) async {
    final response = await http.delete(Uri.parse('$_baseUrl/$studentId'),
        headers: AuthSession.instance.headers(json: false));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to delete student: ${response.statusCode}');
    }
  }

  // Get students by tenant
  static Future<List<Student>> getStudentsByTenant(String tenantId) async {
    final response = await http.get(Uri.parse('$_baseUrl/tenant/$tenantId'),
        headers: AuthSession.instance.headers(json: false));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return data.map((json) => Student.fromJson(json)).toList();
      }
      return [];
    } else {
      throw Exception('Failed to fetch students by tenant: ${response.statusCode}');
    }
  }

  // Get students by grade
  static Future<List<Student>> getStudentsByGrade(int gradeLevel, {String? tenantId}) async {
    final queryParams = tenantId != null ? {'tenant_id': tenantId} : <String, String>{};
    final uri = Uri.parse('$_baseUrl/grade/$gradeLevel').replace(queryParameters: queryParams);
    
    final response = await http.get(uri,
        headers: AuthSession.instance.headers(json: false));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return data.map((json) => Student.fromJson(json)).toList();
      }
      return [];
    } else {
      throw Exception('Failed to fetch students by grade: ${response.statusCode}');
    }
  }

  // Get student statistics
  static Future<Map<String, dynamic>> getStudentStatistics(String tenantId) async {
    final response = await http.get(Uri.parse('$_baseUrl/statistics/$tenantId'),
        headers: AuthSession.instance.headers(json: false));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch statistics: ${response.statusCode}');
    }
  }

  // Export students
  static Future<String> exportStudents(
    String tenantId, {
    String format = 'json',
    int? gradeLevel,
    String? section,
    String status = 'active',
  }) async {
    final queryParams = {
      'format': format,
      'status': status,
    };

    if (gradeLevel != null) queryParams['grade_level'] = gradeLevel.toString();
    if (section != null && section.isNotEmpty) queryParams['section'] = section;

    final uri = Uri.parse('$_baseUrl/export/$tenantId').replace(queryParameters: queryParams);
    final response = await http.get(uri,
        headers: AuthSession.instance.headers(json: false));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to export students: ${response.statusCode}');
    }
  }
}
