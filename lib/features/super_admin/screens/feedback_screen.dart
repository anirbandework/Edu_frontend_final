// lib/features/super_admin/screens/feedback_screen.dart
//
// Super-admin feedback inbox: everything users submit, with status filter and
// triage (mark reviewed / resolved, delete). Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/feedback_service.dart';
import '../widgets/sa_widgets.dart';

const _typeMeta = <String, MapEntry<String, IconData>>{
  'suggestion': MapEntry('Suggestion', Icons.lightbulb_outline),
  'bug': MapEntry('Bug', Icons.bug_report_outlined),
  'complaint': MapEntry('Complaint', Icons.sentiment_dissatisfied_outlined),
  'appreciation': MapEntry('Appreciation', Icons.favorite_outline),
  'other': MapEntry('Other', Icons.chat_bubble_outline),
};

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {};
  String _filter = ''; // '', pending, reviewed, resolved

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
      final items = await FeedbackService.getAll(status: _filter.isEmpty ? null : _filter);
      Map<String, dynamic> stats = {};
      try {
        stats = await FeedbackService.getStats();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _stats = stats;
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

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Future<void> _setStatus(Map<String, dynamic> f, String status) async {
    try {
      await FeedbackService.setStatus(id: f['id'].toString(), status: status);
      _toast('Marked $status', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete feedback?'),
        content: Text('"${f['title'] ?? ''}" will be removed.'),
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
      await FeedbackService.delete(id: f['id'].toString());
      _toast('Deleted', AppTheme.greenPrimary);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Feedback',
          subtitle: 'What your users are saying',
          icon: Icons.feedback_outlined,
        ),
      ),
      child: _body(),
    );
  }

  Widget _filters() {
    final chips = [
      const MapEntry('', 'All'),
      MapEntry('pending', 'Pending (${_stats['pending'] ?? 0})'),
      MapEntry('reviewed', 'Reviewed (${_stats['reviewed'] ?? 0})'),
      MapEntry('resolved', 'Resolved (${_stats['resolved'] ?? 0})'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        final sel = _filter == c.key;
        return ChoiceChip(
          label: Text(c.value),
          selected: sel,
          showCheckmark: false,
          selectedColor: Sa.accent,
          backgroundColor: AppTheme.neutral100,
          labelStyle: AppTheme.bodySmall.copyWith(
              color: sel ? Colors.white : AppTheme.neutral700, fontWeight: FontWeight.w600),
          onSelected: (_) {
            setState(() => _filter = c.key);
            _load();
          },
        );
      }).toList(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SaLoading(message: 'Loading feedback…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      children: [
        _filters(),
        const SizedBox(height: Sa.gap),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: SaStateView(
              icon: Icons.inbox_outlined,
              title: _filter.isEmpty ? 'No feedback yet' : 'No $_filter feedback',
              subtitle: _filter.isEmpty
                  ? 'New submissions from your users will land here.'
                  : null,
            ),
          )
        else
          ..._items.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: Sa.gap),
                child: _card(f),
              )),
      ],
    );
  }

  Widget _card(Map<String, dynamic> f) {
    final type = (f['feedback_type'] ?? 'other').toString();
    final meta = _typeMeta[type] ?? const MapEntry('Other', Icons.chat_bubble_outline);
    final title = (f['title'] ?? '').toString();
    final message = (f['message'] ?? '').toString();
    final fStatus = (f['status'] ?? 'pending').toString();
    final rating = (f['rating'] is num) ? (f['rating'] as num).toInt() : 0;
    final who = (f['user_name'] ?? '').toString();
    final role = (f['user_type'] ?? '').toString();
    final phone = (f['user_phone'] ?? '').toString();
    final created = (f['created_at'] ?? '').toString();

    return SaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    color: AppTheme.green50, borderRadius: AppTheme.borderRadius12),
                child: Icon(meta.value, color: Sa.accent, size: AppTheme.iconMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? meta.key : title,
                        style: Sa.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _statusPill(fStatus),
                        SaStatusPill(
                          text: meta.key,
                          color: Sa.accent,
                          icon: meta.value,
                        ),
                        if (rating > 0) _stars(rating),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: Sa.body),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline,
                      size: AppTheme.iconSmall, color: AppTheme.neutral400),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      [
                        if (who.isNotEmpty) who,
                        if (role.isNotEmpty) _roleLabel(role),
                        if (phone.isNotEmpty) phone,
                      ].join(' · '),
                      style: Sa.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (created.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule,
                        size: AppTheme.iconSmall, color: AppTheme.neutral400),
                    const SizedBox(width: 4),
                    Text(created.split('T').first, style: Sa.label),
                  ],
                ),
            ],
          ),
          const Divider(height: 22),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (fStatus != 'reviewed' && fStatus != 'resolved')
                TextButton.icon(
                  onPressed: () => _setStatus(f, 'reviewed'),
                  icon: const Icon(Icons.visibility,
                      size: AppTheme.iconSmall, color: AppTheme.neutral600),
                  label: const Text('Mark reviewed'),
                ),
              if (fStatus != 'resolved')
                TextButton.icon(
                  onPressed: () => _setStatus(f, 'resolved'),
                  icon: const Icon(Icons.check_circle,
                      size: AppTheme.iconSmall, color: AppTheme.greenPrimary),
                  label: const Text('Resolve'),
                ),
              if (fStatus == 'resolved')
                TextButton.icon(
                  onPressed: () => _setStatus(f, 'pending'),
                  icon: const Icon(Icons.undo,
                      size: AppTheme.iconSmall, color: AppTheme.neutral600),
                  label: const Text('Reopen'),
                ),
              IconButton(
                onPressed: () => _delete(f),
                icon: const Icon(Icons.delete_outline, size: AppTheme.iconMedium),
                color: AppTheme.error,
                tooltip: 'Delete',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      return Icon(i < rating ? Icons.star : Icons.star_border,
          size: 14, color: AppTheme.greenPrimary);
    }));
  }

  Widget _statusPill(String s) {
    Color c;
    IconData icon;
    switch (s) {
      case 'resolved':
        c = AppTheme.greenPrimary;
        icon = Icons.check_circle_outline;
        break;
      case 'reviewed':
        c = AppTheme.neutral500;
        icon = Icons.visibility_outlined;
        break;
      default:
        c = AppTheme.neutral400;
        icon = Icons.schedule;
    }
    return SaStatusPill(
      text: s[0].toUpperCase() + s.substring(1),
      color: c,
      icon: icon,
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'school_authority':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role.isEmpty ? '' : role[0].toUpperCase() + role.substring(1);
    }
  }
}
