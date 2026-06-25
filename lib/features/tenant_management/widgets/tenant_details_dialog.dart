// lib/features/admin/widgets/tenant_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/tenant.dart';

class TenantDetailsDialog extends StatelessWidget {
  final Tenant tenant;

  const TenantDetailsDialog({
    super.key,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tenant.isActive
                        ? AppTheme.greenLight.withOpacity(0.2)
                        : AppTheme.neutral200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school,
                    color: tenant.isActive ? AppTheme.greenPrimary : AppTheme.neutral500,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.schoolName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: tenant.isActive ? AppTheme.green50 : AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tenant.statusText,
                              style: AppTheme.bodyMicro.copyWith(
                                color: tenant.isActive ? AppTheme.greenPrimary : AppTheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tenant.schoolType,
                            style: AppTheme.bodyMicro,
                          ),
                          if (tenant.schoolCode != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Code: ${tenant.schoolCode}',
                                style: AppTheme.bodyMicro.copyWith(
                                  color: AppTheme.info,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats
                    _buildStatsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Basic Information
                    _buildSection(
                      'Basic Information',
                      Icons.info,
                      [
                        _buildInfoRow('School ID', tenant.id, copyable: true),
                        _buildInfoRow('School Name', tenant.schoolName),
                        _buildInfoRow('Address', tenant.address),
                        _buildInfoRow('Phone', tenant.phone, copyable: true),
                        _buildInfoRow('Email', tenant.email, copyable: true),
                        _buildInfoRow('Principal', tenant.principalName),
                        _buildInfoRow('School Type', tenant.schoolType),
                        _buildInfoRow('Language', tenant.languageOfInstruction),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Academic Information
                    _buildSection(
                      'Academic Information',
                      Icons.school,
                      [
                        if (tenant.establishedYear != null)
                          _buildInfoRow('Established', tenant.establishedYear.toString()),
                        if (tenant.accreditation != null)
                          _buildInfoRow('Accreditation', tenant.accreditation!),
                        if (tenant.academicYearStart != null)
                          _buildInfoRow('Academic Year Start', 
                            '${tenant.academicYearStart!.day}/${tenant.academicYearStart!.month}/${tenant.academicYearStart!.year}'),
                        if (tenant.academicYearEnd != null)
                          _buildInfoRow('Academic Year End', 
                            '${tenant.academicYearEnd!.day}/${tenant.academicYearEnd!.month}/${tenant.academicYearEnd!.year}'),
                        if (tenant.gradeLevels.isNotEmpty)
                          _buildInfoRow('Grade Levels', tenant.gradeLevels.join(', ')),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Capacity & Statistics
                    _buildSection(
                      'Capacity & Statistics',
                      Icons.analytics,
                      [
                        _buildInfoRow('Maximum Capacity', '${tenant.maximumCapacity} students'),
                        _buildInfoRow('Current Enrollment', '${tenant.currentEnrollment} students'),
                        _buildInfoRow('Total Students', tenant.totalStudents.toString()),
                        _buildInfoRow('Total Teachers', tenant.totalTeachers.toString()),
                        _buildInfoRow('Total Staff', tenant.totalStaff.toString()),
                        _buildInfoRow('Student-Teacher Ratio', 
                          '${tenant.studentTeacherRatio.toStringAsFixed(1)}:1'),
                        _buildInfoRow('Capacity Utilization', 
                          '${tenant.capacityUtilization.toStringAsFixed(1)}%',
                          valueColor: tenant.isOverCapacity ? AppTheme.error : null),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Financial Information
                    _buildSection(
                      'Financial Information',
                      Icons.attach_money,
                      [
                        _buildInfoRow('Annual Tuition', '₹${tenant.annualTuition.toStringAsFixed(0)}'),
                        _buildInfoRow('Registration Fee', '₹${tenant.registrationFee.toStringAsFixed(0)}'),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // System Information
                    _buildSection(
                      'System Information',
                      Icons.settings,
                      [
                        if (tenant.createdAt != null)
                          _buildInfoRow('Created', 
                            '${tenant.createdAt!.day}/${tenant.createdAt!.month}/${tenant.createdAt!.year} at ${tenant.createdAt!.hour}:${tenant.createdAt!.minute.toString().padLeft(2, '0')}'),
                        if (tenant.updatedAt != null)
                          _buildInfoRow('Last Updated', 
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

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.lightGreen.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Statistics',
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Students', '${tenant.totalStudents}', Icons.people, AppTheme.info)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Teachers', '${tenant.totalTeachers}', Icons.person_2, AppTheme.greenPrimary)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Staff', '${tenant.totalStaff}', Icons.work, AppTheme.warning)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                'Capacity',
                '${tenant.capacityUtilization.toStringAsFixed(1)}%',
                Icons.donut_small,
                tenant.isOverCapacity ? AppTheme.error : Colors.purple
              )),
            ],
          ),
          if (tenant.isOverCapacity) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'School is over capacity by ${tenant.currentEnrollment - tenant.maximumCapacity} students',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neutral300),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.neutral50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral700,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? Colors.black87,
                      fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                        SnackBar(
                          content: Text('$label copied to clipboard'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: AppTheme.neutral600,
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

// Add this to your main.dart or wherever you initialize your app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
