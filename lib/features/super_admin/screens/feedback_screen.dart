// lib/features/super_admin/screens/feedback_screen.dart
//
// Super-admin feedback inbox: everything users submit, with status filter and
// triage (mark reviewed / resolved, delete). Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/feedback_service.dart';
import '../widgets/super_admin_action_bar.dart';
import '../widgets/super_admin_header.dart';

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
      _toast('Marked $status', AppTheme.success);
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
      _toast('Deleted', AppTheme.success);
      _load();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SuperAdminHeader(
          title: 'Feedback',
          subtitle: 'What your users are saying',
          icon: Icons.feedback,
        ),
        const SizedBox(height: 12),
        SuperAdminActionBar(
          actions: [
            SaActionButton(
              icon: Icons.refresh,
              label: 'Refresh',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _filters(),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ],
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
      children: chips.map((c) {
        final sel = _filter == c.key;
        return ChoiceChip(
          label: Text(c.value),
          selected: sel,
          showCheckmark: false,
          selectedColor: AppTheme.greenPrimary,
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
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text(_filter.isEmpty ? 'No feedback yet' : 'No $_filter feedback',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _card(_items[i]),
      ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.green50, borderRadius: AppTheme.borderRadius12),
              child: Icon(meta.value, color: AppTheme.greenPrimary, size: AppTheme.iconMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isEmpty ? meta.key : title,
                      style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _tag(meta.key),
                    if (rating > 0) _stars(rating),
                  ]),
                ],
              ),
            ),
            _statusBadge(fStatus),
          ]),
          const SizedBox(height: 10),
          Text(message, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.person_outline, size: AppTheme.iconSmall, color: AppTheme.neutral400),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                [
                  if (who.isNotEmpty) who,
                  if (role.isNotEmpty) _roleLabel(role),
                  if (phone.isNotEmpty) phone,
                ].join(' · '),
                style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (created.isNotEmpty)
              Text(created.split('T').first,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400)),
          ]),
          const Divider(height: 18),
          Row(children: [
            if (fStatus != 'reviewed' && fStatus != 'resolved')
              TextButton.icon(
                onPressed: () => _setStatus(f, 'reviewed'),
                icon: const Icon(Icons.visibility, size: AppTheme.iconSmall, color: AppTheme.info),
                label: const Text('Mark reviewed'),
              ),
            if (fStatus != 'resolved')
              TextButton.icon(
                onPressed: () => _setStatus(f, 'resolved'),
                icon: const Icon(Icons.check_circle, size: AppTheme.iconSmall, color: AppTheme.success),
                label: const Text('Resolve'),
              ),
            if (fStatus == 'resolved')
              TextButton.icon(
                onPressed: () => _setStatus(f, 'pending'),
                icon: const Icon(Icons.undo, size: AppTheme.iconSmall, color: AppTheme.warning),
                label: const Text('Reopen'),
              ),
            const Spacer(),
            IconButton(
              onPressed: () => _delete(f),
              icon: const Icon(Icons.delete_outline, size: AppTheme.iconMedium),
              color: AppTheme.error,
              tooltip: 'Delete',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      return Icon(i < rating ? Icons.star : Icons.star_border,
          size: 14, color: AppTheme.warning);
    }));
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppTheme.green50, borderRadius: AppTheme.borderRadius8),
      child: Text(text,
          style: AppTheme.bodyMicro.copyWith(
              color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(String s) {
    Color c;
    switch (s) {
      case 'resolved':
        c = AppTheme.success;
        break;
      case 'reviewed':
        c = AppTheme.info;
        break;
      default:
        c = AppTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
      child: Text(s[0].toUpperCase() + s.substring(1),
          style: AppTheme.bodyMicro.copyWith(color: c, fontWeight: FontWeight.w700)),
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
