import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/timetable_models.dart';
import '../../../../services/timetable_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkScheduleDialog extends StatefulWidget {
  const BulkScheduleDialog({
    super.key,
    required this.tenantId,
    required this.classId,
    required this.academicYear,
    required this.api,
  });

  final UUID tenantId;
  final UUID classId;
  final String academicYear;
  final TimetableService api;

  @override
  State<BulkScheduleDialog> createState() => _BulkScheduleDialogState();
}

class _BulkScheduleDialogState extends State<BulkScheduleDialog> {
  String mode = "create"; // create | update | delete

  // Row structure for lightweight editing; adapt as needed
  final List<Map<String, dynamic>> rows = [];

  bool _submitting = false;

  void _addRow() {
    setState(() {
      rows.add({
        "schedule_entry_id": null,
        "class_timetable_id": widget.classId,
        "period_id": null, // required for create
        "day_of_week": "monday", // required for create
        "subject_id": null,
        "subject_name": "",
        "teacher_timetable_id": null,
        "teacher_name": "",
        "room_number": "",
        "notes": "",
      });
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      if (mode == "create") {
        final payload = BulkScheduleCreate(
          tenantId: widget.tenantId,
          scheduleEntries: rows
              .map((r) => {
                    "class_timetable_id": r["class_timetable_id"],
                    "period_id": r["period_id"],
                    "day_of_week": r["day_of_week"], // lowercase
                    "subject_id": r["subject_id"],
                    "subject_name": r["subject_name"],
                    "teacher_timetable_id": r["teacher_timetable_id"],
                    "teacher_name": r["teacher_name"],
                    "room_number": r["room_number"],
                    "notes": r["notes"],
                  })
              .toList(),
        );
        await widget.api.bulkCreateSchedule(payload);
      } else if (mode == "update") {
        final payload = BulkScheduleUpdate(
          rows
              .where((r) => r["schedule_entry_id"] != null)
              .map((r) => {
                    "schedule_entry_id": r["schedule_entry_id"],
                    "subject_id": r["subject_id"],
                    "subject_name": r["subject_name"],
                    "teacher_timetable_id": r["teacher_timetable_id"],
                    "teacher_name": r["teacher_name"],
                    "room_number": r["room_number"],
                    "notes": r["notes"],
                  })
              .toList(),
        );
        await widget.api.bulkUpdateSchedule(payload);
      } else {
        final ids = rows
            .map((r) => r["schedule_entry_id"] as String?)
            .whereType<String>()
            .toList();
        await widget.api.bulkDeleteSchedule(ids, hardDelete: false);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$e"),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 640.0);
    final maxH = size.height - 80;
    final bool isDelete = mode == "delete";

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(child: _body(maxW)),
            _actions(isDelete),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
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
            child: const Icon(Icons.edit_calendar_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          const Expanded(
            child: Text(
              "Bulk Schedule Editor",
              style: Sa.headerTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Sa.gapXs),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Close',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _body(double maxW) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode selector.
          const Text('Mode', style: Sa.label),
          const SizedBox(height: 6),
          _modeSelector(),
          const SizedBox(height: Sa.gapLg),
          // Add-row toolbar.
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add row'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Sa.accent,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: Sa.accent, width: 1.5),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadius12),
                ),
              ),
              const SizedBox(width: Sa.gap),
              Expanded(
                child: Text(
                  "${rows.length} row(s)",
                  style: Sa.label,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sa.gap),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SaStateView(
                icon: Icons.table_rows_outlined,
                title: 'No rows yet',
                subtitle: 'Tap "Add row" to start building the schedule.',
              ),
            )
          else
            for (int i = 0; i < rows.length; i++) ...[
              _rowCard(i, maxW),
              if (i != rows.length - 1) const SizedBox(height: Sa.gap),
            ],
        ],
      ),
    );
  }

  Widget _modeSelector() {
    const options = [
      ['create', 'Create'],
      ['update', 'Update'],
      ['delete', 'Delete'],
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o[1]),
            selected: mode == o[0],
            onSelected: (_) => setState(() => mode = o[0]),
            selectedColor:
                o[0] == 'delete' ? AppTheme.error : AppTheme.greenPrimary,
            backgroundColor: AppTheme.neutral100,
            labelStyle: TextStyle(
              color: mode == o[0] ? Colors.white : AppTheme.neutral700,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: mode == o[0] ? Colors.transparent : Sa.stroke,
              ),
            ),
          ),
      ],
    );
  }

  Widget _rowCard(int i, double maxW) {
    final r = rows[i];
    return SaCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Sa.accent.withValues(alpha: 0.10),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Sa.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Entry', style: Sa.label)),
              IconButton(
                onPressed: () => setState(() => rows.removeAt(i)),
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                tooltip: 'Remove row',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, c) {
              final oneCol = c.maxWidth < 600;
              final dayField = _field(
                label: "Day (monday..sunday)",
                initial: r["day_of_week"]?.toString() ?? "monday",
                onChanged: (v) => r["day_of_week"] = v.toLowerCase(),
              );
              final periodField = _field(
                label: "Period ID (UUID)",
                initial: r["period_id"]?.toString(),
                onChanged: (v) => r["period_id"] = v,
              );
              final subjectField = _field(
                label: "Subject name",
                initial: r["subject_name"]?.toString(),
                onChanged: (v) => r["subject_name"] = v,
              );
              final teacherField = _field(
                label: "Teacher name",
                initial: r["teacher_name"]?.toString(),
                onChanged: (v) => r["teacher_name"] = v,
              );
              final roomField = _field(
                label: "Room",
                initial: r["room_number"]?.toString(),
                onChanged: (v) => r["room_number"] = v,
              );

              if (oneCol) {
                return Column(
                  children: [
                    dayField,
                    const SizedBox(height: Sa.gap),
                    periodField,
                    const SizedBox(height: Sa.gap),
                    subjectField,
                    const SizedBox(height: Sa.gap),
                    teacherField,
                    const SizedBox(height: Sa.gap),
                    roomField,
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dayField),
                      const SizedBox(width: Sa.gap),
                      Expanded(child: periodField),
                    ],
                  ),
                  const SizedBox(height: Sa.gap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: subjectField),
                      const SizedBox(width: Sa.gap),
                      Expanded(child: teacherField),
                    ],
                  ),
                  const SizedBox(height: Sa.gap),
                  roomField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String? initial,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initial,
      onChanged: onChanged,
      style: Sa.value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Sa.label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _actions(bool isDelete) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          TextButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neutral600,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Close'),
          ),
          const Spacer(),
          SaPrimaryButton(
            label: isDelete ? 'Delete' : 'Submit',
            icon: isDelete ? Icons.delete_outline : Icons.check_rounded,
            busy: _submitting,
            color: isDelete ? AppTheme.error : Sa.accent,
            onPressed: rows.isEmpty ? null : _submit,
          ),
        ],
      ),
    );
  }
}
