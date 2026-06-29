// lib/features/tenant_management/widgets/tenant_details_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/tenant.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class TenantDetailsDialog extends StatelessWidget {
  final Tenant tenant;

  const TenantDetailsDialog({
    super.key,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 520.0);
    final statusColor = tenant.isActive ? AppTheme.greenPrimary : AppTheme.error;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height - 64,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: Icon(
                      Icons.school,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.schoolName,
                          style: Sa.cardTitle.copyWith(fontSize: 17),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SaStatusPill(
                              text: tenant.statusText,
                              color: statusColor,
                              icon: tenant.isActive
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                            ),
                            Text(tenant.schoolType, style: Sa.label),
                            if (tenant.schoolCode != null)
                              SaStatusPill(
                                text: 'Code: ${tenant.schoolCode}',
                                color: AppTheme.neutral500,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppTheme.neutral600,
                    iconSize: 22,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.neutral200),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats
                    _buildStatsSection(context),

                    const SizedBox(height: Sa.gapLg),

                    // Basic Information
                    _buildSection(
                      'Basic Information',
                      Icons.info_outline,
                      [
                        _buildInfoRow(context, 'School ID', tenant.id,
                            copyable: true),
                        _buildInfoRow(context, 'School Name', tenant.schoolName),
                        _buildInfoRow(context, 'Address', tenant.address),
                        _buildInfoRow(context, 'Phone', tenant.phone,
                            copyable: true),
                        _buildInfoRow(context, 'Email', tenant.email,
                            copyable: true),
                        _buildInfoRow(
                            context, 'Principal', tenant.principalName),
                        _buildInfoRow(
                            context, 'School Type', tenant.schoolType),
                        _buildInfoRow(context, 'Language',
                            tenant.languageOfInstruction),
                      ],
                    ),

                    const SizedBox(height: Sa.gapLg),

                    // Academic Information
                    _buildSection(
                      'Academic Information',
                      Icons.school_outlined,
                      [
                        if (tenant.establishedYear != null)
                          _buildInfoRow(context, 'Established',
                              tenant.establishedYear.toString()),
                        if (tenant.accreditation != null)
                          _buildInfoRow(context, 'Accreditation',
                              tenant.accreditation!),
                        if (tenant.academicYearStart != null)
                          _buildInfoRow(context, 'Academic Year Start',
                              '${tenant.academicYearStart!.day}/${tenant.academicYearStart!.month}/${tenant.academicYearStart!.year}'),
                        if (tenant.academicYearEnd != null)
                          _buildInfoRow(context, 'Academic Year End',
                              '${tenant.academicYearEnd!.day}/${tenant.academicYearEnd!.month}/${tenant.academicYearEnd!.year}'),
                        if (tenant.gradeLevels.isNotEmpty)
                          _buildInfoRow(context, 'Grade Levels',
                              tenant.gradeLevels.join(', ')),
                      ],
                    ),

                    const SizedBox(height: Sa.gapLg),

                    // Capacity & Statistics
                    _buildSection(
                      'Capacity & Statistics',
                      Icons.analytics_outlined,
                      [
                        _buildInfoRow(context, 'Maximum Capacity',
                            '${tenant.maximumCapacity} students'),
                        _buildInfoRow(context, 'Current Enrollment',
                            '${tenant.currentEnrollment} students'),
                        _buildInfoRow(context, 'Total Students',
                            tenant.totalStudents.toString()),
                        _buildInfoRow(context, 'Total Teachers',
                            tenant.totalTeachers.toString()),
                        _buildInfoRow(context, 'Total Staff',
                            tenant.totalStaff.toString()),
                        _buildInfoRow(context, 'Student-Teacher Ratio',
                            '${tenant.studentTeacherRatio.toStringAsFixed(1)}:1'),
                        _buildInfoRow(
                          context,
                          'Capacity Utilization',
                          '${tenant.capacityUtilization.toStringAsFixed(1)}%',
                          valueColor:
                              tenant.isOverCapacity ? AppTheme.error : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: Sa.gapLg),

                    // Financial Information
                    _buildSection(
                      'Financial Information',
                      Icons.payments_outlined,
                      [
                        _buildInfoRow(context, 'Annual Tuition',
                            '₹${tenant.annualTuition.toStringAsFixed(0)}'),
                        _buildInfoRow(context, 'Registration Fee',
                            '₹${tenant.registrationFee.toStringAsFixed(0)}'),
                      ],
                    ),

                    const SizedBox(height: Sa.gapLg),

                    // System Information
                    _buildSection(
                      'System Information',
                      Icons.settings_outlined,
                      [
                        if (tenant.createdAt != null)
                          _buildInfoRow(context, 'Created',
                              '${tenant.createdAt!.day}/${tenant.createdAt!.month}/${tenant.createdAt!.year} at ${tenant.createdAt!.hour}:${tenant.createdAt!.minute.toString().padLeft(2, '0')}'),
                        if (tenant.updatedAt != null)
                          _buildInfoRow(context, 'Last Updated',
                              '${tenant.updatedAt!.day}/${tenant.updatedAt!.month}/${tenant.updatedAt!.year} at ${tenant.updatedAt!.hour}:${tenant.updatedAt!.minute.toString().padLeft(2, '0')}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.green50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Sa.radius),
        border: Border.all(color: AppTheme.greenLight.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Statistics',
            style: Sa.cardTitle.copyWith(color: AppTheme.greenPrimary),
          ),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, c) {
              final cards = <Widget>[
                _buildStatCard('Students', '${tenant.totalStudents}',
                    Icons.people_outline),
                _buildStatCard('Teachers', '${tenant.totalTeachers}',
                    Icons.person_2_outlined),
                _buildStatCard(
                    'Staff', '${tenant.totalStaff}', Icons.work_outline),
                _buildStatCard(
                  'Capacity',
                  '${tenant.capacityUtilization.toStringAsFixed(1)}%',
                  Icons.donut_small_outlined,
                  valueColor:
                      tenant.isOverCapacity ? AppTheme.error : AppTheme.greenPrimary,
                ),
              ];
              // 4-up on wide, 2-up on phones.
              final cols = c.maxWidth < 380 ? 2 : 4;
              return Wrap(
                spacing: Sa.gap,
                runSpacing: Sa.gap,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width:
                          (c.maxWidth - (cols - 1) * Sa.gap) / cols,
                      child: card,
                    ),
                ],
              );
            },
          ),
          if (tenant.isOverCapacity) ...[
            const SizedBox(height: Sa.gap),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.10),
                borderRadius: AppTheme.borderRadius8,
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'School is over capacity by ${tenant.currentEnrollment - tenant.maximumCapacity} students',
                      style: Sa.body.copyWith(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color valueColor = AppTheme.greenPrimary}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadius12,
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        children: [
          Icon(icon, color: valueColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Sa.value.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Sa.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return SaCard(
      padding: const EdgeInsets.all(16),
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

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {bool copyable = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Sa.label),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Sa.value.copyWith(
                      color: valueColor,
                      fontWeight:
                          valueColor != null ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: AppTheme.borderRadius8,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied to clipboard'),
                          backgroundColor: AppTheme.greenPrimary,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: AppTheme.neutral500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
