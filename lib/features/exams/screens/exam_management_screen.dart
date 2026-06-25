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
      _toast('No classes available to attach an exam to', AppTheme.warning);
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
      _toast('Results published to students', AppTheme.success);
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
      _toast('Exam deleted', AppTheme.success);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exams', style: AppTheme.headingMedium),
                  Text(_loading ? 'Loading…' : '${_exams.length} exams',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _createExam,
              icon: const Icon(Icons.add, size: AppTheme.iconSmall),
              label: const Text('New Exam'),
            ),
            const SizedBox(width: 8),
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
    if (_exams.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No exams yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _createExam,
              icon: const Icon(Icons.add, size: AppTheme.iconSmall),
              label: const Text('Create your first exam')),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 620 ? 2 : 1);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 184,
          ),
          itemCount: _exams.length,
          itemBuilder: (context, i) => _examCard(_exams[i]),
        );
      }),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    Text(name,
                        style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (code.isNotEmpty)
                      Text(code,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                  ],
                ),
              ),
              _statusChip(published),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (type.isNotEmpty) _tag(_label(type)),
            if (year.isNotEmpty) _tag(year),
          ]),
          const Spacer(),
          Row(children: [
            if (totalStudents != null) _meta(Icons.people_outline, '$totalStudents students'),
            if (completed != null) ...[
              const SizedBox(width: 12),
              _meta(Icons.task_alt, '$completed marked'),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            if (!published)
              TextButton.icon(
                onPressed: busy ? null : () => _publish(e),
                icon: busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish, size: AppTheme.iconSmall, color: AppTheme.success),
                label: const Text('Publish'),
              ),
            const Spacer(),
            IconButton(
              onPressed: () => _delete(e),
              icon: const Icon(Icons.delete_outline, size: AppTheme.iconMedium),
              color: AppTheme.error,
              tooltip: 'Delete',
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

  Widget _statusChip(bool published) {
    final color = published ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
      child: Text(published ? 'Published' : 'Draft',
          style: AppTheme.bodyMicro.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
      child: Text(text,
          style: AppTheme.bodyMicro.copyWith(
              color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
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
    return AlertDialog(
      title: const Text('New Exam'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Exam name *', isDense: true),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type', isDense: true),
                    items: _examTypes
                        .map((t) => DropdownMenuItem(value: t.key, child: Text(t.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? 'unit_test'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _year,
                    decoration: const InputDecoration(labelText: 'Academic year', isDense: true),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (min)', isDense: true),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                    labelText: 'Exam code (auto if blank)', isDense: true),
              ),
              const SizedBox(height: 16),
              Text('Classes *', style: AppTheme.labelMedium),
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
                    showCheckmark: false,
                    selectedColor: AppTheme.greenPrimary,
                    backgroundColor: AppTheme.neutral100,
                    labelStyle: AppTheme.bodySmall.copyWith(
                        color: sel ? Colors.white : AppTheme.neutral700,
                        fontWeight: FontWeight.w600),
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
                const SizedBox(height: 12),
                Text(_err!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: AppTheme.iconSmall),
          label: Text(_saving ? 'Creating…' : 'Create'),
        ),
      ],
    );
  }
}
