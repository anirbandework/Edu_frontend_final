// lib/features/super_admin/widgets/group_pages_dialog.dart
//
// Per-INSTITUTION-GROUP page control for the super-admin. TWO independent ceilings,
// one tab each:
//   • Admin pages       — which pages the ADMIN of this organisation sees in their own
//                         sidebar/toolset (GET/PUT .../admin-page(s)).
//   • Group pages — which pages the admin may GIVE to their staff/teacher/
//                         student roles, "what they paid for" (.../page(s)).
// Each toggle writes immediately (optimistic, reverts on error). Required pages
// (Profile) are always on.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../services/super_admin_service.dart';
import '../../../shared/widgets/page_group_toggle.dart';
import '../../../shared/widgets/sa_widgets.dart';

Future<void> showGroupPagesDialog(
  BuildContext context, {
  required String groupId,
  required String groupName,
}) {
  return showDialog(
    context: context,
    builder: (_) => _GroupPagesDialog(groupId: groupId, groupName: groupName),
  );
}

class _GroupPagesDialog extends StatelessWidget {
  final String groupId;
  final String groupName;
  const _GroupPagesDialog({required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = media.size.width - 24;
    final maxH = media.size.height - 80;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW > 520 ? 520 : maxW,
          maxHeight: maxH,
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titleBar(context),
              const TabBar(
                labelColor: Sa.accent,
                unselectedLabelColor: AppTheme.neutral500,
                indicatorColor: Sa.accent,
                labelStyle: Sa.value,
                tabs: [
                  Tab(text: 'Admin pages'),
                  Tab(text: 'Group pages'),
                ],
              ),
              const Divider(height: 1),
              Flexible(
                child: TabBarView(
                  children: [
                    _PageGrantList(
                      key: const ValueKey('admin'),
                      groupId: groupId,
                      hint: "Pages the group's admins see in their own menu.",
                      load: SuperAdminService.getAdminPages,
                      toggle: SuperAdminService.setAdminPage,
                      bulk: SuperAdminService.setAllAdminPages,
                    ),
                    _PageGrantList(
                      key: const ValueKey('org'),
                      groupId: groupId,
                      hint: 'Pages admins can grant to staff roles in any organisation of the group.',
                      load: SuperAdminService.getGroupPages,
                      toggle: SuperAdminService.setGroupPage,
                      bulk: SuperAdminService.setAllGroupPages,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Sa.accent.withValues(alpha: 0.10),
            borderRadius: AppTheme.borderRadius8,
          ),
          child: const Icon(Icons.tune, color: Sa.accent, size: 20),
        ),
        const SizedBox(width: Sa.gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page access', style: Sa.cardTitle),
              const SizedBox(height: 2),
              Text(groupName,
                  style: Sa.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.neutral500),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }
}

/// A toggleable list of pages driven by injected load/toggle/bulk calls, so the
/// same UI serves both the Admin-pages and Organisation-pages tabs.
class _PageGrantList extends StatefulWidget {
  final String groupId;
  final String hint;
  final Future<List<Map<String, dynamic>>> Function(String groupId) load;
  final Future<void> Function({
    required String groupId,
    required String moduleKey,
    required bool enabled,
  }) toggle;
  final Future<void> Function({required String groupId, required bool enabled}) bulk;

  const _PageGrantList({
    super.key,
    required this.groupId,
    required this.hint,
    required this.load,
    required this.toggle,
    required this.bulk,
  });

  @override
  State<_PageGrantList> createState() => _PageGrantListState();
}

class _PageGrantListState extends State<_PageGrantList>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pages = [];
  final Map<String, bool> _enabled = {};
  PageGroupMode _groupMode = PageGroupMode.function;
  String? _busyKey;

  @override
  bool get wantKeepAlive => true; // keep each tab's state across tab switches

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
      final pages = await widget.load(widget.groupId);
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _enabled
          ..clear()
          ..addEntries(pages
              .map((m) => MapEntry(m['module_key'].toString(), m['enabled'] == true)));
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

  Future<void> _toggleOne(String key, bool value) async {
    final prev = _enabled[key] ?? false;
    setState(() {
      _enabled[key] = value;
      _busyKey = key;
    });
    try {
      await widget.toggle(groupId: widget.groupId, moduleKey: key, enabled: value);
    } catch (e) {
      if (mounted) setState(() => _enabled[key] = prev);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _bulk(bool enabled) async {
    setState(() => _loading = true);
    try {
      await widget.bulk(groupId: widget.groupId, enabled: enabled);
      await _load();
      _toast(enabled ? 'All pages enabled' : 'All pages revoked', AppTheme.greenPrimary);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: SaLoading(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SaStateView.error(message: _error!, onRetry: _load),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hint, style: Sa.label),
          const SizedBox(height: 8),
          // Enable all / Revoke all + the Group-by (Function | Audience) toggle,
          // all on one line. Horizontally scrollable so it never overflows on
          // narrow phones.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => _bulk(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Sa.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Enable all'),
                ),
                TextButton(
                  onPressed: () => _bulk(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.neutral600,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Revoke all'),
                ),
                const SizedBox(width: Sa.gap),
                PageGroupToggle(
                  mode: _groupMode,
                  onChanged: (m) => setState(() => _groupMode = m),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: ListView(
              children: groupCatalog(_pages, _groupMode)
                  .entries
                  .map(_groupSection)
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupSection(MapEntry<String, List<Map<String, dynamic>>> e) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        child: Text(e.key,
            style: Sa.label.copyWith(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppTheme.green50 : AppTheme.neutral50,
          borderRadius: AppTheme.borderRadius12,
          border: Border.all(
              color: on ? Sa.accent.withValues(alpha: 0.4) : AppTheme.neutral200),
        ),
        child: Row(children: [
          Icon(on ? Icons.check_circle : Icons.circle_outlined,
              size: 18, color: on ? Sa.accent : AppTheme.neutral400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m['module_name']?.toString() ?? key,
                    style: Sa.value.copyWith(
                        color: on ? AppTheme.neutral800 : AppTheme.neutral600,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (required)
                  Text('Always on',
                      style: Sa.label.copyWith(color: Sa.accent, fontSize: 11)),
              ],
            ),
          ),
          if (_busyKey == key)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Sa.accent))
          else
            Switch(
              value: on,
              onChanged: required ? null : (v) => _toggleOne(key, v),
              activeThumbColor: Sa.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ]),
      ),
    );
  }
}
