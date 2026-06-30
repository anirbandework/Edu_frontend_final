// lib/features/super_admin/screens/analytics_screen.dart
//
// Super-admin platform analytics: headline KPIs (organisations/admins/students/
// teachers), active-vs-inactive ratios, capacity utilisation, organisation-type
// distribution, and top admins by organisation count. Real backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../services/super_admin_service.dart';
import '../../../shared/widgets/sa_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _admins = [];

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
      final stats = await SuperAdminService.getComprehensiveStats();
      List<Map<String, dynamic>> admins = const [];
      try {
        admins = await SuperAdminService.getAdmins();
      } catch (_) {/* per-admin breakdown is best-effort */}
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _admins = admins;
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

  int _i(String k) => (_stats[k] is num) ? (_stats[k] as num).toInt() : 0;
  num _n(String k) => (_stats[k] is num) ? _stats[k] as num : 0;

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Analytics',
          subtitle: 'Platform overview across all organisations',
          icon: Icons.insights,
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SaLoading(message: 'Loading analytics…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      children: [
        _kpiGrid(),
        const SizedBox(height: Sa.gapLg),
        _ratiosCard(),
        const SizedBox(height: Sa.gapLg),
        _capacityCard(),
        const SizedBox(height: Sa.gapLg),
        _distributionCard(),
        const SizedBox(height: Sa.gapLg),
        _topAdminsCard(),
      ],
    );
  }

  // ---- KPI cards ----
  Widget _kpiGrid() {
    final kpis = [
      _Kpi('Organisations', _i('total_organisations'), '${_i('active_organisations')} active',
          Icons.business, AppTheme.greenPrimary),
      _Kpi('Admins', _i('total_admins'), '${_i('active_admins')} active',
          Icons.admin_panel_settings, AppTheme.greenPrimary),
      _Kpi('Students', _i('total_students'), 'enrolled', Icons.apartment, AppTheme.greenPrimary),
      _Kpi('Teachers', _i('total_teachers'), 'platform-wide', Icons.person, AppTheme.greenPrimary),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 480 ? 2 : 1);
      return GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: cols == 1 ? 3.4 : 1.5,
        children: kpis.map(_kpiCard).toList(),
      );
    });
  }

  Widget _kpiCard(_Kpi k) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: k.color.withValues(alpha: 0.12), borderRadius: AppTheme.borderRadius12),
              child: Icon(k.icon, color: k.color, size: AppTheme.iconMedium),
            ),
            const Spacer(),
            Flexible(
              child: Text(_fmt(k.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.neutral900, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(k.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Sa.cardTitle),
          Text(k.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Sa.label),
        ],
      ),
    );
  }

  // ---- active / inactive ratios ----
  Widget _ratiosCard() {
    return _section('Active vs inactive', Icons.toggle_on, [
      _ratioRow('Organisations', _i('active_organisations'), _i('inactive_organisations'), AppTheme.greenPrimary),
      const SizedBox(height: 12),
      _ratioRow('Admins', _i('active_admins'), _i('inactive_admins'), AppTheme.greenPrimary),
    ]);
  }

  Widget _ratioRow(String label, int active, int inactive, Color color) {
    final total = active + inactive;
    final pct = total > 0 ? active / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: Sa.value)),
          Text('$active / $total  (${(pct * 100).round()}%)',
              style: Sa.label),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppTheme.borderRadius8,
          child: LinearProgressIndicator(
            value: pct.toDouble(),
            minHeight: 10,
            backgroundColor: AppTheme.neutral200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _legend('Active $active', color),
            _legend('Inactive $inactive', AppTheme.neutral400),
          ],
        ),
      ],
    );
  }

  Widget _legend(String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(text, style: Sa.label),
    ]);
  }

  // ---- capacity ----
  Widget _capacityCard() {
    final cap = _i('total_capacity');
    final students = _i('total_students');
    final util = (_n('capacity_utilization')).toDouble();
    final avgTuition = _n('average_tuition');
    return _section('Capacity & finance', Icons.donut_large, [
      LayoutBuilder(builder: (context, c) {
        final twoCol = c.maxWidth < 360;
        final itemW = twoCol
            ? (c.maxWidth - Sa.gap) / 2
            : (c.maxWidth - Sa.gap * 2) / 3;
        return Wrap(
          spacing: Sa.gap,
          runSpacing: Sa.gap,
          children: [
            SizedBox(width: itemW, child: _miniStat('Total capacity', _fmt(cap), Icons.event_seat)),
            SizedBox(width: itemW, child: _miniStat('Enrolled', _fmt(students), Icons.groups)),
            SizedBox(width: itemW, child: _miniStat('Avg tuition', '₹${_fmt(avgTuition.round())}', Icons.payments)),
          ],
        );
      }),
      const SizedBox(height: Sa.gap),
      Row(children: [
        const Expanded(
          child: Text('Capacity utilisation', style: Sa.value),
        ),
        Text('${util.round()}%',
            style: Sa.value.copyWith(
                color: AppTheme.greenPrimary, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: AppTheme.borderRadius8,
        child: LinearProgressIndicator(
          value: (util / 100).clamp(0, 1).toDouble(),
          minHeight: 10,
          backgroundColor: AppTheme.neutral200,
          valueColor: const AlwaysStoppedAnimation(AppTheme.greenPrimary),
        ),
      ),
    ]);
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Sa.cardTitle),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Sa.label),
      ],
    );
  }

  // ---- organisation-type distribution ----
  Widget _distributionCard() {
    final dist = (_stats['org_type_distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    if (dist.isEmpty) {
      return _section('Organisations by type', Icons.category, [
        const Text('No organisations yet', style: Sa.body),
      ]);
    }
    final entries = dist.entries.toList()
      ..sort((a, b) => ((b.value as num?) ?? 0).compareTo((a.value as num?) ?? 0));
    final maxV = entries.fold<int>(1, (m, e) => ((e.value as num?)?.toInt() ?? 0) > m ? (e.value as num).toInt() : m);
    return _section('Organisations by type', Icons.category,
        entries.map((e) => _barRow(e.key, (e.value as num?)?.toInt() ?? 0, maxV, AppTheme.greenPrimary)).toList());
  }

  // ---- top admins by organisation count ----
  Widget _topAdminsCard() {
    final admins = [..._admins]
      ..sort((a, b) => ((b['org_count'] as num?) ?? 0).compareTo((a['org_count'] as num?) ?? 0));
    final top = admins.take(6).where((a) => ((a['org_count'] as num?) ?? 0) > 0).toList();
    if (top.isEmpty) {
      return _section('Top admins by organisations', Icons.leaderboard, [
        const Text('No admin owns a organisation yet', style: Sa.body),
      ]);
    }
    final maxV = top.fold<int>(1, (m, a) => ((a['org_count'] as num?)?.toInt() ?? 0) > m ? (a['org_count'] as num).toInt() : m);
    return _section('Top admins by organisations', Icons.leaderboard, top.map((a) {
      final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
      return _barRow(name.isEmpty ? 'Admin' : name,
          (a['org_count'] as num?)?.toInt() ?? 0, maxV, AppTheme.greenPrimary);
    }).toList());
  }

  Widget _barRow(String label, int value, int maxV, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
          width: 104,
          child: Text(label,
              style: Sa.value,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: AppTheme.borderRadius8,
            child: LinearProgressIndicator(
              value: maxV > 0 ? (value / maxV).clamp(0, 1).toDouble() : 0,
              minHeight: 14,
              backgroundColor: AppTheme.neutral100,
              valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$value',
            style: Sa.value.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ---- shared section card ----
  Widget _section(String title, IconData icon, List<Widget> children) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(icon: icon, title: title),
          const SizedBox(height: Sa.gap),
          ...children,
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    if (n < 1000) return s;
    // thousands separators
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _Kpi {
  final String label;
  final int value;
  final String sub;
  final IconData icon;
  final Color color;
  _Kpi(this.label, this.value, this.sub, this.icon, this.color);
}
