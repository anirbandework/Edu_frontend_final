// lib/features/teacher/screens/teacher_schedule_screen.dart
//
// The teacher's weekly timetable. Wrapped by MainLayout in the router, so this
// widget renders the page content only. Real data from TeacherPortalService.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/teacher_portal_service.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String? teacherId;
  final String? academicYear;
  const TeacherScheduleScreen({super.key, this.teacherId, this.academicYear});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  bool _loading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _byDay = {};
  int _totalPeriods = 0;

  String get _teacherId =>
      (widget.teacherId?.isNotEmpty == true)
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
      final byDay = <String, List<Map<String, dynamic>>>{};
      var total = 0;
      for (final day in _days) {
        final raw = (weekly[day] as List?) ?? const [];
        final periods = raw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
          ..sort((a, b) =>
              _periodNo(a).compareTo(_periodNo(b)));
        byDay[day] = periods;
        total += periods.length;
      }
      if (!mounted) return;
      setState(() {
        _byDay = byDay;
        _totalPeriods = total;
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

  int _periodNo(Map<String, dynamic> p) =>
      (p['period_number'] ?? p['period'] ?? 0) is int
          ? (p['period_number'] ?? p['period'] ?? 0) as int
          : int.tryParse('${p['period_number'] ?? p['period'] ?? 0}') ?? 0;

  String _subject(Map<String, dynamic> p) =>
      (p['subject_name'] ?? p['subject'] ?? 'Subject').toString();
  String _className(Map<String, dynamic> p) =>
      (p['class_name'] ?? p['class'] ?? '').toString();
  String _room(Map<String, dynamic> p) =>
      (p['room_number'] ?? p['room'] ?? '').toString();
  String _time(Map<String, dynamic> p) {
    final s = (p['start_time'] ?? '').toString();
    final e = (p['end_time'] ?? '').toString();
    if (s.isEmpty && e.isEmpty) return '';
    return [s, e].where((x) => x.isNotEmpty).join(' – ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 16),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Schedule', style: AppTheme.headingMedium),
              const SizedBox(height: 2),
              Text(
                _loading
                    ? 'Loading your weekly timetable…'
                    : '$_totalPeriods periods • $_academicYear',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
              ),
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
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.greenPrimary),
      );
    }
    if (_error != null) {
      return _stateMessage(
        icon: Icons.error_outline,
        color: AppTheme.error,
        title: 'Could not load schedule',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_totalPeriods == 0) {
      return _stateMessage(
        icon: Icons.event_busy,
        color: AppTheme.neutral400,
        title: 'No schedule yet',
        subtitle:
            'Your timetable for $_academicYear has not been published. Check back once your school sets it up.',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }

    final visibleDays = _days.where((d) => (_byDay[d] ?? []).isNotEmpty).toList();
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visibleDays.length,
        itemBuilder: (context, i) => _daySection(visibleDays[i]),
      ),
    );
  }

  Widget _daySection(String day) {
    final periods = _byDay[day] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.greenPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(day, style: AppTheme.headingSmall),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.green50,
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Text(
                  '${periods.length}',
                  style: AppTheme.bodyMicro.copyWith(
                    color: AppTheme.greenPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...periods.map(_periodCard),
        ],
      ),
    );
  }

  Widget _periodCard(Map<String, dynamic> p) {
    final time = _time(p);
    final cls = _className(p);
    final room = _room(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppTheme.borderRadius12,
            ),
            child: Center(
              child: Text(
                'P${_periodNo(p)}',
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _subject(p),
                  style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (cls.isNotEmpty) _meta(Icons.class_, cls),
                    if (room.isNotEmpty) _meta(Icons.meeting_room, room),
                  ],
                ),
              ],
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              time,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.neutral600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
        Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
      ],
    );
  }

  Widget _stateMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
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
            Text(
              subtitle,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
