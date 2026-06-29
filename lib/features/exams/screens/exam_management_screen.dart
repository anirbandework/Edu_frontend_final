// lib/features/exams/screens/exam_management_screen.dart
//
// Create & manage exams (require_staff: teachers and school authorities). Listing,
// create-with-classes, publish-to-students, delete. Unblocks the teacher Grades
// flow. Real backend (/exam-management, NO /api/v1 prefix). AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/grades_service.dart';
import '../../../services/teacher_portal_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

const _examTypes = <MapEntry<String, String>>[
  MapEntry('unit_test', 'Unit Test'),
  MapEntry('class_test', 'Class Test'),
  MapEntry('mid_term', 'Mid Term'),
  MapEntry('quarterly', 'Quarterly'),
  MapEntry('half_yearly', 'Half Yearly'),
  MapEntry('final', 'Final'),
  MapEntry('annual', 'Annual'),
  MapEntry('practical', 'Practical'),
];

class ExamManagementScreen extends StatefulWidget {
  final String? tenantId;
  const ExamManagementScreen({super.key, this.tenantId});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  String? _tenantId;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId ?? AuthSession.instance.tenantId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await GradesService.getExams();
      List<Map<String, dynamic>> classes = const [];
      if ((_tenantId ?? '').isNotEmpty) {
        classes = await TeacherPortalService.getClasses(tenantId: _tenantId!);
      }
      if (!mounted) return;
      setState(() {
        _exams = exams;
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

  Future<void> _createExam() async {
    if (_classes.isEmpty) {
      _toast('No classes available to attach an exam to', AppTheme.error);
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateExamDialog(classes: _classes),
    );
    if (created == true) _load();
  }

  Future<void> _publish(Map<String, dynamic> e) async {
    final id = e['id']?.toString();
    if (id == null) return;
    setState(() => e['_busy'] = true);
    try {
      await GradesService.publishExam(examId: id);
      _toast('Results published to students', AppTheme.greenPrimary);
      _load();
    } catch (err) {
      if (!mounted) return;
      setState(() => e.remove('_busy'));
      _toast(err.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final id = e['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exam?'),
        content: Text('"${e['exam_name'] ?? 'This exam'}" and its marks will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GradesService.deleteExam(examId: id);
      _toast('Exam deleted', AppTheme.greenPrimary);
      _load();
    } catch (err) {
      _toast(err.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Exam Management',
          subtitle: _loading ? 'Loading…' : '${_exams.length} exams',
          icon: Icons.fact_check_outlined,
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'New exam',
            onPressed: _createExam,
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading exams…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    if (_exams.isEmpty) {
      return SaStateView(
        icon: Icons.fact_check_outlined,
        title: 'No exams yet',
        subtitle: 'Create your first exam to start tracking marks.',
        action: SaPrimaryButton(
          label: 'Create your first exam',
          icon: Icons.add,
          onPressed: _createExam,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
      itemCount: _exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _examCard(_exams[i]),
    );
  }

  Widget _examCard(Map<String, dynamic> e) {
    final name = (e['exam_name'] ?? 'Exam').toString();
    final code = (e['exam_code'] ?? '').toString();
    final type = (e['exam_type'] ?? '').toString();
    final year = (e['academic_year'] ?? '').toString();
    final published = e['is_published'] == true;
    final busy = e['_busy'] == true;
    final totalStudents = e['total_students'];
    final completed = e['completed_markings'];
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.borderRadius12),
                child: const Icon(Icons.fact_check_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: Sa.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: Sa.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (code.isNotEmpty)
                      Text(code,
                          style: Sa.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: Sa.gapXs),
              SaStatusPill(
                text: published ? 'Published' : 'Draft',
                color: published ? AppTheme.greenPrimary : AppTheme.neutral500,
              ),
            ],
          ),
          if (type.isNotEmpty || year.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (type.isNotEmpty) _tag(_label(type)),
              if (year.isNotEmpty) _tag(year),
            ]),
          ],
          if (totalStudents != null || completed != null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: Sa.gap, runSpacing: 6, children: [
              if (totalStudents != null)
                _meta(Icons.people_outline, '$totalStudents students'),
              if (completed != null) _meta(Icons.task_alt, '$completed marked'),
            ]),
          ],
          const SizedBox(height: Sa.gap),
          Row(children: [
            if (!published)
              TextButton.icon(
                onPressed: busy ? null : () => _publish(e),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.greenPrimary,
                  minimumSize: const Size(0, 44),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.greenPrimary))
                    : const Icon(Icons.publish,
                        size: 18, color: AppTheme.greenPrimary),
                label: const Text('Publish'),
              ),
            const Spacer(),
            IconButton(
              onPressed: () => _delete(e),
              icon: const Icon(Icons.delete_outline, size: 22),
              color: AppTheme.error,
              tooltip: 'Delete',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ]),
        ],
      ),
    );
  }

  String _label(String type) {
    for (final t in _examTypes) {
      if (t.key == type) return t.value;
    }
    return type.replaceAll('_', ' ');
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
          color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
      child: Text(text,
          style: Sa.label.copyWith(
              color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: AppTheme.neutral500),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            style: Sa.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _CreateExamDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  const _CreateExamDialog({required this.classes});

  @override
  State<_CreateExamDialog> createState() => _CreateExamDialogState();
}

class _CreateExamDialogState extends State<_CreateExamDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _subject = TextEditingController();
  final _year = TextEditingController(text: '2025-26');
  final _duration = TextEditingController(text: '60');
  String _type = 'unit_test';
  final Set<String> _selectedClasses = {};
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _subject.dispose();
    _year.dispose();
    _duration.dispose();
    super.dispose();
  }

  String _genCode() {
    final initials = _name.text.trim().isEmpty
        ? 'EXM'
        : _name.text.trim().split(RegExp(r'\s+')).map((w) => w[0].toUpperCase()).take(3).join();
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    return '$initials${ms.substring(ms.length - 4)}';
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Exam name is required');
      return;
    }
    if (_selectedClasses.isEmpty) {
      setState(() => _err = 'Select at least one class');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await GradesService.createExam(
        examName: _name.text.trim(),
        examCode: _code.text.trim().isEmpty ? _genCode() : _code.text.trim(),
        examType: _type,
        academicYear: _year.text.trim().isEmpty ? '2025-26' : _year.text.trim(),
        classIds: _selectedClasses.toList(),
        subject: _subject.text.trim(),
        durationMinutes: int.tryParse(_duration.text.trim()),
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
          maxWidth: maxW > 460 ? 460 : maxW,
          maxHeight: MediaQuery.of(context).size.height - 80,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Exam', style: Sa.cardTitle.copyWith(fontSize: 17)),
              const SizedBox(height: Sa.gapLg),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Exam name *', isDense: true),
                      ),
                      const SizedBox(height: Sa.gap),
                      LayoutBuilder(builder: (context, c) {
                        final typeField = DropdownButtonFormField<String>(
                          initialValue: _type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Type', isDense: true),
                          items: _examTypes
                              .map((t) => DropdownMenuItem(
                                  value: t.key, child: Text(t.value)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _type = v ?? 'unit_test'),
                        );
                        final yearField = TextField(
                          controller: _year,
                          decoration: const InputDecoration(
                              labelText: 'Academic year', isDense: true),
                        );
                        return c.maxWidth < 600
                            ? Column(children: [
                                typeField,
                                const SizedBox(height: Sa.gap),
                                yearField,
                              ])
                            : Row(children: [
                                Expanded(child: typeField),
                                const SizedBox(width: Sa.gap),
                                Expanded(child: yearField),
                              ]);
                      }),
                      const SizedBox(height: Sa.gap),
                      LayoutBuilder(builder: (context, c) {
                        final subjectField = TextField(
                          controller: _subject,
                          decoration: const InputDecoration(
                              labelText: 'Subject', isDense: true),
                        );
                        final durationField = TextField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Duration (min)', isDense: true),
                        );
                        return c.maxWidth < 600
                            ? Column(children: [
                                subjectField,
                                const SizedBox(height: Sa.gap),
                                durationField,
                              ])
                            : Row(children: [
                                Expanded(child: subjectField),
                                const SizedBox(width: Sa.gap),
                                Expanded(child: durationField),
                              ]);
                      }),
                      const SizedBox(height: Sa.gap),
                      TextField(
                        controller: _code,
                        decoration: const InputDecoration(
                            labelText: 'Exam code (auto if blank)',
                            isDense: true),
                      ),
                      const SizedBox(height: Sa.gapLg),
                      const Text('Classes *', style: Sa.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.classes.map((c) {
                          final id = c['id']?.toString() ?? '';
                          final name = (c['class_name'] ?? 'Class').toString();
                          final sec = (c['section'] ?? '').toString();
                          final sel = _selectedClasses.contains(id);
                          return FilterChip(
                            label: Text(sec.isEmpty ? name : '$name • $sec'),
                            selected: sel,
                            checkmarkColor: Colors.white,
                            selectedColor: AppTheme.greenPrimary,
                            backgroundColor: AppTheme.neutral100,
                            labelStyle: Sa.value.copyWith(
                                color: sel ? Colors.white : AppTheme.neutral700),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selectedClasses.add(id);
                              } else {
                                _selectedClasses.remove(id);
                              }
                            }),
                          );
                        }).toList(),
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
              const SizedBox(height: Sa.gapLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: _saving ? 'Creating…' : 'Create',
                    icon: Icons.check,
                    busy: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
