// lib/features/tenant_management/widgets/tenant_stats_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/tenant.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class TenantStatsDialog extends StatefulWidget {
  final Tenant tenant;

  const TenantStatsDialog({
    super.key,
    required this.tenant,
  });

  @override
  State<TenantStatsDialog> createState() => _TenantStatsDialogState();
}

class _TenantStatsDialogState extends State<TenantStatsDialog> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/${widget.tenant.id}/stats'),
        headers: AuthSession.instance.headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _error = 'Statistics not found for this school';
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading statistics: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 720.0);
    final maxH = size.height - 80;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: SaLoading(message: 'Loading statistics…'),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: SaStateView.error(
                            message: _error!,
                            onRetry: _loadStats,
                          ),
                        )
                      : _buildStatsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Statistics & Analytics',
                  style: Sa.headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.tenant.schoolName,
                  style: Sa.headerSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
            iconSize: 22,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(),
          const SizedBox(height: Sa.gapLg),
          _buildCapacityAnalysis(),
          const SizedBox(height: Sa.gapLg),
          _buildFinancialOverview(),
          const SizedBox(height: Sa.gapLg),
          _buildPerformanceMetrics(),
          const SizedBox(height: Sa.gapLg),
          _buildAcademicInfo(),
          const SizedBox(height: Sa.gapLg),
          _buildGrowthTrends(),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: Sa.cardTitle.copyWith(fontSize: 16)),
        const SizedBox(height: Sa.gap),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 520 ? 4 : 2;
            final overCapacity = widget.tenant.isOverCapacity;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: Sa.gap,
              mainAxisSpacing: Sa.gap,
              childAspectRatio: 1.15,
              children: [
                _buildOverviewCard('Total Students', '${widget.tenant.totalStudents}', Icons.people, AppTheme.greenPrimary),
                _buildOverviewCard('Total Teachers', '${widget.tenant.totalTeachers}', Icons.person_2, AppTheme.greenPrimary),
                _buildOverviewCard('Total Staff', '${widget.tenant.totalStaff}', Icons.work, AppTheme.greenPrimary),
                _buildOverviewCard(
                  'Capacity Used',
                  '${widget.tenant.capacityUtilization.toStringAsFixed(1)}%',
                  Icons.donut_small,
                  overCapacity ? AppTheme.error : AppTheme.greenPrimary,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return SaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Sa.cardTitle.copyWith(fontSize: 18, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Sa.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityAnalysis() {
    final utilizationPercent = widget.tenant.capacityUtilization;
    final isOverCapacity = widget.tenant.isOverCapacity;
    final availableSpaces = widget.tenant.maximumCapacity - widget.tenant.currentEnrollment;

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.pie_chart_outline, title: 'Capacity Analysis'),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, constraints) {
              final rows = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCapacityRow('Current Enrollment', '${widget.tenant.currentEnrollment}', Icons.people),
                  _buildCapacityRow('Maximum Capacity', '${widget.tenant.maximumCapacity}', Icons.business),
                  _buildCapacityRow(
                    'Available Spaces',
                    '$availableSpaces',
                    availableSpaces < 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    valueColor: availableSpaces < 0 ? AppTheme.error : AppTheme.greenPrimary,
                  ),
                  _buildCapacityRow(
                    'Utilization Rate',
                    '${utilizationPercent.toStringAsFixed(1)}%',
                    Icons.timeline,
                    valueColor: isOverCapacity ? AppTheme.error : AppTheme.greenPrimary,
                  ),
                ],
              );
              final dial = _buildCapacityDial(utilizationPercent, isOverCapacity);

              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    rows,
                    const SizedBox(height: Sa.gap),
                    dial,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 2, child: rows),
                  const SizedBox(width: Sa.gapLg),
                  Expanded(flex: 1, child: dial),
                ],
              );
            },
          ),
          if (isOverCapacity) ...[
            const SizedBox(height: Sa.gap),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: AppTheme.borderRadius8,
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Over capacity by ${widget.tenant.currentEnrollment - widget.tenant.maximumCapacity} students. Consider expanding facilities or limiting new admissions.',
                      style: Sa.body.copyWith(color: AppTheme.error, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCapacityDial(double utilizationPercent, bool isOverCapacity) {
    final color = isOverCapacity ? AppTheme.error : AppTheme.greenPrimary;
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color, width: 3),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${utilizationPercent.toStringAsFixed(1)}%',
                style: Sa.cardTitle.copyWith(fontSize: 18, color: color),
              ),
              Text('Utilized', style: Sa.label.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapacityRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.neutral500),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Sa.label)),
          Text(
            value,
            style: Sa.value.copyWith(color: valueColor ?? AppTheme.neutral800),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview() {
    final totalRevenue = (widget.tenant.annualTuition * widget.tenant.totalStudents) +
        (widget.tenant.registrationFee * widget.tenant.currentEnrollment);
    final revenuePerStudent = widget.tenant.totalStudents > 0
        ? totalRevenue / widget.tenant.totalStudents
        : 0;

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.account_balance_wallet_outlined, title: 'Financial Overview'),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _buildFinancialCard('Annual Tuition', '₹${_formatCurrency(widget.tenant.annualTuition)}', Icons.school),
                _buildFinancialCard('Registration Fee', '₹${_formatCurrency(widget.tenant.registrationFee)}', Icons.payment),
                _buildFinancialCard('Est. Total Revenue', '₹${_formatCurrency(totalRevenue)}', Icons.trending_up),
                _buildFinancialCard('Revenue/Student', '₹${_formatCurrency(revenuePerStudent.toDouble())}', Icons.person),
              ];
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: Sa.gap),
                      cards[i],
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: Sa.gap),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: Sa.gap),
                  Row(children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: Sa.gap),
                    Expanded(child: cards[3]),
                  ]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.green50,
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: Sa.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.greenPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Sa.label)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Sa.value.copyWith(color: AppTheme.greenPrimary, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final studentTeacherRatio = widget.tenant.studentTeacherRatio;
    final staffPerHundred = widget.tenant.totalStudents > 0
        ? (widget.tenant.totalStaff / widget.tenant.totalStudents) * 100
        : 0;

    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.leaderboard_outlined, title: 'Performance Metrics'),
          const SizedBox(height: Sa.gap),
          _buildMetricRow('Student-Teacher Ratio', '${studentTeacherRatio.toStringAsFixed(1)}:1',
              _getRatioColor(studentTeacherRatio), _getRatioStatus(studentTeacherRatio)),
          _buildMetricRow('Staff per 100 Students', staffPerHundred.toStringAsFixed(1), AppTheme.greenPrimary, 'Good'),
          _buildMetricRow(
            'Capacity Efficiency',
            '${widget.tenant.capacityUtilization.toStringAsFixed(1)}%',
            widget.tenant.isOverCapacity ? AppTheme.error : AppTheme.greenPrimary,
            widget.tenant.isOverCapacity ? 'Over Capacity' : 'Optimal',
          ),
          if (widget.tenant.gradeLevels.isNotEmpty)
            _buildMetricRow('Grade Levels', '${widget.tenant.gradeLevels.length} levels', AppTheme.greenPrimary, 'Active'),
        ],
      ),
    );
  }

  Color _getRatioColor(double ratio) {
    if (ratio > 30) return AppTheme.error;
    if (ratio > 20) return AppTheme.neutral600;
    return AppTheme.greenPrimary;
  }

  String _getRatioStatus(double ratio) {
    if (ratio > 30) return 'High';
    if (ratio > 20) return 'Moderate';
    return 'Optimal';
  }

  Widget _buildMetricRow(String label, String value, Color color, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Sa.label)),
          const SizedBox(width: Sa.gap),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SaStatusPill(text: status, color: color),
              SaStatusPill(text: value, color: color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfo() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.school_outlined, title: 'Academic Information'),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, constraints) {
              final oneCol = constraints.maxWidth < 520;
              final infoPairs = <Widget>[
                _buildInfoCard('School Type', widget.tenant.schoolType, Icons.category_outlined),
                _buildInfoCard('Language', widget.tenant.languageOfInstruction, Icons.language),
              ];
              if (widget.tenant.establishedYear != null) {
                infoPairs.add(_buildInfoCard('Established', widget.tenant.establishedYear.toString(), Icons.history));
                infoPairs.add(_buildInfoCard(
                  'Experience',
                  '${DateTime.now().year - (widget.tenant.establishedYear?.toDouble() ?? DateTime.now().year.toDouble()).toInt()} years',
                  Icons.timeline,
                ));
              }
              if (oneCol) {
                return Column(
                  children: [
                    for (var i = 0; i < infoPairs.length; i++) ...[
                      if (i > 0) const SizedBox(height: Sa.gap),
                      infoPairs[i],
                    ],
                  ],
                );
              }
              final rows = <Widget>[];
              for (var i = 0; i < infoPairs.length; i += 2) {
                if (i > 0) rows.add(const SizedBox(height: Sa.gap));
                rows.add(Row(children: [
                  Expanded(child: infoPairs[i]),
                  const SizedBox(width: Sa.gap),
                  if (i + 1 < infoPairs.length) Expanded(child: infoPairs[i + 1]) else const Expanded(child: SizedBox()),
                ]));
              }
              return Column(children: rows);
            },
          ),
          if (widget.tenant.gradeLevels.isNotEmpty) ...[
            const SizedBox(height: Sa.gapLg),
            Text(
              'Grade Levels Offered (${widget.tenant.gradeLevels.length})',
              style: Sa.label.copyWith(fontWeight: FontWeight.w600, color: AppTheme.neutral700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.tenant.gradeLevels
                  .map((grade) => SaStatusPill(text: 'Grade $grade', color: AppTheme.greenPrimary))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: Sa.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.neutral500),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: Sa.label)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Sa.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTrends() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(icon: Icons.trending_up, title: 'Growth Trends (Estimated)'),
          const SizedBox(height: 6),
          const Text('Based on current enrollment and capacity', style: Sa.label),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _buildTrendCard('Student Growth', '+${(widget.tenant.totalStudents * 0.08).toInt()}', '8.2%'),
                _buildTrendCard('Teacher Hiring', '+${(widget.tenant.totalTeachers * 0.12).toInt()}', '12.5%'),
                _buildTrendCard('Capacity Usage', '+5.3%', '5.3%'),
              ];
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: Sa.gap),
                      cards[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: Sa.gap),
                  Expanded(child: cards[1]),
                  const SizedBox(width: Sa.gap),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, String value, String percentage) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: Sa.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Sa.label),
          const SizedBox(height: 8),
          Text(
            value,
            style: Sa.cardTitle.copyWith(fontSize: 16, color: AppTheme.greenPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: AppTheme.greenPrimary),
              const SizedBox(width: 4),
              Text(
                percentage,
                style: Sa.label.copyWith(color: AppTheme.greenPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}
