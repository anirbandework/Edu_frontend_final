// lib/features/assignments/screens/assignment_management_screen.dart
//
// Teacher assignment management: pick a class, create assignments, and view +
// grade student PDF submissions. Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/assignment_service.dart';
import '../../../services/teacher_portal_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class AssignmentManagementScreen extends StatefulWidget {
  final String? tenantId;
  const AssignmentManagementScreen({super.key, this.tenantId});

  @override
  State<AssignmentManagementScreen> createState() => _AssignmentManagementScreenState();
}

class _AssignmentManagementScreenState extends State<AssignmentManagementScreen> {
  String? _tenantId;
  List<Map<String, dynamic>> _classes = [];
  String? _classId;
  static const _academicYear = '2025-26';

  bool _loadingClasses = true;
  bool _loadingList = false;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId ?? AuthSession.instance.tenantId;
    _loadClasses();
  }

  String get _academicYearForClass {
    final c = _classes.firstWhere((c) => c['id']?.toString() == _classId,
        orElse: () => const <String, dynamic>{});
    final y = (c['academic_year'] ?? '').toString();
    return y.isNotEmpty ? y : _academicYear;
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
      if (_classId != null) _loadAssignments();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadAssignments() async {
    if (_classId == null) return;
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final list = await AssignmentService.getClassAssignments(classId: _classId!);
      if (!mounted) return;
      setState(() {
        _assignments = list;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _create() async {
    if (_classId == null) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateAssignmentDialog(
        classId: _classId!,
        academicYear: _academicYearForClass,
      ),
    );
    if (created == true) _loadAssignments();
  }

  void _openSubmissions(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmissionsSheet(
        assessmentId: a['id'].toString(),
        title: (a['assessment_title'] ?? 'Assignment').toString(),
        maxMarks: (a['max_marks'] as num?)?.toDouble() ?? 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Assignments',
          subtitle: 'Create assignments and grade submissions',
          icon: Icons.assignment_outlined,
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'New assignment',
            onPressed: (_classId == null) ? null : _create,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: _classPicker(),
          ),
          const SizedBox(height: Sa.gap),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _classPicker() {
    return SaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: _loadingClasses
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                color: AppTheme.greenPrimary,
                backgroundColor: AppTheme.neutral200,
              ),
            )
          : DropdownButtonFormField<String>(
              initialValue: _classId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Class',
                  prefixIcon: Icon(Icons.class_, color: AppTheme.neutral500),
                  isDense: true,
                  border: InputBorder.none),
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
                _loadAssignments();
              },
            ),
    );
  }

  Widget _body() {
    if (_loadingClasses || _loadingList) {
      return const SaLoading(message: 'Loading…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _loadClasses);
    }
    if (_assignments.isEmpty) {
      return SaStateView(
        icon: Icons.assignment_outlined,
        title: 'No assignments yet',
        subtitle: 'Assignments for this class will appear here once created.',
        action: SaPrimaryButton(
          label: 'Create assignment',
          icon: Icons.add,
          onPressed: _classId == null ? null : _create,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
      itemCount: _assignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _card(_assignments[i]),
    );
  }

  Widget _card(Map<String, dynamic> a) {
    final title = (a['assessment_title'] ?? 'Assignment').toString();
    final subject = (a['subject'] ?? '').toString();
    final type = (a['assessment_type'] ?? '').toString();
    final due = (a['due_date'] ?? '').toString();
    final max = a['max_marks'];
    return SaCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openSubmissions(a),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppTheme.borderRadius12),
          child: const Icon(Icons.assignment,
              color: Colors.white, size: AppTheme.iconMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Sa.cardTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(spacing: 10, runSpacing: 4, children: [
                if (subject.isNotEmpty) _meta(Icons.menu_book, subject),
                if (max != null) _meta(Icons.star_outline, '$max marks'),
                if (due.isNotEmpty) _meta(Icons.event, due.split('T').first),
              ]),
            ],
          ),
        ),
        if (type.isNotEmpty) ...[
          const SizedBox(width: 6),
          SaStatusPill(text: type),
        ],
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, color: AppTheme.neutral400),
      ]),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral500),
      const SizedBox(width: 4),
      Text(text, style: Sa.label),
    ]);
  }
}

