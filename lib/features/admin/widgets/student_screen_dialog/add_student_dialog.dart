// lib/features/school_authority/widgets/add_student_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/student.dart';
import '../../../../core/utils/school_session.dart';
import '../../../../services/student_management_service.dart';

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
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppTheme.bodySmall.copyWith(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                  Icon(Icons.person_add, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add New Student',
                      style: AppTheme.headingSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      Text(
                        'Basic Information',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutral800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // First Name & Last Name Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              style: AppTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'First Name *',
                                labelStyle: AppTheme.bodySmall,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.borderRadius12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              style: AppTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'Last Name *',
                                labelStyle: AppTheme.bodySmall,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.borderRadius12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Student ID & Roll Number Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _studentIdController,
                              style: AppTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'Student ID *',
                                labelStyle: AppTheme.bodySmall,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.borderRadius12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Student ID is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _rollNumberController,
                              style: AppTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'Roll Number',
                                labelStyle: AppTheme.bodySmall,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.borderRadius12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Grade & Section Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _gradeLevel,
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral800),
                              decoration: InputDecoration(
                                labelText: 'Grade *',
                                labelStyle: AppTheme.bodySmall,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.borderRadius12,
                                ),
                              ),
                              items: _grades.map((grade) => DropdownMenuItem(
                                value: grade,
                                child: Text('Grade $grade'),
                              )).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _gradeLevel = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _section,
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral800),
                              decoration: InputDecoration(
                                labelText: 'Section *',
                                labelStyle: AppTheme.bodySmall,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.borderRadius12,
                                ),
                              ),
                              items: _sections.map((section) => DropdownMenuItem(
                                value: section,
                                child: Text('Section $section'),
                              )).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _section = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth
                      InkWell(
                        onTap: _selectDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            labelStyle: AppTheme.bodySmall,
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.borderRadius12,
                            ),
                            suffixIcon: Icon(Icons.calendar_today, color: AppTheme.greenPrimary),
                          ),
                          child: Text(
                            _dateOfBirth != null 
                                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                : 'Select date of birth',
                            style: AppTheme.bodyMedium.copyWith(
                              color: _dateOfBirth != null ? AppTheme.neutral800 : AppTheme.neutral400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contact Information Section
                      Text(
                        'Contact Information',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutral800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        style: AppTheme.bodyMedium,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: AppTheme.bodySmall,
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.borderRadius12,
                          ),
                          prefixIcon: Icon(Icons.email, color: AppTheme.greenPrimary),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        style: AppTheme.bodyMedium,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          labelStyle: AppTheme.bodySmall,
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.borderRadius12,
                          ),
                          prefixIcon: Icon(Icons.phone, color: AppTheme.greenPrimary),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        style: AppTheme.bodyMedium,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          labelStyle: AppTheme.bodySmall,
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.borderRadius12,
                          ),
                          prefixIcon: Icon(Icons.home, color: AppTheme.greenPrimary),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Academic Information Section
                      Text(
                        'Academic Information',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutral800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Admission Number
                      TextFormField(
                        controller: _admissionNumberController,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Admission Number',
                          labelStyle: AppTheme.bodySmall,
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.borderRadius12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Academic Year
                      TextFormField(
                        controller: _academicYearController,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Academic Year',
                          labelStyle: AppTheme.bodySmall,
                          hintText: 'e.g., 2024-2025',
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.borderRadius12,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.greenPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadius12,
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('Creating...', style: AppTheme.bodyMedium),
                              ],
                            )
                          : Text('Create Student', style: AppTheme.bodyMedium),
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
}
