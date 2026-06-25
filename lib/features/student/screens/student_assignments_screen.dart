// lib/features/student/screens/student_assignments_screen.dart
//
// The student's work: a Quizzes tab (take quiz) and an Assignments tab (view
// assigned work + submit a PDF, see grade/feedback). Real backend, AppTheme only.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/assignment_service.dart';
import '../../../services/student_portal_service.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  final String? studentId;
  final String? tenantId;
  const StudentAssignmentsScreen({super.key, this.studentId, this.tenantId});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  bool _loadingQuizzes = true;
  bool _loadingAssignments = true;
  String? _quizError;
  String? _assignmentError;
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _assignments = [];
  String? _submittingId;

  String get _studentId => (widget.studentId?.isNotEmpty == true)
      ? widget.studentId!
      : (AuthSession.instance.userId ?? '');
  String? get _tenantId => widget.tenantId ?? AuthSession.instance.tenantId;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
    _loadAssignments();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    if (_studentId.isEmpty) {
      setState(() {
        _loadingQuizzes = false;
        _quizError = 'No session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loadingQuizzes = true;
      _quizError = null;
    });
    try {
      final quizzes = await StudentPortalService.getAvailableQuizzes(
          studentId: _studentId, tenantId: _tenantId);
      if (!mounted) return;
      setState(() {
        _quizzes = quizzes.where((q) => q['is_active'] != false).toList();
        _loadingQuizzes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingQuizzes = false;
        _quizError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadAssignments() async {
    if (_studentId.isEmpty) {
      setState(() => _loadingAssignments = false);
      return;
    }
    setState(() {
      _loadingAssignments = true;
      _assignmentError = null;
    });
    try {
      final list = await AssignmentService.getStudentAssignments(studentId: _studentId);
      if (!mounted) return;
      setState(() {
        _assignments = list;
        _loadingAssignments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAssignments = false;
        _assignmentError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _openQuiz(Map<String, dynamic> q) {
    final id = q['id']?.toString();
    if (id == null) return;
    final qp = <String, String>{
      'quizId': id,
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.studentQuizRoute, queryParameters: qp).toString());
  }

  Future<void> _submit(Map<String, dynamic> a) async {
    final id = a['id']?.toString();
    if (id == null) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _toast('Could not read the file', AppTheme.error);
        return;
      }
      setState(() => _submittingId = id);
      await AssignmentService.submitAssignment(
        assessmentId: id,
        fileBytes: bytes,
        filename: file.name,
        studentId: _studentId,
      );
      if (!mounted) return;
      setState(() => _submittingId = null);
      _toast('Assignment submitted', AppTheme.success);
      _loadAssignments();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingId = null);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('My Work', style: AppTheme.headingMedium)),
          IconButton(
            onPressed: () {
              _loadQuizzes();
              _loadAssignments();
            },
            icon: const Icon(Icons.refresh),
            color: AppTheme.greenPrimary,
            tooltip: 'Refresh',
          ),
        ]),
        const SizedBox(height: 8),
        TabBar(
          controller: _tab,
          labelColor: AppTheme.greenPrimary,
          unselectedLabelColor: AppTheme.neutral500,
          indicatorColor: AppTheme.greenPrimary,
          tabs: [
            Tab(text: 'Quizzes (${_quizzes.length})'),
            Tab(text: 'Assignments (${_assignments.length})'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_quizzesTab(), _assignmentsTab()],
          ),
        ),
      ],
    );
  }

  // ---- Quizzes ----
  Widget _quizzesTab() {
    if (_loadingQuizzes) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_quizError != null) {
      return _errorState(_quizError!, _loadQuizzes);
    }
    if (_quizzes.isEmpty) {
      return _emptyState(Icons.quiz_outlined, 'No quizzes assigned right now',
          'Check back later — new quizzes will appear here.');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _loadQuizzes,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 168,
          ),
          itemCount: _quizzes.length,
          itemBuilder: (context, i) => _quizCard(_quizzes[i]),
        );
      }),
    );
  }

  Widget _quizCard(Map<String, dynamic> q) {
    final title = (q['title'] ?? 'Quiz').toString();
    final desc = (q['description'] ?? '').toString();
    final totalQ = q['total_questions'];
    final points = q['total_points'];
    final time = q['time_limit'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient, borderRadius: AppTheme.borderRadius12),
              child: const Icon(Icons.quiz, color: Colors.white, size: AppTheme.iconMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 8),
          if (desc.isNotEmpty)
            Text(desc,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(children: [
            if (totalQ != null) _meta(Icons.help_outline, '$totalQ Qs'),
            if (points != null) ...[
              const SizedBox(width: 12),
              _meta(Icons.star_outline, '$points pts'),
            ],
            if (time != null) ...[
              const SizedBox(width: 12),
              _meta(Icons.timer_outlined, '$time min'),
            ],
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openQuiz(q),
              icon: const Icon(Icons.play_arrow, size: AppTheme.iconSmall),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Assignments ----
  Widget _assignmentsTab() {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_assignmentError != null) {
      return _errorState(_assignmentError!, _loadAssignments);
    }
    if (_assignments.isEmpty) {
      return _emptyState(Icons.assignment_outlined, 'No assignments right now',
          'Assignments from your teachers will appear here.');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _loadAssignments,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _assignments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _assignmentCard(_assignments[i]),
      ),
    );
  }

  Widget _assignmentCard(Map<String, dynamic> a) {
    final id = a['id']?.toString() ?? '';
    final title = (a['assessment_title'] ?? 'Assignment').toString();
    final subject = (a['subject'] ?? '').toString();
    final due = (a['due_date'] ?? '').toString();
    final max = a['max_marks'];
    final sub = (a['submission'] as Map?)?.cast<String, dynamic>();
    final submitted = sub != null;
    final graded = submitted && (sub['is_graded'] == true || sub['marks_obtained'] != null);
    final marks = sub?['marks_obtained'];
    final grade = (sub?['grade_letter'] ?? '').toString();
    final feedback = (sub?['teacher_feedback'] ?? '').toString();
    final busy = _submittingId == id;

    Color statusColor;
    String statusText;
    if (graded) {
      statusColor = AppTheme.success;
      statusText = 'Graded';
    } else if (submitted) {
      statusColor = AppTheme.info;
      statusText = 'Submitted';
    } else {
      statusColor = AppTheme.warning;
      statusText = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient, borderRadius: AppTheme.borderRadius12),
              child: const Icon(Icons.assignment, color: Colors.white, size: AppTheme.iconMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Wrap(spacing: 10, children: [
                    if (subject.isNotEmpty) _meta(Icons.menu_book, subject),
                    if (max != null) _meta(Icons.star_outline, '$max marks'),
                    if (due.isNotEmpty) _meta(Icons.event, 'Due ${due.split('T').first}'),
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
              child: Text(statusText,
                  style: AppTheme.bodyMicro.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (graded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Score: $marks${max != null ? ' / $max' : ''}'
                      '${grade.isNotEmpty ? '  ·  $grade' : ''}',
                      style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.greenPrimary, fontWeight: FontWeight.w700)),
                  if (feedback.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(feedback,
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral700)),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => _submit(a),
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(submitted ? Icons.refresh : Icons.upload_file, size: AppTheme.iconSmall),
                label: Text(busy
                    ? 'Uploading…'
                    : (submitted ? 'Re-submit PDF' : 'Submit PDF')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- shared ----
  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
      const SizedBox(width: 4),
      Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
    ]);
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppTheme.neutral400),
        const SizedBox(height: 12),
        Text(title, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _errorState(String error, VoidCallback retry) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 40, color: AppTheme.error),
        const SizedBox(height: 12),
        Text(error,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
            label: const Text('Retry')),
      ]),
    );
  }
}
