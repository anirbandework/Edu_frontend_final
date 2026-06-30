// lib/features/admin/widgets/custom_fields.dart
//
// Per-role custom fields, shared by:
//   • the Roles & Access editor — CustomFieldsBuilder lets an admin DEFINE fields
//     (label, type, required, dropdown options) for a role.
//   • the Staff & Users add/edit dialog — CustomFieldsForm renders those fields as
//     inputs so the values get FILLED when adding a user to that role.
// Backed by rbac_roles.custom_fields (defs) + members.profile['custom_fields'] (values).
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../super_admin/widgets/sa_widgets.dart';

/// The field types the admin can choose (kept in sync with backend custom_fields.py).
const List<Map<String, String>> kCustomFieldTypes = [
  {'value': 'text', 'label': 'Text'},
  {'value': 'textarea', 'label': 'Long text'},
  {'value': 'number', 'label': 'Number'},
  {'value': 'email', 'label': 'Email'},
  {'value': 'phone', 'label': 'Phone'},
  {'value': 'date', 'label': 'Date'},
  {'value': 'select', 'label': 'Dropdown'},
  {'value': 'bool', 'label': 'Yes / No'},
];

String customFieldTypeLabel(String v) => kCustomFieldTypes
    .firstWhere((t) => t['value'] == v, orElse: () => const {'label': 'Text'})['label']!;

