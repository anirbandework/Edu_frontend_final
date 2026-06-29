// lib/shared/widgets/page_group_toggle.dart
//
// Shared "Group by: Function / Audience" control + grouping helper used by both
// RBAC page pickers (admin Roles & Access and super-admin Module Access).
// Grouping is purely presentational — granting stays unrestricted cross-group.
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

enum PageGroupMode { function, audience }

const List<String> _functionOrder = [
  'Core', 'Administration', 'Academics', 'Communication',
];
const List<String> _audienceOrder = [
  'Common (everyone)', 'For Admins', 'For Teachers & Faculty', 'For Students', 'For Parents',
];

/// Group catalog modules by the chosen mode, in a stable friendly order.
Map<String, List<Map<String, dynamic>>> groupCatalog(
    List<Map<String, dynamic>> catalog, PageGroupMode mode) {
  final field = mode == PageGroupMode.function ? 'section' : 'audience_group';
  final wanted = mode == PageGroupMode.function ? _functionOrder : _audienceOrder;
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final m in catalog) {
    final g = (m[field] ?? 'Other').toString();
    groups.putIfAbsent(g, () => []).add(m);
  }
  final ordered = <String, List<Map<String, dynamic>>>{};
  for (final k in wanted) {
    if (groups.containsKey(k)) ordered[k] = groups[k]!;
  }
  for (final k in groups.keys) {
    ordered.putIfAbsent(k, () => groups[k]!);
  }
  return ordered;
}

/// Compact two-option toggle: Function | Audience.
class PageGroupToggle extends StatelessWidget {
  final PageGroupMode mode;
  final ValueChanged<PageGroupMode> onChanged;
  const PageGroupToggle({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, PageGroupMode m, IconData ic) {
      final sel = mode == m;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: ChoiceChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 13, color: sel ? Colors.white : AppTheme.neutral600),
            const SizedBox(width: 4),
            Text(label),
          ]),
          selected: sel,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          selectedColor: AppTheme.greenPrimary,
          backgroundColor: AppTheme.neutral100,
          labelStyle: AppTheme.bodySmall.copyWith(
              color: sel ? Colors.white : AppTheme.neutral700, fontWeight: FontWeight.w600),
          onSelected: (_) => onChanged(m),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Group by', style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral500)),
      chip('Function', PageGroupMode.function, Icons.category_outlined),
      chip('Audience', PageGroupMode.audience, Icons.groups_outlined),
    ]);
  }
}
