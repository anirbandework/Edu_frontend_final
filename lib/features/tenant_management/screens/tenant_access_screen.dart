// lib/features/tenant_management/screens/tenant_access_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/auth/auth_session.dart';
import '../../../services/rbac_api_service.dart';

/// Super-admin tier-0: configure which modules/tabs each school (tenant) may use,
/// per audience (Authority / Teacher / Student). This is the ceiling.
class TenantAccessScreen extends StatefulWidget {
  const TenantAccessScreen({super.key});

  @override
  State<TenantAccessScreen> createState() => _TenantAccessScreenState();
}

class _TenantAccessScreenState extends State<TenantAccessScreen> {
  List<Map<String, dynamic>> _schools = [];
  String? _tenantId;
  List<dynamic> _modules = [];
  bool _loadingSchools = true;
  bool _loadingPerms = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() => _loadingSchools = true);
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/?page=1&size=100'),
        headers: AuthSession.instance.headers(json: false),
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final items = (body is Map ? body['items'] : body) as List? ?? [];
        setState(() {
          _schools = items.cast<Map<String, dynamic>>();
          _tenantId = _schools.isNotEmpty ? _schools.first['id'].toString() : null;
        });
        if (_tenantId != null) await _loadPerms();
      } else {
        setState(() => _error = 'Could not load schools (${r.statusCode})');
      }
    } catch (e) {
      setState(() => _error = "Couldn't reach the server");
    } finally {
      if (mounted) setState(() => _loadingSchools = false);
    }
  }

  Future<void> _loadPerms() async {
    if (_tenantId == null) return;
    setState(() => _loadingPerms = true);
    try {
      final r = await RbacApiService.tenantPermissions(_tenantId!);
      setState(() => _modules = r['modules'] as List<dynamic>);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingPerms = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggle(Map<String, dynamic> mod, String audience, bool v) async {
    final field = '${audience}_enabled';
    setState(() => mod[field] = v);
    try {
      await RbacApiService.toggleTenantModule(_tenantId!, mod['module_key'],
          authority: audience == 'authority' ? v : null,
          teacher: audience == 'teacher' ? v : null,
          student: audience == 'student' ? v : null);
    } catch (e) {
      setState(() => mod[field] = !v);
      _snack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _toggleTab(Map<String, dynamic> mod, Map<String, dynamic> tab, bool v) async {
    setState(() => tab['enabled'] = v);
    try {
      await RbacApiService.toggleTenantTab(_tenantId!, mod['module_key'], tab['tab_key'], v);
    } catch (e) {
      setState(() => tab['enabled'] = !v);
      _snack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Module Access (Schools)'),
        backgroundColor: AppTheme.greenPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _loadingSchools
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    value: _tenantId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'School', border: OutlineInputBorder(), isDense: true),
                    items: _schools
                        .map((s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['school_name']?.toString() ?? s['id'].toString())))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _tenantId = v);
                      _loadPerms();
                    },
                  ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
              ),
            const SizedBox(height: 8),
            // legend
            Row(children: [
              Text('Per role: ', style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral500)),
              _legend('A', 'Authority'),
              _legend('T', 'Teacher'),
              _legend('S', 'Student'),
            ]),
            const Divider(),
            Expanded(
              child: _loadingPerms
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary))
                  : ListView(children: _modules.map((m) => _moduleTile(m as Map<String, dynamic>)).toList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String k, String label) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text('$k=$label', style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600)),
      );

  Widget _moduleTile(Map<String, dynamic> mod) {
    final audience = (mod['audience'] as List?)?.cast<String>() ?? [];
    final tabs = (mod['tabs'] as List?) ?? [];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: AppTheme.borderRadius12, side: BorderSide(color: AppTheme.neutral200)),
      child: ExpansionTile(
        title: Text(mod['module_name'] ?? mod['module_key'], style: AppTheme.labelMedium),
        subtitle: Row(
          children: [
            if (audience.contains('school_authority')) _audSwitch(mod, 'authority', 'A'),
            if (audience.contains('teacher')) _audSwitch(mod, 'teacher', 'T'),
            if (audience.contains('student')) _audSwitch(mod, 'student', 'S'),
          ],
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
        children: tabs.isEmpty
            ? [Padding(
                padding: const EdgeInsets.all(8),
                child: Text('No sub-sections', style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral400)))]
            : tabs.map<Widget>((t) {
                final tab = t as Map<String, dynamic>;
                return SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(tab['tab_label'] ?? tab['tab_key'], style: AppTheme.bodySmall),
                  value: tab['enabled'] == true,
                  activeColor: AppTheme.greenPrimary,
                  onChanged: (v) => _toggleTab(mod, tab, v),
                );
              }).toList(),
      ),
    );
  }

  Widget _audSwitch(Map<String, dynamic> mod, String audience, String label) {
    final v = mod['${audience}_enabled'] == true;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600)),
        Switch(
          value: v,
          activeColor: AppTheme.greenPrimary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (nv) => _toggle(mod, audience, nv),
        ),
      ]),
    );
  }
}
