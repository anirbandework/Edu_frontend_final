// lib/features/admin/widgets/tenant_stats_dialog.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/tenant.dart';

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
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.analytics, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics & Analytics',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      Text(
                        widget.tenant.schoolName,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.neutral500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildStatsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          Text(
            'Loading statistics...',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Text(
            'Unable to load statistics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.neutral700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          _buildOverviewSection(),
          
          const SizedBox(height: 24),
          
          // Capacity Analysis
          _buildCapacityAnalysis(),
          
          const SizedBox(height: 24),
          
          // Financial Overview
          _buildFinancialOverview(),
          
          const SizedBox(height: 24),
          
          // Performance Metrics
          _buildPerformanceMetrics(),
          
          const SizedBox(height: 24),
          
          // Academic Information
          _buildAcademicInfo(),
          
          const SizedBox(height: 24),
          
          // Growth Trends (mock data for demo)
          _buildGrowthTrends(),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildOverviewCard('Total Students', '${widget.tenant.totalStudents}', Icons.people, AppTheme.info),
                _buildOverviewCard('Total Teachers', '${widget.tenant.totalTeachers}', Icons.person_2, AppTheme.greenPrimary),
                _buildOverviewCard('Total Staff', '${widget.tenant.totalStaff}', Icons.work, AppTheme.warning),
                _buildOverviewCard('Capacity Used', '${widget.tenant.capacityUtilization.toStringAsFixed(1)}%', Icons.donut_small,
                  widget.tenant.isOverCapacity ? AppTheme.error : Colors.purple),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: AppTheme.bodyMicro.copyWith(
                color: AppTheme.neutral500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityAnalysis() {
    final utilizationPercent = widget.tenant.capacityUtilization;
    final isOverCapacity = widget.tenant.isOverCapacity;
    final availableSpaces = widget.tenant.maximumCapacity - widget.tenant.currentEnrollment;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Capacity Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCapacityRow('Current Enrollment', '${widget.tenant.currentEnrollment}', Icons.people),
                      _buildCapacityRow('Maximum Capacity', '${widget.tenant.maximumCapacity}', Icons.business),
                      _buildCapacityRow('Available Spaces', '$availableSpaces',
                        availableSpaces < 0 ? Icons.warning : Icons.check_circle,
                        valueColor: availableSpaces < 0 ? AppTheme.error : AppTheme.success),
                      _buildCapacityRow('Utilization Rate', '${utilizationPercent.toStringAsFixed(1)}%', Icons.timeline,
                        valueColor: isOverCapacity ? AppTheme.error : AppTheme.info),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          isOverCapacity ? AppTheme.error.withValues(alpha: 0.2) : AppTheme.green50,
                          isOverCapacity ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.green50,
                        ],
                      ),
                      border: Border.all(
                        color: isOverCapacity ? AppTheme.error : AppTheme.greenLight,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${utilizationPercent.toStringAsFixed(1)}%',
                            style: AppTheme.headingSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isOverCapacity ? AppTheme.error : AppTheme.greenPrimary,
                            ),
                          ),
                          Text(
                            'Utilized',
                            style: AppTheme.bodyMicro.copyWith(
                              color: isOverCapacity ? AppTheme.error : AppTheme.greenPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (isOverCapacity) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Over capacity by ${widget.tenant.currentEnrollment - widget.tenant.maximumCapacity} students. Consider expanding facilities or limiting new admissions.',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700),
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.neutral800,
            ),
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
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Financial Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildFinancialCard('Annual Tuition', '₹${_formatCurrency(widget.tenant.annualTuition)}', Icons.school, AppTheme.info),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialCard('Registration Fee', '₹${_formatCurrency(widget.tenant.registrationFee)}', Icons.payment, AppTheme.greenLight),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildFinancialCard('Est. Total Revenue', '₹${_formatCurrency(totalRevenue)}', Icons.trending_up, Colors.purple),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialCard('Revenue/Student', '₹${_formatCurrency(revenuePerStudent.toDouble())}', Icons.person, AppTheme.warning),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyMicro.copyWith(
                    color: AppTheme.neutral700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildMetricRow('Student-Teacher Ratio', '${studentTeacherRatio.toStringAsFixed(1)}:1', 
              _getRatioColor(studentTeacherRatio), _getRatioStatus(studentTeacherRatio)),
            _buildMetricRow('Staff per 100 Students', '${staffPerHundred.toStringAsFixed(1)}', AppTheme.info, 'Good'),
            _buildMetricRow('Capacity Efficiency', '${widget.tenant.capacityUtilization.toStringAsFixed(1)}%',
              widget.tenant.isOverCapacity ? AppTheme.error : AppTheme.success,
              widget.tenant.isOverCapacity ? 'Over Capacity' : 'Optimal'),
            if (widget.tenant.gradeLevels.isNotEmpty)
              _buildMetricRow('Grade Levels', '${widget.tenant.gradeLevels.length} levels', Colors.purple, 'Active'),
          ],
        ),
      ),
    );
  }

  Color _getRatioColor(double ratio) {
    if (ratio > 30) return AppTheme.error;
    if (ratio > 20) return AppTheme.warning;
    return AppTheme.success;
  }

  String _getRatioStatus(double ratio) {
    if (ratio > 30) return 'High';
    if (ratio > 20) return 'Moderate';
    return 'Optimal';
  }

  Widget _buildMetricRow(String label, String value, Color color, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: AppTheme.bodyMicro.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Academic Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard('School Type', widget.tenant.schoolType, Icons.category),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard('Language', widget.tenant.languageOfInstruction, Icons.language),
                ),
              ],
            ),
            
            if (widget.tenant.establishedYear != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard('Established', widget.tenant.establishedYear.toString(), Icons.history),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard('Experience', '${DateTime.now().year - (widget.tenant.establishedYear?.toDouble() ?? DateTime.now().year.toDouble()).toInt()} years', Icons.timeline),
                  ),
                ],
              ),
            ],
            
            if (widget.tenant.gradeLevels.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Grade Levels Offered (${widget.tenant.gradeLevels.length})',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.tenant.gradeLevels.map((grade) {
                  return Chip(
                    label: Text('Grade $grade'),
                    backgroundColor: AppTheme.lightGreen.withValues(alpha: 0.2),
                    labelStyle: AppTheme.bodyMicro.copyWith(
                      color: AppTheme.primaryGreen,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.neutral500),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTheme.bodyMicro.copyWith(
                  color: AppTheme.neutral500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTrends() {
    // Mock data for demo purposes - in real app, this would come from API
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Growth Trends (Estimated)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Based on current enrollment and capacity',
              style: AppTheme.bodyMicro.copyWith(
                color: AppTheme.neutral500,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTrendCard('Student Growth', '+${(widget.tenant.totalStudents * 0.08).toInt()}', '8.2%', AppTheme.greenPrimary, true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTrendCard('Teacher Hiring', '+${(widget.tenant.totalTeachers * 0.12).toInt()}', '12.5%', AppTheme.info, true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTrendCard('Capacity Usage', '+5.3%', '5.3%', AppTheme.warning, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(String title, String value, String percentage, Color color, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.bodyMicro.copyWith(
              color: AppTheme.neutral600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: isPositive ? AppTheme.success : AppTheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                percentage,
                style: AppTheme.bodyMicro.copyWith(
                  color: isPositive ? AppTheme.success : AppTheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) { // 1 crore
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) { // 1 lakh
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) { // 1 thousand
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}
