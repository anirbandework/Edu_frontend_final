// lib/features/services/school_authority_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class AuthorityService {
  static const String _baseUrl = AppConstants.apiBaseUrl;

  /// Get authority by ID
  static Future<Map<String, dynamic>> getAuthorityById(String authorityId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/authorities/$authorityId'),
        headers: AuthSession.instance.headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('School Authority not found with this ID');
      } else if (response.statusCode == 422) {
        throw Exception('Invalid ID format');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      }
      throw Exception('Error fetching authority: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Get authorities by tenant ID
  static Future<Map<String, dynamic>> getAuthoritiesByTenant({
    required String tenantId,
    int page = 1,
    int size = 20,
    String? search,
    String? role,
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
      if (role != null && role.isNotEmpty) {
        queryParams['role'] = role;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/api/v1/tenants/$tenantId/authorities').replace(
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
      throw Exception('Error fetching authorities: $e');
    }
  }

  /// Create new authority
  static Future<Map<String, dynamic>> createAuthority(Map<String, dynamic> authorityData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/authorities/'),
        headers: AuthSession.instance.headers(),
        body: json.encode(authorityData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create authority');
      }
    } catch (e) {
      throw Exception('Error creating authority: $e');
    }
  }

  /// Update authority
  static Future<Map<String, dynamic>> updateAuthority(String authorityId, Map<String, dynamic> authorityData) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/authorities/$authorityId'),
        headers: AuthSession.instance.headers(),
        body: json.encode(authorityData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update authority');
      }
    } catch (e) {
      throw Exception('Error updating authority: $e');
    }
  }

  /// Delete authority
  static Future<void> deleteAuthority(String authorityId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/authorities/$authorityId'),
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete authority');
      }
    } catch (e) {
      throw Exception('Error deleting authority: $e');
    }
  }
}
