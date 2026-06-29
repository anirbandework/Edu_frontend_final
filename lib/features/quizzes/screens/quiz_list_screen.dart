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
import '../../super_admin/widgets/sa_widgets.dart';

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
      _toast(active ? 'Quiz hidden from students' : 'Quiz published to students',
          AppTheme.greenPrimary);
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
      _toast('Quiz deleted', AppTheme.greenPrimary);
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
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'My Quizzes',
          subtitle: _loading ? 'Loading…' : '${_quizzes.length} quizzes',
          icon: Icons.quiz_outlined,
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'New quiz',
            onPressed: _newQuiz,
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    if (_quizzes.isEmpty) {
      return SaStateView(
        icon: Icons.quiz_outlined,
        title: 'No quizzes yet',
        subtitle: 'Create your first quiz to get started.',
        action: SaPrimaryButton(
          label: 'Create your first quiz',
          icon: Icons.add,
          onPressed: _newQuiz,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
      itemCount: _quizzes.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _quizCard(_quizzes[i]),
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
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.borderRadius12),
              child:
                  const Icon(Icons.quiz, color: Colors.white, size: AppTheme.iconMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Sa.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subject.isNotEmpty)
                    Text(subject,
                        style: Sa.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: Sa.gapXs),
            _statusChip(active),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 8, children: [
            if (totalQ != null) _meta(Icons.help_outline, '$totalQ Qs'),
            if (points != null) _meta(Icons.star_outline, '$points pts'),
            if (time != null) _meta(Icons.timer_outlined, '$time min'),
          ]),
          const SizedBox(height: Sa.gap),
          Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton.icon(
              onPressed: busy ? null : () => _toggle(q),
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(active ? Icons.visibility_off : Icons.publish,
                      size: AppTheme.iconSmall,
                      color: active ? AppTheme.neutral500 : AppTheme.greenPrimary),
              label: Text(active ? 'Hide' : 'Publish'),
              style: TextButton.styleFrom(
                foregroundColor: active ? AppTheme.neutral600 : AppTheme.greenPrimary,
                minimumSize: const Size(0, 44),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openResults(q),
              icon: const Icon(Icons.bar_chart,
                  size: AppTheme.iconSmall, color: AppTheme.greenPrimary),
              label: const Text('Results'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.greenPrimary,
                minimumSize: const Size(0, 44),
              ),
            ),
            IconButton(
              onPressed: () => _delete(q),
              icon: const Icon(Icons.delete_outline, size: AppTheme.iconMedium),
              color: AppTheme.error,
              tooltip: 'Delete',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statusChip(bool active) {
    return SaStatusPill(
      text: active ? 'Live' : 'Draft',
      color: active ? AppTheme.greenPrimary : AppTheme.neutral400,
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
