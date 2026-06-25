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
        backgroundColor: AppTheme.success,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.greenPrimary,
            tooltip: 'Back',
          ),
          Expanded(child: Text('Create Quiz', style: AppTheme.headingMedium)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              _metaCard(),
              const SizedBox(height: 16),
              Row(children: [
                Text('Questions', style: AppTheme.headingSmall),
                const SizedBox(width: 8),
                Text('${_questions.length}',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
              ]),
              const SizedBox(height: 8),
              ..._questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add, size: AppTheme.iconSmall),
                label: const Text('Add question'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTheme.bodyMedium.copyWith(color: AppTheme.error)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Creating…' : 'Create quiz'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Quiz title *', isDense: true),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject *', isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _grade,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grade (1-12)', isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _time,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Time (min)', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _instructions,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Instructions (optional)', isDense: true),
          ),
          if (_classes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Assign to classes (optional)', style: AppTheme.labelMedium),
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
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            value: _publishNow,
            onChanged: (v) => setState(() => _publishNow = v),
            activeColor: AppTheme.greenPrimary,
            contentPadding: EdgeInsets.zero,
            title: Text('Make available to students immediately',
                style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(int index, _QDraft q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                  color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
              child: Center(
                child: Text('${index + 1}',
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.greenPrimary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: q.type,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: _qTypes
                    .map((t) => DropdownMenuItem(value: t.key, child: Text(t.value)))
                    .toList(),
                onChanged: (v) => setState(() => q.type = v ?? 'multiple_choice'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: TextField(
                controller: q.points,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pts', isDense: true),
              ),
            ),
            IconButton(
              onPressed: _questions.length == 1 ? null : () => _removeQuestion(index),
              icon: const Icon(Icons.close, size: AppTheme.iconMedium),
              color: AppTheme.error,
              tooltip: 'Remove',
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: q.text,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Question', isDense: true),
          ),
          const SizedBox(height: 10),
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
    );
  }

  Widget _mcqEditor(_QDraft q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tap the circle to mark the correct option',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
        const SizedBox(height: 6),
        ...List.generate(q.options.length, (k) {
          final key = _optionKeys[k];
          final isCorrect = q.correctKey == key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              InkWell(
                onTap: () => setState(() => q.correctKey = key),
                borderRadius: AppTheme.borderRadius8,
                child: Icon(
                  isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCorrect ? AppTheme.success : AppTheme.neutral400,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Text(key,
                    style: AppTheme.labelMedium.copyWith(
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
    return Row(children: [
      _tfChip(q, true, 'True'),
      const SizedBox(width: 8),
      _tfChip(q, false, 'False'),
    ]);
  }

  Widget _tfChip(_QDraft q, bool value, String label) {
    final sel = q.tfAnswer == value;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      showCheckmark: false,
      selectedColor: AppTheme.success,
      backgroundColor: AppTheme.neutral100,
      labelStyle: AppTheme.bodyMedium.copyWith(
          color: sel ? Colors.white : AppTheme.neutral700, fontWeight: FontWeight.w600),
      onSelected: (_) => setState(() => q.tfAnswer = value),
    );
  }
}
