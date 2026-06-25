// lib/features/super_admin/widgets/org_pages_dialog.dart
//
// Super-admin grants a SET OF PAGES to an ORGANISATION (the "what they paid for"
// ceiling). Each toggle writes immediately. Pages left off show as "Premium / not
// in plan" in the admin's role picker and are unusable by the org's users.
// Required pages (Profile) are always on. AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../../../shared/widgets/page_group_toggle.dart';

Future<void> showOrgPagesDialog(
  BuildContext context, {
  required String tenantId,
  required String tenantName,
}) {
  return showDialog(
    context: context,
    builder: (_) => _OrgPagesDialog(tenantId: tenantId, tenantName: tenantName),
  );
}

class _OrgPagesDialog extends StatefulWidget {
  final String tenantId;
  final String tenantName;
  const _OrgPagesDialog({required this.tenantId, required this.tenantName});

  @override
  State<_OrgPagesDialog> createState() => _OrgPagesDialogState();
}

class _OrgPagesDialogState extends State<_OrgPagesDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pages = [];
  final Map<String, bool> _enabled = {};
  PageGroupMode _groupMode = PageGroupMode.function;
  String? _busyKey; // page currently saving

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await SuperAdminService.getOrgPages(widget.tenantId);
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _enabled
          ..clear()
          ..addEntries(pages.map((m) => MapEntry(m['module_key'].toString(), m['enabled'] == true)));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _toast(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  Future<void> _toggle(String key, bool value) async {
    final prev = _enabled[key] ?? false;
    setState(() {
      _enabled[key] = value;
      _busyKey = key;
    });
    try {
      await SuperAdminService.setOrgPage(tenantId: widget.tenantId, moduleKey: key, enabled: value);
    } catch (e) {
      if (mounted) setState(() => _enabled[key] = prev); // revert
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _bulk(bool enabled) async {
    setState(() => _loading = true);
    try {
      await SuperAdminService.setAllOrgPages(tenantId: widget.tenantId, enabled: enabled);
      await _load();
      _toast(enabled ? 'All pages enabled' : 'All pages revoked', AppTheme.success);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  int get _onCount => _enabled.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.tune, color: AppTheme.greenPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Pages · ${widget.tenantName}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
      content: SizedBox(
        width: 480,
        height: 460,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary))
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, size: 36, color: AppTheme.error),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('$_onCount of ${_pages.length} pages enabled',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                      const Spacer(),
                      TextButton(onPressed: () => _bulk(true), child: const Text('Enable all')),
                      TextButton(onPressed: () => _bulk(false), child: const Text('Revoke all')),
                    ]),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PageGroupToggle(
                        mode: _groupMode,
                        onChanged: (m) => setState(() => _groupMode = m),
                      ),
                    ),
                    const Divider(height: 12),
                    Expanded(
                      child: ListView(
                        children: groupCatalog(_pages, _groupMode)
                            .entries
                            .map(_groupSection)
                            .toList(),
                      ),
                    ),
                  ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }

  Widget _groupSection(MapEntry<String, List<Map<String, dynamic>>> e) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        child: Text(e.key,
            style: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w700, color: AppTheme.neutral700)),
      ),
      ...e.value.map(_pageRow),
      const SizedBox(height: 4),
    ]);
  }

  Widget _pageRow(Map<String, dynamic> m) {
    final key = m['module_key'].toString();
    final required = m['required'] == true;
    final on = required || (_enabled[key] ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: on ? AppTheme.green50 : AppTheme.neutral50,
          borderRadius: AppTheme.borderRadius8,
          border: Border.all(
              color: on ? AppTheme.greenPrimary.withOpacity(0.4) : AppTheme.neutral200),
        ),
        child: Row(children: [
          Icon(on ? Icons.check_circle : Icons.circle_outlined,
              size: 18, color: on ? AppTheme.greenPrimary : AppTheme.neutral400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m['module_name']?.toString() ?? key,
                    style: AppTheme.bodyMedium.copyWith(
                        color: on ? AppTheme.neutral800 : AppTheme.neutral600,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (required)
                  Text('Always on',
                      style: AppTheme.bodyMicro.copyWith(color: AppTheme.greenPrimary)),
              ],
            ),
          ),
          if (_busyKey == key)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.greenPrimary))
          else
            Switch(
              value: on,
              onChanged: required ? null : (v) => _toggle(key, v),
              activeColor: AppTheme.greenPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ]),
      ),
    );
  }
}
