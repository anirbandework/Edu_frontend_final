import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/timetable_models.dart';
import '../../../../services/timetable_service.dart';
import '../../../../services/class_service.dart';
import '../../../../core/models/class_model.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class CreateClassTimetableDialog extends StatefulWidget {
  const CreateClassTimetableDialog({
    super.key,
    required this.tenantId,
    required this.userId,
    required this.masterId,
    required this.academicYear,
    required this.api,
    required this.classApi,
  });

  final String tenantId;
  final String userId;
  final String masterId;
  final String academicYear;
  final TimetableService api;
  final ClassApi classApi;

  @override
  State<CreateClassTimetableDialog> createState() => _CreateClassTimetableDialogState();
}

class _CreateClassTimetableDialogState extends State<CreateClassTimetableDialog> {
  // Required
  String? classId;

  // Optional meta
  final termCtrl = TextEditingController();
  final classNameCtrl = TextEditingController();
  final gradeLevelCtrl = TextEditingController();

  // Audit
  final createdByCtrl = TextEditingController();
  final createdAtCtrl = TextEditingController();
  final lastModifiedByCtrl = TextEditingController();
  final lastModifiedAtCtrl = TextEditingController();

  // Time slots editor state
  final List<_SlotRow> slots = [
    _SlotRow(start: '08:00', end: '08:45', periodText: '1'),
    _SlotRow(start: '08:45', end: '09:30', periodText: '2'),
    _SlotRow(start: '09:30', end: '10:15', periodText: '3'),
    _SlotRow(start: '10:15', end: '10:30', periodText: 'Break'),
    _SlotRow(start: '10:30', end: '11:15', periodText: '4'),
    _SlotRow(start: '11:15', end: '12:00', periodText: '5'),
  ];

  // Weekly schedule editor state
  final Map<String, List<_WeeklyRow>> weekly = {
    'monday': [],
    'tuesday': [],
    'wednesday': [],
    'thursday': [],
    'friday': [],
    'saturday': [],
  };

