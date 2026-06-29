// lib/features/admin/widgets/attendance_dialog/mark_attendance_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/attendance_models.dart';
import '../../../../services/attendance_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class MarkAttendanceDialog extends StatefulWidget {
  final AttendanceService service;
  final String authorityId;
  const MarkAttendanceDialog({super.key, required this.service, required this.authorityId});

  @override
  State<MarkAttendanceDialog> createState() => _MarkAttendanceDialogState();
}

class _MarkAttendanceDialogState extends State<MarkAttendanceDialog> {
  final _form = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _classId = TextEditingController();
  final _subject = TextEditingController();
  final _remarks = TextEditingController();
  DateTime _date = DateTime.now();
  AttendanceType _type = AttendanceType.daily;
  AttendanceStatus _status = AttendanceStatus.present;
  int? _period;

  bool _loading = false;

  @override
  void dispose() {
    _userId.dispose();
    _classId.dispose();
    _subject.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = math.min(media.size.width - 24, 520.0);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: media.size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Form(
                  key: _form,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final oneCol = c.maxWidth < 600;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _row(oneCol, [
                            _text('User ID', _userId),
                            _text('Class ID (optional)', _classId),
                          ]),
                          const SizedBox(height: Sa.gap),
                          _row(oneCol, [
                            _dateField(context),
                            _dropdown<AttendanceType>('Type', _type, AttendanceType.values,
                                (v) => setState(() => _type = v)),
                            _dropdown<AttendanceStatus>('Status', _status, AttendanceStatus.values,
                                (v) => setState(() => _status = v)),
                          ]),
                          const SizedBox(height: Sa.gap),
                          _row(oneCol, [
                            _text('Subject (optional)', _subject),
                            _number('Period (optional)', (v) => _period = v),
                          ]),
                          const SizedBox(height: Sa.gap),
                          _multiline('Remarks (optional)', _remarks),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            _actions(context),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: const Icon(Icons.how_to_reg_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          const Expanded(
            child: Text('Mark Attendance', style: Sa.headerTitle,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neutral600,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: Sa.gapXs),
          SaPrimaryButton(
            label: 'Submit',
            icon: Icons.check_rounded,
            busy: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }

  /// Lays the fields out as a single column on phones, or an even row on wider
  /// dialogs.
  Widget _row(bool oneCol, List<Widget> fields) {
    if (oneCol) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: Sa.gap),
            fields[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: Sa.gap),
          Expanded(child: fields[i]),
        ],
      ],
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: Sa.label,
        isDense: true,
        filled: true,
        fillColor: AppTheme.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.accent, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: AppTheme.error, width: 1.5),
        ),
      );

  Widget _text(String label, TextEditingController c) => TextFormField(
        decoration: _decoration(label),
        style: Sa.value,
        controller: c,
        validator: (v) => (v == null || v.isEmpty) && label.contains('User') ? 'Required' : null,
      );

  Widget _number(String label, void Function(int?) onSaved) => TextFormField(
        decoration: _decoration(label),
        style: Sa.value,
        keyboardType: TextInputType.number,
        onSaved: (v) => onSaved(int.tryParse(v ?? '')),
      );

  Widget _multiline(String label, TextEditingController c) => TextFormField(
        decoration: _decoration(label),
        style: Sa.value,
        controller: c,
        minLines: 2,
        maxLines: 3,
      );

  Widget _dateField(BuildContext context) => InkWell(
        borderRadius: AppTheme.borderRadius12,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDate: _date,
          );
          if (picked != null) setState(() => _date = picked);
        },
        child: InputDecorator(
          decoration: _decoration('Date'),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.neutral500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _date.toIso8601String().split('T').first,
                  style: Sa.value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _dropdown<T>(String label, T value, List<T> items, void Function(T) onChanged) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: _decoration(label),
      style: Sa.value,
      isExpanded: true,
      iconEnabledColor: AppTheme.neutral500,
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.toString().split('.').last, style: Sa.value),
              ))
          .toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() => _loading = true);
    try {
      final body = {
        'user_id': _userId.text.trim(),
        'user_type': UserType.student.name, // change via UX as needed
        'class_id': _classId.text.isEmpty ? null : _classId.text.trim(),
        'attendance_date': _date.toIso8601String().split('T').first,
        'attendance_type': _type.name,
        'status': _status.name,
        'period_number': _period,
        'subject_name': _subject.text.isEmpty ? null : _subject.text.trim(),
      }..removeWhere((k, v) => v == null);

      await widget.service.markStudent(
        markedBy: widget.authorityId,
        markedByType: UserType.school_authority,
        body: body,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
