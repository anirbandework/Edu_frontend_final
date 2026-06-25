// lib/features/teacher/screens/teacher_attendance_screen.dart
//
// Take attendance for a class on a date. Real backend; the server derives the
// marking teacher from the JWT. Wrapped by MainLayout in the router.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/teacher_portal_service.dart';

class _Status {
  final String key;
  final String label;
  final Color color;
  const _Status(this.key, this.label, this.color);
}

const _statuses = <_Status>[
  _Status('present', 'Present', AppTheme.success),
  _Status('absent', 'Absent', AppTheme.error),
  _Status('late', 'Late', AppTheme.warning),
  _Status('excused', 'Excused', AppTheme.info),
];

class TeacherAttendanceScreen extends StatefulWidget {
  final String? tenantId;
  const TeacherAttendanceScreen({super.key, this.tenantId});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  String? _tenantId;
  List<Map<String, dynamic>> _classes = [];
  String? _classId;
  DateTime _date = DateTime.now();

  bool _loadingClasses = true;
  bool _loadingStudents = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _students = [];
  final Map<String, String> _marks = {}; // studentId -> status key

  String get _teacherId => AuthSession.instance.userId ?? '';
  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId ?? AuthSession.instance.tenantId;
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if ((_tenantId ?? '').isEmpty) {
      setState(() {
        _loadingClasses = false;
        _error = 'No school session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    try {
      final classes = await TeacherPortalService.getClasses(tenantId: _tenantId!);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _loadingClasses = false;
        if (classes.isNotEmpty) _classId = classes.first['id']?.toString();
      });
      if (_classId != null) _loadStudents();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadStudents() async {
    if (_classId == null) return;
    setState(() {
      _loadingStudents = true;
      _error = null;
      _students = [];
      _marks.clear();
    });
    try {
      final data = await TeacherPortalService.getClassAttendance(
        classId: _classId!,
        date: _dateStr,
      );
      final students = ((data['students'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      for (final s in students) {
        final id = s['student_id']?.toString() ?? '';
        final cur = (s['attendance_status'] ?? '').toString().toLowerCase();
        _marks[id] = _statuses.any((st) => st.key == cur) ? cur : 'present';
      }
      if (!mounted) return;
      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_classId == null || _students.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updates = _students.map((s) {
        final id = s['student_id'].toString();
        return {'user_id': id, 'status': _marks[id] ?? 'present', 'remarks': ''};
      }).toList();
      final res = await TeacherPortalService.markClassAttendance(
        classId: _classId!,
        date: _dateStr,
        updates: updates,
        teacherId: _teacherId,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      final n = res['updated_students'] ?? res['successful_records'] ?? updates.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Attendance saved for $n students'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final s in _students) {
        _marks[s['student_id'].toString()] = status;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _loadStudents();
    }
  }

  int _countOf(String key) =>
      _marks.values.where((v) => v == key).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Take Attendance', style: AppTheme.headingMedium),
        const SizedBox(height: 12),
        _controls(),
        const SizedBox(height: 12),
        Expanded(child: _body()),
        if (_students.isNotEmpty && _error == null) _saveBar(),
      ],
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: _loadingClasses
                ? const LinearProgressIndicator(color: AppTheme.greenPrimary)
                : DropdownButtonFormField<String>(
                    value: _classId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      prefixIcon: Icon(Icons.class_),
                      isDense: true,
                    ),
                    items: _classes.map((c) {
                      final name = (c['class_name'] ?? 'Class').toString();
                      final sec = (c['section'] ?? '').toString();
                      return DropdownMenuItem(
                        value: c['id']?.toString(),
                        child: Text(sec.isEmpty ? name : '$name • $sec',
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _classId = v);
                      _loadStudents();
                    },
                  ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: AppTheme.iconSmall),
            label: Text(_dateStr),
          ),
          if (_students.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () => _markAll('present'),
              icon: const Icon(Icons.done_all, size: AppTheme.iconSmall, color: AppTheme.success),
              label: const Text('All present'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    if (_loadingClasses) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 40, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _loadClasses,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_students.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No students enrolled in this class',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
        ]),
      );
    }
    return ListView.separated(
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _studentRow(_students[i]),
    );
  }

  Widget _studentRow(Map<String, dynamic> s) {
    final id = s['student_id'].toString();
    final name = ('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}').trim();
    final roll = (s['roll_number'] ?? s['student_number'] ?? '').toString();
    final selected = _marks[id] ?? 'present';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.green50,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTheme.labelMedium.copyWith(color: AppTheme.greenPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Student' : name,
                        style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (roll.isNotEmpty)
                      Text('Roll $roll',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _statuses.map((st) {
              final isSel = selected == st.key;
              return ChoiceChip(
                label: Text(st.label),
                selected: isSel,
                showCheckmark: false,
                onSelected: (_) => setState(() => _marks[id] = st.key),
                backgroundColor: AppTheme.neutral100,
                selectedColor: st.color,
                labelStyle: AppTheme.bodySmall.copyWith(
                  color: isSel ? Colors.white : AppTheme.neutral600,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              children: _statuses
                  .map((st) => _pill(st.label, _countOf(st.key), st.color))
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: AppTheme.iconSmall),
            label: Text(_saving ? 'Saving…' : 'Save attendance'),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label $count',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600)),
      ],
    );
  }
}
