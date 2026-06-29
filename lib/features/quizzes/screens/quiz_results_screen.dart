// lib/features/quizzes/screens/quiz_results_screen.dart
//
// Teacher view of a quiz's student results, plus the manual short-answer grading
// queue and a publish action. Real backend (/assessment/quiz). AppTheme only.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/quiz_admin_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final String? teacherId;
  final String? tenantId;
  const QuizResultsScreen({
    super.key,
    required this.quizId,
    this.quizTitle = 'Quiz',
    this.teacherId,
    this.tenantId,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _loading = true;
  bool _publishing = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _pending = [];
  final Map<String, TextEditingController> _pointCtrls = {};

  String get _teacherId => (widget.teacherId?.isNotEmpty == true)
      ? widget.teacherId!
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
    for (final c in _pointCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await QuizAdminService.getQuizResults(
          quizId: widget.quizId, teacherId: _teacherId, tenantId: _tenantId);
      List<Map<String, dynamic>> pending = const [];
      if ((_tenantId ?? '').isNotEmpty) {
        pending = await QuizAdminService.getPendingGrading(
            tenantId: _tenantId!, teacherId: _teacherId);
      }
      for (final c in _pointCtrls.values) {
        c.dispose();
      }
      _pointCtrls.clear();
      for (final p in pending) {
        _pointCtrls[p['answer_id'].toString()] = TextEditingController();
      }
      if (!mounted) return;
      setState(() {
        _results = results;
        _pending = pending;
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

  Future<void> _grade(Map<String, dynamic> item) async {
    final id = item['answer_id'].toString();
    final max = (item['max_points'] as num?)?.toInt() ?? 0;
    final txt = _pointCtrls[id]?.text.trim() ?? '';
    final pts = int.tryParse(txt);
    if (pts == null || pts < 0 || (max > 0 && pts > max)) {
      _toast('Enter points between 0 and $max', AppTheme.error);
      return;
    }
    try {
      await QuizAdminService.gradeAnswer(
          answerId: id, pointsAwarded: pts, teacherId: _teacherId, tenantId: _tenantId);
      _toast('Graded', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final ready = await QuizAdminService.getReadyToPublish(
          teacherId: _teacherId, tenantId: _tenantId);
      final ids = ready
          .map((r) => (r['attempt_id'] ?? r['id'])?.toString())
          .whereType<String>()
          .toList();
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() => _publishing = false);
        _toast('Nothing ready to publish yet (finish grading first)', AppTheme.greenPrimary);
        return;
      }
      await QuizAdminService.publishResults(
          attemptIds: ids, teacherId: _teacherId, tenantId: _tenantId);
      if (!mounted) return;
      setState(() => _publishing = false);
      _toast('Published ${ids.length} result(s) to students', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
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

  void _back() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.teacherQuizzesRoute, queryParameters: qp).toString());
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          icon: Icons.leaderboard_outlined,
          title: widget.quizTitle,
          subtitle: 'Quiz results',
          leading: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _back,
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
          trailing: SizedBox(
            height: 44,
            child: SaPrimaryButton(
              label: 'Publish',
              icon: Icons.publish_outlined,
              busy: _publishing,
              onPressed: _publishing ? null : _publish,
            ),
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading results…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: TabBar(
            controller: _tab,
            labelColor: AppTheme.greenPrimary,
            unselectedLabelColor: AppTheme.neutral500,
            indicatorColor: AppTheme.greenPrimary,
            labelStyle: Sa.value,
            tabs: [
              Tab(text: 'Results (${_results.length})'),
              Tab(text: 'To grade (${_pending.length})'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_resultsList(), _gradeList()],
          ),
        ),
      ],
    );
  }

  Widget _resultsList() {
    if (_results.isEmpty) {
      return const SaStateView(
        icon: Icons.people_outline,
        title: 'No attempts yet',
        subtitle: 'Student results will appear here once they attempt the quiz.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _resultCard(_results[i]),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final name = ('${r['first_name'] ?? ''} ${r['last_name'] ?? ''}').trim();
    final display = name.isEmpty ? (r['student_name'] ?? 'Student').toString() : name;
    final score = r['total_score'];
    final maxScore = r['max_score'];
    final pctRaw = r['percentage'];
    final pct = pctRaw is num ? pctRaw.round() : null;
    final submitted = r['is_submitted'] == true;
    return SaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.green50,
              child: Text(display.isNotEmpty ? display[0].toUpperCase() : '?',
                  style: Sa.value.copyWith(color: AppTheme.greenPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(display,
                      style: Sa.cardTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (score != null && maxScore != null)
                    Text('$score / $maxScore points', style: Sa.label),
                  if (!submitted)
                    Text('In progress',
                        style: Sa.label.copyWith(color: AppTheme.neutral600)),
                ],
              ),
            ),
            if (pct != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppTheme.greenPrimary.withValues(alpha: 0.12),
                    borderRadius: AppTheme.borderRadius8),
                child: Text('$pct%',
                    style: Sa.value.copyWith(
                        color: AppTheme.greenPrimary, fontWeight: FontWeight.w800)),
              ),
          ]),
          if (pct != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: AppTheme.borderRadius8,
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppTheme.neutral200,
                valueColor: const AlwaysStoppedAnimation(AppTheme.greenPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradeList() {
    if (_pending.isEmpty) {
      return const SaStateView(
        icon: Icons.task_alt,
        title: 'Nothing to grade',
        subtitle: 'Short answers are all marked.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      itemCount: _pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _gradeCard(_pending[i]),
    );
  }

  Widget _gradeCard(Map<String, dynamic> p) {
    final id = p['answer_id'].toString();
    final name = ('${p['first_name'] ?? ''} ${p['last_name'] ?? ''}').trim();
    final question = (p['question_text'] ?? '').toString();
    final answer = (p['student_answer'] ?? '').toString();
    final max = (p['max_points'] as num?)?.toInt() ?? 0;
    final quizTitle = (p['quiz_title'] ?? '').toString();
    return SaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name.isEmpty ? 'Student' : name,
                  style: Sa.cardTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (quizTitle.isNotEmpty) ...[
              const SizedBox(width: Sa.gapXs),
              Flexible(
                child: Text(quizTitle,
                    style: Sa.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text(question, style: Sa.value),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: AppTheme.neutral50, borderRadius: AppTheme.borderRadius8),
            child: Text(answer.isEmpty ? '(no answer)' : answer, style: Sa.body),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final field = SizedBox(
              width: 120,
              child: TextField(
                controller: _pointCtrls[id],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Points', suffixText: '/$max', isDense: true),
              ),
            );
            final saveBtn = SaPrimaryButton(
              label: 'Save',
              icon: Icons.check_rounded,
              onPressed: () => _grade(p),
            );
            if (c.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field,
                  const SizedBox(height: Sa.gap),
                  saveBtn,
                ],
              );
            }
            return Row(children: [
              field,
              const Spacer(),
              saveBtn,
            ]);
          }),
        ],
      ),
    );
  }
}
