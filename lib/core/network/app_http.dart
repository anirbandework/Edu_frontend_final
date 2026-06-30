// lib/core/network/app_http.dart
//
// Drop-in replacement for the `http` package's top-level get/post/put/patch/delete,
// for AUTHENTICATED service calls. A service opts in by changing only its import:
//
//     import 'package:http/http.dart' as http;   // before
//     import '../core/network/app_http.dart' as http;   // after — same call sites
//
// What it adds over raw http:
//   • attaches the current bearer token itself (the caller's `headers:` arg is IGNORED,
//     which is what makes the retry below use the FRESH token, not the stale one);
//   • on a 401, runs ONE single-flight refresh and retries the request once;
//   • when refresh fails (refresh token expired, or the account/org/group was
//     deactivated → backend 403s the refresh) it hard-clears the session, which
//     notifies the router (refreshListenable: AuthSession) and redirects home.
//
// Do NOT use this for the pre-auth endpoints (login / refresh / signup / forgot-
// password / the public org list) — those stay on the raw `http` package.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../auth/permission_store.dart';
import '../constants/app_constants.dart';
import '../utils/org_session.dart';

// Re-export Response so callers that alias this file as `http` still get `http.Response`.
export 'package:http/http.dart' show Response;

const Duration _timeout = Duration(seconds: 15);

// Collapses concurrent refreshes: if many requests 401 at once they all await the
// SAME refresh future instead of stampeding /refresh.
Future<bool>? _refreshing;

Map<String, String> _auth({required bool json}) =>
    AuthSession.instance.headers(json: json);

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    _send(() => http.get(url, headers: _auth(json: false)).timeout(_timeout));

Future<http.Response> post(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.post(url, headers: _auth(json: true), body: body, encoding: encoding).timeout(_timeout));

Future<http.Response> put(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.put(url, headers: _auth(json: true), body: body, encoding: encoding).timeout(_timeout));

Future<http.Response> patch(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.patch(url, headers: _auth(json: true), body: body, encoding: encoding).timeout(_timeout));

Future<http.Response> delete(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.delete(url, headers: _auth(json: false), body: body, encoding: encoding).timeout(_timeout));

/// Send a multipart request (file upload) through the same 401-refresh/retry/hard-logout
/// path. Pass a BUILDER, not a request — a MultipartRequest is single-use, so a retry
/// after refresh rebuilds it; fresh auth is attached on each attempt (don't set it yourself).
Future<http.Response> multipart(http.MultipartRequest Function() build,
        {Duration timeout = const Duration(minutes: 3)}) =>
    _send(() async {
      final req = build()..headers.addAll(_auth(json: false));
      final streamed = await req.send().timeout(timeout);
      return http.Response.fromStream(streamed);
    });

/// Runs `call`; on a 401 refreshes once (single-flight) and retries. The closure
/// rebuilds its headers each invocation, so the retry uses the freshly-minted token.
Future<http.Response> _send(Future<http.Response> Function() call) async {
  var resp = await call();

  if (resp.statusCode == 401 &&
      (AuthSession.instance.refreshToken?.isNotEmpty ?? false)) {
    final refreshed = await _refreshOnce();
    if (refreshed && AuthSession.instance.isAuthenticated) {
      resp = await call(); // retry once with the new access token
    }
    if (resp.statusCode == 401) {
      _hardLogout(); // refresh failed, or the new token is still rejected
    }
  } else if (resp.statusCode == 403 && _isDeactivation(resp)) {
    _hardLogout(); // account/org/group deactivated mid-session
  }
  return resp;
}

Future<bool> _refreshOnce() =>
    _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

Future<bool> _doRefresh() async {
  final rt = AuthSession.instance.refreshToken;
  if (rt == null || rt.isEmpty) return false;
  try {
    final r = await http
        .post(
          Uri.parse('${AppConstants.apiBaseUrl}/api/auth/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': rt}),
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      AuthSession.instance.setFromLogin(jsonDecode(r.body) as Map<String, dynamic>);
      return true;
    }
    return false; // 401/403 → refresh token expired or session revoked/deactivated
  } catch (_) {
    return false; // network/timeout
  }
}

bool _isDeactivation(http.Response r) {
  try {
    final d = jsonDecode(r.body);
    final detail = (d is Map ? (d['detail']?.toString() ?? '') : '').toLowerCase();
    return detail.contains('deactivated') || detail.contains('session expired');
  } catch (_) {
    return false;
  }
}

/// Clear all client-side session state. AuthSession.clear() notifies the router
/// (refreshListenable) which redirects to the home/landing route.
void _hardLogout() {
  AuthSession.instance.clear();
  PermissionStore.instance.clear();
  OrgSession.clearData();
}
