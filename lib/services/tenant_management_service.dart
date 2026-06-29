// lib/features/services/tenant_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/models/tenant.dart';
import '../core/auth/auth_session.dart';

class TenantService {
  static const String _baseUrl = AppConstants.apiBaseUrl;

  /// Public (no auth) minimal active-school list for the login picker.
  static Future<List<Tenant>> getPublicSchools() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/auth/schools'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list
          .map((e) => Tenant.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load schools (${response.statusCode})');
  }

  /// Fetch paginated list of tenants
  static Future<Map<String, dynamic>> getTenants({
    int page = 1,
    int size = 50,
    bool includeInactive = false,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/tenants/').replace(
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
          'include_inactive': includeInactive.toString(),
        },
      );
      
      final response = await http
          .get(uri, headers: AuthSession.instance.headers(json: false))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decodedResponse = json.decode(response.body);
        
        List<dynamic> tenantsData;
        bool hasMoreData = false;
        int total = 0;
        
        if (decodedResponse is Map<String, dynamic>) {
          if (decodedResponse.containsKey('items')) {
            tenantsData = decodedResponse['items'] as List<dynamic>;
            total = decodedResponse['total'] ?? 0;
            final int totalPages = (total / size).ceil();
            hasMoreData = page < totalPages;
          } else {
            throw Exception('Unexpected response format: Map without items key');
          }
        } else if (decodedResponse is List<dynamic>) {
          tenantsData = decodedResponse;
          hasMoreData = false;
        } else {
          throw Exception('Unexpected response format: ${decodedResponse.runtimeType}');
        }

        final List<Tenant> tenants = tenantsData
            .map((json) => Tenant.fromJson(json))
            .toList();

        return {
          'tenants': tenants,
          'hasMoreData': hasMoreData,
          'total': total,
        };
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get specific tenant by ID
  static Future<Tenant> getTenantById(String tenantId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/tenants/$tenantId');
      final response = await http
          .get(uri, headers: AuthSession.instance.headers(json: false))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final tenantData = json.decode(response.body);
        return Tenant.fromJson(tenantData);
      } else if (response.statusCode == 404) {
        throw Exception('Tenant not found');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching tenant: $e');
    }
  }

  /// Create new tenant
  static Future<Tenant> createTenant(Map<String, dynamic> tenantData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/tenants/'),
        headers: AuthSession.instance.headers(),
        body: json.encode(tenantData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return Tenant.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create tenant');
      }
    } catch (e) {
      throw Exception('Error creating tenant: $e');
    }
  }

  /// Update tenant
  static Future<Tenant> updateTenant(String tenantId, Map<String, dynamic> tenantData) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/tenants/$tenantId'),
        headers: AuthSession.instance.headers(),
        body: json.encode(tenantData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Tenant.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update tenant');
      }
    } catch (e) {
      throw Exception('Error updating tenant: $e');
    }
  }

  /// Delete tenant
  static Future<void> deleteTenant(String tenantId, {bool hardDelete = false}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/tenants/$tenantId').replace(
        queryParameters: hardDelete ? {'hard_delete': 'true'} : null,
      );
      
      final response = await http
          .delete(uri, headers: AuthSession.instance.headers(json: false))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete tenant');
      }
    } catch (e) {
      throw Exception('Error deleting tenant: $e');
    }
  }

  /// Reactivate tenant
  static Future<Tenant> reactivateTenant(String tenantId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/tenants/$tenantId/reactivate'),
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Tenant.fromJson(responseData);
      } else {
        throw Exception('Failed to reactivate tenant');
      }
    } catch (e) {
      throw Exception('Error reactivating tenant: $e');
    }
  }

  /// Get tenant statistics
  static Future<Map<String, dynamic>> getTenantStats(String tenantId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/tenants/$tenantId/stats'),
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Statistics not found for this tenant');
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading statistics: $e');
    }
  }
}
