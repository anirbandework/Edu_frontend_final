// lib/features/quizzes/screens/quiz_list_screen.dart
//
// A teacher's quizzes: create new ones, toggle availability to students, delete.
// Real backend (/assessment/quiz). AppTheme only.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/quiz_admin_service.dart';

class QuizListScreen extends StatefulWidget {
  final String? teacherId;
  final String? tenantId;
  const QuizListScreen({super.key, this.teacherId, this.tenantId});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _quizzes = [];

  String get _teacherId => (widget.teacherId?.isNotEmpty == true)
      ? widget.teacherId!
      : (AuthSession.instance.userId ?? '');
  String? get _tenantId => widget.tenantId ?? AuthSession.instance.tenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_teacherId.isEmpty) {
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
      final quizzes = await QuizAdminService.getTeacherQuizzes(
          teacherId: _teacherId, tenantId: _tenantId);
      if (!mounted) return;
      setState(() {
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

  void _newQuiz() {
    final qp = <String, String>{
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.teacherQuizBuilderRoute, queryParameters: qp).toString());
  }

  void _openResults(Map<String, dynamic> q) {
    final id = q['id']?.toString();
    if (id == null) return;
    final qp = <String, String>{
      'quizId': id,
      'title': (q['title'] ?? 'Quiz').toString(),
      if (AuthSession.instance.userId != null) 'userId': AuthSession.instance.userId!,
      if (_tenantId != null) 'tenantId': _tenantId!,
    };
    context.go(Uri(path: AppConstants.teacherQuizResultsRoute, queryParameters: qp).toString());
  }

  Future<void> _toggle(Map<String, dynamic> q) async {
    final id = q['id']?.toString();
    if (id == null) return;
    final active = q['is_active'] == true;
    setState(() => q['_busy'] = true);
    try {
      await QuizAdminService.setStatus(
          quizId: id, isActive: !active, teacherId: _teacherId, tenantId: _tenantId);
      _toast(active ? 'Quiz hidden from students' : 'Quiz published to students', AppTheme.success);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => q.remove('_busy'));
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _delete(Map<String, dynamic> q) async {
    final id = q['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: Text('"${q['title'] ?? 'This quiz'}" will be removed.'),
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
      await QuizAdminService.deleteQuiz(quizId: id, teacherId: _teacherId, tenantId: _tenantId);
      _toast('Quiz deleted', AppTheme.success);
      _load();
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Quizzes', style: AppTheme.headingMedium),
                Text(_loading ? 'Loading…' : '${_quizzes.length} quizzes',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _newQuiz,
            icon: const Icon(Icons.add, size: AppTheme.iconSmall),
            label: const Text('New Quiz'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            color: AppTheme.greenPrimary,
            tooltip: 'Refresh',
          ),
        ]),
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
    if (_quizzes.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.quiz_outlined, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No quizzes yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _newQuiz,
              icon: const Icon(Icons.add, size: AppTheme.iconSmall),
              label: const Text('Create your first quiz')),
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
            mainAxisExtent: 176,
          ),
          itemCount: _quizzes.length,
          itemBuilder: (context, i) => _quizCard(_quizzes[i]),
        );
      }),
    );
  }

  Widget _quizCard(Map<String, dynamic> q) {
    final title = (q['title'] ?? 'Quiz').toString();
    final subject = (q['subject'] ?? '').toString();
    final active = q['is_active'] == true;
    final busy = q['_busy'] == true;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subject.isNotEmpty)
                    Text(subject,
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                ],
              ),
            ),
            _statusChip(active),
          ]),
          const SizedBox(height: 10),
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
          const Spacer(),
          Row(children: [
            TextButton.icon(
              onPressed: busy ? null : () => _toggle(q),
              icon: busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(active ? Icons.visibility_off : Icons.publish,
                      size: AppTheme.iconSmall,
                      color: active ? AppTheme.warning : AppTheme.success),
              label: Text(active ? 'Hide' : 'Publish'),
            ),
            TextButton.icon(
              onPressed: () => _openResults(q),
              icon: const Icon(Icons.bar_chart, size: AppTheme.iconSmall, color: AppTheme.info),
              label: const Text('Results'),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _delete(q),
              icon: const Icon(Icons.delete_outline, size: AppTheme.iconMedium),
              color: AppTheme.error,
              tooltip: 'Delete',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statusChip(bool active) {
    final color = active ? AppTheme.success : AppTheme.neutral400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
      child: Text(active ? 'Live' : 'Draft',
          style: AppTheme.bodyMicro.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
      const SizedBox(width: 4),
      Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
    ]);
  }
}