  // Classes list
  List<Map<String, String>> classes = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    createdByCtrl.text = widget.userId;
    lastModifiedByCtrl.text = widget.userId;
    createdAtCtrl.text = DateTime.now().toUtc().toIso8601String();
    lastModifiedAtCtrl.text = DateTime.now().toUtc().toIso8601String();
    _loadClasses();
  }

  @override
  void dispose() {
    termCtrl.dispose();
    classNameCtrl.dispose();
    gradeLevelCtrl.dispose();
    createdByCtrl.dispose();
    createdAtCtrl.dispose();
    lastModifiedByCtrl.dispose();
    lastModifiedAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await widget.classApi.getPaginated(
        page: 1,
        pageSize: 200,
        tenantId: widget.tenantId,
        academicYear: widget.academicYear,
        isActive: true,
      );
      final list = ClassModel.listFromPaginated(res);
      classes = list
          .map((c) => {
                'id': c.id,
                'name': '${c.className} (${c.gradeLevel}-${c.section})',
              })
          .toList();
      if (classes.isNotEmpty) classId = classes.first['id'];
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _buildTimeSlots() {
    return slots
        .where((s) => s.start.text.trim().isNotEmpty && s.end.text.trim().isNotEmpty && s.periodText.text.trim().isNotEmpty)
        .map((s) {
      final startTime = s.start.text.trim();
      final endTime = s.end.text.trim();
      final p = s.periodText.text.trim();

      // Validate time format (HH:mm)
      final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
      if (!timeRegex.hasMatch(startTime) || !timeRegex.hasMatch(endTime)) {
        throw const FormatException('Invalid time format. Use HH:mm format (e.g., 08:00)');
      }

      final int? period = int.tryParse(p);
      if (period == null) {
        throw const FormatException('Period must be a number for extended timetable creation');
      }

      return {
        'start_time': startTime,
        'end_time': endTime,
        'period': period,
      };
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _buildWeekly() {
    final map = <String, List<Map<String, dynamic>>>{};
    weekly.forEach((day, rows) {
      final dayList = <Map<String, dynamic>>[];
      for (final r in rows) {
        if (r.subject.text.trim().isEmpty) continue;
        final periodText = r.period.text.trim();
        if (periodText.isEmpty) continue; // Skip entries without period

        final int? period = int.tryParse(periodText);
        if (period == null) continue; // Skip non-numeric periods

        dayList.add({
          'subject': r.subject.text.trim(),
          'period': period,
          if (r.teacherId.text.trim().isNotEmpty) 'teacher_id': r.teacherId.text.trim(),
          if (r.room.text.trim().isNotEmpty) 'room': r.room.text.trim(),
        });
      }
      // Only include days that have actual schedule entries
      if (dayList.isNotEmpty) {
        map[day] = dayList;
      }
    });
    return map;
  }

  Future<void> _submit() async {
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }

    // Validate required fields
    if (widget.tenantId.isEmpty || widget.masterId.isEmpty || widget.academicYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing required tenant, master, or academic year')));
      return;
    }

    // Ensure proper date format (ISO 8601)
    final now = DateTime.now().toUtc().toIso8601String();
    final createdAt = createdAtCtrl.text.trim().isEmpty ? now : createdAtCtrl.text.trim();
    final lastModifiedAt = lastModifiedAtCtrl.text.trim().isEmpty ? now : lastModifiedAtCtrl.text.trim();

    // Validate date formats
    try {
      DateTime.parse(createdAt);
      DateTime.parse(lastModifiedAt);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid date format. Use ISO 8601 format (YYYY-MM-DDTHH:mm:ss.sssZ)')));
      return;
    }

    // Validate and build time slots
    List<Map<String, dynamic>> timeSlots;
    try {
      timeSlots = _buildTimeSlots();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Time slots error: ${e.toString()}')));
      return;
    }

    final weeklySchedule = _buildWeekly();

    final payload = ClassTimetableCreate(
      tenantId: widget.tenantId,
      classId: classId!,
      masterTimetableId: widget.masterId,
      academicYear: widget.academicYear,
      createdBy: widget.userId,
      term: termCtrl.text.trim().isEmpty ? null : termCtrl.text.trim(),
      className: classNameCtrl.text.trim().isEmpty ? null : classNameCtrl.text.trim(),
      gradeLevel: gradeLevelCtrl.text.trim().isEmpty ? null : gradeLevelCtrl.text.trim(),
      createdAtIso: createdAt,
      lastModifiedBy: lastModifiedByCtrl.text.trim().isEmpty ? widget.userId : lastModifiedByCtrl.text.trim(),
      lastModifiedAtIso: lastModifiedAt,
      timeSlots: timeSlots.isEmpty ? null : timeSlots,
      weeklySchedule: weeklySchedule.isEmpty ? null : weeklySchedule,
    );

    setState(() => loading = true);
    try {
      final res = await widget.api.createClassTimetable(payload);
      if (mounted) Navigator.of(context).pop(res);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        String errorMsg = 'Failed to create timetable';
        if (e.toString().contains('422')) {
          errorMsg = 'Validation error: Please check all required fields and data formats';
        } else if (e.toString().contains('Exception:')) {
          errorMsg = e.toString().replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  void _addSlot() => setState(() => slots.add(_SlotRow()));
  void _removeSlot(int i) => setState(() => slots.removeAt(i));

  void _addWeeklyRow(String day) => setState(() => weekly[day]!.add(_WeeklyRow()));
  void _removeWeeklyRow(String day, int idx) => setState(() => weekly[day]!.removeAt(idx));

  // Compact, brand-consistent field decoration.
  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: Sa.label,
        isDense: true,
        filled: true,
        fillColor: AppTheme.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.accent, width: 1.6),
        ),
      );

  /// Lays out [children] in a single column when narrow, else an even row.
  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) {
          final out = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            if (i > 0) out.add(const SizedBox(height: Sa.gap));
            out.add(children[i]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
        }
        final out = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) out.add(const SizedBox(width: Sa.gap));
          out.add(Expanded(child: children[i]));
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: out);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = math.min(media.size.width - 24, 560.0);
    final maxH = media.size.height - 80;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: SaLoading(message: 'Loading…'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _form(),
                    ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
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
            child: const Icon(Icons.calendar_view_week_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          const Expanded(
            child: Text(
              'Create Class Timetable',
              style: Sa.headerTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: loading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: Sa.gap),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.10),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(error!, style: Sa.body.copyWith(color: AppTheme.error))),
              ],
            ),
          ),

        // Core selection
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: classId,
          style: Sa.value,
          items: classes
              .map((e) => DropdownMenuItem(
                    value: e['id'],
                    child: Text(e['name'] ?? e['id']!, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => classId = v),
          decoration: _dec('Class'),
        ),
        const SizedBox(height: Sa.gapLg),

        // Meta fields
        _responsiveFields([
          TextFormField(controller: termCtrl, style: Sa.value, decoration: _dec('Term (optional)')),
          TextFormField(controller: classNameCtrl, style: Sa.value, decoration: _dec('Class name (optional)')),
          TextFormField(controller: gradeLevelCtrl, style: Sa.value, decoration: _dec('Grade level (optional)')),
        ]),
        const SizedBox(height: Sa.gapLg),

        // Audit fields
        _sectionCard(
          icon: Icons.history_rounded,
          title: 'Audit',
          child: Column(
            children: [
              _responsiveFields([
                TextFormField(controller: createdByCtrl, style: Sa.value, decoration: _dec('created_by')),
                TextFormField(controller: createdAtCtrl, style: Sa.value, decoration: _dec('created_at (ISO)')),
              ]),
              const SizedBox(height: Sa.gap),
              _responsiveFields([
                TextFormField(controller: lastModifiedByCtrl, style: Sa.value, decoration: _dec('last_modified_by')),
                TextFormField(controller: lastModifiedAtCtrl, style: Sa.value, decoration: _dec('last_modified_at (ISO)')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: Sa.gapLg),

        // Time slots editor
        _sectionCard(
          icon: Icons.schedule_rounded,
          title: 'Time slots',
          trailing: _addButton('Add slot', _addSlot),
          child: Column(
            children: List.generate(slots.length, (i) {
              final s = slots[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: Sa.gap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _responsiveFields([
                        TextFormField(controller: s.start, style: Sa.value, decoration: _dec('Start (HH:mm)')),
                        TextFormField(controller: s.end, style: Sa.value, decoration: _dec('End (HH:mm)')),
                        TextFormField(controller: s.periodText, style: Sa.value, decoration: _dec('Period')),
                      ]),
                    ),
                    _deleteButton(() => _removeSlot(i)),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: Sa.gapLg),

        // Weekly schedule editor
        _sectionCard(
          icon: Icons.view_week_rounded,
          title: 'Weekly schedule',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weekly.keys.map((day) {
              final list = weekly[day]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: Sa.gapLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            day[0].toUpperCase() + day.substring(1),
                            style: Sa.cardTitle.copyWith(fontSize: 13.5),
                          ),
                        ),
                        _addButton('Add', () => _addWeeklyRow(day)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Column(
                      children: List.generate(list.length, (idx) {
                        final r = list[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Sa.gap),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _responsiveFields([
                                  TextFormField(controller: r.subject, style: Sa.value, decoration: _dec('Subject')),
                                  TextFormField(controller: r.teacherId, style: Sa.value, decoration: _dec('Teacher ID')),
                                  TextFormField(controller: r.room, style: Sa.value, decoration: _dec('Room')),
                                  TextFormField(controller: r.period, style: Sa.value, decoration: _dec('Period')),
                                ]),
                              ),
                              _deleteButton(() => _removeWeeklyRow(day, idx)),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return SaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(icon: icon, title: title, trailing: trailing),
          const SizedBox(height: Sa.gap),
          child,
        ],
      ),
    );
  }

  Widget _addButton(String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Sa.accent,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontFamily: AppTheme.interFontFamily, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _deleteButton(VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Remove',
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Sa.stroke.withValues(alpha: 0.7))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: loading ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neutral600,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          SaPrimaryButton(
            label: 'Create',
            icon: Icons.check_rounded,
            busy: loading,
            onPressed: loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// Helpers for form rows
class _SlotRow {
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController periodText;
  _SlotRow({String start = '', String end = '', String periodText = ''})
      : start = TextEditingController(text: start),
        end = TextEditingController(text: end),
        periodText = TextEditingController(text: periodText);
}

class _WeeklyRow {
  final TextEditingController subject = TextEditingController();
  final TextEditingController teacherId = TextEditingController();
  final TextEditingController room = TextEditingController();
  final TextEditingController period = TextEditingController();
}
