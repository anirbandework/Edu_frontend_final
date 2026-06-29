// lib/services/auth_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/permission_store.dart';

class AuthResult {
  final bool ok;
  final String? error;
  final Map<String, dynamic>? data;
  const AuthResult(this.ok, {this.error, this.data});
}

class AuthApiService {
  static Uri _u(String path) => Uri.parse('${AppConstants.apiBaseUrl}$path');
  static const _json = {'Content-Type': 'application/json'};

  static String _err(http.Response r, String fallback) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {}
    return '$fallback (${r.statusCode})';
  }

  // ---- login (phone + password) ----
  static Future<AuthResult> login(String phone, String password, {String? tenantId}) async {
    try {
      final r = await http.post(_u('/api/auth/login'),
          headers: _json,
          body: jsonEncode({
            'phone': phone.trim(),
            'password': password,
            if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
          }));
      if (r.statusCode == 200) {
        AuthSession.instance.setFromLogin(jsonDecode(r.body) as Map<String, dynamic>);
        await PermissionStore.instance.load();
        return const AuthResult(true);
      }
      return AuthResult(false, error: _err(r, 'Invalid phone or password'));
    } catch (e) {
      return AuthResult(false, error: 'Could not reach server: $e');
    }
  }

  static Future<void> logout() async {
    final t = AuthSession.instance.accessToken;
    if (t != null && t.isNotEmpty) {
      try {
        await http.post(_u('/api/auth/logout'), headers: {'Authorization': 'Bearer $t'});
      } catch (_) {}
    }
    AuthSession.instance.clear();
    PermissionStore.instance.clear();
  }

  // ---- first-login signup (phone + OTP, NO invite) ----
  static Future<AuthResult> signupRequestOtp(String phone) async {
    return _post('/api/auth/signup/request-otp', {'phone': phone.trim()},
        'Could not send code');
  }

  static Future<AuthResult> signupVerify({
    required String phone,
    required String otp,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final r = await http.post(_u('/api/auth/signup/verify'),
          headers: _json,
          body: jsonEncode({
            'phone': phone.trim(),
            'otp': otp.trim(),
            'password': password,
            if (firstName != null) 'first_name': firstName,
            if (lastName != null) 'last_name': lastName,
          }));
      if (r.statusCode == 200) {
        AuthSession.instance.setFromLogin(jsonDecode(r.body) as Map<String, dynamic>);
        await PermissionStore.instance.load();
        return const AuthResult(true);
      }
      return AuthResult(false, error: _err(r, 'Signup failed'));
    } catch (e) {
      return AuthResult(false, error: 'Could not reach server: $e');
    }
  }

  // ---- forgot password ----
  static Future<AuthResult> forgotRequestOtp(String phone) =>
      _post('/api/auth/password/request-otp', {'phone': phone.trim()}, 'Could not send code');

  static Future<AuthResult> resetPassword(String phone, String otp, String newPassword) =>
      _post('/api/auth/password/reset',
          {'phone': phone.trim(), 'otp': otp.trim(), 'new_password': newPassword}, 'Reset failed');

  // ---- invites (authed: super-admin / authority) ----
  static Future<AuthResult> inviteAuthority({
    required String tenantId,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
  }) =>
      _authedPost('/api/auth/invites/authority', {
        'tenant_id': tenantId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });

  // ---- helpers ----
  static Future<AuthResult> _post(String path, Map<String, dynamic> body, String fallback) async {
    try {
      final r = await http.post(_u(path), headers: _json, body: jsonEncode(body));
      if (r.statusCode == 200) {
        return AuthResult(true, data: jsonDecode(r.body) as Map<String, dynamic>);
      }
      return AuthResult(false, error: _err(r, fallback));
    } catch (e) {
      return AuthResult(false, error: 'Could not reach server: $e');
    }
  }

  static Future<AuthResult> _authedPost(String path, Map<String, dynamic> body) async {
    try {
      final r = await http.post(_u(path), headers: AuthSession.instance.headers(), body: jsonEncode(body));
      if (r.statusCode == 200) {
        return AuthResult(true, data: jsonDecode(r.body) as Map<String, dynamic>);
      }
      return AuthResult(false, error: _err(r, 'Request failed'));
    } catch (e) {
      return AuthResult(false, error: 'Could not reach server: $e');
    }
  }
}
