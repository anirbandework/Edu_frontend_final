// lib/services/student_bulk_operations_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class StudentBulkOperationsService {
  static const String _baseUrl = '${AppConstants.apiBaseUrl}/api/v1/school_authority/students/bulk';

  // Bulk import students
  static Future<Map<String, dynamic>> importStudents({
    required String tenantId,
    required List<Map<String, dynamic>> students,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/import'),
      headers: AuthSession.instance.headers(),
      body: json.encode({
        'tenant_id': tenantId,
        'students': students,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to import students: ${response.statusCode}');
    }
  }

  // Bulk update grades
  static Future<Map<String, dynamic>> updateGrades({
    required String tenantId,
    required List<Map<String, dynamic>> gradeUpdates,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/update-grades'),
      headers: AuthSession.instance.headers(),
      body: json.encode({
        'tenant_id': tenantId,
        'grade_updates': gradeUpdates,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update grades: ${response.statusCode}');
    }
  }

  // Bulk promote students
  static Future<Map<String, dynamic>> promoteStudents({
    required String tenantId,
    required int currentGrade,
    required String academicYear,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/promote'),
      headers: AuthSession.instance.headers(),
      body: json.encode({
        'tenant_id': tenantId,
        'current_grade': currentGrade,
        'academic_year': academicYear,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to promote students: ${response.statusCode}');
    }
  }

  // Bulk update status
  static Future<Map<String, dynamic>> updateStatus({
    required String tenantId,
    required List<String> studentIds,
    required String newStatus,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/update-status'),
      headers: AuthSession.instance.headers(),
      body: json.encode({
        'tenant_id': tenantId,
        'student_ids': studentIds,
        'new_status': newStatus,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update status: ${response.statusCode}');
    }
  }

  // Bulk update sections
  static Future<Map<String, dynamic>> updateSections({
    required String tenantId,
    required List<Map<String, dynamic>> sectionUpdates,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/update-sections'),
      headers: AuthSession.instance.headers(),
      body: json.encode({
        'tenant_id': tenantId,
        'section_updates': sectionUpdates,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update sections: ${response.statusCode}');
    }
  }

  // Bulk delete students
  }
