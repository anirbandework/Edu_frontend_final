// lib/features/admin/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/attendance_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';
import '../widgets/attendance_dialog/mark_attendance_dialog.dart';
import '../widgets/attendance_dialog/bulk_mark_dialog.dart';
import '../widgets/attendance_dialog/bulk_status_dialog.dart';
import '../widgets/attendance_dialog/bulk_approve_dialog.dart';
import '../widgets/attendance_dialog/class_by_date_dialog.dart';

class AttendanceScreen extends StatefulWidget {
  final AttendanceService service;
  final String tenantId;
  final String authorityUserId;
  const AttendanceScreen({super.key, required this.service, required this.tenantId, required this.authorityUserId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.service.getDashboard(tenantId: widget.tenantId);
      if (!mounted) return;
      setState(() => _dashboard = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Attendance',
          subtitle: 'Mark, review and approve attendance',
          icon: Icons.fact_check_outlined,
          trailing: SaHeaderAction(
            icon: Icons.check,
            tooltip: 'Mark attendance',
            onPressed: () => _openMarkDialog(context),
          ),
        ),
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Sa.gap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _actions(context),
        ),
        const SizedBox(height: Sa.gap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _tabs(context),
        ),
        const SizedBox(height: Sa.gap),
        Expanded(child: _tabViews(context)),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    // Quick bulk operations; Wrap so they never overflow on narrow phones.
    return Wrap(
      spacing: Sa.gapXs,
      runSpacing: Sa.gapXs,
      children: [
        _actionChip(
          label: 'Bulk Mark',
          icon: Icons.playlist_add,
          onTap: () => _openBulkMark(context),
        ),
        _actionChip(
          label: 'Bulk Status',
          icon: Icons.sync,
          onTap: () => _openBulkStatus(context),
        ),
        _actionChip(
          label: 'Approve Absences',
          icon: Icons.verified,
          onTap: () => _openBulkApprove(context),
        ),
      ],
    );
  }

  Widget _actionChip({required String label, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Sa.surface,
      borderRadius: AppTheme.borderRadius12,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius12,
        child: Ink(
          decoration: BoxDecoration(
            color: Sa.surface,
            borderRadius: AppTheme.borderRadius12,
            border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
            boxShadow: Sa.cardShadow,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Sa.accent),
                const SizedBox(width: 8),
                Text(label, style: Sa.value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Sa.surface,
        borderRadius: BorderRadius.circular(Sa.radius),
        border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
        boxShadow: Sa.cardShadow,
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.neutral600,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: Sa.value,
        unselectedLabelStyle: Sa.value,
        indicator: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.borderRadius12,
        ),
        tabs: const [Tab(text: 'Daily'), Tab(text: 'Period'), Tab(text: 'Analytics')],
      ),
    );
  }

  Widget _tabViews(BuildContext context) {
    return TabBarView(
      controller: _tab,
      children: [
        _dailyTab(context),
        _periodTab(context),
        _analyticsTab(context),
      ],
    );
  }

  Widget _dailyTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
      children: [
        SaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SaCardHeader(
                icon: Icons.people_outline,
                title: 'Class attendance by date',
              ),
              const SizedBox(height: Sa.gap),
              const Text(
                'View and edit a class roster for a specific date.',
                style: Sa.body,
              ),
              const SizedBox(height: Sa.gapLg),
              SaPrimaryButton(
                label: 'Open class by date',
                icon: Icons.calendar_today_outlined,
                expand: true,
                onPressed: () => _openClassByDate(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
      children: [
        SaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SaCardHeader(
                icon: Icons.schedule_outlined,
                title: 'Period-wise attendance',
              ),
              const SizedBox(height: Sa.gap),
              const Text(
                'Period-wise operations live with the Mark dialog — set the period number when marking.',
                style: Sa.body,
              ),
              const SizedBox(height: Sa.gapLg),
              SaPrimaryButton(
                label: 'Mark attendance',
                icon: Icons.check,
                expand: true,
                onPressed: () => _openMarkDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _analyticsTab(BuildContext context) {
    if (_loading) return const SaLoading(message: 'Loading analytics…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _loadDashboard);
    if (_dashboard == null) {
      return const SaStateView(
        icon: Icons.bar_chart_outlined,
        title: 'No analytics yet',
        subtitle: 'Attendance stats will appear here once available.',
      );
    }
    final stats = _dashboard!['stats'] ?? _dashboard!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
      children: [
        _statTile(
          'Present',
          stats['present_count'] ?? stats['presentcount'],
          icon: Icons.check_circle_outline,
          color: AppTheme.greenPrimary,
        ),
        const SizedBox(height: Sa.gap),
        _statTile(
          'Absent',
          stats['absent_count'] ?? stats['absentcount'],
          icon: Icons.cancel_outlined,
          color: AppTheme.error,
        ),
        const SizedBox(height: Sa.gap),
        _statTile(
          'Late',
          stats['late_count'] ?? stats['latecount'],
          icon: Icons.access_time,
          color: AppTheme.neutral600,
        ),
        const SizedBox(height: Sa.gap),
        _statTile(
          'Average Rate',
          stats['average_attendance_rate'] ?? stats['averageattendancerate'],
          icon: Icons.insights_outlined,
          color: AppTheme.greenPrimary,
        ),
      ],
    );
  }

  Widget _statTile(String title, Object? value, {required IconData icon, required Color color}) {
    return SaCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Text(title, style: Sa.value, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Sa.gapXs),
          Text(
            '${value ?? '—'}',
            style: Sa.cardTitle.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _openMarkDialog(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => MarkAttendanceDialog(
        authorityId: widget.authorityUserId,
        service: widget.service,
      ),
    );
  }

  Future<void> _openBulkMark(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => BulkMarkDialog(
        tenantId: widget.tenantId,
        service: widget.service,
      ),
    );
  }

  Future<void> _openBulkStatus(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => BulkStatusDialog(service: widget.service),
    );
  }

  Future<void> _openBulkApprove(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => BulkApproveDialog(service: widget.service),
    );
  }

  Future<void> _openClassByDate(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => ClassByDateDialog(service: widget.service),
    );
  }
}
