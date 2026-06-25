import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/timetable_models.dart';
import '../../../../services/timetable_service.dart';
import '../../../../services/class_service.dart';
import '../../../../core/models/class_model.dart';

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
        throw FormatException('Invalid time format. Use HH:mm format (e.g., 08:00)');
      }
      
      final int? period = int.tryParse(p);
      if (period == null) {
        throw FormatException('Period must be a number for extended timetable creation');
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
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  void _addSlot() => setState(() => slots.add(_SlotRow()));
  void _removeSlot(int i) => setState(() => slots.removeAt(i));

  void _addWeeklyRow(String day) => setState(() => weekly[day]!.add(_WeeklyRow()));
  void _removeWeeklyRow(String day, int idx) => setState(() => weekly[day]!.removeAt(idx));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Class Timetable'),
      content: SizedBox(
        width: 760,
        child: loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(error!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
                      ),

                    // Core selection
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: classId,
                      items: classes.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['name'] ?? e['id']!))).toList(),
                      onChanged: (v) => setState(() => classId = v),
                      decoration: const InputDecoration(labelText: 'Class'),
                    ),
                    const SizedBox(height: 8),

                    // Meta fields
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: termCtrl, decoration: const InputDecoration(labelText: 'Term (optional)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: classNameCtrl, decoration: const InputDecoration(labelText: 'Class name (optional)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: gradeLevelCtrl, decoration: const InputDecoration(labelText: 'Grade level (optional)'))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Audit fields
                    Text('Audit', style: AppTheme.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: createdByCtrl, decoration: const InputDecoration(labelText: 'created_by'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: createdAtCtrl, decoration: const InputDecoration(labelText: 'created_at (ISO)'))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: lastModifiedByCtrl, decoration: const InputDecoration(labelText: 'last_modified_by'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: lastModifiedAtCtrl, decoration: const InputDecoration(labelText: 'last_modified_at (ISO)'))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Time slots editor
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Time slots', style: AppTheme.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                        TextButton.icon(onPressed: _addSlot, icon: const Icon(Icons.add), label: const Text('Add slot')),
                      ],
                    ),
                    Column(
                      children: List.generate(slots.length, (i) {
                        final s = slots[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: TextFormField(controller: s.start, decoration: const InputDecoration(labelText: 'Start (HH:mm)'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: s.end, decoration: const InputDecoration(labelText: 'End (HH:mm)'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: s.periodText, decoration: const InputDecoration(labelText: 'Period (number or text)'))),
                              IconButton(onPressed: () => _removeSlot(i), icon: const Icon(Icons.delete_outline)),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Weekly schedule editor
                    Text('Weekly schedule', style: AppTheme.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...weekly.keys.map((day) {
                      final list = weekly[day]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(day[0].toUpperCase() + day.substring(1), style: AppTheme.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                TextButton.icon(onPressed: () => _addWeeklyRow(day), icon: const Icon(Icons.add), label: const Text('Add')),
                              ],
                            ),
                            Column(
                              children: List.generate(list.length, (idx) {
                                final r = list[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(child: TextFormField(controller: r.subject, decoration: const InputDecoration(labelText: 'Subject'))),
                                      const SizedBox(width: 6),
                                      Expanded(child: TextFormField(controller: r.teacherId, decoration: const InputDecoration(labelText: 'Teacher ID'))),
                                      const SizedBox(width: 6),
                                      Expanded(child: TextFormField(controller: r.room, decoration: const InputDecoration(labelText: 'Room'))),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: 90,
                                        child: TextFormField(controller: r.period, decoration: const InputDecoration(labelText: 'Period')),
                                      ),
                                      IconButton(onPressed: () => _removeWeeklyRow(day, idx), icon: const Icon(Icons.delete_outline)),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: loading ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: loading ? null : _submit,
          child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
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
