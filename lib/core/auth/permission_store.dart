// lib/core/auth/permission_store.dart
//
// Holds the logged-in user's effective module/tab permissions (from
// GET /api/access/my-permissions). Drives sidebar/route/tab gating — the same
// pattern as the indusinfotechs frontend. Server still enforces; this is UX.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'auth_session.dart';

class ModulePerm {
  final String key;
  final String name;
  final String path;
  final bool enabled;
  final bool locked;
  final Map<String, bool> tabPermissions;
  final Map<String, bool> lockedTabs;

  ModulePerm({
    required this.key,
    required this.name,
    required this.path,
    required this.enabled,
    required this.locked,
    required this.tabPermissions,
    required this.lockedTabs,
  });

  factory ModulePerm.fromJson(Map<String, dynamic> j) => ModulePerm(
        key: j['module_key'] as String,
        name: (j['module_name'] ?? '') as String,
        path: (j['path'] ?? '') as String,
        enabled: j['enabled'] != false,
        locked: j['locked'] == true,
        tabPermissions: ((j['tab_permissions'] ?? {}) as Map)
            .map((k, v) => MapEntry(k as String, v == true)),
        lockedTabs: ((j['locked_tabs'] ?? {}) as Map)
            .map((k, v) => MapEntry(k as String, v == true)),
      );
}

class PermissionStore extends ChangeNotifier {
  PermissionStore._();
  static final PermissionStore instance = PermissionStore._();

  final Map<String, ModulePerm> _modules = {};
  bool loaded = false;
  bool get isSuperAdmin => AuthSession.instance.role == 'super_admin';

  ModulePerm? module(String key) => _modules[key];
  List<ModulePerm> get modules => _modules.values.toList();

  /// Whether a module is available to the user. Permissive until permissions
  /// have loaded (avoids a flash of empty navigation); super-admin sees all.
  bool canModule(String? key) {
    if (key == null || key.isEmpty) return true;
    if (isSuperAdmin || !loaded) return true;
    final m = _modules[key];
    // Only hide when the module is in the user's set AND explicitly disabled.
    // (A missing module = catalog gap, not a deny — keep it visible; server enforces.)
    if (m == null) return true;
    return m.enabled;
  }

  /// Whether a tab within a module is available.
  bool canTab(String moduleKey, String tabKey) {
    if (isSuperAdmin || !loaded) return true;
    final m = _modules[moduleKey];
    if (m == null) return true;
    return m.tabPermissions[tabKey] ?? true;
  }

  /// Fetch the caller's effective permissions. Best-effort: on failure we stay
  /// permissive (the server still enforces).
  Future<void> load() async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/access/my-permissions'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        _modules.clear();
        for (final m in (body['modules'] as List? ?? [])) {
          final mp = ModulePerm.fromJson(m as Map<String, dynamic>);
          _modules[mp.key] = mp;
        }
        loaded = true;
        notifyListeners();
      }
    } catch (_) {
      // stay permissive; server enforces
    }
  }

  void clear() {
    _modules.clear();
    loaded = false;
    notifyListeners();
  }
}
