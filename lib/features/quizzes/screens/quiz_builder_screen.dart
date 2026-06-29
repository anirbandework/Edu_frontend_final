// lib/features/quizzes/screens/quiz_builder_screen.dart
//
// Teacher authoring: build a quiz with inline questions and publish it to
// students in one flow. Honors the backend contract: options is a Dict{key:text}
// and correct_answer is the KEY (MCQ) or "True"/"False". AppTheme only.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/quiz_admin_service.dart';
import '../../../services/teacher_portal_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

const _qTypes = <MapEntry<String, String>>[
  MapEntry('multiple_choice', 'Multiple choice'),
  MapEntry('true_false', 'True / False'),
  MapEntry('short_answer', 'Short answer'),
];
const _optionKeys = ['A', 'B', 'C', 'D', 'E'];

class _QDraft {
  String type = 'multiple_choice';
  final TextEditingController text = TextEditingController();
  final TextEditingController points = TextEditingController(text: '1');
  final TextEditingController explanation = TextEditingController();
  // MCQ
  final List<TextEditingController> options = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String correctKey = 'A'; // MCQ key
  bool tfAnswer = true; // true_false
  final TextEditingController shortAnswer = TextEditingController();

  void dispose() {
    text.dispose();
    points.dispose();
    explanation.dispose();
    shortAnswer.dispose();
    for (final c in options) {
      c.dispose();
    }
  }
}

class QuizBuilderScreen extends StatefulWidget {
  final String? tenantId;
  const QuizBuilderScreen({super.key, this.tenantId});

  @override
  State<QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends State<QuizBuilderScreen> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _grade = TextEditingController();
  final _time = TextEditingController(text: '15');
  final _instructions = TextEditingController();

  String? _tenantId;
  List<Map<String, dynamic>> _classes = [];
  final Set<String> _selectedClasses = {};
  bool _publishNow = true;

  final List<_QDraft> _questions = [_QDraft()];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId ?? AuthSession.instance.tenantId;
    _loadClasses();
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _grade.dispose();
    _time.dispose();
    _instructions.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _loadClasses() async {
    if ((_tenantId ?? '').isEmpty) return;
    try {
      final classes = await TeacherPortalService.getClasses(tenantId: _tenantId!);
      if (!mounted) return;
      setState(() => _classes = classes);
    } catch (_) {/* class selection is optional */}
  }