// ---------------------------------------------------------------------------
class _CreateAssignmentDialog extends StatefulWidget {
  final String classId;
  final String academicYear;
  const _CreateAssignmentDialog({required this.classId, required this.academicYear});

  @override
  State<_CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _maxMarks = TextEditingController(text: '100');
  final _desc = TextEditingController();
  String _type = 'assignment';
  DateTime? _due;
  bool _saving = false;
  String? _err;

  static const _types = ['assignment', 'homework', 'project', 'test'];

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _maxMarks.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _err = 'Title is required');
      return;
    }
    if (_subject.text.trim().isEmpty) {
      setState(() => _err = 'Subject is required');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await AssignmentService.createAssignment(
        classId: widget.classId,
        title: _title.text.trim(),
        subject: _subject.text.trim(),
        academicYear: widget.academicYear,
        type: _type,
        description: _desc.text.trim(),
        dueDate: _due?.toIso8601String(),
        maxMarks: num.tryParse(_maxMarks.text.trim()) ?? 100,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width - 24;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW > 440 ? 440 : maxW,
          maxHeight: MediaQuery.of(context).size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('New Assignment', style: Sa.cardTitle),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                          labelText: 'Title *', isDense: true),
                    ),
                    const SizedBox(height: Sa.gap),
                    LayoutBuilder(builder: (context, c) {
                      final subjectField = TextField(
                        controller: _subject,
                        decoration: const InputDecoration(
                            labelText: 'Subject *', isDense: true),
                      );
                      final typeField = DropdownButtonFormField<String>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Type', isDense: true),
                        items: _types
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _type = v ?? 'assignment'),
                      );
                      return c.maxWidth < 600
                          ? Column(children: [
                              subjectField,
                              const SizedBox(height: Sa.gap),
                              typeField,
                            ])
                          : Row(children: [
                              Expanded(child: subjectField),
                              const SizedBox(width: Sa.gap),
                              Expanded(child: typeField),
                            ]);
                    }),
                    const SizedBox(height: Sa.gap),
                    LayoutBuilder(builder: (context, c) {
                      final marksField = TextField(
                        controller: _maxMarks,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Max marks', isDense: true),
                      );
                      final dueField = OutlinedButton.icon(
                        onPressed: _pickDue,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Sa.accent,
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: Sa.accent),
                        ),
                        icon:
                            const Icon(Icons.event, size: AppTheme.iconSmall),
                        label: Text(_due == null
                            ? 'Due date'
                            : _due!.toIso8601String().split('T').first),
                      );
                      return c.maxWidth < 600
                          ? Column(children: [
                              marksField,
                              const SizedBox(height: Sa.gap),
                              SizedBox(width: double.infinity, child: dueField),
                            ])
                          : Row(children: [
                              Expanded(child: marksField),
                              const SizedBox(width: Sa.gap),
                              Expanded(child: dueField),
                            ]);
                    }),
                    const SizedBox(height: Sa.gap),
                    TextField(
                      controller: _desc,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Instructions (optional)', isDense: true),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: Sa.gap),
                      Text(_err!,
                          style: Sa.body.copyWith(color: AppTheme.error)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: _saving ? 'Creating…' : 'Create',
                    icon: Icons.check_rounded,
                    busy: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _SubmissionsSheet extends StatefulWidget {
  final String assessmentId;
  final String title;
  final double maxMarks;
  const _SubmissionsSheet({
    required this.assessmentId,
    required this.title,
    required this.maxMarks,
  });

  @override
  State<_SubmissionsSheet> createState() => _SubmissionsSheetState();
}

class _SubmissionsSheetState extends State<_SubmissionsSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AssignmentService.getSubmissions(assessmentId: widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _subs = ((data['submissions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
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

  Future<void> _grade(Map<String, dynamic> s) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _GradeDialog(
        submissionId: s['submission_id'].toString(),
        studentName: (s['student_name'] ?? 'Student').toString(),
        maxMarks: widget.maxMarks,
      ),
    );
    if (res == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(width: 40, height: 4,
                  decoration: const BoxDecoration(
                      color: AppTheme.neutral300, borderRadius: AppTheme.borderRadius8)),
              const SizedBox(height: 12),
              Text(widget.title, style: Sa.cardTitle.copyWith(fontSize: 17),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${_subs.length} submission${_subs.length == 1 ? '' : 's'}',
                  style: Sa.label),
              const SizedBox(height: 12),
              Expanded(child: _list(controller)),
            ],
          ),
        );
      },
    );
  }

  Widget _list(ScrollController controller) {
    if (_loading) {
      return const SaLoading(message: 'Loading…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    if (_subs.isEmpty) {
      return const SaStateView(
        icon: Icons.inbox_outlined,
        title: 'No submissions yet',
        subtitle: 'Student submissions will appear here.',
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _subs.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) {
        final s = _subs[i];
        final name = (s['student_name'] ?? 'Student').toString();
        final filename = (s['filename'] ?? '').toString();
        final graded = s['marks_obtained'] != null || s['grade'] != null;
        final marks = s['marks_obtained'];
        final grade = (s['grade'] ?? '').toString();
        return SaCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.green50,
              child: Icon(Icons.picture_as_pdf,
                  color: AppTheme.greenPrimary, size: AppTheme.iconMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Sa.value,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (filename.isNotEmpty)
                    Text(filename,
                        style: Sa.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (graded)
                    Text('Graded: $marks ${grade.isNotEmpty ? '($grade)' : ''}',
                        style: Sa.label.copyWith(
                            color: AppTheme.greenPrimary,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () => _grade(s),
              style: TextButton.styleFrom(
                foregroundColor: Sa.accent,
                minimumSize: const Size(0, 44),
              ),
              child: Text(graded ? 'Re-grade' : 'Grade'),
            ),
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
class _GradeDialog extends StatefulWidget {
  final String submissionId;
  final String studentName;
  final double maxMarks;
  const _GradeDialog({
    required this.submissionId,
    required this.studentName,
    required this.maxMarks,
  });

  @override
  State<_GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<_GradeDialog> {
  final _marks = TextEditingController();
  final _grade = TextEditingController();
  final _feedback = TextEditingController();
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _marks.dispose();
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  String _letter(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  Future<void> _save() async {
    final m = double.tryParse(_marks.text.trim());
    if (m == null || m < 0 || m > widget.maxMarks) {
      setState(() => _err = 'Enter marks between 0 and ${widget.maxMarks.toStringAsFixed(0)}');
      return;
    }
    final grade = _grade.text.trim().isNotEmpty
        ? _grade.text.trim()
        : _letter(widget.maxMarks > 0 ? (m / widget.maxMarks * 100) : 0);
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await AssignmentService.gradeSubmission(
        submissionId: widget.submissionId,
        marks: m,
        grade: grade,
        feedback: _feedback.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width - 24;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW > 420 ? 420 : maxW,
          maxHeight: MediaQuery.of(context).size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Grade · ${widget.studentName}',
                  style: Sa.cardTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(builder: (context, c) {
                      final marksField = TextField(
                        controller: _marks,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: 'Marks',
                            suffixText:
                                '/${widget.maxMarks.toStringAsFixed(0)}',
                            isDense: true),
                      );
                      final gradeField = TextField(
                        controller: _grade,
                        decoration: const InputDecoration(
                            labelText: 'Grade (auto)', isDense: true),
                      );
                      return c.maxWidth < 600
                          ? Column(children: [
                              marksField,
                              const SizedBox(height: Sa.gap),
                              gradeField,
                            ])
                          : Row(children: [
                              Expanded(child: marksField),
                              const SizedBox(width: Sa.gap),
                              Expanded(child: gradeField),
                            ]);
                    }),
                    const SizedBox(height: Sa.gap),
                    TextField(
                      controller: _feedback,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Feedback (optional)', isDense: true),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: Sa.gap),
                      Text(_err!,
                          style: Sa.body.copyWith(color: AppTheme.error)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: _saving ? 'Saving…' : 'Save grade',
                    icon: Icons.check_rounded,
                    busy: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
