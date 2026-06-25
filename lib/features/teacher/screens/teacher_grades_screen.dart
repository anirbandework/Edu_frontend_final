// lib/features/teacher/screens/teacher_grades_screen.dart
//
// Enter exam marks for a class. Flow: pick class + exam -> the class roster is
// merged with any marks already entered -> teacher types obtained marks per
// student -> bulk save (server auto-resolves each student's class from their
// enrolment) -> optionally publish results to students. Real backend, AppTheme.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/grades_service.dart';
import '../../../services/teacher_portal_service.dart';

class _Row {
  final String studentId; // students.id UUID (marks user_id)
  final String name;
  final String roll;
  final TextEditingController ctrl;
  _Row(this.studentId, this.name, this.roll, this.ctrl);
}

class TeacherGradesScreen extends StatefulWidget {
  final String? tenantId;
  const TeacherGradesScreen({super.key, this.tenantId});

  @override
  State<TeacherGradesScreen> createState() => _TeacherGradesScreenState();
}

class _TeacherGradesScreenState extends State<TeacherGradesScreen> {
  String? _tenantId;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _exams = [];
  String? _classId;
  String? _examId;
  final TextEditingController _maxCtrl = TextEditingController(text: '100');

  bool _loadingMeta = true; // classes + exams
  bool _loadingGrid = false;
  bool _saving = false;
  bool _publishing = false;
  String? _error;

