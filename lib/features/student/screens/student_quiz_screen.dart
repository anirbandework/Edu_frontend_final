// lib/features/student/screens/student_quiz_screen.dart
//
// Take a quiz: intro -> start attempt -> answer questions -> submit -> scored
// result. Questions come WITHOUT correct answers; the attempt is identity-checked
// on submit. Optional countdown auto-submits when time runs out. AppTheme only.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/student_portal_service.dart';

enum _Phase { loading, intro, taking, submitting, done, error }

class StudentQuizScreen extends StatefulWidget {
  final String quizId;
  final String? tenantId;
  const StudentQuizScreen({super.key, required this.quizId, this.tenantId});

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  _Phase _phase = _Phase.loading;
  String? _error;

  Map<String, dynamic> _quiz = {};
  List<Map<String, dynamic>> _questions = [];
  final Map<String, String> _answers = {}; // question_id -> answer

  String? _attemptId;
  Map<String, dynamic> _result = {};

  Timer? _timer;
  int _secondsLeft = 0;

  String? get _tenantId => widget.tenantId ?? AuthSession.instance.tenantId;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final q = await StudentPortalService.getQuizForStudent(
          quizId: widget.quizId, tenantId: _tenantId);
      _quiz = q;
      _questions = ((q['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() => _phase = _Phase.intro);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.loading);
    try {
      final res = await StudentPortalService.startQuizAttempt(
          quizId: widget.quizId, tenantId: _tenantId);
      _attemptId = (res['id'] ?? res['attempt_id'])?.toString();
      if (!mounted) return;
      setState(() => _phase = _Phase.taking);
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _startTimer() {
    final minutes = (_quiz['time_limit'] as num?)?.toInt() ?? 0;
    if (minutes <= 0) return;
    _secondsLeft = minutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _submit(auto: true);
      }
    });
  }

  Future<void> _submit({bool auto = false}) async {
    if (_attemptId == null) return;
    if (!auto) {
      final unanswered = _questions.length - _answers.length;
      if (unanswered > 0) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Submit quiz?'),
            content: Text('You have $unanswered unanswered '
                '${unanswered == 1 ? 'question' : 'questions'}. Submit anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
            ],
          ),
        );
        if (go != true) return;
      }
    }
    _timer?.cancel();
    setState(() => _phase = _Phase.submitting);
    try {
      final answers = _answers.entries
          .map((e) => {'question_id': e.key, 'student_answer': e.value})
          .toList();
      final res = await StudentPortalService.submitQuizAttempt(
          attemptId: _attemptId!, answers: answers, tenantId: _tenantId);
      if (!mounted) return;
      setState(() {
        _result = res;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
      case _Phase.submitting:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.greenPrimary),
            const SizedBox(height: 12),
            Text(_phase == _Phase.submitting ? 'Submitting…' : 'Loading…',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          ]),
        );
      case _Phase.error:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 40, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _loadQuiz,
                icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
                label: const Text('Retry')),
          ]),
        );
      case _Phase.intro:
        return _intro();
      case _Phase.taking:
        return _taking();
      case _Phase.done:
        return _done();
    }
  }

  Widget _intro() {
    final title = (_quiz['title'] ?? 'Quiz').toString();
    final desc = (_quiz['description'] ?? '').toString();
    final instructions = (_quiz['instructions'] ?? '').toString();
    final totalQ = _quiz['total_questions'] ?? _questions.length;
    final points = _quiz['total_points'];
    final time = _quiz['time_limit'];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                Text(title,
                    style: AppTheme.headingMedium.copyWith(color: Colors.white)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(desc, style: AppTheme.bodyMedium.copyWith(color: Colors.white70)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _stat(Icons.help_outline, '$totalQ', 'Questions'),
            const SizedBox(width: 12),
            if (points != null) _stat(Icons.star_outline, '$points', 'Points'),
            if (points != null) const SizedBox(width: 12),
            if (time != null) _stat(Icons.timer_outlined, '$time min', 'Time limit'),
          ]),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions', style: AppTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(instructions,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _questions.isEmpty ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(_questions.isEmpty ? 'No questions available' : 'Start quiz'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCardDecoration,
        child: Column(children: [
          Icon(icon, color: AppTheme.greenPrimary, size: AppTheme.iconMedium),
          const SizedBox(height: 6),
          Text(value,
              style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
        ]),
      ),
    );
  }

  Widget _taking() {
    final answered = _answers.length;
    final total = _questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text((_quiz['title'] ?? 'Quiz').toString(),
                style: AppTheme.headingSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (_timer != null && _secondsLeft > 0) _timerChip(),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppTheme.borderRadius8,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : answered / total,
                minHeight: 6,
                backgroundColor: AppTheme.neutral200,
                valueColor: const AlwaysStoppedAnimation(AppTheme.greenPrimary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$answered/$total',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _questionCard(i, _questions[i]),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _submit(),
            icon: const Icon(Icons.check),
            label: const Text('Submit quiz'),
          ),
        ),
      ],
    );
  }

  Widget _timerChip() {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    final low = _secondsLeft <= 60;
    final color = low ? AppTheme.error : AppTheme.greenPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer, size: AppTheme.iconSmall, color: color),
        const SizedBox(width: 6),
        Text('$m:$s',
            style: AppTheme.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _questionCard(int index, Map<String, dynamic> q) {
    final id = q['id'].toString();
    final text = (q['question_text'] ?? '').toString();
    final type = (q['question_type'] ?? 'short_answer').toString().toLowerCase();
    final points = q['points'];
    final selected = _answers[id];

    final options = _optionsFor(q, type);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: Text(text,
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (points != null)
                Text('$points pts',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
            ],
          ),
          const SizedBox(height: 12),
          if (options.isNotEmpty)
            ...options.map((o) => _optionTile(id, o.key, o.value, selected))
          else
            TextField(
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your answer',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() {
                if (v.trim().isEmpty) {
                  _answers.remove(id);
                } else {
                  _answers[id] = v;
                }
              }),
            ),
        ],
      ),
    );
  }

  // Returns option (key -> label) pairs. The backend serves options as a
  // Dict[str,str] (e.g. {"A":"Paris"}); the student SUBMITS the key, which the
  // server compares (case-insensitively) against the question's correct_answer.
  List<MapEntry<String, String>> _optionsFor(Map<String, dynamic> q, String type) {
    final raw = q['options'];
    final out = <MapEntry<String, String>>[];
    if (raw is Map) {
      raw.forEach((k, v) => out.add(MapEntry(k.toString(), v.toString())));
    } else if (raw is List) {
      for (final o in raw) {
        if (o is String) {
          out.add(MapEntry(o, o));
        } else if (o is Map) {
          final m = o.cast<String, dynamic>();
          final key = (m['key'] ?? m['id'] ?? m['value'] ?? m['text'] ?? '').toString();
          final label = (m['text'] ?? m['option_text'] ?? m['label'] ?? m['value'] ?? key).toString();
          if (label.isNotEmpty) out.add(MapEntry(key, label));
        }
      }
    }
    if (out.isEmpty && (type.contains('true') || type.contains('bool'))) {
      return const [MapEntry('True', 'True'), MapEntry('False', 'False')];
    }
    return out;
  }

  Widget _optionTile(String questionId, String optionKey, String optionLabel, String? selected) {
    final isSel = selected == optionKey;
    return InkWell(
      borderRadius: AppTheme.borderRadius12,
      onTap: () => setState(() => _answers[questionId] = optionKey),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.green50 : AppTheme.neutral50,
          borderRadius: AppTheme.borderRadius12,
          border: Border.all(
              color: isSel ? AppTheme.greenPrimary : AppTheme.neutral200,
              width: isSel ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: AppTheme.iconMedium,
              color: isSel ? AppTheme.greenPrimary : AppTheme.neutral400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(optionLabel,
                style: AppTheme.bodyMedium.copyWith(
                    color: isSel ? AppTheme.neutral800 : AppTheme.neutral600,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
          ),
        ]),
      ),
    );
  }

  Widget _done() {
    final score = _result['total_score'];
    final maxScore = _result['max_score'];
    final pctRaw = _result['percentage'];
    final pct = pctRaw is num ? pctRaw.round() : null;
    final color = pct == null
        ? AppTheme.greenPrimary
        : (pct >= 60 ? AppTheme.success : (pct >= 40 ? AppTheme.warning : AppTheme.error));
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: Center(
                child: Text(pct != null ? '$pct%' : '✓',
                    style: AppTheme.headingLarge.copyWith(
                        color: color, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Quiz submitted', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            if (score != null && maxScore != null)
              Text('You scored $score out of $maxScore',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.neutral600)),
            const SizedBox(height: 6),
            Text('Detailed results appear under "My Results" once published.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _backToQuizzes,
              icon: const Icon(Icons.arrow_back, size: AppTheme.iconSmall),
              label: const Text('Back to Quizzes'),
            ),
          ],
        ),
      ),
    );
  }

  void _backToQuizzes() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.studentAssignmentsRoute, queryParameters: qp).toString());
  }
}
