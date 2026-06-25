// lib/features/student/screens/student_report_card_screen.dart
//
// A report card aggregated from the student's actual exam marks (by subject):
// overall %, per-subject average + grade, pass/fail. Reachable by the student
// for themselves and by staff for any student. AppTheme only.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/grades_service.dart';

class StudentReportCardScreen extends StatefulWidget {
  final String? studentId;
  final String? academicYear;
  final String? studentName;
  const StudentReportCardScreen({
    super.key,
    this.studentId,
    this.academicYear,
    this.studentName,
  });

  @override
  State<StudentReportCardScreen> createState() => _StudentReportCardScreenState();
}

class _StudentReportCardScreenState extends State<StudentReportCardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _card = {};

  String get _studentId => (widget.studentId?.isNotEmpty == true)
      ? widget.studentId!
      : (AuthSession.instance.userId ?? '');

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
      final card = await GradesService.getStudentReportCard(
          studentId: _studentId, academicYear: widget.academicYear);
      if (!mounted) return;
      setState(() {
        _card = card;
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

  void _back() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (AuthSession.instance.tenantId != null) 'tenantId': AuthSession.instance.tenantId!,
    };
    context.go(Uri(path: AppConstants.studentGradesRoute, queryParameters: qp).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.greenPrimary,
            tooltip: 'Back',
          ),
          Expanded(child: Text('Report Card', style: AppTheme.headingMedium)),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            color: AppTheme.greenPrimary,
            tooltip: 'Refresh',
          ),
        ]),
        const SizedBox(height: 12),
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
    final subjects = ((_card['subjects'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    if (subjects.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No graded exams yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 4),
          Text('Your report card appears once exams are marked.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400),
              textAlign: TextAlign.center),
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
          Text('Subjects', style: AppTheme.labelLarge),
          const SizedBox(height: 8),
          ...subjects.map(_subjectCard),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final overall = (_card['overall_percentage'] as num?)?.round() ?? 0;
    final grade = (_card['overall_grade'] ?? '').toString();
    final result = (_card['result'] ?? '').toString();
    final passed = _card['subjects_passed'] ?? 0;
    final total = _card['total_subjects'] ?? 0;
    final exams = _card['total_exams'] ?? 0;
    final year = (_card['academic_year'] ?? '').toString();
    final isPass = result == 'PASS';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.borderRadius16,
        boxShadow: const [AppTheme.greenShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.studentName?.isNotEmpty == true ? widget.studentName! : 'Report Card',
                      style: AppTheme.headingSmall.copyWith(color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (year.isNotEmpty)
                    Text(year, style: AppTheme.bodyMedium.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            if (result == 'PASS' || result == 'FAIL')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Text(result,
                    style: AppTheme.labelLarge.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _stat('$overall%', 'Overall'),
            _divider(),
            _stat(grade.isEmpty ? '—' : grade, 'Grade'),
            _divider(),
            _stat('$passed/$total', 'Subjects'),
            _divider(),
            _stat('$exams', 'Exams'),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: AppTheme.borderRadius8,
            child: LinearProgressIndicator(
              value: (overall / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                  isPass ? Colors.white : const Color(0xFFFFCDD2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTheme.headingSmall.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: Colors.white24);

  Widget _subjectCard(Map<String, dynamic> s) {
    final subject = (s['subject'] ?? 'Subject').toString();
    final avg = (s['average_percentage'] as num?)?.round() ?? 0;
    final grade = (s['grade'] ?? '').toString();
    final passed = s['passed'] == true;
    final exams = ((s['exams'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final color = passed
        ? (avg >= 60 ? AppTheme.success : AppTheme.warning)
        : AppTheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
          title: Row(
            children: [
              Expanded(
                child: Text(subject,
                    style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('$avg%',
                  style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.neutral600, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: AppTheme.borderRadius8,
                ),
                alignment: Alignment.center,
                child: Text(grade.isEmpty ? '—' : grade,
                    style: AppTheme.labelMedium.copyWith(
                        color: color, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          subtitle: Text('${exams.length} exam${exams.length == 1 ? '' : 's'}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
          children: exams.map((e) {
            final pct = (e['percentage'] as num?)?.round();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(Icons.circle, size: 6, color: AppTheme.neutral400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text((e['exam_name'] ?? 'Exam').toString(),
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (e['obtained_marks'] != null && e['total_marks'] != null)
                  Text('${e['obtained_marks']}/${e['total_marks']}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                const SizedBox(width: 10),
                Text(pct != null ? '$pct%' : '—',
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.greenPrimary, fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}