  List<_Row> _rows = [];

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId ?? AuthSession.instance.tenantId;
    _loadMeta();
  }

  @override
  void dispose() {
    _maxCtrl.dispose();
    for (final r in _rows) {
      r.ctrl.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _exam =>
      _exams.where((e) => e['id']?.toString() == _examId).cast<Map<String, dynamic>?>().firstWhere((_) => true, orElse: () => null);

  Future<void> _loadMeta() async {
    if ((_tenantId ?? '').isEmpty) {
      setState(() {
        _loadingMeta = false;
        _error = 'No school session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loadingMeta = true;
      _error = null;
    });
    try {
      final classes = await TeacherPortalService.getClasses(tenantId: _tenantId!);
      final exams = await GradesService.getExams();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _exams = exams;
        _loadingMeta = false;
        if (classes.isNotEmpty) _classId = classes.first['id']?.toString();
        if (exams.isNotEmpty) _examId = exams.first['id']?.toString();
      });
      if (_classId != null && _examId != null) _loadGrid();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMeta = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadGrid() async {
    if (_classId == null || _examId == null) return;
    setState(() {
      _loadingGrid = true;
      _error = null;
    });
    try {
      final roster = await TeacherPortalService.getClassRoster(classId: _classId!);
      final marks = await GradesService.getExamMarks(examId: _examId!, classId: _classId!);
      // Index existing marks by student UUID.
      final byId = <String, Map<String, dynamic>>{};
      for (final m in marks) {
        byId[m['student_id'].toString()] = m;
      }
      // Adopt the exam max from the first existing mark, if any.
      final firstTotal = marks
          .map((m) => m['total_marks'])
          .firstWhere((v) => v != null, orElse: () => null);
      if (firstTotal != null) _maxCtrl.text = firstTotal.toString();

      for (final r in _rows) {
        r.ctrl.dispose();
      }
      final students = ((roster['students'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final rows = students.map((s) {
        final id = s['id'].toString(); // roster PK = students.id UUID
        final name = ('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}').trim();
        final roll = (s['roll_number'] ?? s['student_id'] ?? '').toString();
        final existing = byId[id];
        final obtained = existing?['obtained_marks'];
        return _Row(id, name.isEmpty ? 'Student' : name, roll,
            TextEditingController(text: obtained?.toString() ?? ''));
      }).toList();

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadingGrid = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGrid = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  int get _maxMarks => int.tryParse(_maxCtrl.text.trim()) ?? 100;

  String _gradeFor(int pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  int _enteredCount() =>
      _rows.where((r) => r.ctrl.text.trim().isNotEmpty).length;

  Future<void> _save() async {
    if (_examId == null) return;
    final max = _maxMarks;
    if (max <= 0) {
      _toast('Set a valid maximum marks first', AppTheme.error);
      return;
    }
    final entries = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final txt = r.ctrl.text.trim();
      if (txt.isEmpty) continue;
      final obtained = double.tryParse(txt);
      if (obtained == null) continue;
      final ob = obtained.round();
      final pct = ((obtained / max) * 100).round().clamp(0, 100);
      entries.add({
        'student_id': r.studentId,
        'marks_data': {'obtained': ob, 'total': max},
        'total_marks': max,
        'obtained_marks': ob,
        'percentage': pct,
        'grade': _gradeFor(pct),
        'attendance_status': 'present',
      });
    }
    if (entries.isEmpty) {
      _toast('Enter marks for at least one student', AppTheme.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await GradesService.saveBulkMarks(
        examId: _examId!,
        marks: entries,
        batchName: (_exam?['exam_name'] ?? 'Marks').toString(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      final ok = res['success_count'] ?? entries.length;
      final errs = res['error_count'] ?? 0;
      _toast(
        errs == 0
            ? 'Saved marks for $ok students'
            : 'Saved $ok • $errs failed (check enrolment)',
        errs == 0 ? AppTheme.success : AppTheme.warning,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _publish() async {
    if (_examId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish results?'),
        content: Text(
            'Students will be able to see their results for "${_exam?['exam_name'] ?? 'this exam'}". '
            'Make sure all marks are entered and saved first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _publishing = true);
    try {
      await GradesService.publishExam(examId: _examId!);
      if (!mounted) return;
      setState(() => _publishing = false);
      _toast('Results published', AppTheme.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final published = (_exam?['is_published'] == true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter Grades', style: AppTheme.headingMedium),
        const SizedBox(height: 12),
        _controls(published),
        const SizedBox(height: 12),
        Expanded(child: _body()),
        if (_rows.isNotEmpty && _error == null) _saveBar(),
      ],
    );
  }

  Widget _controls(bool published) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: _loadingMeta
                    ? const LinearProgressIndicator(color: AppTheme.greenPrimary)
                    : DropdownButtonFormField<String>(
                        value: _classId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Class', prefixIcon: Icon(Icons.class_), isDense: true),
                        items: _classes.map((c) {
                          final name = (c['class_name'] ?? 'Class').toString();
                          final sec = (c['section'] ?? '').toString();
                          return DropdownMenuItem(
                            value: c['id']?.toString(),
                            child: Text(sec.isEmpty ? name : '$name • $sec',
                                overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _classId = v);
                          _loadGrid();
                        },
                      ),
              ),
              SizedBox(
                width: 240,
                child: _loadingMeta
                    ? const SizedBox.shrink()
                    : DropdownButtonFormField<String>(
                        value: _examId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Exam', prefixIcon: Icon(Icons.assignment), isDense: true),
                        items: _exams.map((e) {
                          return DropdownMenuItem(
                            value: e['id']?.toString(),
                            child: Text((e['exam_name'] ?? 'Exam').toString(),
                                overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _examId = v);
                          _loadGrid();
                        },
                      ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Max marks', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_examId != null)
                published
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.12),
                            borderRadius: AppTheme.borderRadius8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, size: AppTheme.iconSmall, color: AppTheme.success),
                          const SizedBox(width: 6),
                          Text('Published',
                              style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.success, fontWeight: FontWeight.w700)),
                        ]),
                      )
                    : OutlinedButton.icon(
                        onPressed: _publishing ? null : _publish,
                        icon: _publishing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.publish, size: AppTheme.iconSmall),
                        label: const Text('Publish'),
                      ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loadingMeta || _loadingGrid) {
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
              onPressed: _loadMeta,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    if (_exams.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No exams created yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 4),
          Text('Ask your school admin to create an exam first.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400)),
        ]),
      );
    }
    if (_rows.isEmpty) {
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
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _gradeRow(_rows[i]),
    );
  }

  Widget _gradeRow(_Row r) {
    final txt = r.ctrl.text.trim();
    final obtained = double.tryParse(txt);
    final max = _maxMarks;
    int? pct;
    String? grade;
    if (obtained != null && max > 0) {
      pct = ((obtained / max) * 100).round().clamp(0, 100);
      grade = _gradeFor(pct);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.green50,
            child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.greenPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (r.roll.isNotEmpty)
                  Text('Roll ${r.roll}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
              ],
            ),
          ),
          if (grade != null) ...[
            _gradeChip(grade, pct!),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 92,
            child: TextField(
              controller: r.ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: '/$max',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradeChip(String grade, int pct) {
    final color = pct >= 60
        ? AppTheme.success
        : (pct >= 40 ? AppTheme.warning : AppTheme.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppTheme.borderRadius8,
      ),
      child: Text('$grade • $pct%',
          style: AppTheme.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700)),
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
            child: Text('${_enteredCount()} of ${_rows.length} entered',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: AppTheme.iconSmall),
            label: Text(_saving ? 'Saving…' : 'Save marks'),
          ),
        ],
      ),
    );
  }
}
