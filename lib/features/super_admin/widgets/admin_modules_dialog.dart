// lib/features/super_admin/widgets/admin_modules_dialog.dart
//
// Grant/revoke which module/pages an admin (and all their schools) can use.
// Loads the module catalog, pre-selects the admin's current grant, saves via
// SuperAdminService.updateAdminModules. AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../../../shared/widgets/page_group_toggle.dart';

/// Shows the module-access editor for [adminId]. Returns true if saved.
Future<bool?> showAdminModulesDialog(
  BuildContext context, {
  required String adminId,
  required String adminName,
  required List<String> currentModules,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _AdminModulesDialog(
      adminId: adminId,
      adminName: adminName,
      currentModules: currentModules,
    ),
  );
}

class _AdminModulesDialog extends StatefulWidget {
  final String adminId;
  final String adminName;
  final List<String> currentModules;
  const _AdminModulesDialog({
    required this.adminId,
    required this.adminName,
    required this.currentModules,
  });

  @override
  State<_AdminModulesDialog> createState() => _AdminModulesDialogState();
}

class _AdminModulesDialogState extends State<_AdminModulesDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _catalog = [];
  late final Set<String> _selected = {...widget.currentModules};
  PageGroupMode _groupMode = PageGroupMode.function;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cat = await SuperAdminService.getModuleCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = cat;
        // Required pages (e.g. Profile) are always granted.
        _selected.addAll(
            cat.where((m) => m['required'] == true).map((m) => m['module_key'].toString()));
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SuperAdminService.updateAdminModules(
          adminId: widget.adminId, modules: _selected.toList());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Page access · ${widget.adminName}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 460,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${_selected.length} of ${_catalog.length} granted',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selected
                        ..clear()
                        ..addAll(_catalog.map((m) => m['module_key'].toString()))),
                      child: const Text('All'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selected
                        ..clear()
                        // keep required pages (Profile) on even after "None"
                        ..addAll(_catalog
                            .where((m) => m['required'] == true)
                            .map((m) => m['module_key'].toString()))),
                      child: const Text('None'),
                    ),
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
                      children: groupCatalog(_catalog, _groupMode)
                          .entries
                          .map(_groupSection)
                          .toList(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: (_loading || _saving) ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: AppTheme.iconSmall),
          label: Text(_saving ? 'Saving…' : 'Save access'),
        ),
      ],
    );
  }

  /// A group (function/audience) header with per-group select-all, then its rows.
  Widget _groupSection(MapEntry<String, List<Map<String, dynamic>>> e) {
    // Required pages can't be toggled; per-group select-all/clear skips them.
    final keys = e.value.where((m) => m['required'] != true)
        .map((m) => m['module_key'].toString()).toList();
    final allOn = keys.isNotEmpty && keys.every(_selected.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
          child: Row(children: [
            Expanded(
              child: Text(e.key,
                  style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w700, color: AppTheme.neutral700)),
            ),
            if (keys.isNotEmpty)
              InkWell(
                onTap: () => setState(() =>
                    allOn ? _selected.removeAll(keys) : _selected.addAll(keys)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(allOn ? 'Clear' : 'Select all',
                      style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
        ...e.value.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _moduleToggleRow(m),
            )),
        const SizedBox(height: 6),
      ],
    );
  }

  /// One module per horizontal line: name on the left, on/off switch on the
  /// right (matches the indusinfotechs per-module toggle layout).
  Widget _moduleToggleRow(Map<String, dynamic> m) {
    final key = m['module_key'].toString();
    final name = (m['module_name'] ?? key).toString();
    final required = m['required'] == true;
    final on = required || _selected.contains(key);
    void toggle() {
      if (required) return; // Profile etc. can't be switched off
      setState(() {
        if (_selected.contains(key)) {
          _selected.remove(key);
        } else {
          _selected.add(key);
        }
      });
    }

    return InkWell(
      borderRadius: AppTheme.borderRadius8,
      onTap: required ? null : toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppTheme.green50 : AppTheme.neutral50,
          borderRadius: AppTheme.borderRadius8,
          border: Border.all(
              color: on ? AppTheme.greenPrimary.withOpacity(0.4) : AppTheme.neutral200),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.check_circle : Icons.circle_outlined,
                size: 18, color: on ? AppTheme.greenPrimary : AppTheme.neutral400),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
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
            Switch(
              value: on,
              onChanged: required ? null : (_) => toggle(),
              activeColor: AppTheme.greenPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
