// lib/features/student/screens/student_attendance_screen.dart
//
// The student's own attendance history with a client-computed summary (the
// backend exposes no summary/% endpoint). Status from the API is UPPERCASE
// ('PRESENT'/'ABSENT'/'LATE'/...). Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/student_portal_service.dart';

class _Day {
  final String date;
  final String status; // normalized UPPERCASE, or 'NOT_MARKED'
  final String subject;
  final String? remarks;
  _Day(this.date, this.status, this.subject, this.remarks);
}

class StudentAttendanceScreen extends StatefulWidget {
  final String? studentId;
  final String? tenantId;
  const StudentAttendanceScreen({super.key, this.studentId, this.tenantId});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  bool _loading = true;
  String? _error;
  List<_Day> _days = [];
  int _rangeDays = 30;

  String get _studentId => (widget.studentId?.isNotEmpty == true)
      ? widget.studentId!
      : (AuthSession.instance.userId ?? '');
  String? get _tenantId => widget.tenantId ?? AuthSession.instance.tenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (_studentId.isEmpty || (_tenantId ?? '').isEmpty) {
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
      final now = DateTime.now();
      final start = now.subtract(Duration(days: _rangeDays));
      final data = await StudentPortalService.getMyAttendanceHistory(
        tenantId: _tenantId!,
        studentId: _studentId,
        startDate: _fmt(start),
        endDate: _fmt(now),
      );
      final history = ((data['attendance_history'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final days = <_Day>[];
      for (final h in history) {
        final date = (h['date'] ?? '').toString();
        Map<String, dynamic>? rec;
        final grade = h['grade_attendance'];
        if (grade is Map) rec = grade.cast<String, dynamic>();
        if (rec == null) {
          final cls = h['class_attendance'];
          if (cls is List && cls.isNotEmpty && cls.first is Map) {
            rec = (cls.first as Map).cast<String, dynamic>();
          }
        }
        if (rec == null) continue; // no record that day -> skip
        final status = (rec['status'] ?? 'NOT_MARKED').toString().toUpperCase();
        final subject = (rec['subject_name'] ?? rec['class_name'] ?? '').toString();
        final remarks = (rec['remarks'] ?? '').toString();
        days.add(_Day(date, status, subject, remarks.isEmpty ? null : remarks));
      }
      days.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _days = days;
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

  int _count(List<String> keys) =>
      _days.where((d) => keys.contains(d.status)).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('My Attendance', style: AppTheme.headingMedium)),
            _rangeSelector(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              color: AppTheme.greenPrimary,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: _bodyWrap()),
      ],
    );
  }

  Widget _rangeSelector() {
    return DropdownButton<int>(
      value: _rangeDays,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 30, child: Text('Last 30 days')),
        DropdownMenuItem(value: 90, child: Text('Last 90 days')),
        DropdownMenuItem(value: 180, child: Text('Last 6 months')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _rangeDays = v);
        _load();
      },
    );
  }

  Widget _bodyWrap() {
    if (_loading) {
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
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _summaryCard(),
          const SizedBox(height: 16),
          if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('No attendance records in this period',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
              ),
            )
          else
            ..._days.map(_dayTile),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final present = _count(['PRESENT']);
    final absent = _count(['ABSENT']);
    final late = _count(['LATE']);
    final excused = _count(['EXCUSED', 'SICK']);
    final total = _days.length;
    final pct = total == 0 ? 0 : ((present + late) / total * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.borderRadius16,
        boxShadow: const [AppTheme.greenShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$pct%',
                  style: AppTheme.headingLarge.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('attendance',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.white70)),
              ),
              const Spacer(),
              Text('$total days',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppTheme.borderRadius8,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (present + late) / total,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 8, children: [
            _legend('Present', present, Colors.white),
            _legend('Late', late, const Color(0xFFFFE082)),
            _legend('Absent', absent, const Color(0xFFFFCDD2)),
            _legend('Excused', excused, const Color(0xFFB3E5FC)),
          ]),
        ],
      ),
    );
  }

  Widget _legend(String label, int count, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label $count',
          style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _dayTile(_Day d) {
    final meta = _statusMeta(d.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: meta.$2.withOpacity(0.12), borderRadius: AppTheme.borderRadius12),
            child: Icon(meta.$3, color: meta.$2, size: AppTheme.iconMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.date,
                    style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                if (d.subject.isNotEmpty)
                  Text(d.subject,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                if (d.remarks != null)
                  Text(d.remarks!,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: meta.$2.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
            child: Text(meta.$1,
                style: AppTheme.bodySmall.copyWith(color: meta.$2, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _statusMeta(String status) {
    switch (status) {
      case 'PRESENT':
        return ('Present', AppTheme.success, Icons.check_circle);
      case 'ABSENT':
        return ('Absent', AppTheme.error, Icons.cancel);
      case 'LATE':
        return ('Late', AppTheme.warning, Icons.schedule);
      case 'EXCUSED':
        return ('Excused', AppTheme.info, Icons.event_available);
      case 'SICK':
        return ('Sick', AppTheme.info, Icons.healing);
      default:
        return (status.toLowerCase(), AppTheme.neutral400, Icons.help_outline);
    }
  }
}
