// lib/features/admin/widgets/student_screen_dialog/student_details_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/student.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class StudentDetailsDialog extends StatelessWidget {
  final Student student;

  const StudentDetailsDialog({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 520.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      student.firstName.isNotEmpty
                          ? student.firstName[0].toUpperCase()
                          : 'S',
                      style: Sa.headerTitle,
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          student.fullName,
                          style: Sa.headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          student.gradeText,
                          style: Sa.headerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    splashRadius: 22,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildSection(
                      'Basic Information',
                      Icons.badge_outlined,
                      [
                        SaInfoRow(label: 'Student ID', value: student.studentId),
                        if (student.rollNumber != null)
                          SaInfoRow(
                              label: 'Roll Number',
                              value: student.rollNumber!),
                        if (student.admissionNumber != null)
                          SaInfoRow(
                              label: 'Admission Number',
                              value: student.admissionNumber!),
                        if (student.dateOfBirth != null)
                          SaInfoRow(
                            label: 'Date of Birth',
                            value:
                                '${student.dateOfBirth!.day}/${student.dateOfBirth!.month}/${student.dateOfBirth!.year}',
                          ),
                        if (student.age > 0)
                          SaInfoRow(label: 'Age', value: '${student.age} years'),
                        SaInfoRow(label: 'Status', value: student.statusText),
                        if (student.academicYear != null)
                          SaInfoRow(
                              label: 'Academic Year',
                              value: student.academicYear!),
                      ],
                    ),

                    // Contact Information
                    if (student.email != null ||
                        student.phone != null ||
                        student.address != null) ...[
                      const SizedBox(height: Sa.gapLg),
                      _buildSection(
                        'Contact Information',
                        Icons.contact_mail_outlined,
                        [
                          if (student.email != null)
                            SaInfoRow(label: 'Email', value: student.email!),
                          if (student.phone != null)
                            SaInfoRow(label: 'Phone', value: student.phone!),
                          if (student.address != null)
                            SaInfoRow(label: 'Address', value: student.address!),
                        ],
                      ),
                    ],

                    const SizedBox(height: Sa.gapLg),

                    // Academic Information
                    _buildSection(
                      'Academic Information',
                      Icons.school_outlined,
                      [
                        SaInfoRow(
                            label: 'Grade Level',
                            value: 'Grade ${student.gradeLevel}'),
                        if (student.section != null)
                          SaInfoRow(label: 'Section', value: student.section!),
                        SaInfoRow(
                            label: 'Enrollment Status',
                            value: student.isActive ? 'Active' : 'Inactive'),
                      ],
                    ),

                    // Parent Information (if available)
                    if (student.parentInfo != null &&
                        student.parentInfo!.isNotEmpty) ...[
                      const SizedBox(height: Sa.gapLg),
                      _buildSection(
                        'Parent Information',
                        Icons.family_restroom_outlined,
                        student.parentInfo!.entries
                            .map((entry) => SaInfoRow(
                                  label: entry.key,
                                  value: entry.value.toString(),
                                ))
                            .toList(),
                      ),
                    ],

                    // System Information (if available)
                    if (student.createdAt != null) ...[
                      const SizedBox(height: Sa.gapLg),
                      _buildSection(
                        'System Information',
                        Icons.info_outline,
                        [
                          SaInfoRow(
                            label: 'Created At',
                            value:
                                '${student.createdAt!.day}/${student.createdAt!.month}/${student.createdAt!.year}',
                          ),
                          if (student.updatedAt != null)
                            SaInfoRow(
                              label: 'Last Updated',
                              value:
                                  '${student.updatedAt!.day}/${student.updatedAt!.month}/${student.updatedAt!.year}',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Sa.stroke)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Close', style: Sa.value),
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: SaPrimaryButton(
                      label: 'Edit Student',
                      icon: Icons.edit_outlined,
                      expand: true,
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Navigate to edit student
                      },
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(icon: icon, title: title),
          const SizedBox(height: Sa.gapXs),
          ...children,
        ],
      ),
    );
  }
}
