// lib/features/services/student_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class StudentService {
  static const String _baseUrl = AppConstants.apiBaseUrl;

  /// Get student by ID
  static Future<Map<String, dynamic>> getStudentById(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/school_authority/students/$studentId'),
        headers: AuthSession.instance.headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Student not found with this ID');
      } else if (response.statusCode == 422) {
        throw Exception('Invalid ID format');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      }
      throw Exception('Error fetching student: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Get students by tenant ID
  static Future<Map<String, dynamic>> getStudentsByTenant({
    required String tenantId,
    int page = 1,
    int size = 20,
    String? search,
    String? gradeLevel,
    String? section,
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
      if (gradeLevel != null && gradeLevel.isNotEmpty) {
        queryParams['grade_level'] = gradeLevel;
      }
      if (section != null && section.isNotEmpty) {
        queryParams['section'] = section;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/tenants/$tenantId/students').replace(
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
      throw Exception('Error fetching students: $e');
    }
  }

  /// Create new student
  static Future<Map<String, dynamic>> createStudent(Map<String, dynamic> studentData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/school_authority/students/'),
        headers: AuthSession.instance.headers(),
        body: json.encode(studentData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create student');
      }
    } catch (e) {
      throw Exception('Error creating student: $e');
    }
  }

  /// Update student
  static Future<Map<String, dynamic>> updateStudent(String studentId, Map<String, dynamic> studentData) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/school_authority/students/$studentId'),
        headers: AuthSession.instance.headers(),
        body: json.encode(studentData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update student');
      }
    } catch (e) {
      throw Exception('Error updating student: $e');
    }
  }

  /// Delete student
  static Future<void> deleteStudent(String studentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/school_authority/students/$studentId'),
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete student');
      }
    } catch (e) {
      throw Exception('Error deleting student: $e');
    }
  }

  /// Get student assignments
  static Future<Map<String, dynamic>> getStudentAssignments({
    required String studentId,
    int page = 1,
    int size = 20,
    String? subject,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      if (subject != null && subject.isNotEmpty) {
        queryParams['subject'] = subject;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/students/$studentId/assignments').replace(
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

  /// Get student grades
  static Future<Map<String, dynamic>> getStudentGrades({
    required String studentId,
    String? subject,
    String? examType,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (subject != null && subject.isNotEmpty) {
        queryParams['subject'] = subject;
      }
      if (examType != null && examType.isNotEmpty) {
        queryParams['exam_type'] = examType;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/students/$studentId/grades').replace(
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
      throw Exception('Error fetching grades: $e');
    }
  }

  /// Get student attendance
  static Future<Map<String, dynamic>> getStudentAttendance({
    required String studentId,
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

      final uri = Uri.parse('$_baseUrl/api/v1/students/$studentId/attendance').replace(
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
      throw Exception('Error fetching attendance: $e');
    }
  }
}
