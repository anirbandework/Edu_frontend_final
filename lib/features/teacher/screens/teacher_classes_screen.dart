// lib/features/teacher/screens/teacher_classes_screen.dart
//
// The classes a teacher teaches, derived from their real timetable schedule
// (the backend has no per-teacher classes endpoint; the schedule is the source
// of truth for which class+subject a teacher is assigned to). No mock data.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/teacher_portal_service.dart';

class _TeacherClass {
  final String name;
  final Set<String> subjects = {};
  final Set<String> rooms = {};
  final Set<String> days = {};
  int periods = 0;
  _TeacherClass(this.name);
}

class TeacherClassesScreen extends StatefulWidget {
  final String? teacherId;
  final String? academicYear;
  const TeacherClassesScreen({super.key, this.teacherId, this.academicYear});

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  bool _loading = true;
  String? _error;
  List<_TeacherClass> _classes = [];

  String get _teacherId => (widget.teacherId?.isNotEmpty == true)
      ? widget.teacherId!
      : (AuthSession.instance.userId ?? '');
  String get _academicYear => widget.academicYear ?? '2025-26';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_teacherId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No teacher session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await TeacherPortalService.getMySchedule(
        teacherId: _teacherId,
        academicYear: _academicYear,
      );
      final weekly = (data['weekly_schedule'] as Map?) ?? {};
      final map = <String, _TeacherClass>{};
      for (final day in _days) {
        final raw = (weekly[day] as List?) ?? const [];
        for (final e in raw.whereType<Map>()) {
          final p = e.cast<String, dynamic>();
          final cls = (p['class_name'] ?? p['class'] ?? 'Unassigned').toString();
          final c = map.putIfAbsent(cls, () => _TeacherClass(cls));
          c.periods++;
          c.days.add(day);
          final subj = (p['subject_name'] ?? p['subject'] ?? '').toString();
          if (subj.isNotEmpty) c.subjects.add(subj);
          final room = (p['room_number'] ?? p['room'] ?? '').toString();
          if (room.isNotEmpty) c.rooms.add(room);
        }
      }
      final classes = map.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _classes = classes;
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

  void _goSchedule() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (AuthSession.instance.tenantId != null) 'tenantId': AuthSession.instance.tenantId!,
    };
    context.go(Uri(path: AppConstants.teacherScheduleRoute, queryParameters: qp).toString());
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
                  Text('My Classes', style: AppTheme.headingMedium),
                  const SizedBox(height: 2),
                  Text(
                    _loading
                        ? 'Loading your classes…'
                        : '${_classes.length} ${_classes.length == 1 ? 'class' : 'classes'} • $_academicYear',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _goSchedule,
              icon: const Icon(Icons.schedule, size: AppTheme.iconSmall),
              label: const Text('View schedule'),
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
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.greenPrimary),
      );
    }
    if (_error != null) {
      return _state(Icons.error_outline, AppTheme.error, 'Could not load classes', _error!);
    }
    if (_classes.isEmpty) {
      return _state(Icons.class_outlined, AppTheme.neutral400, 'No classes assigned',
          'You have no classes in your timetable for $_academicYear yet.');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 178,
          ),
          itemCount: _classes.length,
          itemBuilder: (context, i) => _classCard(_classes[i]),
        );
      }),
    );
  }

  Widget _classCard(_TeacherClass c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.borderRadius12,
                ),
                child: const Icon(Icons.class_, color: Colors.white, size: AppTheme.iconMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.name,
                    style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (c.subjects.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: c.subjects
                  .take(4)
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.green50,
                          borderRadius: AppTheme.borderRadius8,
                        ),
                        child: Text(s,
                            style: AppTheme.bodyMicro.copyWith(
                                color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          const Spacer(),
          Row(
            children: [
              _meta(Icons.event, '${c.periods} periods/wk'),
              const SizedBox(width: 14),
              _meta(Icons.today, '${c.days.length} days'),
              if (c.rooms.isNotEmpty) ...[
                const SizedBox(width: 14),
                Flexible(child: _meta(Icons.meeting_room, c.rooms.join(', '))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _state(IconData icon, Color color, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: AppTheme.borderRadius16,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.headingSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
                label: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
