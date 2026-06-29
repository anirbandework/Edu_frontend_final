// lib/features/school_authority/widgets/bulk_import_students_dialog.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/school_session.dart';
import '../../../../services/student_bulk_operations_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkImportStudentsDialog extends StatefulWidget {
  final Function(String message)? onSuccess;
  final Function(String message)? onError;
  final VoidCallback onImportComplete;

  const BulkImportStudentsDialog({
    super.key,
    required this.onImportComplete,
    this.onSuccess,
    this.onError,
  });

  @override
  State<BulkImportStudentsDialog> createState() => _BulkImportStudentsDialogState();
}

class _BulkImportStudentsDialogState extends State<BulkImportStudentsDialog> {
  List<Map<String, dynamic>> _studentsData = [];
  bool _isLoading = false;
  bool _hasUploadedFile = false;
  String? _fileName;
  int _validStudents = 0;
  int _invalidStudents = 0;
  final List<String> _errors = [];

  Future<void> _pickAndProcessFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final csvContent = utf8.decode(bytes); // handles BOM automatically
        _processCsvContent(csvContent, result.files.single.name);
      }
    } catch (e) {
      setState(() => _errors.add('Error picking file: $e'));
    }
  }

  void _processCsvContent(String csvContent, String fileName) {
    try {
      setState(() {
        _isLoading = true;
        _errors.clear();
      });

      final csvTable = const CsvToListConverter(eol: '\n').convert(csvContent);
      if (csvTable.isEmpty) {
        setState(() {
          _errors.add('CSV file is empty');
          _isLoading = false;
        });
        return;
      }

      // Normalize headers (strip BOM, trim, lowercase)
      final List<dynamic> headers = csvTable.first
          .map((h) => h
              .toString()
              .replaceAll('﻿', '') // BOM
              .trim()
              .toLowerCase())
          .toList();

      final List<Map<String, dynamic>> studentsData = [];

      // Process rows
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

        final student = _parseStudentRow(headers, row, i + 1);
        if (student.isNotEmpty) studentsData.add(student);
      }

      setState(() {
        _studentsData = studentsData;
        _fileName = fileName;
        _hasUploadedFile = true;
        _validStudents = studentsData.length;
        _invalidStudents = (csvTable.length - 1) - _validStudents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errors.add('Error processing CSV: $e');
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _parseStudentRow(
    List<dynamic> headers,
    List<dynamic> row,
    int rowNumber,
  ) {
    final Map<String, dynamic> studentData = {};
    final List<String> rowErrors = [];

    try {
      for (int j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j].toString().trim().toLowerCase();
        final cellValue = row[j].toString().trim();
        if (cellValue.isEmpty) continue;

        switch (header) {
          case 'student id':
          case 'student_id':
            studentData['student_id'] = cellValue;
            break;
          case 'first name':
          case 'first_name':
            studentData['first_name'] = cellValue;
            break;
          case 'last name':
          case 'last_name':
            studentData['last_name'] = cellValue;
            break;
          case 'email':
            if (_isValidEmail(cellValue)) {
              studentData['email'] = cellValue;
            } else {
              rowErrors.add('Invalid email format');
            }
            break;
          case 'phone':
            studentData['phone'] = cellValue;
            break;
          case 'date of birth':
          case 'date_of_birth':
          case 'dob':
            try {
              final parsedDate = DateTime.parse(cellValue);
              studentData['date_of_birth'] = parsedDate.toIso8601String();
            } catch (_) {
              rowErrors.add('Invalid date format (use YYYY-MM-DD)');
            }
            break;
          case 'address':
            studentData['address'] = cellValue;
            break;
          case 'admission number':
          case 'admission_number':
            studentData['admission_number'] = cellValue;
            break;
          case 'roll number':
          case 'roll_number':
            studentData['roll_number'] = cellValue;
            break;
          case 'grade level':
          case 'grade_level':
          case 'grade':
            try {
              final grade = int.parse(cellValue);
              if (grade >= 1 && grade <= 12) {
                studentData['grade_level'] = grade;
              } else {
                rowErrors.add('Grade must be between 1-12');
              }
            } catch (_) {
              rowErrors.add('Invalid grade format (must be number)');
            }
            break;
          case 'section':
            studentData['section'] = cellValue.toUpperCase();
            break;
          case 'academic year':
          case 'academic_year':
            studentData['academic_year'] = cellValue;
            break;
        }
      }

      // Required fields
      if (!studentData.containsKey('student_id')) rowErrors.add('Student ID is required');
      if (!studentData.containsKey('first_name')) rowErrors.add('First Name is required');
      if (!studentData.containsKey('last_name')) rowErrors.add('Last Name is required');
      if (!studentData.containsKey('grade_level')) rowErrors.add('Grade Level is required');

      if (rowErrors.isNotEmpty) {
        _errors.add('Row $rowNumber: ${rowErrors.join(', ')}');
        return {};
      }

      // Defaults + tenant
      studentData['tenant_id'] = SchoolSession.tenantId;
      studentData['parent_info'] = {};
      studentData['health_medical_info'] = {};
      studentData['emergency_information'] = {};
      studentData['behavioral_disciplinary'] = {};
      studentData['extended_academic_info'] = {};
      studentData['enrollment_details'] = {};
      studentData['financial_info'] = {};
      studentData['extracurricular_social'] = {};
      studentData['attendance_engagement'] = {};
      studentData['additional_metadata'] = {};

      return studentData;
    } catch (e) {
      _errors.add('Row $rowNumber: Error processing data - $e');
      return {};
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _importStudents() async {
    if (_studentsData.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await StudentBulkOperationsService.importStudents(
        tenantId: SchoolSession.tenantId!,
        students: _studentsData,
      );

      if (!mounted) return;
      // Close dialog first, then notify parent on next frame (avoids SnackBar without Scaffold)
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onImportComplete();
        widget.onSuccess?.call('Successfully imported ${_studentsData.length} students');
      });
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onError?.call('Failed to import students: $e');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _downloadSampleCSV() {
    final csvContent = [
      [
        'student_id',
        'first_name',
        'last_name',
        'email',
        'phone',
        'date_of_birth',
        'address',
        'admission_number',
        'roll_number',
        'grade_level',
        'section',
        'academic_year'
      ],
      [
        'STU001',
        'John',
        'Doe',
        'john.doe@email.com',
        '+1234567890',
        '2010-05-15',
        '123 Main St, City',
        'ADM2024001',
        '001',
        '8',
        'A',
        '2024-2025'
      ],
      [
        'STU002',
        'Jane',
        'Smith',
        'jane.smith@email.com',
        '+1234567891',
        '2011-03-22',
        '456 Oak Ave, City',
        'ADM2024002',
        '002',
        '7',
        'B',
        '2024-2025'
      ],
    ];

    final csvString = const ListToCsvConverter().convert(csvContent);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        final maxW = MediaQuery.of(context).size.width - 24;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Sa.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxW > 520 ? 520 : maxW,
              maxHeight: MediaQuery.of(context).size.height - 120,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('Sample CSV Content', style: Sa.cardTitle),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral50,
                        borderRadius: AppTheme.borderRadius8,
                        border: Border.all(color: Sa.stroke),
                      ),
                      child: Text(
                        csvString,
                        style: Sa.body.copyWith(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
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
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: const Icon(Icons.upload_file, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: Sa.gap),
                  const Expanded(
                    child: Text(
                      'Bulk Import Students',
                      style: Sa.headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    splashRadius: 22,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Sa.gapLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Sa.gapLg),
                      decoration: BoxDecoration(
                        color: AppTheme.green50,
                        borderRadius: BorderRadius.circular(Sa.radius),
                        border: Border.all(color: Sa.accent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Sa.accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'CSV Format Instructions',
                                  style: Sa.cardTitle.copyWith(color: Sa.accent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Upload a CSV file with student data\n'
                            '• Required columns: student_id, first_name, last_name, grade_level\n'
                            '• Optional columns: email, phone, date_of_birth, address, etc.\n'
                            '• Date format should be YYYY-MM-DD\n'
                            '• Grade level should be between 1-12',
                            style: Sa.body,
                          ),
                          const SizedBox(height: Sa.gap),
                          TextButton.icon(
                            onPressed: _downloadSampleCSV,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download Sample CSV'),
                            style: TextButton.styleFrom(
                              foregroundColor: Sa.accent,
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: Sa.gapLg),

                    // File Upload Section
                    if (!_hasUploadedFile) ...[
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                color: AppTheme.neutral50,
                                borderRadius: BorderRadius.circular(Sa.radius),
                                border: Border.all(color: AppTheme.neutral300),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _pickAndProcessFile,
                                  borderRadius: BorderRadius.circular(Sa.radius),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoading)
                                        const CircularProgressIndicator(color: Sa.accent)
                                      else ...[
                                        const Icon(Icons.cloud_upload_outlined,
                                            size: 40, color: AppTheme.neutral500),
                                        const SizedBox(height: 8),
                                        const Text('Upload CSV', style: Sa.label),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: Sa.gapLg),
                            Text(
                              _isLoading ? 'Processing file...' : 'Click to select CSV file',
                              style: Sa.body,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // File Upload Success
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Sa.gapLg),
                        decoration: BoxDecoration(
                          color: AppTheme.green50,
                          borderRadius: BorderRadius.circular(Sa.radius),
                          border: Border.all(color: Sa.accent.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Sa.accent, size: 24),
                                const SizedBox(width: Sa.gap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'File Processed Successfully',
                                        style: Sa.cardTitle.copyWith(color: Sa.accent),
                                      ),
                                      Text(
                                        _fileName ?? '',
                                        style: Sa.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Sa.gap),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                      'Valid Students', '$_validStudents', Sa.accent),
                                ),
                                const SizedBox(width: Sa.gap),
                                Expanded(
                                  child: _buildStatCard(
                                      'Invalid Rows', '$_invalidStudents', AppTheme.error),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: Sa.gapLg),

                      // Errors (if any)
                      if (_errors.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 200),
                          padding: const EdgeInsets.all(Sa.gapLg),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(Sa.radius),
                            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Errors Found:',
                                style: Sa.cardTitle.copyWith(color: AppTheme.error),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: _errors
                                        .map((error) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('• ',
                                                      style: Sa.label
                                                          .copyWith(color: AppTheme.error)),
                                                  Expanded(
                                                    child: Text(
                                                      error,
                                                      style: Sa.label
                                                          .copyWith(color: AppTheme.error),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Sa.gapLg),
                      ],

                      // Upload another file button
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasUploadedFile = false;
                              _studentsData.clear();
                              _errors.clear();
                              _fileName = null;
                              _validStudents = 0;
                              _invalidStudents = 0;
                            });
                          },
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload Different File'),
                          style: TextButton.styleFrom(
                            foregroundColor: Sa.accent,
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(Sa.gapLg),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Sa.stroke)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: SaPrimaryButton(
                      label: _isLoading ? 'Importing…' : 'Import Students',
                      icon: Icons.upload_file,
                      busy: _isLoading,
                      expand: true,
                      onPressed: (_hasUploadedFile && _studentsData.isNotEmpty && !_isLoading)
                          ? _importStudents
                          : null,
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(Sa.gap),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Sa.cardTitle.copyWith(fontSize: 18, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Sa.label.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
