// lib/features/admin/widgets/student_screen_dialog/add_student_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/school_session.dart';
import '../../../../services/student_management_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class AddStudentDialog extends StatefulWidget {
  final VoidCallback onStudentCreated;

  const AddStudentDialog({
    super.key,
    required this.onStudentCreated,
  });

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _academicYearController = TextEditingController();

  int _gradeLevel = 1;
  String _section = 'A';
  DateTime? _dateOfBirth;
  bool _isLoading = false;

  final List<int> _grades = List.generate(12, (index) => index + 1);
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _studentIdController.dispose();
    _rollNumberController.dispose();
    _admissionNumberController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
    );
    if (date != null) {
      setState(() {
        _dateOfBirth = date;
      });
    }
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final studentData = {
        'tenant_id': SchoolSession.tenantId,
        'student_id': _studentIdController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'date_of_birth': _dateOfBirth?.toIso8601String(),
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'admission_number': _admissionNumberController.text.trim().isNotEmpty
            ? _admissionNumberController.text.trim() : null,
        'roll_number': _rollNumberController.text.trim().isNotEmpty
            ? _rollNumberController.text.trim() : null,
        'grade_level': _gradeLevel,
        'section': _section,
        'academic_year': _academicYearController.text.trim().isNotEmpty
            ? _academicYearController.text.trim() : null,
        'parent_info': {},
        'health_medical_info': {},
        'emergency_information': {},
        'behavioral_disciplinary': {},
        'extended_academic_info': {},
        'enrollment_details': {},
        'financial_info': {},
        'extracurricular_social': {},
        'attendance_engagement': {},
        'additional_metadata': {},
      };

      await StudentManagementService.createStudent(studentData);

      if (mounted) {
        Navigator.pop(context);
        widget.onStudentCreated();
        _showSuccessSnackBar('Student created successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to create student: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: Sa.body.copyWith(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: Sa.body.copyWith(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Shared input styling so every field reads as the green+white system.
  InputDecoration _fieldDecoration(
    String label, {
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: Sa.label,
      hintStyle: Sa.label,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.neutral50,
      border: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: AppTheme.greenPrimary, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: AppTheme.error, width: 1.6),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sa.gap),
      child: Text(title, style: Sa.cardTitle),
    );
  }

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
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
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
                    child: const Icon(Icons.person_add, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: Sa.gap),
                  const Expanded(
                    child: Text(
                      'Add New Student',
                      style: Sa.headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final oneCol = constraints.maxWidth < 600;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Information
                          _sectionTitle('Basic Information'),

                          _responsivePair(
                            oneCol,
                            _firstNameField(),
                            _lastNameField(),
                          ),
                          const SizedBox(height: Sa.gapLg),

                          _responsivePair(
                            oneCol,
                            _studentIdField(),
                            _rollNumberField(),
                          ),
                          const SizedBox(height: Sa.gapLg),

                          _responsivePair(
                            oneCol,
                            _gradeField(),
                            _sectionField(),
                          ),
                          const SizedBox(height: Sa.gapLg),

                          _dateOfBirthField(),
                          const SizedBox(height: 24),

                          // Contact Information
                          _sectionTitle('Contact Information'),
                          _emailField(),
                          const SizedBox(height: Sa.gapLg),
                          _phoneField(),
                          const SizedBox(height: Sa.gapLg),
                          _addressField(),
                          const SizedBox(height: 24),

                          // Academic Information
                          _sectionTitle('Academic Information'),
                          _admissionNumberField(),
                          const SizedBox(height: Sa.gapLg),
                          _academicYearField(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
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
                      child: Text(
                        'Cancel',
                        style: Sa.value.copyWith(color: AppTheme.neutral600),
                      ),
                    ),
                  ),
                  const SizedBox(width: Sa.gapLg),
                  Expanded(
                    child: SaPrimaryButton(
                      label: _isLoading ? 'Creating…' : 'Create Student',
                      icon: Icons.check_rounded,
                      busy: _isLoading,
                      expand: true,
                      onPressed: _isLoading ? null : _createStudent,
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

  // Collapses a two-field row to a single column under ~600px.
  Widget _responsivePair(bool oneCol, Widget a, Widget b) {
    if (oneCol) {
      return Column(
        children: [a, const SizedBox(height: Sa.gapLg), b],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: Sa.gapLg),
        Expanded(child: b),
      ],
    );
  }

  Widget _firstNameField() => TextFormField(
        controller: _firstNameController,
        style: Sa.value,
        decoration: _fieldDecoration('First Name *'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'First name is required';
          }
          return null;
        },
      );

  Widget _lastNameField() => TextFormField(
        controller: _lastNameController,
        style: Sa.value,
        decoration: _fieldDecoration('Last Name *'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Last name is required';
          }
          return null;
        },
      );

  Widget _studentIdField() => TextFormField(
        controller: _studentIdController,
        style: Sa.value,
        decoration: _fieldDecoration('Student ID *'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Student ID is required';
          }
          return null;
        },
      );

  Widget _rollNumberField() => TextFormField(
        controller: _rollNumberController,
        style: Sa.value,
        decoration: _fieldDecoration('Roll Number'),
      );

  Widget _gradeField() => DropdownButtonFormField<int>(
        initialValue: _gradeLevel,
        style: Sa.value,
        decoration: _fieldDecoration('Grade *'),
        items: _grades
            .map((grade) => DropdownMenuItem(
                  value: grade,
                  child: Text('Grade $grade'),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _gradeLevel = value!;
          });
        },
      );

  Widget _sectionField() => DropdownButtonFormField<String>(
        initialValue: _section,
        style: Sa.value,
        decoration: _fieldDecoration('Section *'),
        items: _sections
            .map((section) => DropdownMenuItem(
                  value: section,
                  child: Text('Section $section'),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _section = value!;
          });
        },
      );

  Widget _dateOfBirthField() => InkWell(
        onTap: _selectDateOfBirth,
        borderRadius: AppTheme.borderRadius12,
        child: InputDecorator(
          decoration: _fieldDecoration(
            'Date of Birth',
            suffixIcon: const Icon(Icons.calendar_today, color: AppTheme.greenPrimary),
          ),
          child: Text(
            _dateOfBirth != null
                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                : 'Select date of birth',
            style: Sa.value.copyWith(
              color: _dateOfBirth != null ? AppTheme.neutral800 : AppTheme.neutral400,
            ),
          ),
        ),
      );

  Widget _emailField() => TextFormField(
        controller: _emailController,
        style: Sa.value,
        keyboardType: TextInputType.emailAddress,
        decoration: _fieldDecoration(
          'Email',
          prefixIcon: const Icon(Icons.email, color: AppTheme.greenPrimary),
        ),
        validator: (value) {
          if (value != null && value.trim().isNotEmpty) {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
          }
          return null;
        },
      );

  Widget _phoneField() => TextFormField(
        controller: _phoneController,
        style: Sa.value,
        keyboardType: TextInputType.phone,
        decoration: _fieldDecoration(
          'Phone',
          prefixIcon: const Icon(Icons.phone, color: AppTheme.greenPrimary),
        ),
      );

  Widget _addressField() => TextFormField(
        controller: _addressController,
        style: Sa.value,
        maxLines: 3,
        decoration: _fieldDecoration(
          'Address',
          prefixIcon: const Icon(Icons.home, color: AppTheme.greenPrimary),
        ),
      );

  Widget _admissionNumberField() => TextFormField(
        controller: _admissionNumberController,
        style: Sa.value,
        decoration: _fieldDecoration('Admission Number'),
      );

  Widget _academicYearField() => TextFormField(
        controller: _academicYearController,
        style: Sa.value,
        decoration: _fieldDecoration(
          'Academic Year',
          hintText: 'e.g., 2024-2025',
        ),
      );
}
