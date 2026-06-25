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
      _toast('Enter points between 0 and $max', AppTheme.warning);
      return;
    }
    try {
      await QuizAdminService.gradeAnswer(
          answerId: id, pointsAwarded: pts, teacherId: _teacherId, tenantId: _tenantId);
      _toast('Graded', AppTheme.success);
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
        _toast('Nothing ready to publish yet (finish grading first)', AppTheme.info);
        return;
      }
      await QuizAdminService.publishResults(
          attemptIds: ids, teacherId: _teacherId, tenantId: _tenantId);
      if (!mounted) return;
      setState(() => _publishing = false);
      _toast('Published ${ids.length} result(s) to students', AppTheme.success);
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
          Expanded(
            child: Text('Results · ${widget.quizTitle}',
                style: AppTheme.headingMedium,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ElevatedButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.publish, size: AppTheme.iconSmall),
            label: const Text('Publish'),
          ),
        ]),
        const SizedBox(height: 8),
        TabBar(
          controller: _tab,
          labelColor: AppTheme.greenPrimary,
          unselectedLabelColor: AppTheme.neutral500,
          indicatorColor: AppTheme.greenPrimary,
          tabs: [
            Tab(text: 'Results (${_results.length})'),
            Tab(text: 'To grade (${_pending.length})'),
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
    return TabBarView(controller: _tab, children: [_resultsList(), _gradeList()]);
  }

  Widget _resultsList() {
    if (_results.isEmpty) {
      return _empty(Icons.people_outline, 'No attempts yet');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _resultCard(_results[i]),
      ),
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
    final color = pct == null
        ? AppTheme.neutral400
        : (pct >= 60 ? AppTheme.success : (pct >= 40 ? AppTheme.warning : AppTheme.error));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.green50,
          child: Text(display.isNotEmpty ? display[0].toUpperCase() : '?',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.greenPrimary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(display,
                  style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (score != null && maxScore != null)
                Text('$score / $maxScore points',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
              if (!submitted)
                Text('In progress',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.warning)),
            ],
          ),
        ),
        if (pct != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
            child: Text('$pct%',
                style: AppTheme.labelLarge.copyWith(color: color, fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }

  Widget _gradeList() {
    if (_pending.isEmpty) {
      return _empty(Icons.task_alt, 'Nothing to grade — short answers are all marked');
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _gradeCard(_pending[i]),
      ),
    );
  }

  Widget _gradeCard(Map<String, dynamic> p) {
    final id = p['answer_id'].toString();
    final name = ('${p['first_name'] ?? ''} ${p['last_name'] ?? ''}').trim();
    final question = (p['question_text'] ?? '').toString();
    final answer = (p['student_answer'] ?? '').toString();
    final max = (p['max_points'] as num?)?.toInt() ?? 0;
    final quizTitle = (p['quiz_title'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name.isEmpty ? 'Student' : name,
                  style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (quizTitle.isNotEmpty)
              Text(quizTitle,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
          ]),
          const SizedBox(height: 8),
          Text(question, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.neutral50, borderRadius: AppTheme.borderRadius8),
            child: Text(answer.isEmpty ? '(no answer)' : answer,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: _pointCtrls[id],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Points', suffixText: '/$max', isDense: true),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _grade(p),
              icon: const Icon(Icons.check, size: AppTheme.iconSmall),
              label: const Text('Save'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String text) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppTheme.neutral400),
        const SizedBox(height: 12),
        Text(text,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
