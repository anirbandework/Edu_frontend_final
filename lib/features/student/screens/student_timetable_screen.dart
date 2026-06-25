// lib/features/student/screens/student_timetable_screen.dart
//
// The student's weekly timetable. Resolves the student's enrolled class id from
// /students/{id}/classes, then loads the class timetable. Day keys are lowercase
// monday..saturday; times are 'HH:MM'. Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/student_portal_service.dart';

class StudentTimetableScreen extends StatefulWidget {
  final String? studentId;
  final String? academicYear;
  const StudentTimetableScreen({super.key, this.studentId, this.academicYear});

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  static const _dayLabels = {
    'monday': 'Monday', 'tuesday': 'Tuesday', 'wednesday': 'Wednesday',
    'thursday': 'Thursday', 'friday': 'Friday', 'saturday': 'Saturday',
  };

  bool _loading = true;
  String? _error;
  String _className = '';
  Map<String, List<Map<String, dynamic>>> _schedule = {};

  String get _studentId => (widget.studentId?.isNotEmpty == true)
      ? widget.studentId!
      : (AuthSession.instance.userId ?? '');
  String get _academicYear => widget.academicYear ?? '2025-26';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_studentId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classesResp =
          await StudentPortalService.getMyClasses(studentId: _studentId, academicYear: _academicYear);
      final classes = ((classesResp['classes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (classes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'You are not enrolled in a class yet.';
        });
        return;
      }
      final cls = classes.first;
      _className = (cls['class_name'] ?? '').toString();
      final classId = cls['id'].toString();

      final tt = await StudentPortalService.getClassTimetable(
          classId: classId, academicYear: _academicYear);
      final sched = (tt['schedule'] as Map?) ?? (tt['weekly_schedule'] as Map?) ?? {};
      final map = <String, List<Map<String, dynamic>>>{};
      for (final day in _days) {
        final raw = (sched[day] as List?) ?? (sched[_dayLabels[day]] as List?) ?? const [];
        final periods = raw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
          ..sort((a, b) => ((a['period_number'] ?? 0) as num)
              .compareTo((b['period_number'] ?? 0) as num));
        map[day] = periods;
      }
      if (!mounted) return;
      setState(() {
        _schedule = map;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Timetable', style: AppTheme.headingMedium),
                  if (_className.isNotEmpty)
                    Text('$_className • $_academicYear',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                ],
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              color: AppTheme.greenPrimary,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_busy, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text(_error!,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    final hasAny = _schedule.values.any((v) => v.isNotEmpty);
    if (!hasAny) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No timetable published yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: _days
            .where((d) => (_schedule[d] ?? []).isNotEmpty)
            .map((d) => _dayBlock(d, _schedule[d]!))
            .toList(),
      ),
    );
  }

  Widget _dayBlock(String day, List<Map<String, dynamic>> periods) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18,
                decoration: BoxDecoration(
                    color: AppTheme.greenPrimary, borderRadius: AppTheme.borderRadius8)),
            const SizedBox(width: 8),
            Text(_dayLabels[day]!, style: AppTheme.labelLarge),
            const SizedBox(width: 8),
            Text('${periods.length} periods',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
          ]),
          const SizedBox(height: 8),
          ...periods.map(_periodCard),
        ],
      ),
    );
  }

  Widget _periodCard(Map<String, dynamic> p) {
    final n = (p['period_number'] ?? '').toString();
    final subject = (p['subject_name'] ?? p['subject'] ?? 'Subject').toString();
    final teacher = (p['teacher_name'] ?? '').toString();
    final room = (p['room_number'] ?? p['room'] ?? '').toString();
    final start = (p['start_time'] ?? '').toString();
    final end = (p['end_time'] ?? '').toString();
    final time = (start.isNotEmpty && end.isNotEmpty) ? '$start - $end' : (start + end);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient, borderRadius: AppTheme.borderRadius12),
            child: Center(
              child: Text('P$n',
                  style: AppTheme.labelMedium.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject,
                    style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Wrap(spacing: 12, children: [
                  if (teacher.isNotEmpty) _meta(Icons.person, teacher),
                  if (room.isNotEmpty) _meta(Icons.meeting_room, room),
                ]),
              ],
            ),
          ),
          if (time.trim().isNotEmpty)
            Text(time,
                style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
      const SizedBox(width: 4),
      Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
    ]);
  }
}
