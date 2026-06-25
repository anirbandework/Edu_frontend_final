// lib/features/school_authority/widgets/bulk_import_students_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/school_session.dart';
import '../../../../services/student_bulk_operations_service.dart';

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
  List<String> _errors = [];

  // For help text only
  final Map<String, String> _columnMappings = const {
    'student_id': 'Student ID',
    'first_name': 'First Name',
    'last_name': 'Last Name',
    'email': 'Email',
    'phone': 'Phone',
    'date_of_birth': 'Date of Birth',
    'address': 'Address',
    'admission_number': 'Admission Number',
    'roll_number': 'Roll Number',
    'grade_level': 'Grade Level',
    'section': 'Section',
    'academic_year': 'Academic Year',
  };

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
              .replaceAll('\uFEFF', '') // BOM
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
      builder: (context) => AlertDialog(
        title: const Text('Sample CSV Content'),
        content: SingleChildScrollView(
          child: Text(
            csvString,
            style: AppTheme.bodyMicro.copyWith(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenSize.width > 700 ? 600 : screenSize.width * 0.95,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.9),
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
                  const Icon(Icons.upload_file, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bulk Import Students',
                      style: AppTheme.headingSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
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
                    // Instructions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.1),
                        borderRadius: AppTheme.borderRadius12,
                        border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'CSV Format Instructions',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Upload a CSV file with student data\n'
                            '• Required columns: student_id, first_name, last_name, grade_level\n'
                            '• Optional columns: email, phone, date_of_birth, address, etc.\n'
                            '• Date format should be YYYY-MM-DD\n'
                            '• Grade level should be between 1-12',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.info),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _downloadSampleCSV,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download Sample CSV'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.info,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // File Upload Section
                    if (!_hasUploadedFile) ...[
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppTheme.neutral100,
                                borderRadius: AppTheme.borderRadius12,
                                border: Border.all(color: AppTheme.neutral300),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _pickAndProcessFile,
                                  borderRadius: AppTheme.borderRadius12,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoading)
                                        CircularProgressIndicator(color: AppTheme.greenPrimary)
                                      else ...[
                                        Icon(Icons.cloud_upload_outlined, size: 40, color: AppTheme.neutral500),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Upload CSV',
                                          style: AppTheme.labelSmall.copyWith(
                                            color: AppTheme.neutral600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isLoading ? 'Processing file...' : 'Click to select CSV file',
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // File Upload Success
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: AppTheme.borderRadius12,
                          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.success, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'File Processed Successfully',
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.success,
                                        ),
                                      ),
                                      Text(
                                        _fileName ?? '',
                                        style: AppTheme.bodySmall.copyWith(color: AppTheme.success),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard('Valid Students', '$_validStudents', AppTheme.success),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard('Invalid Rows', '$_invalidStudents', AppTheme.error),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Errors (if any)
                      if (_errors.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: AppTheme.borderRadius12,
                            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Errors Found:',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: _errors
                                        .map((error) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('• ', style: AppTheme.bodyMicro.copyWith(color: AppTheme.error)),
                                                  Expanded(
                                                    child: Text(
                                                      error,
                                                      style: AppTheme.bodyMicro.copyWith(color: AppTheme.error),
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
                        const SizedBox(height: 16),
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
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Upload Different File'),
                        ),
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
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (_hasUploadedFile && _studentsData.isNotEmpty && !_isLoading) ? _importStudents : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.greenPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius12),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text('Importing...', style: AppTheme.bodyMedium),
                              ],
                            )
                          : Text('Import Students', style: AppTheme.bodyMedium),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.bodyMicro.copyWith(color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
