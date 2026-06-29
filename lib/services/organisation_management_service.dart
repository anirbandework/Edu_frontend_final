// lib/features/services/organisation_service.dart
import 'dart:convert';
import '../core/network/app_http.dart' as http; // authed calls get 401-refresh/hard-logout; the public org list is harmlessly passed through
import '../core/constants/app_constants.dart';
import '../core/models/organisation.dart';
import '../core/auth/auth_session.dart';

class OrganisationService {
  static const String _baseUrl = AppConstants.apiBaseUrl;

  /// Public (no auth) organisation list for the login picker — SERVER-SIDE search,
  /// capped. Pass `query` to filter by name/code; the backend never returns more than
  /// `limit` (≤50) rows, so this scales to 100k+ organisations.
  static Future<List<Organisation>> getPublicOrganisations({
    String query = '',
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/organisations').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'limit': '$limit',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list
          .map((e) => Organisation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load organisations (${response.statusCode})');
  }

  static String? _detail(http.Response r) {
    try {
      final d = json.decode(r.body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {}
    return null;
  }

  /// GET /api/auth/my-organisation -> the admin's ACTIVE organisation (full editable
  /// detail). Used by the profile → Organisation tab.
  static Future<Map<String, dynamic>> getMyOrganisation() async {
    final r = await http
        .get(Uri.parse('$_baseUrl/api/auth/my-organisation'),
            headers: AuthSession.instance.headers(json: false))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw Exception(_detail(r) ?? 'Failed to load organisation (${r.statusCode})');
  }

  /// PATCH /api/auth/my-organisation -> update the admin's ACTIVE organisation.
  static Future<Map<String, dynamic>> updateMyOrganisation(Map<String, dynamic> data) async {
    final r = await http
        .patch(Uri.parse('$_baseUrl/api/auth/my-organisation'),
            headers: AuthSession.instance.headers(), body: json.encode(data))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    throw Exception(_detail(r) ?? 'Failed to update organisation (${r.statusCode})');
  }

  /// Get organisation statistics
  static Future<Map<String, dynamic>> getOrganisationStats(String organisationId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/organisations/$organisationId/stats'),
        headers: AuthSession.instance.headers(json: false),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Statistics not found for this organisation');
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading statistics: $e');
    }
  }
}