  void _addQuestion() => setState(() => _questions.add(_QDraft()));
  void _removeQuestion(int i) {
    if (_questions.length == 1) return;
    setState(() {
      _questions[i].dispose();
      _questions.removeAt(i);
    });
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Quiz title is required';
    if (_subject.text.trim().isEmpty) return 'Subject is required';
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.text.text.trim().isEmpty) return 'Question ${i + 1}: text is required';
      if (q.type == 'multiple_choice') {
        final filled = q.options.where((c) => c.text.trim().isNotEmpty).length;
        if (filled < 2) return 'Question ${i + 1}: add at least 2 options';
        final correctIdx = _optionKeys.indexOf(q.correctKey);
        if (correctIdx >= q.options.length || q.options[correctIdx].text.trim().isEmpty) {
          return 'Question ${i + 1}: the correct option must have text';
        }
      }
      if (q.type == 'short_answer' && q.shortAnswer.text.trim().isEmpty) {
        return 'Question ${i + 1}: provide the expected answer';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _buildQuestions() {
    final out = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final points = int.tryParse(q.points.text.trim()) ?? 1;
      final base = <String, dynamic>{
        'question_text': q.text.text.trim(),
        'question_type': q.type,
        'difficulty_level': 'medium',
        'points': points < 1 ? 1 : points,
        if (q.explanation.text.trim().isNotEmpty) 'explanation': q.explanation.text.trim(),
      };
      if (q.type == 'multiple_choice') {
        final opts = <String, String>{};
        for (var k = 0; k < q.options.length; k++) {
          final t = q.options[k].text.trim();
          if (t.isNotEmpty) opts[_optionKeys[k]] = t;
        }
        base['options'] = opts;
        base['correct_answer'] = q.correctKey; // KEY, per backend grading
      } else if (q.type == 'true_false') {
        base['correct_answer'] = q.tfAnswer ? 'True' : 'False';
      } else {
        base['correct_answer'] = q.shortAnswer.text.trim();
      }
      out.add(base);
    }
    return out;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await QuizAdminService.createWithQuestions(
        title: _title.text.trim(),
        subject: _subject.text.trim(),
        gradeLevel: int.tryParse(_grade.text.trim()),
        instructions: _instructions.text.trim(),
        classIds: _selectedClasses.toList(),
        timeLimit: int.tryParse(_time.text.trim()),
        questions: _buildQuestions(),
      );
      // Make it visible to students immediately if requested.
      if (_publishNow) {
        final id = (res['id'] ?? res['quiz_id'])?.toString();
        if (id != null) {
          try {
            await QuizAdminService.setStatus(
                quizId: id, isActive: true, tenantId: _tenantId);
          } catch (_) {/* non-fatal; teacher can toggle from the list */}
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Quiz created'),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
      ));
      _goBack();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _goBack() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.teacherQuizzesRoute, queryParameters: qp).toString());
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Create Quiz',
          subtitle: 'Build questions and publish to students',
          icon: Icons.edit_note,
          leading: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _goBack,
              borderRadius: AppTheme.borderRadius12,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppTheme.borderRadius12,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
        children: [
          _metaCard(),
          const SizedBox(height: Sa.gapLg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Text('Questions', style: Sa.cardTitle.copyWith(fontSize: 16)),
              const SizedBox(width: 8),
              SaStatusPill(text: '${_questions.length}'),
            ]),
          ),
          const SizedBox(height: Sa.gap),
          ..._questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add question'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Sa.accent,
              minimumSize: const Size(0, 46),
              side: const BorderSide(color: Sa.accent, width: 1.5),
              shape: const RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadius12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Sa.gap),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 18, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: Sa.body.copyWith(color: AppTheme.error)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: Sa.gapLg),
          SaPrimaryButton(
            label: _saving ? 'Creating…' : 'Create quiz',
            icon: Icons.check_rounded,
            busy: _saving,
            expand: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _metaCard() {
    final gradeField = TextField(
      controller: _grade,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Grade (1-12)', isDense: true),
    );
    final timeField = TextField(
      controller: _time,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Time (min)', isDense: true),
    );
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.quiz_outlined, title: 'Quiz details'),
          const SizedBox(height: Sa.gap),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Quiz title *', isDense: true),
          ),
          const SizedBox(height: Sa.gap),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject *', isDense: true),
          ),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(builder: (context, c) {
            final oneCol = c.maxWidth < 600;
            return oneCol
                ? Column(children: [
                    gradeField,
                    const SizedBox(height: Sa.gap),
                    timeField,
                  ])
                : Row(children: [
                    Expanded(child: gradeField),
                    const SizedBox(width: Sa.gap),
                    Expanded(child: timeField),
                  ]);
          }),
          const SizedBox(height: Sa.gap),
          TextField(
            controller: _instructions,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Instructions (optional)', isDense: true),
          ),
          if (_classes.isNotEmpty) ...[
            const SizedBox(height: Sa.gapLg),
            const Text('Assign to classes (optional)', style: Sa.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classes.map((c) {
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
                  labelStyle: Sa.label.copyWith(
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
          ],
          const SizedBox(height: 4),
          SwitchListTile(
            value: _publishNow,
            onChanged: (v) => setState(() => _publishNow = v),
            activeThumbColor: AppTheme.greenPrimary,
            contentPadding: EdgeInsets.zero,
            title: const Text('Make available to students immediately',
                style: Sa.value),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(int index, _QDraft q) {
    final typeField = DropdownButtonFormField<String>(
      initialValue: q.type,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Type', isDense: true),
      items: _qTypes
          .map((t) => DropdownMenuItem(value: t.key, child: Text(t.value)))
          .toList(),
      onChanged: (v) => setState(() => q.type = v ?? 'multiple_choice'),
    );
    final pointsField = TextField(
      controller: q.points,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Points', isDense: true),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: Sa.gap),
      child: SaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: Sa.accent.withValues(alpha: 0.10),
                    borderRadius: AppTheme.borderRadius8),
                child: Center(
                  child: Text('${index + 1}',
                      style: Sa.value.copyWith(
                          color: AppTheme.greenPrimary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Question ${index + 1}', style: Sa.cardTitle)),
              IconButton(
                onPressed:
                    _questions.length == 1 ? null : () => _removeQuestion(index),
                icon: const Icon(Icons.delete_outline, size: 22),
                color: AppTheme.error,
                tooltip: 'Remove',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ]),
            const SizedBox(height: Sa.gap),
            LayoutBuilder(builder: (context, c) {
              final oneCol = c.maxWidth < 600;
              return oneCol
                  ? Column(children: [
                      typeField,
                      const SizedBox(height: Sa.gap),
                      pointsField,
                    ])
                  : Row(children: [
                      Expanded(flex: 2, child: typeField),
                      const SizedBox(width: Sa.gap),
                      Expanded(child: pointsField),
                    ]);
            }),
            const SizedBox(height: Sa.gap),
            TextField(
              controller: q.text,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Question', isDense: true),
            ),
            const SizedBox(height: Sa.gap),
            if (q.type == 'multiple_choice') _mcqEditor(q),
            if (q.type == 'true_false') _tfEditor(q),
            if (q.type == 'short_answer')
              TextField(
                controller: q.shortAnswer,
                decoration: const InputDecoration(
                    labelText: 'Expected answer (graded manually)', isDense: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mcqEditor(_QDraft q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tap the circle to mark the correct option',
            style: Sa.label),
        const SizedBox(height: 6),
        ...List.generate(q.options.length, (k) {
          final key = _optionKeys[k];
          final isCorrect = q.correctKey == key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              InkWell(
                onTap: () => setState(() => q.correctKey = key),
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCorrect ? AppTheme.greenPrimary : AppTheme.neutral400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 20,
                child: Text(key,
                    style: Sa.value.copyWith(
                        color: AppTheme.greenPrimary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: q.options[k],
                  decoration: InputDecoration(hintText: 'Option $key', isDense: true),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }

  Widget _tfEditor(_QDraft q) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _tfChip(q, true, 'True'),
        _tfChip(q, false, 'False'),
      ],
    );
  }

  Widget _tfChip(_QDraft q, bool value, String label) {
    final sel = q.tfAnswer == value;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      showCheckmark: false,
      selectedColor: AppTheme.greenPrimary,
      backgroundColor: AppTheme.neutral100,
      labelStyle: Sa.value.copyWith(
          color: sel ? Colors.white : AppTheme.neutral700, fontWeight: FontWeight.w600),
      onSelected: (_) => setState(() => q.tfAnswer = value),
    );
  }
}
