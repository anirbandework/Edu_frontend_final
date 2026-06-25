// lib/features/student/screens/student_results_screen.dart
//
// The student's results: formal exam marks (/exam-management exam-history) and
// quiz attempts (/assessment quiz results). Both are tenant-scoped; quiz results
// are already filtered server-side to published only. Real backend, AppTheme.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/grades_service.dart';
import '../../../services/student_portal_service.dart';

class StudentResultsScreen extends StatefulWidget {
  final String? studentId;
  final String? tenantId;
  const StudentResultsScreen({super.key, this.studentId, this.tenantId});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _quizzes = [];

  String get _studentId => (widget.studentId?.isNotEmpty == true)
      ? widget.studentId!
      : (AuthSession.instance.userId ?? '');
  String? get _tenantId => widget.tenantId ?? AuthSession.instance.tenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openReportCard() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.studentReportCardRoute, queryParameters: qp).toString());
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
      final examResp = await GradesService.getStudentExamHistory(studentId: _studentId);
      final exams = ((examResp['exams'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          // only show exams the student has actually been marked in
          .where((e) => e['obtained_marks'] != null || e['grade'] != null)
          .toList();
      final quizzes = await StudentPortalService.getMyQuizResults(
          studentId: _studentId, tenantId: _tenantId);
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _quizzes = quizzes;
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
            Expanded(child: Text('My Results', style: AppTheme.headingMedium)),
            TextButton.icon(
              onPressed: _openReportCard,
              icon: const Icon(Icons.description, size: AppTheme.iconSmall),
              label: const Text('Report Card'),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              color: AppTheme.greenPrimary,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tab,
          labelColor: AppTheme.greenPrimary,
          unselectedLabelColor: AppTheme.neutral500,
          indicatorColor: AppTheme.greenPrimary,
          tabs: [
            Tab(text: 'Exams (${_exams.length})'),
            Tab(text: 'Quizzes (${_quizzes.length})'),
          ],
        ),
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
    return TabBarView(
      controller: _tab,
      children: [
        _examList(),
        _quizList(),
      ],
    );
  }

  Widget _examList() {
    if (_exams.isEmpty) {
      return _empty(Icons.assignment_outlined, 'No exam results published yet');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _exams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _examCard(_exams[i]),
      ),
    );
  }

  Widget _examCard(Map<String, dynamic> e) {
    final name = (e['exam_name'] ?? 'Exam').toString();
    final type = (e['exam_type'] ?? '').toString();
    final subject = (e['subject'] ?? '').toString();
    final obtained = e['obtained_marks'];
    final total = e['total_marks'];
    final pctRaw = e['percentage'];
    final pct = pctRaw is num ? pctRaw.round() : null;
    final grade = (e['grade'] ?? '').toString();
    final color = _scoreColor(pct);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 4, children: [
                  if (subject.isNotEmpty) _meta(Icons.menu_book, subject),
                  if (type.isNotEmpty) _meta(Icons.category, type),
                ]),
                if (obtained != null && total != null) ...[
                  const SizedBox(height: 6),
                  Text('$obtained / $total marks',
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.neutral700, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _scoreBadge(grade.isNotEmpty ? grade : (pct != null ? '$pct%' : '—'),
              pct != null ? '$pct%' : '', color),
        ],
      ),
    );
  }

  Widget _quizList() {
    if (_quizzes.isEmpty) {
      return _empty(Icons.quiz_outlined, 'No quiz results published yet');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _quizzes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _quizCard(_quizzes[i]),
      ),
    );
  }

  Widget _quizCard(Map<String, dynamic> q) {
    final title = (q['quiz_title'] ?? q['title'] ?? 'Quiz').toString();
    final score = q['total_score'];
    final maxScore = q['max_score'];
    final pctRaw = q['percentage'];
    final pct = pctRaw is num ? pctRaw.round() : null;
    final attempt = q['attempt_number'];
    final color = _scoreColor(pct);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (score != null && maxScore != null)
                  Text('$score / $maxScore points',
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.neutral700, fontWeight: FontWeight.w600)),
                if (attempt != null)
                  Text('Attempt $attempt',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _scoreBadge(pct != null ? '$pct%' : '—', '', color),
        ],
      ),
    );
  }

  Widget _scoreBadge(String big, String small, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppTheme.borderRadius16,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(big,
              style: AppTheme.labelLarge.copyWith(color: color, fontWeight: FontWeight.w800)),
          if (small.isNotEmpty && small != big)
            Text(small, style: AppTheme.bodyMicro.copyWith(color: color)),
        ],
      ),
    );
  }

  Color _scoreColor(int? pct) {
    if (pct == null) return AppTheme.neutral400;
    if (pct >= 60) return AppTheme.success;
    if (pct >= 40) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
      const SizedBox(width: 4),
      Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
    ]);
  }

  Widget _empty(IconData icon, String text) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppTheme.neutral400),
        const SizedBox(height: 12),
        Text(text, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
      ]),
    );
  }
}