/// Client-side mirror of the backend's required/format check. Returns the first
/// error message, or null when everything is valid.
String? validateCustomValues(List<Map<String, dynamic>> defs, Map<String, dynamic> values) {
  for (final f in defs) {
    final key = f['key']?.toString() ?? '';
    final label = (f['label'] ?? key).toString();
    final type = (f['type'] ?? 'text').toString();
    final v = values[key];
    final blank = v == null || (v is String && v.trim().isEmpty);
    if (blank) {
      if (f['required'] == true) return "'$label' is required.";
      continue;
    }
    if (type == 'select') {
      final opts = (f['options'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      if (!opts.contains(v.toString())) return "'$label' must be one of its options.";
    }
  }
  return null;
}

InputDecoration _dec(String label, {String? hint, Widget? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      suffixIcon: suffix,
      border: const OutlineInputBorder(borderRadius: AppTheme.borderRadius12),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.accent, width: 1.5),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// BUILDER — define a role's fields (used in the Roles & Access editor)
// ─────────────────────────────────────────────────────────────────────────────

class _RowState {
  final String? key; // existing stable key (null = new field, backend assigns)
  final TextEditingController label;
  final TextEditingController options; // comma-separated, for 'select'
  String type;
  bool required;
  _RowState({this.key, String label = '', this.type = 'text', this.required = false, String options = ''})
      : label = TextEditingController(text: label),
        options = TextEditingController(text: options);
  void dispose() {
    label.dispose();
    options.dispose();
  }
}

class CustomFieldsBuilder extends StatefulWidget {
  final List<Map<String, dynamic>> initial;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  const CustomFieldsBuilder({super.key, required this.initial, required this.onChanged});

  @override
  State<CustomFieldsBuilder> createState() => _CustomFieldsBuilderState();
}

class _CustomFieldsBuilderState extends State<CustomFieldsBuilder> {
  late List<_RowState> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initial
        .map((f) => _RowState(
              key: f['key']?.toString(),
              label: (f['label'] ?? '').toString(),
              type: (f['type'] ?? 'text').toString(),
              required: f['required'] == true,
              options: ((f['options'] as List?)?.join(', ')) ?? '',
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final out = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final label = r.label.text.trim();
      if (label.isEmpty) continue; // skip half-typed rows
      final m = <String, dynamic>{
        if (r.key != null) 'key': r.key,
        'label': label,
        'type': r.type,
        'required': r.required,
      };
      if (r.type == 'select') {
        m['options'] = r.options.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      out.add(m);
    }
    widget.onChanged(out);
  }

  void _add() {
    setState(() => _rows.add(_RowState()));
    _emit();
  }

  void _remove(int i) {
    setState(() => _rows.removeAt(i).dispose());
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_rows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('No extra fields. Add fields like Grade, Parent name, Address…',
              style: Sa.label),
        ),
      for (int i = 0; i < _rows.length; i++) _rowCard(i),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add field'),
          style: TextButton.styleFrom(foregroundColor: Sa.accent),
        ),
      ),
    ]);
  }

  Widget _rowCard(int i) {
    final r = _rows[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadius12,
        border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: r.label,
              onChanged: (_) => _emit(),
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Field label', hint: 'e.g. Grade, Parent name'),
            ),
          ),
          IconButton(
            tooltip: 'Remove field',
            onPressed: () => _remove(i),
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: r.type,
              isExpanded: true,
              decoration: _dec('Type'),
              items: kCustomFieldTypes
                  .map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => r.type = v);
                _emit();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Compact "Required" toggle.
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Required', style: Sa.label),
            Switch(
              value: r.required,
              activeThumbColor: Sa.accent,
              onChanged: (v) {
                setState(() => r.required = v);
                _emit();
              },
            ),
          ]),
        ]),
        if (r.type == 'select') ...[
          const SizedBox(height: 8),
          TextField(
            controller: r.options,
            onChanged: (_) => _emit(),
            decoration: _dec('Options (comma-separated)', hint: 'e.g. 9, 10, 11, 12'),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM — fill a role's fields (used in the Staff & Users add/edit dialog)
// ─────────────────────────────────────────────────────────────────────────────

class CustomFieldsForm extends StatefulWidget {
  final List<Map<String, dynamic>> definitions;
  final Map<String, dynamic> initialValues;
  const CustomFieldsForm({super.key, required this.definitions, this.initialValues = const {}});

  @override
  State<CustomFieldsForm> createState() => CustomFieldsFormState();
}

class CustomFieldsFormState extends State<CustomFieldsForm> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _vals = {}; // select (String) / date (String) / bool (bool)

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(CustomFieldsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = widget.definitions.map((e) => e['key']).join(',');
    final b = oldWidget.definitions.map((e) => e['key']).join(',');
    if (a != b) {
      _disposeText();
      _text.clear();
      _vals.clear();
      _init();
    }
  }

  void _init() {
    for (final f in widget.definitions) {
      final key = f['key']?.toString() ?? '';
      final type = (f['type'] ?? 'text').toString();
      final init = widget.initialValues[key];
      if (type == 'bool') {
        _vals[key] = init == true || init?.toString() == 'true';
      } else if (type == 'select' || type == 'date') {
        _vals[key] = init?.toString() ?? '';
      } else {
        _text[key] = TextEditingController(text: init?.toString() ?? '');
      }
    }
  }

  void _disposeText() {
    for (final c in _text.values) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeText();
    super.dispose();
  }

  /// Current non-empty values keyed by field key — read this on save.
  Map<String, dynamic> collect() {
    final out = <String, dynamic>{};
    for (final f in widget.definitions) {
      final key = f['key']?.toString() ?? '';
      final type = (f['type'] ?? 'text').toString();
      if (type == 'bool') {
        out[key] = _vals[key] == true;
      } else if (type == 'select' || type == 'date') {
        final v = (_vals[key] ?? '').toString();
        if (v.isNotEmpty) out[key] = v;
      } else {
        final v = _text[key]?.text.trim() ?? '';
        if (v.isNotEmpty) out[key] = v;
      }
    }
    return out;
  }

  /// First validation error (required/format), or null when valid.
  String? validate() => validateCustomValues(widget.definitions, collect());

  @override
  Widget build(BuildContext context) {
    if (widget.definitions.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final f in widget.definitions) ...[
        _fieldWidget(f),
        const SizedBox(height: Sa.gap),
      ],
    ]);
  }

  Widget _fieldWidget(Map<String, dynamic> f) {
    final key = f['key']?.toString() ?? '';
    final required = f['required'] == true;
    final label = '${(f['label'] ?? key)}${required ? ' *' : ''}';
    final type = (f['type'] ?? 'text').toString();
    switch (type) {
      case 'bool':
        return _boolField(key, label);
      case 'select':
        return _selectField(f, key, label);
      case 'date':
        return _dateField(key, label);
      default:
        return _plainField(key, label, type);
    }
  }

  Widget _plainField(String key, String label, String type) {
    final keyboard = switch (type) {
      'number' => TextInputType.number,
      'email' => TextInputType.emailAddress,
      'phone' => TextInputType.phone,
      'textarea' => TextInputType.multiline,
      _ => TextInputType.text,
    };
    return TextField(
      controller: _text[key],
      keyboardType: keyboard,
      maxLines: type == 'textarea' ? 3 : 1,
      decoration: _dec(label),
    );
  }

  Widget _selectField(Map<String, dynamic> f, String key, String label) {
    final opts = (f['options'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final current = (_vals[key] ?? '').toString();
    return DropdownButtonFormField<String>(
      initialValue: current.isEmpty ? null : current,
      isExpanded: true,
      decoration: _dec(label),
      items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) => setState(() => _vals[key] = v ?? ''),
    );
  }

  Widget _dateField(String key, String label) {
    final current = (_vals[key] ?? '').toString();
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: current),
      decoration: _dec(label, hint: 'YYYY-MM-DD', suffix: const Icon(Icons.calendar_today, size: 18)),
      onTap: () async {
        final now = DateTime.now();
        final initial = DateTime.tryParse(current) ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1900),
          lastDate: DateTime(now.year + 50),
        );
        if (picked != null) {
          setState(() => _vals[key] =
              '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        }
      },
    );
  }

  Widget _boolField(String key, String label) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.borderRadius12,
        border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        activeThumbColor: Sa.accent,
        title: Text(label, style: Sa.value),
        value: _vals[key] == true,
        onChanged: (v) => setState(() => _vals[key] = v),
      ),
    );
  }
}
