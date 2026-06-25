// lib/features/school_authority/widgets/student_details_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/student.dart';

class StudentDetailsDialog extends StatelessWidget {
  final Student student;

  const StudentDetailsDialog({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenSize.width > 600 ? 500 : screenSize.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.9,
        ),
        decoration: AppTheme.getCompactDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : 'S',
                      style: AppTheme.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: AppTheme.headingSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          student.gradeText,
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildSection(
                      'Basic Information',
                      [
                        _buildInfoRow('Student ID', student.studentId),
                        if (student.rollNumber != null) 
                          _buildInfoRow('Roll Number', student.rollNumber!),
                        if (student.admissionNumber != null)
                          _buildInfoRow('Admission Number', student.admissionNumber!),
                        if (student.dateOfBirth != null)
                          _buildInfoRow('Date of Birth', 
                            '${student.dateOfBirth!.day}/${student.dateOfBirth!.month}/${student.dateOfBirth!.year}'),
                        if (student.age > 0)
                          _buildInfoRow('Age', '${student.age} years'),
                        _buildInfoRow('Status', student.statusText),
                        if (student.academicYear != null)
                          _buildInfoRow('Academic Year', student.academicYear!),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Contact Information
                    if (student.email != null || student.phone != null || student.address != null)
                      _buildSection(
                        'Contact Information',
                        [
                          if (student.email != null) 
                            _buildInfoRow('Email', student.email!),
                          if (student.phone != null)
                            _buildInfoRow('Phone', student.phone!),
                          if (student.address != null)
                            _buildInfoRow('Address', student.address!),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Academic Information
                    _buildSection(
                      'Academic Information',
                      [
                        _buildInfoRow('Grade Level', 'Grade ${student.gradeLevel}'),
                        if (student.section != null)
                          _buildInfoRow('Section', student.section!),
                        _buildInfoRow('Enrollment Status', student.isActive ? 'Active' : 'Inactive'),
                      ],
                    ),

                    // Additional Information (if available)
                    if (student.parentInfo != null && student.parentInfo!.isNotEmpty)
                      ...[
                        const SizedBox(height: 24),
                        _buildSection(
                          'Parent Information',
                          student.parentInfo!.entries
                              .map((entry) => _buildInfoRow(entry.key, entry.value.toString()))
                              .toList(),
                        ),
                      ],

                    if (student.createdAt != null)
                      ...[
                        const SizedBox(height: 24),
                        _buildSection(
                          'System Information',
                          [
                            _buildInfoRow('Created At', 
                              '${student.createdAt!.day}/${student.createdAt!.month}/${student.createdAt!.year}'),
                            if (student.updatedAt != null)
                              _buildInfoRow('Last Updated', 
                                '${student.updatedAt!.day}/${student.updatedAt!.month}/${student.updatedAt!.year}'),
                          ],
                        ),
                      ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.neutral200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Close',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Navigate to edit student
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.greenPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadius12,
                        ),
                      ),
                      child: Text('Edit Student', style: AppTheme.bodyMedium),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.neutral800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.neutral50,
            borderRadius: AppTheme.borderRadius12,
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.neutral800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
