// lib/features/services/teacher_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class TeacherService {
  static const String _baseUrl = AppConstants.apiBaseUrl;

  /// Get teacher by ID
  static Future<Map<String, dynamic>> getTeacherById(String teacherId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/school_authority/teachers/$teacherId'),
        headers: AuthSession.instance.headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Teacher not found with this ID');
      } else if (response.statusCode == 422) {
        throw Exception('Invalid ID format');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      }
      throw Exception('Error fetching teacher: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Get teachers by tenant ID
  static Future<Map<String, dynamic>> getTeachersByTenant({
    required String tenantId,
    int page = 1,
    int size = 20,
    String? search,
    String? subject,
    String? department,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (subject != null && subject.isNotEmpty) {
        queryParams['subject'] = subject;
      }
      if (department != null && department.isNotEmpty) {
        queryParams['department'] = department;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/tenants/$tenantId/teachers').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching teachers: $e');
    }
  }

  /// Create new teacher
  static Future<Map<String, dynamic>> createTeacher(Map<String, dynamic> teacherData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/school_authority/teachers/'),
        headers: AuthSession.instance.headers(),
        body: json.encode(teacherData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create teacher');
      }
    } catch (e) {
      throw Exception('Error creating teacher: $e');
    }
  }

  /// Update teacher
  static Future<Map<String, dynamic>> updateTeacher(String teacherId, Map<String, dynamic> teacherData) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/school_authority/teachers/$teacherId'),
        headers: AuthSession.instance.headers(),
        body: json.encode(teacherData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update teacher');
      }
    } catch (e) {
      throw Exception('Error updating teacher: $e');
    }
  }

  /// Delete teacher
  static Future<void> deleteTeacher(String teacherId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/school_authority/teachers/$teacherId'),
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete teacher');
      }
    } catch (e) {
      throw Exception('Error deleting teacher: $e');
    }
  }

  /// Get teacher's classes
  static Future<Map<String, dynamic>> getTeacherClasses({
    required String teacherId,
    int page = 1,
    int size = 20,
    String? gradeLevel,
    String? section,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      if (gradeLevel != null && gradeLevel.isNotEmpty) {
        queryParams['grade_level'] = gradeLevel;
      }
      if (section != null && section.isNotEmpty) {
        queryParams['section'] = section;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/teachers/$teacherId/classes').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching classes: $e');
    }
  }

  /// Get teacher's assignments
  static Future<Map<String, dynamic>> getTeacherAssignments({
    required String teacherId,
    int page = 1,
    int size = 20,
    String? classId,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      if (classId != null && classId.isNotEmpty) {
        queryParams['class_id'] = classId;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/teachers/$teacherId/assignments').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching assignments: $e');
    }
  }

  /// Create assignment
  static Future<Map<String, dynamic>> createAssignment(Map<String, dynamic> assignmentData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/teachers/assignments/'),
        headers: AuthSession.instance.headers(),
        body: json.encode(assignmentData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create assignment');
      }
    } catch (e) {
      throw Exception('Error creating assignment: $e');
    }
  }

  /// Get teacher schedule
  static Future<Map<String, dynamic>> getTeacherSchedule({
    required String teacherId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final uri = Uri.parse('$_baseUrl/api/v1/teachers/$teacherId/schedule').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching schedule: $e');
    }
  }
}
